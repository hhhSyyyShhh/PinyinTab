use std::env;
use std::process::ExitCode;

/// Keep the binary entry point deliberately small. Argument handling lives in
/// the library so the completion engine can be tested without spawning a
/// subprocess.
fn main() -> ExitCode {
    pinyintab::cli::run(env::args_os())
}
