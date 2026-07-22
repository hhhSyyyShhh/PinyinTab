use std::env;

/// Build the diagnostic report printed by `ptab doctor`.
pub(crate) fn doctor_report() -> String {
    format!(
        "product: PinyinTab\nversion: {}\nplatform: {}\narchitecture: {}\nmode: shell completion (FUSE is not required)",
        env!("CARGO_PKG_VERSION"),
        env::consts::OS,
        env::consts::ARCH
    )
}

/// Build the compact version string printed by `ptab version`.
pub(crate) fn version_report() -> String {
    format!("PinyinTab {}", env!("CARGO_PKG_VERSION"))
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
}
