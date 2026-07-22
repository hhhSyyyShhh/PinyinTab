# Changelog

All notable changes to PinyinTab are documented here. The project follows Semantic Versioning.

## [Unreleased]

### Fixed

- Fixed the online installer incorrectly rejecting the configured GitHub repository owner.
- Made the repository-owner configuration script reusable after the initial setup.
- Preserved Zsh input while listing ambiguous English and Chinese/Pinyin candidates.

### Documentation

- Expanded the maintainer guide with the complete Git, README, Star History, license, CI, packaging, and release workflow.

### Planned

- Configurable polyphonic phrase dictionary.
- Fish integration and additional release architectures.

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
