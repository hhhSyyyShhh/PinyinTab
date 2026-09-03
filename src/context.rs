//! Conservative classification of already-tokenized shell words.
//!
//! This is not a shell parser: the shell owns quoting, expansion and execution.
//! Known non-path operands are left alone; command-specific DSLs still need
//! dedicated adapters. Both shells use this module to avoid policy drift.

use crate::completion::EntryFilter;

/// Return the candidate policy at a zero-based word index, or leave it native.
pub fn path_context(words: &[String], index: usize) -> Option<EntryFilter> {
    let typed = words.get(index)?;
    if typed.starts_with('-')
        || typed.starts_with('$')
        || typed.starts_with('~')
        || typed.contains(':')
    {
        return None;
    }
    if index > 0 {
        let previous = words[index - 1].trim_start_matches(|c: char| c.is_ascii_digit());
        match previous {
            "<" | ">" | ">>" | "<>" | ">|" | "&>" | "&>>" => return Some(EntryFilter::Any),
            "<<" | "<<-" | "<<<" | ">&" | "<&" => return None,
            _ => {}
        }
    }
    let mut command_index = words[..index]
        .iter()
        .rposition(|word| matches!(word.as_str(), "|" | "||" | "&&" | ";" | "&" | "("))
        .map_or(0, |position| position + 1);
    while command_index < index && is_assignment(&words[command_index]) {
        command_index += 1;
    }
    // Peel only documented common wrapper forms. Unknown options are not
    // guessed, because their next operand might be a username or expression.
    loop {
        let command = words.get(command_index)?.rsplit('/').next()?;
        if !matches!(command, "sudo" | "command" | "exec" | "env") || command_index == index {
            break;
        }
        command_index += 1;
        while command_index < index {
            let word = words[command_index].as_str();
            if word == "--" {
                command_index += 1;
                break;
            }
            if command == "env" && is_assignment(word) {
                command_index += 1;
                continue;
            }
            let takes_value = match command {
                "sudo" => matches!(word, "-u" | "-g" | "-h" | "-p" | "-C" | "-T" | "-R" | "-D"),
                "env" => matches!(word, "-u" | "--unset" | "-C" | "--chdir"),
                _ => false,
            };
            if takes_value {
                command_index += 2;
                continue;
            }
            if word.starts_with('-') {
                if !matches!(word, "-n" | "-E" | "-H" | "-p" | "-i" | "-l") {
                    return None;
                }
                command_index += 1;
            } else {
                break;
            }
        }
    }
    if command_index > index {
        return None;
    }
    if command_index == index {
        return typed.contains('/').then_some(EntryFilter::Executables);
    }
    let command = words[command_index].rsplit('/').next()?;
    let before = &words[command_index + 1..index];
    let previous = before.last().map(String::as_str).unwrap_or("");
    // Common coreutils options consume numbers/delimiters, not paths.
    if matches!(
        (command, previous),
        ("head" | "tail", "-n" | "-c" | "--lines" | "--bytes")
            | (
                "cut",
                "-d" | "-f" | "-b" | "-c" | "--delimiter" | "--fields" | "--bytes" | "--characters"
            )
            | ("sort", "-k" | "-t" | "--key" | "--field-separator")
            | ("du", "-d" | "--max-depth")
            | ("diff", "-I" | "--ignore-matching-lines")
    ) {
        return None;
    }
    if matches!(
        previous,
        "-c" | "-e" | "--eval" | "--regexp" | "--expression"
    ) {
        return None;
    }
    if command.starts_with("python")
        && before
            .iter()
            .any(|word| matches!(word.as_str(), "-c" | "-m"))
    {
        return None;
    }
    if matches!(
        command,
        "bash" | "sh" | "zsh" | "node" | "ruby" | "perl" | "julia"
    ) && before
        .iter()
        .any(|word| matches!(word.as_str(), "-c" | "-e" | "--eval"))
    {
        return None;
    }
    match command {
        "cd" | "rmdir" | "pushd" => Some(EntryFilter::Directories),
        "echo" | "printf" | "export" | "unset" | "alias" | "tr" => None,
        "grep" | "egrep" | "fgrep" | "rg" | "sed" | "awk" | "gawk" => pattern_command(before),
        "find" => (!before
            .iter()
            .any(|word| word.starts_with('-') || word == "("))
        .then_some(EntryFilter::Directories),
        "chmod" | "chown" | "chgrp" => {
            // First operand is a mode/owner/group, not a filename.
            before
                .iter()
                .any(|word| !word.starts_with('-'))
                .then_some(EntryFilter::Any)
        }
        "java" => {
            if previous == "-jar" || matches!(previous, "-cp" | "-classpath" | "--class-path") {
                Some(EntryFilter::Any)
            } else if before.is_empty() {
                Some(EntryFilter::JavaClasses)
            } else {
                None
            }
        }
        _ => Some(EntryFilter::Any),
    }
}

fn is_assignment(word: &str) -> bool {
    let Some((name, _)) = word.split_once('=') else { return false; };
    !name.is_empty()
        && name
            .chars()
            .enumerate()
            .all(|(i, c)| c == '_' || c.is_ascii_alphabetic() || (i > 0 && c.is_ascii_digit()))
}

