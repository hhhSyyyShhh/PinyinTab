use crate::NameMapper;
use std::fs;
use std::path::{Path, PathBuf};

/// Split a typed path into its parent portion and final component.
pub(super) fn split_typed_path(typed: &str) -> (&str, &str) {
    match typed.rsplit_once('/') {
        Some(("", name)) if typed.starts_with('/') => ("/", name),
        Some((parent, name)) => (parent, name),
        None => ("", typed),
    }
}

/// Resolve every parent component to a unique real directory.
pub(super) fn resolve_parent(
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
            "." => append_component(&mut completion_prefix, "."),
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

/// Append one real component using shell-style `/` separators.
fn append_component(prefix: &mut String, component: &str) {
    if !prefix.is_empty() && !prefix.ends_with('/') {
        prefix.push('/');
    }
    prefix.push_str(component);
    prefix.push('/');
}

/// Resolve one Pinyin directory component only when the result is unique.
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
            // Unix permits non-UTF-8 names. The current line-based shell
            // protocol cannot represent them safely, so they are skipped.
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

#[cfg(test)]
mod tests {
    use super::{resolve_parent, split_typed_path};
    use crate::test_support::TestDirectory;
    use std::fs;

    #[test]
    fn splits_relative_absolute_and_nested_paths() {
        assert_eq!(split_typed_path("ceshi.py"), ("", "ceshi.py"));
        assert_eq!(split_typed_path("dir/ceshi.py"), ("dir", "ceshi.py"));
        assert_eq!(split_typed_path("/ceshi.py"), ("/", "ceshi.py"));
        assert_eq!(split_typed_path("dir/"), ("dir", ""));
    }

    #[test]
    fn resolves_a_unique_pinyin_parent() {
        let root = TestDirectory::new("unique-parent");
        fs::create_dir(root.path().join("测试目录")).expect("Chinese directory");

        let (resolved, prefix) =
            resolve_parent(root.path(), "ceshimulu").expect("unique Pinyin parent");
        assert_eq!(resolved, root.path().join("测试目录"));
        assert_eq!(prefix, "测试目录/");
    }

    #[test]
    fn rejects_an_ambiguous_pinyin_parent() {
        let root = TestDirectory::new("ambiguous-parent");
        fs::create_dir(root.path().join("测试")).expect("first directory");
        fs::create_dir(root.path().join("测视")).expect("second directory");

        let error = resolve_parent(root.path(), "ce").expect_err("ambiguous parent");
        assert_eq!(error.kind(), std::io::ErrorKind::NotFound);
    }
}
