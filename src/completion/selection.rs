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

#[cfg(test)]
mod tests {
    use super::{contains_han, CandidateLanguage};

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
}
