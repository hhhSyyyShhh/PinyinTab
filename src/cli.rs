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
    let program = args.next().unwrap_or_default();
    let command = args.next().and_then(|value| value.into_string().ok());

    match command.as_deref() {
        Some("doctor") => {
            println!("{}", doctor_report());
            ExitCode::SUCCESS
        }
        Some("version") | Some("--version") | Some("-V") => {
            println!("{}", version_report());
            ExitCode::SUCCESS
        }
        Some("help") | Some("--help") | Some("-h") => {
            usage(&program);
            ExitCode::SUCCESS
        }
        Some("alias") => {
            let Some(name) = args.next().and_then(|value| value.into_string().ok()) else {
                usage(&program);
                return ExitCode::from(2);
            };
            let aliases = NameMapper.aliases(&name);
            println!("real: {name}");
            println!("full: {}", aliases.full);
            println!("initials: {}", aliases.initials);
            ExitCode::SUCCESS
        }
        Some("complete") => {
            let Some(directory) = args.next().map(PathBuf::from) else {
                usage(&program);
                return ExitCode::from(2);
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
        _ => {
            usage(&program);
            ExitCode::from(2)
        }
    }
}

/// Convert the optional completion flag to a command-aware filter.
fn entry_filter(flag: Option<&OsStr>) -> EntryFilter {
    match flag {
        Some(value) if value == OsStr::new("--directories") => EntryFilter::Directories,
        Some(value) if value == OsStr::new("--files") => EntryFilter::Files,
        Some(value) if value == OsStr::new("--java-classes") => EntryFilter::JavaClasses,
        _ => EntryFilter::Any,
    }
}

/// Print concise CLI usage. The shell-facing completion protocol remains
/// intentionally small because it runs on every Tab press.
fn usage(program: &OsStr) {
    eprintln!(
        "PinyinTab — type Pinyin, press Tab, get the real Chinese path.\n\nUsage:\n  {} doctor\n  {} version\n  {} alias <name>\n  {} complete <directory> <typed-path> [--directories|--files|--java-classes]",
        program.to_string_lossy(),
        program.to_string_lossy(),
        program.to_string_lossy(),
        program.to_string_lossy()
    );
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
    }
}
