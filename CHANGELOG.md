# Changelog

All notable changes to PinyinTab are documented here. The project follows Semantic Versioning.

## [Unreleased]

### Planned

- Configurable polyphonic phrase dictionary.
- Fish integration and additional release architectures.

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
