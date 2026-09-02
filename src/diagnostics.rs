use std::env;

#[cfg(target_os = "linux")]
use std::{fs, process::Command};

/// Build the diagnostic report printed by `ptab doctor`.
pub(crate) fn doctor_report() -> String {
    let report = format!(
        "product: PinyinTab\nversion: {}\nplatform: {}\narchitecture: {}\nmode: shell completion (FUSE is not required)",
        env!("CARGO_PKG_VERSION"),
        env::consts::OS,
        env::consts::ARCH
    );

    #[cfg(target_os = "linux")]
    let report = append_linux_details(report);

    report
}

#[cfg(target_os = "linux")]
fn append_linux_details(mut report: String) -> String {
    if let Some(distribution) = linux_distribution() {
        report.push_str("\ndistribution: ");
        report.push_str(&distribution);
    }
    if let Some(libc) = linux_libc() {
        report.push_str("\nlibc: ");
        report.push_str(&libc);
    }
    report
}

/// Build the compact version string printed by `ptab version`.
pub(crate) fn version_report() -> String {
    format!("PinyinTab {}", env!("CARGO_PKG_VERSION"))
}

/// Read the human-friendly Linux distribution name used in bug reports.
#[cfg(target_os = "linux")]
fn linux_distribution() -> Option<String> {
    let os_release = fs::read_to_string("/etc/os-release").ok()?;
    parse_os_release_value(&os_release, "PRETTY_NAME")
}

/// Ask libc's standard configuration utility for the runtime glibc version.
#[cfg(target_os = "linux")]
fn linux_libc() -> Option<String> {
    let output = Command::new("getconf")
        .arg("GNU_LIBC_VERSION")
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let value = String::from_utf8(output.stdout).ok()?;
    let value = value.trim();
    (!value.is_empty()).then(|| value.to_owned())
}

#[cfg(target_os = "linux")]
fn parse_os_release_value(contents: &str, key: &str) -> Option<String> {
    let prefix = format!("{key}=");
    contents.lines().find_map(|line| {
        let value = line.strip_prefix(&prefix)?.trim();
        let value = value
            .strip_prefix('"')
            .and_then(|quoted| quoted.strip_suffix('"'))
            .unwrap_or(value);
        Some(value.replace("\\\"", "\""))
    })
}

#[cfg(test)]
mod tests {
    use super::{doctor_report, version_report};

    #[test]
    fn doctor_contains_release_and_platform_information() {
        let report = doctor_report();
        assert!(report.contains("product: PinyinTab"));
        assert!(report.contains(concat!("version: ", env!("CARGO_PKG_VERSION"))));
        assert!(report.contains("mode: shell completion"));
    }

    #[test]
    fn version_uses_the_cargo_package_version() {
        assert_eq!(
            version_report(),
            concat!("PinyinTab ", env!("CARGO_PKG_VERSION"))
        );
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn parses_pretty_name_from_os_release() {
        let contents = "NAME=Example\nPRETTY_NAME=\"Example Linux 9\"\n";
        assert_eq!(
            super::parse_os_release_value(contents, "PRETTY_NAME"),
            Some("Example Linux 9".to_owned())
        );
    }
}
