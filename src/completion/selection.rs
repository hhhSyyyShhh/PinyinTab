//! Candidate language selection, independent of command and file-type filters.

/// Controls which *final path components* may be returned.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum CandidateLanguage {
    /// Keep both literal and Pinyin matches (the diagnostic protocol default).
    #[default]
    All,
    /// Prefer non-Han names for a non-empty query, falling back to Han names.
    Auto,
    /// Names containing a Han character, including mixed Chinese/ASCII names.
    Chinese,
    /// Names without Han characters; not restricted to ASCII or English words.
    English,
}

impl CandidateLanguage {
    /// Parse the stable shell protocol spelling without locale-dependent rules.
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "all" => Some(Self::All),
            "auto" => Some(Self::Auto),
            "chinese" => Some(Self::Chinese),
            "english" => Some(Self::English),
            _ => None,
        }
    }

    pub(super) fn accepts(self, name: &str) -> bool {
        match self {
            Self::Chinese => contains_han(name),
            Self::English => !contains_han(name),
            Self::All | Self::Auto => true,
        }
    }
}

/// Identify Han script blocks rather than treating every non-ASCII name as
/// Chinese. A Chinese parent directory must not classify an English leaf as
/// Chinese, so callers pass the final component only.
pub(super) fn contains_han(name: &str) -> bool {
    name.chars().any(|character| {
        matches!(character as u32,
            0x3400..=0x4dbf | 0x4e00..=0x9fff | 0xf900..=0xfaff |
            0x20000..=0x2fa1f | 0x30000..=0x323af)
    })
}

/// Compare complete names across scripts, not prefixes. In particular,
/// 测试.py must not switch to cs1.py merely because `cs` is its initials.
pub(super) fn equivalent_name(source: &str, candidate: &str) -> bool {
    let mapper = crate::NameMapper;
    let (chinese, latin) = match (contains_han(source), contains_han(candidate)) {
        (true, false) => (source, candidate),
        (false, true) => (candidate, source),
        _ => return false,
    };
    let aliases = mapper.aliases(chinese);
    aliases.full.eq_ignore_ascii_case(latin) || aliases.initials.eq_ignore_ascii_case(latin)
}

#[cfg(test)]
mod tests {
    use super::{contains_han, equivalent_name, CandidateLanguage};

    #[test]
    fn distinguishes_han_from_other_non_ascii_names() {
        for name in ["测试.py", "test测试1.py", "\u{20000}.txt"] {
            assert!(contains_han(name), "{name}");
        }
        for name in ["cs1.py", "café.txt", "данные.txt", "📄.txt"] {
            assert!(!contains_han(name), "{name}");
        }
    }

    #[test]
    fn parses_only_documented_language_values() {
        for value in ["all", "auto", "chinese", "english"] {
            assert!(CandidateLanguage::parse(value).is_some());
        }
        assert_eq!(CandidateLanguage::parse("zh"), None);
        assert_eq!(CandidateLanguage::parse(""), None);
    }

    #[test]
    fn complete_equivalence_preserves_numbers_extensions_and_mixed_names() {
        for (chinese, latin) in [
            ("测试.py", "cs.py"),
            ("测试.py", "ceshi.py"),
            ("测试1.py", "CS1.py"),
            ("测试-v2.py", "cs-v2.py"),
            ("项目 说明.txt", "xm sm.txt"),
        ] {
            assert!(equivalent_name(chinese, latin));
            assert!(equivalent_name(latin, chinese));
        }
        for candidate in ["c.py", "cs1.py", "cs.txt", "cs.py.bak", "测视.py"] {
            assert!(!equivalent_name("测试.py", candidate), "{candidate}");
        }
    }
}
