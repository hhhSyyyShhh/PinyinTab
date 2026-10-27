//! Filesystem candidate generation for Bash and Zsh.

mod matcher;
mod path;
mod selection;

pub use selection::CandidateLanguage;

use crate::completion::matcher::{candidate_matches, mixed_candidate_matches};
use crate::completion::path::{resolve_parent, split_typed_path};
use crate::NameMapper;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;

/// Restricts candidates according to the command being completed.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EntryFilter {
    /// Return files and directories.
    Any,
    /// Return directories only, for commands such as `cd`.
    Directories,
    /// Return regular path entries but not directories.
    Files,
    /// Return top-level Java class names without the `.class` suffix.
    JavaClasses,
    /// Executable regular files, plus directories for further path navigation.
    Executables,
}

/// Generate real filesystem candidates for one shell word.
///
/// The function scans only the directory currently being completed. Parent
/// components are resolved one level at a time, which avoids recursively
/// walking an entire project on every Tab press.
pub fn complete(
    current_directory: &Path,
    typed: &str,
    filter: EntryFilter,
) -> std::io::Result<Vec<String>> {
    complete_with_language(current_directory, typed, filter, CandidateLanguage::All)
}

/// Apply language selection after command/type filtering, while never letting
/// a Pinyin alias override a complete real name in the selected language.
pub fn complete_with_language(
    current_directory: &Path,
    typed: &str,
    filter: EntryFilter,
    language: CandidateLanguage,
) -> std::io::Result<Vec<String>> {
    let (typed_parent, typed_name) = split_typed_path(typed);
    if matches!(filter, EntryFilter::JavaClasses) && !typed_parent.is_empty() {
        return Ok(Vec::new());
    }
    let (search_directory, completion_prefix) = resolve_parent(current_directory, typed_parent)?;
    let mapper = NameMapper;
    let mut matches = Vec::new();

    for entry in fs::read_dir(search_directory)? {
        let entry = entry?;
        let is_directory = entry.path().is_dir();
        if matches!(filter, EntryFilter::Executables) && !is_directory {
            let metadata = match fs::metadata(entry.path()) {
                Ok(metadata) => metadata,
                Err(_) => continue,
            };
            if !metadata.is_file() || metadata.permissions().mode() & 0o111 == 0 {
                continue;
            }
        }
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
        // The shell protocol is line-based. Never turn one control-bearing
        // filename into several candidates or terminal control instructions.
        if real_name.chars().any(char::is_control) {
            continue;
        }
        let completion_name = if matches!(filter, EntryFilter::JavaClasses) {
            let Some(class_name) = real_name.strip_suffix(".class") else {
                continue;
            };
            // Java compilers generate `Outer$Inner.class`; these are not
            // independent main-class names and should not pollute completion.
            if class_name.contains('$') {
                continue;
            }
            class_name
        } else {
            &real_name
        };
        if !language.accepts(completion_name) {
            continue;
        }
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
        // Exact real names are not abbreviations. In Chinese-only mode an
        // English collision was excluded above, so an explicit request can
        // still select 测试.py even when the real cs.py exists.
        if completion_name == typed_name {
            return Ok(vec![completion]);
        }
        matches.push((completion, selection::contains_han(completion_name)));
    }

    // An empty word starts a new argument (or a new directory component): show
    // all names instead of hiding Chinese entries merely because English ones
    // are also present. Explicit Chinese/English requests remain filtered.
    if language == CandidateLanguage::Auto
        && !typed_name.is_empty()
        && matches.iter().any(|(_, chinese)| !chinese)
    {
        matches.retain(|(_, chinese)| !chinese);
    }
    let mut paths: Vec<String> = matches.into_iter().map(|(path, _)| path).collect();
    paths.sort();
    paths.dedup();
    Ok(paths)
}

#[cfg(test)]
mod tests {
    use super::{complete, complete_with_language, CandidateLanguage, EntryFilter};
    use crate::test_support::TestDirectory;
    use std::fs;
    use std::os::unix::fs::{symlink, PermissionsExt};

