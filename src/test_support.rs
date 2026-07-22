use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

static NEXT_TEST_DIRECTORY: AtomicU64 = AtomicU64::new(0);

/// A unique temporary directory owned by exactly one test.
///
/// Keeping this helper in the standard library avoids adding a runtime-irrelevant
/// dependency while still ensuring cleanup can never target the project tree.
pub(crate) struct TestDirectory {
    path: PathBuf,
}

impl TestDirectory {
    pub(crate) fn new(label: &str) -> Self {
        let sequence = NEXT_TEST_DIRECTORY.fetch_add(1, Ordering::Relaxed);
        let path = std::env::temp_dir().join(format!(
            "pinyintab-test-{}-{label}-{sequence}",
            std::process::id()
        ));
        fs::create_dir(&path).expect("create unique test directory");
        Self { path }
    }

    pub(crate) fn path(&self) -> &Path {
        &self.path
    }
}

impl Drop for TestDirectory {
    fn drop(&mut self) {
        // The path is constructed internally from the system temporary root,
        // process ID and an atomic sequence; it never accepts a caller path.
        let _ = fs::remove_dir_all(&self.path);
    }
}
