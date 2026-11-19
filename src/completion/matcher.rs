use crate::NameMapper;

/// Match either a direct prefix or a stem prefix with an exact extension.
pub(super) fn candidate_matches(candidate: &str, typed: &str) -> bool {
    candidate_matches_with_case(candidate, typed, false)
}

/// Apply ASCII case folding only to aliases created by transliteration.
/// Literal names still follow the case-sensitive comparison above.
pub(super) fn pinyin_candidate_matches(alias: &str, real: &str, typed: &str) -> bool {
    alias != real && candidate_matches_with_case(alias, typed, true)
}

pub(super) fn ascii_prefix(candidate: &str, typed: &str) -> bool {
    candidate
        .get(..typed.len())
        .map_or(false, |prefix| prefix.eq_ignore_ascii_case(typed))
}

fn candidate_matches_with_case(candidate: &str, typed: &str, fold_ascii: bool) -> bool {
    let starts_with = |name: &str, query: &str| {
        if fold_ascii {
            ascii_prefix(name, query)
        } else {
            name.starts_with(query)
        }
    };
    if starts_with(candidate, typed) {
        return true;
    }

    let Some((typed_stem, typed_extension)) = typed.rsplit_once('.') else {
        return false;
    };
    let Some((candidate_stem, candidate_extension)) = candidate.rsplit_once('.') else {
        return false;
    };

    let same_extension = if fold_ascii {
        candidate_extension.eq_ignore_ascii_case(typed_extension)
    } else {
        candidate_extension == typed_extension
    };
    same_extension && starts_with(candidate_stem, typed_stem)
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
        if pinyin_candidate_matches(&aliases.full, candidate_remainder, typed_remainder)
            || pinyin_candidate_matches(&aliases.initials, candidate_remainder, typed_remainder)
        {
            return true;
        }
    }

    false
}

#[cfg(test)]
mod tests {
    use super::{candidate_matches, mixed_candidate_matches, pinyin_candidate_matches};
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
    fn folds_ascii_case_only_for_transliterated_aliases() {
        assert!(pinyin_candidate_matches("Cyuyan.c", "C语言.c", "cyu.C"));
        assert!(!pinyin_candidate_matches("Cyuyan.c", "C语言.c", "cyu.rs"));
        assert!(!pinyin_candidate_matches("lower.c", "lower.c", "LOW"));
        assert!(!pinyin_candidate_matches("Cyuyan.c", "C语言.c", "C语"));
        assert!(mixed_candidate_matches(
            &NameMapper,
            "C语言API.c",
            "C语yanapi.c"
        ));
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
