# Changelog

All notable changes to PinyinTab are documented here. The project follows Semantic Versioning.

## [Unreleased]

### Planned

- Configurable polyphonic phrase dictionary.
- Fish integration and additional release architectures.

## [0.4.0] - 2026-09-02

### Changed

- Changed normal installations to load the `ptab` command without enabling completion automatically in every new Shell.
- Reinstalling now migrates the installer-managed v0.3 startup block to the new opt-in policy while preserving unrelated Shell configuration and its original backup.
- Expanded the supported Linux matrix from Ubuntu-only validation to Ubuntu 22.04, Ubuntu 24.04, and CentOS Stream 9 on x86_64.

### Added

- Added `--enable-on-startup` for users who explicitly want completion enabled in every new Shell.
- Added installer policy tests and end-to-end tests that install the actual Linux Release archive on Ubuntu and CentOS Stream.
- Added Linux distribution and glibc information to `ptab doctor` to improve compatibility reports.

### Fixed

- Added clear installer failures for missing download/checksum tools and Linux binaries that cannot run on the host.
- Preserved existing Shell startup-file permissions when removing PinyinTab's managed block during uninstall.

### Compatibility

- The Linux Release requires x86_64 and glibc 2.34 or newer.
- CentOS Linux 7/8 and CentOS Stream 8 are not supported; these releases are end-of-life and do not meet the binary runtime baseline.

## [0.3.1] - 2026-07-23

### Fixed

- Fixed the online installer incorrectly rejecting the configured GitHub repository owner.
- Made the repository-owner configuration script reusable after the initial setup.
- Preserved Zsh input while listing ambiguous English and Chinese/Pinyin candidates.

### Added

- Added an Oh My Zsh/Zsh plugin-manager entry point with an isolated CI smoke test.
- Added an LCOV job to CI with a 70% minimum Rust line-coverage gate.

### Changed

- Split the Rust command-line, completion, path-resolution, Pinyin-mapping, and diagnostics code into focused modules.
- Reduced the binary entry point to process startup only and documented the core interfaces.
- Expanded unit coverage for aliases, mixed-script matching, nested paths, ambiguity, command filters, Java classes, diagnostics, and hidden files.
- Added the bootstrap installer to each GitHub Release so installation does not depend on `raw.githubusercontent.com`.

### Documentation

- Added a privacy-checked terminal demonstration and updated installation, compatibility, and architecture documentation.

## [0.3.0] - 2026-07-19

### Added

- Renamed the project to PinyinTab and the management command to `ptab`.
- Added `ptab status`, `ptab doctor`, `ptab version`, and help output.
- Added one-user installers, reversible shell startup configuration, and an uninstaller.
- Added prebuilt release packaging for Linux x86_64 and macOS arm64 with SHA-256 files.
- Added GitHub Actions CI, tag-driven Releases, issue forms, bilingual README files, and Star History integration.
- Added architecture, compatibility, release, contribution, and security documentation.

### Preserved

- Full Pinyin, initials, Chinese prefixes, mixed refinement, nested paths, and command-aware filtering from the v0.2 series.

## [0.2.3] - 2026-07-18

- Added the Linux Bash version and compatibility tests.
- Fixed ambiguous-prefix refinement and completion restoration.

## [0.2.2] - 2026-07-17

- Added nested path resolution and macOS Zsh completion tests.
- Fixed stray slash insertion and file-versus-directory filtering.

## [0.1.0] - 2026-07-15

- Initial Rust proof of concept for mapping Pinyin aliases to Chinese filenames.
