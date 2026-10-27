//! Launch the updater installed beside this executable, never a PATH lookup.
//!
//! The helper owns staging, verification and rollback. Keeping it separate
//! means the running executable can be replaced by rename on Linux as well.

use std::path::Path;
use std::process::Command;

/// Source checkouts are deliberately not silently replaced with a binary
/// release. Only the normal `<prefix>/bin/ptab` layout has an updater.
pub(crate) fn run() -> Result<bool, String> {
    let executable = std::env::current_exe().map_err(|error| error.to_string())?;
    let root = installation_root(&executable)
        .ok_or("ptab update requires an installed release; run the installer first")?;
    let helper = root.join("share/pinyintab/update.sh");
    if !helper.is_file() {
        return Err("updater is missing; install the latest release once to repair it".into());
    }
    let status = Command::new("bash")
        .arg(helper)
        .args(["--update", env!("CARGO_PKG_VERSION")])
        .env("PINYINTAB_INSTALL_ROOT", root)
        .status()
        .map_err(|error| format!("could not start updater: {error}"))?;
    Ok(status.success())
}

fn installation_root(executable: &Path) -> Option<&Path> {
    let directory = executable.parent()?;
    if directory.file_name()? != "bin" || executable.file_name()? != "ptab" {
        return None;
    }
    directory.parent().filter(|root| root.parent().is_some())
}

#[cfg(test)]
mod tests {
    use super::installation_root;
    use std::path::Path;

    #[test]
    fn accepts_only_an_installed_non_root_prefix() {
        assert_eq!(
            installation_root(Path::new("/home/me/.local/bin/ptab")),
            Some(Path::new("/home/me/.local"))
        );
        for name in ["/bin/ptab", "/tmp/target/release/ptab", "/tmp/bin/other"] {
            assert!(installation_root(Path::new(name)).is_none());
        }
    }
}
