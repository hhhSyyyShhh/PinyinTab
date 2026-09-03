//! Command-line interface used by the `ptab` executable and shell wrappers.

use crate::completion::{complete, EntryFilter};
use crate::diagnostics::{doctor_report, version_report};
use crate::NameMapper;
use std::ffi::{OsStr, OsString};
use std::path::PathBuf;
use std::process::ExitCode;

/// Parse and execute one `ptab` command.
///
/// Returning `ExitCode` instead of calling `process::exit` keeps ownership of
/// process termination in the small binary entry point and makes the command
/// dispatcher easier to exercise in tests.
pub fn run<I>(args: I) -> ExitCode
where
    I: IntoIterator<Item = OsString>,
{
    let mut args = args.into_iter();
    // The first item is the executable name, not a user argument.
    let _program = args.next();
    let command = match args.next() {
        Some(value) => match value.into_string() {
            Ok(value) => Some(value),
            Err(_) => return usage_error("command name must be valid UTF-8"),
        },
        None => None,
    };

    if matches!(
        command.as_deref(),
        Some("doctor" | "version" | "--version" | "-V")
    ) && args.next().is_some()
    {
        return usage_error("this command does not accept extra arguments");
    }

    match command.as_deref() {
        Some("doctor") => {
            println!("{}", doctor_report());
            ExitCode::SUCCESS
        }
        Some("version") | Some("--version") | Some("-V") => {
            println!("{}", version_report());
            ExitCode::SUCCESS
        }
        Some("help") | Some("--help") | Some("-h") | None => show_help(&args.collect::<Vec<_>>()),
        Some("alias") => {
            let Some(name) = args.next().and_then(|value| value.into_string().ok()) else {
                return usage_error("expected: ptab alias <name>");
            };
            let aliases = NameMapper.aliases(&name);
            println!("real: {name}");
            println!("full: {}", aliases.full);
            println!("initials: {}", aliases.initials);
            ExitCode::SUCCESS
        }
        Some("complete") => {
            let Some(directory) = args.next().map(PathBuf::from) else {
                return usage_error("expected: ptab complete <directory> <typed-path> [filter]");
            };
            let typed = args
                .next()
                .and_then(|value| value.into_string().ok())
                .unwrap_or_default();
            let filter = entry_filter(args.next().as_deref());
            match complete(&directory, &typed, filter) {
                Ok(candidates) => {
                    for candidate in candidates {
                        println!("{candidate}");
                    }
                    ExitCode::SUCCESS
                }
                Err(error) => {
                    eprintln!("error: {error}");
                    ExitCode::FAILURE
                }
            }
        }
        Some("complete-command") => {
            let Some(directory) = args.next().map(PathBuf::from) else {
                return usage_error(
                    "expected: ptab complete-command <directory> <word-index> <words...>",
                );
            };
            let Some(index) = args
                .next()
                .and_then(|v| v.into_string().ok())
                .and_then(|v| v.parse::<usize>().ok())
            else {
                return usage_error("word-index must be a non-negative integer");
            };
            let words: Vec<String> = match args.map(|v| v.into_string()).collect() {
                Ok(words) => words,
                Err(_) => return usage_error("command words must be valid UTF-8"),
            };
            let Some(filter) = crate::context::path_context(&words, index) else {
                return ExitCode::SUCCESS;
            };
            match complete(&directory, &words[index], filter) {
                Ok(candidates) => {
                    for candidate in candidates {
                        println!("{candidate}");
                    }
                    ExitCode::SUCCESS
                }
                Err(error) => {
                    eprintln!("error: {error}");
                    ExitCode::FAILURE
                }
            }
        }
        Some("on" | "off" | "status") => usage_error(
            "on/off/status require the Bash/Zsh integration to be loaded in the current shell",
        ),
        Some(unknown) => usage_error(&format!("unknown command: {unknown:?}")),
    }
}

/// Convert the optional completion flag to a command-aware filter.
fn entry_filter(flag: Option<&OsStr>) -> EntryFilter {
    match flag {
        Some(value) if value == OsStr::new("--directories") => EntryFilter::Directories,
        Some(value) if value == OsStr::new("--files") => EntryFilter::Files,
        Some(value) if value == OsStr::new("--java-classes") => EntryFilter::JavaClasses,
        Some(value) if value == OsStr::new("--executables") => EntryFilter::Executables,
        _ => EntryFilter::Any,
    }
}

/// Help is successful output, not a diagnostic; it must be pipeable.
fn show_help(args: &[OsString]) -> ExitCode {
    match crate::help::render(args) {
        Ok(text) => {
            print!("{text}");
            ExitCode::SUCCESS
        }
        Err(message) => usage_error(message),
    }
}

/// Keep usage errors short and out of the completion candidate stream.
fn usage_error(message: &str) -> ExitCode {
    eprintln!("error: {message}\nTry 'ptab --help' or 'ptab help advanced'.");
    ExitCode::from(2)
}

#[cfg(test)]
mod tests {
    use super::entry_filter;
    use crate::completion::EntryFilter;
    use std::ffi::OsStr;

    #[test]
    fn parses_completion_filters() {
        assert_eq!(
            entry_filter(Some(OsStr::new("--directories"))),
            EntryFilter::Directories
        );
        assert_eq!(
            entry_filter(Some(OsStr::new("--files"))),
            EntryFilter::Files
        );
        assert_eq!(
            entry_filter(Some(OsStr::new("--java-classes"))),
            EntryFilter::JavaClasses
        );
        assert_eq!(entry_filter(None), EntryFilter::Any);
        assert_eq!(
            entry_filter(Some(OsStr::new("--executables"))),
            EntryFilter::Executables
        );
    }
}
