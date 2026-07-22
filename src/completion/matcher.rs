use crate::NameMapper;

/// Match either a direct prefix or a stem prefix with an exact extension.
pub(super) fn candidate_matches(candidate: &str, typed: &str) -> bool {
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

/// Match a real Chinese prefix followed by Pinyin for the remaining text.
///
/// This supports the two-stage interaction where Zsh first inserts a common
/// real prefix such as `九九`, after which the user types `cheng` to select
/// `九九乘法表.py`.
pub(super) fn mixed_candidate_matches(mapper: &NameMapper, candidate: &str, typed: &str) -> bool {
    // Boundaries come from UTF-8 character indices so slicing never splits a
    // multibyte Chinese character.
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

#[cfg(test)]
mod tests {
    use super::{candidate_matches, mixed_candidate_matches};
    use crate::NameMapper;

    #[test]
    fn matches_direct_prefixes() {
        assert!(candidate_matches("README.md", "READ"));
        assert!(!candidate_matches("README.md", "read"));
    }

    #[test]
    fn compares_extensions_separately() {
        assert!(candidate_matches("jjcfb.py", "jj.py"));
        assert!(!candidate_matches("jiujiuchengfabiao.py", "jj.rs"));
    }

    #[test]
    fn matches_chinese_prefix_plus_pinyin_suffix() {
        let mapper = NameMapper;
        assert!(mixed_candidate_matches(
            &mapper,
            "九九乘法表.py",
            "九九cheng.py"
        ));
        assert!(mixed_candidate_matches(
            &mapper,
            "九九乘法表.py",
            "九九cf.py"
        ));
        assert!(!mixed_candidate_matches(
            &mapper,
            "九九乘法表.py",
            "九九chu.py"
        ));
    }
}
