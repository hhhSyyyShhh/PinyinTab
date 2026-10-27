use pinfs_demo::NameMapper;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

fn main() {
    let mut args = env::args_os();
    let program = args.next().unwrap_or_default();
    let command = args.next().and_then(|value| value.into_string().ok());

    match command.as_deref() {
        Some("doctor") => doctor(),
        Some("alias") => {
            let name = args
                .next()
                .and_then(|value| value.into_string().ok())
                .unwrap_or_else(|| usage(&program));
            let aliases = NameMapper.aliases(&name);
            println!("real: {name}");
            println!("full: {}", aliases.full);
            println!("initials: {}", aliases.initials);
        }
        Some("complete") => {
            let directory = args
                .next()
                .map(PathBuf::from)
                .unwrap_or_else(|| usage(&program));
            let typed = args
                .next()
                .and_then(|value| value.into_string().ok())
                .unwrap_or_default();
            let directories_only =
                args.next().as_deref() == Some(std::ffi::OsStr::new("--directories"));
            complete(&directory, &typed, directories_only).unwrap_or_else(|error| fail(error));
        }
        _ => usage(&program),
    }
}

fn complete(current_directory: &Path, typed: &str, directories_only: bool) -> std::io::Result<()> {
    let typed_path = Path::new(typed);
    let typed_parent = typed_path.parent().unwrap_or_else(|| Path::new(""));
    let typed_name = typed_path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("");
    let search_directory = current_directory.join(typed_parent);
    let mapper = NameMapper;
    let mut matches = Vec::new();

    for entry in fs::read_dir(search_directory)? {
        let entry = entry?;
        let is_directory = entry.path().is_dir();
        if directories_only && !is_directory {
            continue;
        }
        let real_name = match entry.file_name().into_string() {
            Ok(name) => name,
            Err(_) => continue,
        };
        let aliases = mapper.aliases(&real_name);
        if typed_name.is_empty() && real_name.starts_with('.') {
            continue;
        }
        if !real_name.starts_with(typed_name)
            && !aliases.full.starts_with(typed_name)
            && !aliases.initials.starts_with(typed_name)
        {
            continue;
        }

        let mut completion = typed_parent.join(real_name).to_string_lossy().into_owned();
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

fn doctor() {
    println!("platform: {}", env::consts::OS);
    println!("mode: shell completion (FUSE is not required)");
}

fn fail(error: std::io::Error) -> ! {
    eprintln!("error: {error}");
    std::process::exit(1)
}

fn usage(program: &std::ffi::OsStr) -> ! {
    eprintln!(
        "Usage:\n  {} doctor\n  {} alias <name>\n  {} complete <directory> <typed-path> [--directories]",
        program.to_string_lossy(),
        program.to_string_lossy(),
        program.to_string_lossy()
    );
    std::process::exit(2)
}
