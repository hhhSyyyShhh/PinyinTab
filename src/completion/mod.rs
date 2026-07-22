//! Filesystem candidate generation for Bash and Zsh.

mod matcher;
mod path;

use crate::completion::matcher::{candidate_matches, mixed_candidate_matches};
use crate::completion::path::{resolve_parent, split_typed_path};
use crate::NameMapper;
use std::fs;
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
            // Java compilers generate `Outer$Inner.class`; these are not
            // independent main-class names and should not pollute completion.
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
    Ok(matches)
}

#[cfg(test)]
mod tests {
    use super::{complete, EntryFilter};
    use crate::test_support::TestDirectory;
    use std::fs;

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