    #[test]
    fn executable_paths_preserve_prefix_and_filter_permissions() {
        let root = TestDirectory::new("executables");
        fs::write(root.path().join("运行程序"), "#!/bin/sh\nexit 0\n").unwrap();
        fs::set_permissions(
            root.path().join("运行程序"),
            fs::Permissions::from_mode(0o755),
        )
        .unwrap();
        fs::write(root.path().join("运行说明.txt"), "text").unwrap();
        fs::create_dir(root.path().join("运行目录")).unwrap();
        let found = complete(root.path(), "./yunxing", EntryFilter::Executables).unwrap();
        assert!(found.contains(&"./运行程序".to_owned()));
        assert!(found.contains(&"./运行目录/".to_owned()));
        assert!(!found.contains(&"./运行说明.txt".to_owned()));
        let absolute = format!("{}/yunxingcheng", root.path().display());
        assert_eq!(
            complete(root.path(), &absolute, EntryFilter::Executables).unwrap(),
            vec![format!("{}/运行程序", root.path().display())]
        );
    }

    #[test]
    fn executable_symlinks_follow_target_and_skip_broken_links() {
        let root = TestDirectory::new("exec-links");
        fs::write(root.path().join("程序"), "#!/bin/sh\n").unwrap();
        fs::set_permissions(root.path().join("程序"), fs::Permissions::from_mode(0o755)).unwrap();
        symlink("程序", root.path().join("链接程序")).unwrap();
        symlink("missing", root.path().join("链接失效")).unwrap();
        assert_eq!(
            complete(root.path(), "./lianjie", EntryFilter::Executables).unwrap(),
            vec!["./链接程序"]
        );
    }

    #[test]
    fn line_protocol_rejects_control_bearing_names() {
        let root = TestDirectory::new("control-names");
        fs::write(root.path().join("测试\n文本"), "text").unwrap();
        fs::create_dir(root.path().join("测试\t目录")).unwrap();
        fs::write(root.path().join("测试.txt"), "text").unwrap();
        assert_eq!(
            complete(root.path(), "ce", EntryFilter::Any).unwrap(),
            vec!["测试.txt"]
        );
    }

    #[test]
    fn returns_literal_english_and_chinese_pinyin_matches() {
        let root = TestDirectory::new("cross-script");
        fs::create_dir(root.path().join("test")).expect("English directory");
        fs::create_dir(root.path().join("图片")).expect("Chinese directory");

        let matches = complete(root.path(), "t", EntryFilter::Directories).expect("completion");
        assert!(matches.contains(&"test/".to_owned()));
        assert!(matches.contains(&"图片/".to_owned()));
    }

    #[test]
    fn exact_real_file_is_not_expanded_as_a_stem_prefix() {
        let root = TestDirectory::new("exact-real");
        for name in ["c.py", "cs.py", "测试.py"] {
            fs::write(root.path().join(name), []).unwrap();
        }
        for name in ["c.py", "cs.py", "测试.py"] {
            assert_eq!(
                complete(root.path(), name, EntryFilter::Any).unwrap(),
                vec![name]
            );
        }
        assert_eq!(
            complete_with_language(
                root.path(),
                "cs.py",
                EntryFilter::Any,
                CandidateLanguage::Chinese
            )
            .unwrap(),
            vec!["测试.py"]
        );
    }

    #[test]
    fn auto_prefers_english_but_empty_arguments_show_both() {
        let root = TestDirectory::new("language-auto");
        for name in ["cs.py", "测试.py"] {
            fs::write(root.path().join(name), []).unwrap();
        }
        let query = |typed, language| {
            complete_with_language(root.path(), typed, EntryFilter::Any, language).unwrap()
        };
        assert_eq!(query("cs", CandidateLanguage::Auto), vec!["cs.py"]);
        assert_eq!(
            query("cs", CandidateLanguage::All),
            vec!["cs.py", "测试.py"]
        );
        assert_eq!(query("ceshi.py", CandidateLanguage::Auto), vec!["测试.py"]);
        assert_eq!(query("", CandidateLanguage::Auto), vec!["cs.py", "测试.py"]);
        assert_eq!(
            query("ceshi", CandidateLanguage::English),
            Vec::<String>::new()
        );
    }

