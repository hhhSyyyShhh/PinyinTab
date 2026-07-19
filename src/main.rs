use pinyintab::NameMapper;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Clone, Copy)]
enum EntryFilter {
    Any,
    Directories,
    Files,
    JavaClasses,
}

fn main() {
    let mut args = env::args_os();
    let program = args.next().unwrap_or_default();
    let command = args.next().and_then(|value| value.into_string().ok());

    match command.as_deref() {
        Some("doctor") => doctor(),
        Some("version") | Some("--version") | Some("-V") => version(),
        Some("help") | Some("--help") | Some("-h") => usage(&program, 0),
        Some("alias") => {
            let name = args
                .next()
                .and_then(|value| value.into_string().ok())
                .unwrap_or_else(|| usage(&program, 2));
            let aliases = NameMapper.aliases(&name);
            println!("real: {name}");
            println!("full: {}", aliases.full);
            println!("initials: {}", aliases.initials);
        }
        Some("complete") => {
            let directory = args
                .next()
                .map(PathBuf::from)
                .unwrap_or_else(|| usage(&program, 2));
            let typed = args
                .next()
                .and_then(|value| value.into_string().ok())
                .unwrap_or_default();
            let filter = match args.next().as_deref() {
                Some(value) if value == std::ffi::OsStr::new("--directories") => {
                    EntryFilter::Directories
                }
                Some(value) if value == std::ffi::OsStr::new("--files") => EntryFilter::Files,
                Some(value) if value == std::ffi::OsStr::new("--java-classes") => {
                    EntryFilter::JavaClasses
                }
                _ => EntryFilter::Any,
            };
            complete(&directory, &typed, filter).unwrap_or_else(|error| fail(error));
        }
        _ => usage(&program, 2),
    }
}

fn complete(current_directory: &Path, typed: &str, filter: EntryFilter) -> std::io::Result<()> {
    let (typed_parent, typed_name) = split_typed_path(typed);
    if matches!(filter, EntryFilter::JavaClasses) && !typed_parent.is_empty() {
        return Ok(());
    }
    let (search_directory, completion_prefix) = resolve_parent(current_directory, typed_parent)?;
    let mapper = NameMapper;
    let mut matches = Vec::new();

    for entry in fs::read_dir(search_directory)? {
        let entry = entry?;
        let is_directory = entry.path().is_dir();
        if matches!(filter, EntryFilter::Directories) && !is_directory {
            continue;
        }
        if matches!(filter, EntryFilter::Files | EntryFilter::JavaClasses) && is_directory {
            continue;
        }
        let real_name = match entry.file_name().into_string() {
            Ok(name) => name,
            Err(_) => continue,
        };
        let completion_name = if matches!(filter, EntryFilter::JavaClasses) {
            let Some(class_name) = real_name.strip_suffix(".class") else {
                continue;
            };
            if class_name.contains('$') {
                continue;
            }
            class_name
        } else {
            &real_name
        };
        let aliases = mapper.aliases(completion_name);
        if typed_name.is_empty() && completion_name.starts_with('.') {
            continue;
        }
        let typed_pinyin = typed_name.to_ascii_lowercase();
        if !candidate_matches(completion_name, typed_name)
            && !candidate_matches(&aliases.full, &typed_pinyin)
            && !candidate_matches(&aliases.initials, &typed_pinyin)
            && !mixed_candidate_matches(&mapper, completion_name, typed_name)
        {
            continue;
        }

        let mut completion = format!("{completion_prefix}{completion_name}");
        if is_directory {
            completion.push('/');
        }
        matches.push(completion);
    }

    matches.sort();
    for candidate in matches {
        println!("{candidate}");
    }
    Ok(())
}

fn candidate_matches(candidate: &str, typed: &str) -> bool {
    if candidate.starts_with(typed) {
        return true;
    }

    let Some((typed_stem, typed_extension)) = typed.rsplit_once('.') else {
        return false;
    };
    let Some((candidate_stem, candidate_extension)) = candidate.rsplit_once('.') else {
        return false;
    };

    candidate_extension == typed_extension && candidate_stem.starts_with(typed_stem)
}