/// grep/sed/awk need a pattern or expression before file operands. Handle
/// common explicit -e/-f forms and leave unknown option arity untouched.
fn pattern_command(before: &[String]) -> Option<EntryFilter> {
    let mut pattern_seen = false;
    let mut pending: Option<bool> = None;
    let mut options = true;
    for word in before {
        if pending.take().is_some() {
            pattern_seen = true;
            continue;
        }
        if options && word == "--" {
            options = false;
            continue;
        }
        if options
            && matches!(
                word.as_str(),
                "-e" | "--regexp" | "--expression" | "-f" | "--file"
            )
        {
            pending = Some(matches!(word.as_str(), "-f" | "--file"));
        } else if options
            && (word.starts_with("-e")
                || word.starts_with("-f")
                || word.starts_with("--regexp=")
                || word.starts_with("--expression=")
                || word.starts_with("--file="))
        {
            pattern_seen = true;
        } else if options && word.starts_with('-') {
            if !matches!(
                word.as_str(),
                "-n" | "-r"
                    | "-R"
                    | "-i"
                    | "-v"
                    | "-E"
                    | "-F"
                    | "-q"
                    | "-l"
                    | "-c"
                    | "-s"
                    | "-w"
                    | "-x"
                    | "-H"
                    | "-h"
            ) {
                return None;
            }
        } else {
            pattern_seen = true;
        }
    }
    match pending {
        Some(true) => Some(EntryFilter::Any),
        Some(false) => None,
        None => pattern_seen.then_some(EntryFilter::Any),
    }
}

#[cfg(test)]
mod tests {
    use super::path_context;
    use crate::completion::EntryFilter::{Any, Directories, Executables, JavaClasses};

    fn check(words: &[&str], expected: Option<crate::completion::EntryFilter>) {
        let words: Vec<String> = words.iter().map(|s| s.to_string()).collect();
        assert_eq!(path_context(&words, words.len() - 1), expected, "{words:?}");
    }

    #[test]
    fn command_positions_and_wrappers() {
        for words in [
            vec!["./ce"],
            vec!["../ce"],
            vec!["/tmp/ce"],
            vec!["true", "&&", "./ce"],
            vec!["cat", "a", "|", "./ce"],
            vec!["sudo", "./ce"],
            vec!["sudo", "-u", "root", "./ce"],
            vec!["env", "LANG=C", "./ce"],
            vec!["X=1", "./ce"],
        ] {
            check(&words, Some(Executables));
        }
        check(&["ls"], None);
        check(&["sudo", "-u", "ro"], None);
        check(&["command", "-v", "ca"], None);
        check(&["sudo", "-u", "root", "cat", "ce"], Some(Any));
    }

    #[test]
    fn native_file_commands_and_redirections() {
        for command in [
            "cat", "ls", "stat", "file", "wc", "sort", "uniq", "diff", "du", "cp", "mv", "rm",
            "ln", "readlink", "realpath", "tee", "head", "tail",
        ] {
            check(&[command, "ce"], Some(Any));
        }
        check(&["cd", "ce"], Some(Directories));
        check(&["cat", "<", "ce"], Some(Any));
        check(&["java", ">", "ce"], Some(Any));
        check(&["cat", "2>", "ce"], Some(Any));
        check(&["cat", "<<", "ce"], None);
        check(&["cat", ">&", "ce"], None);
        check(&["echo", "ce"], None);
        check(&["cut", "-d", "ce"], None);
        check(&["head", "-n", "ce"], None);
        check(&["sort", "-k", "ce"], None);
        check(&["tr", "ce"], None);
    }

    #[test]
    fn patterns_and_permissions_are_not_paths() {
        for command in ["grep", "sed", "awk", "rg"] {
            check(&[command, "ce"], None);
            check(&[command, "pattern", "ce"], Some(Any));
            check(&[command, "-e", "ce"], None);
            check(&[command, "-f", "ce"], Some(Any));
            check(&[command, "-e", "pattern", "ce"], Some(Any));
        }
        check(&["grep", "-n", "ce"], None);
        check(&["grep", "-A", "ce"], None);
        check(&["find", "ce"], Some(Directories));
        check(&["find", ".", "-name", "ce"], None);
        check(&["chmod", "ce"], None);
        check(&["chmod", "+x", "ce"], Some(Any));
        check(&["chown", "root", "ce"], Some(Any));
    }

    #[test]
    fn language_options_and_nonlocal_inputs() {
        check(&["python3.12", "ce"], Some(Any));
        check(&["python3", "-m", "ce"], None);
        check(&["bash", "-c", "ce"], None);
        check(&["java", "ce"], Some(JavaClasses));
        check(&["java", "-jar", "ce"], Some(Any));
        check(&["java", "-cp", "ce"], Some(Any));
        check(&["cat", "--file=ce"], None);
        check(&["scp", "host:ce"], None);
        check(&["cat", "$HOME/ce"], None);
        assert_eq!(path_context(&[], 0), None);
    }
}
