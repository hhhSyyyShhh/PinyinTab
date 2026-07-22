use pinyin::ToPinyin;

/// Search aliases generated for one real filesystem name.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Aliases {
    /// Tone-free full Pinyin while preserving non-Chinese characters.
    pub full: String,
    /// The first letter of each Pinyin syllable.
    pub initials: String,
}

/// Converts real names into full-Pinyin and initial-letter aliases.
#[derive(Debug, Default)]
pub struct NameMapper;

impl NameMapper {
    /// Generate aliases without changing the real name on disk.
    pub fn aliases(&self, name: &str) -> Aliases {
        let mut full = String::new();
        let mut initials = String::new();
        let mut rest = name;

        while !rest.is_empty() {
            // Phrase overrides are checked before individual characters because
            // some Chinese characters have context-dependent pronunciations.
            if let Some((phrase, reading, abbreviated)) = phrase_reading(rest) {
                full.push_str(reading);
                initials.push_str(abbreviated);
                rest = &rest[phrase.len()..];
                continue;
            }

            let ch = rest.chars().next().expect("non-empty input");
            rest = &rest[ch.len_utf8()..];
            if let Some(reading) = ch.to_pinyin() {
                let plain = reading.plain();
                full.push_str(plain);
                initials.push(plain.chars().next().expect("non-empty pinyin"));
            } else {
                // Extensions, numbers, spaces and punctuation must remain
                // searchable exactly as they appear in the real name.
                full.push(ch);
                initials.push(ch);
            }
        }

        Aliases { full, initials }
    }
}

/// Return the longest known phrase reading at the beginning of `input`.
fn phrase_reading(input: &str) -> Option<(&'static str, &'static str, &'static str)> {
    const READINGS: &[(&str, &str, &str)] = &[
        ("重庆", "chongqing", "cq"),
        ("银行", "yinhang", "yh"),
        ("行长", "hangzhang", "hz"),
    ];
    READINGS
        .iter()
        .find(|(phrase, _, _)| input.starts_with(phrase))
        .copied()
}

#[cfg(test)]
mod tests {
    use super::NameMapper;

    #[test]
    fn maps_python_file() {
        let aliases = NameMapper.aliases("测试.py");
        assert_eq!(aliases.full, "ceshi.py");
        assert_eq!(aliases.initials, "cs.py");
    }

    #[test]
    fn maps_mixed_file() {
        let aliases = NameMapper.aliases("项目-v2说明.md");
        assert_eq!(aliases.full, "xiangmu-v2shuoming.md");
        assert_eq!(aliases.initials, "xm-v2sm.md");
    }

    #[test]
    fn applies_phrase_pronunciation_before_single_characters() {
        let aliases = NameMapper.aliases("重庆银行");
        assert_eq!(aliases.full, "chongqingyinhang");
        assert_eq!(aliases.initials, "cqyh");
    }

    #[test]
    fn preserves_ascii_names() {
        let aliases = NameMapper.aliases("test-v2.rs");
        assert_eq!(aliases.full, "test-v2.rs");
        assert_eq!(aliases.initials, "test-v2.rs");
    }
}