fn mixed_candidate_matches(mapper: &NameMapper, candidate: &str, typed: &str) -> bool {
    let mut boundaries: Vec<usize> = candidate.char_indices().map(|(index, _)| index).collect();
    boundaries.push(candidate.len());

    for boundary in boundaries.into_iter().rev() {
        if boundary == 0 {
            continue;
        }

        let real_prefix = &candidate[..boundary];
        if !typed.starts_with(real_prefix) {
            continue;
        }

        let typed_remainder = &typed[boundary..];
        if typed_remainder.is_empty() {
            return true;
        }

        let candidate_remainder = &candidate[boundary..];
        let aliases = mapper.aliases(candidate_remainder);
        let typed_pinyin = typed_remainder.to_ascii_lowercase();
        if candidate_matches(&aliases.full, &typed_pinyin)
            || candidate_matches(&aliases.initials, &typed_pinyin)
        {
            return true;
        }
    }

    false
}

fn split_typed_path(typed: &str) -> (&str, &str) {
    match typed.rsplit_once('/') {
        Some(("", name)) if typed.starts_with('/') => ("/", name),
        Some((parent, name)) => (parent, name),
        None => ("", typed),
    }
}

fn resolve_parent(
    current_directory: &Path,
    typed_parent: &str,
) -> std::io::Result<(PathBuf, String)> {
    let absolute = typed_parent.starts_with('/');
    let mut search_directory = if absolute {
        PathBuf::from("/")
    } else {
        current_directory.to_path_buf()
    };
    let mut completion_prefix = if absolute {
        String::from("/")
    } else {
        String::new()
    };

    for component in typed_parent.split('/') {
        if component.is_empty() {
            continue;
        }

        match component {
            "." => {
                append_component(&mut completion_prefix, ".");
            }
            ".." => {
                search_directory.push("..");
                append_component(&mut completion_prefix, "..");
            }
            _ => {
                let real_component = resolve_directory_component(&search_directory, component)?;
                search_directory.push(&real_component);
                append_component(&mut completion_prefix, &real_component);
            }
        }
    }

    Ok((search_directory, completion_prefix))
}

fn append_component(prefix: &mut String, component: &str) {
    if !prefix.is_empty() && !prefix.ends_with('/') {
        prefix.push('/');
    }
    prefix.push_str(component);
    prefix.push('/');
}

fn resolve_directory_component(directory: &Path, typed: &str) -> std::io::Result<String> {
    let mapper = NameMapper;
    let typed_pinyin = typed.to_ascii_lowercase();
    let mut exact_aliases = Vec::new();
    let mut prefix_aliases = Vec::new();

    for entry in fs::read_dir(directory)? {
        let entry = entry?;
        if !entry.path().is_dir() {
            continue;
        }
        let real_name = match entry.file_name().into_string() {
            Ok(name) => name,
            Err(_) => continue,
        };
        if real_name == typed {
            return Ok(real_name);
        }

        let aliases = mapper.aliases(&real_name);
        if aliases.full == typed_pinyin || aliases.initials == typed_pinyin {
            exact_aliases.push(real_name);
        } else if aliases.full.starts_with(&typed_pinyin)
            || aliases.initials.starts_with(&typed_pinyin)
        {
            prefix_aliases.push(real_name);
        }
    }

    exact_aliases.sort();
    exact_aliases.dedup();
    if exact_aliases.len() == 1 {
        return Ok(exact_aliases.remove(0));
    }

    prefix_aliases.sort();
    prefix_aliases.dedup();
    if exact_aliases.is_empty() && prefix_aliases.len() == 1 {
        return Ok(prefix_aliases.remove(0));
    }

    Err(std::io::Error::new(
        std::io::ErrorKind::NotFound,
        format!("cannot uniquely resolve directory component: {typed}"),
    ))
}

fn doctor() {
    println!("product: PinyinTab");
    println!("version: {}", env!("CARGO_PKG_VERSION"));
    println!("platform: {}", env::consts::OS);
    println!("architecture: {}", env::consts::ARCH);
    println!("mode: shell completion (FUSE is not required)");
}

fn version() {
    println!("PinyinTab {}", env!("CARGO_PKG_VERSION"));
}

fn fail(error: std::io::Error) -> ! {
    eprintln!("error: {error}");
    std::process::exit(1)
}

fn usage(program: &std::ffi::OsStr, exit_code: i32) -> ! {
    eprintln!(
        "PinyinTab — type Pinyin, press Tab, get the real Chinese path.\n\nUsage:\n  {} doctor\n  {} version\n  {} alias <name>\n  {} complete <directory> <typed-path> [--directories|--files|--java-classes]",
        program.to_string_lossy(),
        program.to_string_lossy(),
        program.to_string_lossy(),
        program.to_string_lossy()
    );
    std::process::exit(exit_code)
}