    #[test]
    fn numbered_collisions_and_nested_leaves_are_filtered_independently() {
        let root = TestDirectory::new("language-numbered");
        let parent = root.path().join("测试目录");
        fs::create_dir(&parent).unwrap();
        for name in [
            "cs1.py",
            "cs2.py",
            "cs3.py",
            "测试1.py",
            "测试2.py",
            "测试3.py",
        ] {
            fs::write(parent.join(name), []).unwrap();
        }
        let query = |typed, language| {
            complete_with_language(root.path(), typed, EntryFilter::Any, language).unwrap()
        };
        assert_eq!(
            query("csml/cs1.py", CandidateLanguage::Auto),
            vec!["测试目录/cs1.py"]
        );
        assert_eq!(
            query("csml/cs1.py", CandidateLanguage::Chinese),
            vec!["测试目录/测试1.py"]
        );
        assert_eq!(
            query("csml/cs", CandidateLanguage::Chinese),
            vec![
                "测试目录/测试1.py",
                "测试目录/测试2.py",
                "测试目录/测试3.py"
            ]
        );
        assert_eq!(
            query("csml/cs", CandidateLanguage::English),
            vec!["测试目录/cs1.py", "测试目录/cs2.py", "测试目录/cs3.py"]
        );
    }

    #[test]
    fn missing_real_file_remains_a_query_and_directories_still_navigate() {
        let root = TestDirectory::new("missing-exact");
        fs::write(root.path().join("cs.py"), []).unwrap();
        fs::write(root.path().join("测试.py"), []).unwrap();
        assert_eq!(
            complete(root.path(), "c.py", EntryFilter::Any).unwrap(),
            vec!["cs.py", "测试.py"]
        );
        fs::create_dir(root.path().join("c.py")).unwrap();
        assert_eq!(
            complete(root.path(), "c.py", EntryFilter::Directories).unwrap(),
            vec!["c.py/"]
        );
        assert!(complete(root.path(), "c.py/", EntryFilter::Any)
            .unwrap()
            .is_empty());
        // A disallowed exact file must not bypass the command's type filter.
        assert!(complete(root.path(), "cs.py", EntryFilter::Directories)
            .unwrap()
            .is_empty());
    }

    #[test]
    fn resolves_nested_pinyin_paths() {
        let root = TestDirectory::new("nested-path");
        let nested = root.path().join("测试目录");
        fs::create_dir(&nested).expect("parent directory");
        fs::write(nested.join("内部脚本.py"), "print('ok')").expect("nested file");

        let matches = complete(root.path(), "ceshimulu/neibu", EntryFilter::Files)
            .expect("nested completion");
        assert_eq!(matches, vec!["测试目录/内部脚本.py"]);
    }

    #[test]
    fn filters_files_and_directories_by_command_context() {
        let root = TestDirectory::new("entry-filter");
        fs::create_dir(root.path().join("你好")).expect("directory");
        fs::write(root.path().join("你好.txt"), "hello").expect("file");

        let directories =
            complete(root.path(), "nihao", EntryFilter::Directories).expect("directories");
        assert_eq!(directories, vec!["你好/"]);

        let files = complete(root.path(), "nihao", EntryFilter::Files).expect("files");
        assert_eq!(files, vec!["你好.txt"]);
    }

    #[test]
    fn returns_only_top_level_java_classes_without_extensions() {
        let root = TestDirectory::new("java-classes");
        fs::write(root.path().join("乘法表.class"), []).expect("main class");
        fs::write(root.path().join("乘法表$内部.class"), []).expect("inner class");

        let matches =
            complete(root.path(), "chengfabiao", EntryFilter::JavaClasses).expect("classes");
        assert_eq!(matches, vec!["乘法表"]);
    }

    #[test]
    fn hides_dotfiles_for_an_empty_query() {
        let root = TestDirectory::new("dotfiles");
        fs::write(root.path().join(".hidden"), []).expect("hidden file");
        fs::write(root.path().join("visible"), []).expect("visible file");

        let matches = complete(root.path(), "", EntryFilter::Any).expect("completion");
        assert_eq!(matches, vec!["visible"]);
    }
}
