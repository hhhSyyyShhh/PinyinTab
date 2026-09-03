//! Shared help text for the binary and both shell integrations.
//!
//! Help is deliberately independent of locale and completion state. English is
//! the default; `ptab help zh` selects Chinese even on an English-language server.
//! Keeping text in the binary also prevents Bash and Zsh descriptions drifting.

use std::ffi::OsString;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Language {
    English,
    Chinese,
}

/// Validate the small help grammar without consulting or changing shell state.
fn selection(args: &[OsString]) -> Result<(bool, Language), &'static str> {
    let mut words = args.iter();
    let first = words.next().map(|word| word.to_str());
    let (advanced, language) = if first == Some(Some("advanced")) {
        (true, words.next().map(|word| word.to_str()))
    } else {
        (false, first)
    };
    let language = match language {
        None | Some(Some("en")) => Language::English,
        Some(Some("zh")) => Language::Chinese,
        _ => return Err("expected: ptab help [advanced] [en|zh]"),
    };
    if words.next().is_some() {
        return Err("expected: ptab help [advanced] [en|zh]");
    }
    Ok((advanced, language))
}

/// Render the same versioned help page regardless of how `ptab` is invoked.
pub(crate) fn render(args: &[OsString]) -> Result<String, &'static str> {
    let (advanced, language) = selection(args)?;
    let text = match (advanced, language) {
        (false, Language::English) => include_str!("help/en.txt"),
        (false, Language::Chinese) => include_str!("help/zh.txt"),
        (true, Language::English) => include_str!("help/advanced-en.txt"),
        (true, Language::Chinese) => include_str!("help/advanced-zh.txt"),
    };
    Ok(format!("PinyinTab {}\n\n{text}", env!("CARGO_PKG_VERSION")))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn args(words: &[&str]) -> Vec<OsString> {
        words.iter().map(OsString::from).collect()
    }

    #[test]
    fn selects_general_help_languages() {
        assert_eq!(selection(&[]), Ok((false, Language::English)));
        assert_eq!(selection(&args(&["en"])), Ok((false, Language::English)));
        assert_eq!(selection(&args(&["zh"])), Ok((false, Language::Chinese)));
    }

    #[test]
    fn selects_advanced_help_languages() {
        assert_eq!(
            selection(&args(&["advanced"])),
            Ok((true, Language::English))
        );
        assert_eq!(
            selection(&args(&["advanced", "zh"])),
            Ok((true, Language::Chinese))
        );
    }

    #[test]
    fn rejects_unknown_or_surplus_help_arguments() {
        for words in [
            &["fr"][..],
            &["zh", "en"],
            &["advanced", "extra"],
            &["advanced", "en", "extra"],
        ] {
            assert!(selection(&args(words)).is_err());
        }
    }

    #[test]
    fn renders_versioned_help_with_separate_protocol_reference() {
        for language in ["en", "zh"] {
            let general = render(&args(&[language])).unwrap();
            assert!(general.starts_with(&format!("PinyinTab {}", env!("CARGO_PKG_VERSION"))));
            assert!(general.contains("ptab on"));
            assert!(general.contains("<Tab>"));
            assert!(!general.contains("complete-command <"));
            let advanced = render(&args(&["advanced", language])).unwrap();
            assert!(advanced.contains("ptab complete-command <directory> <word-index> <words...>"));
            assert!(advanced.contains("--executables"));
        }
    }
}
