# Changelog

All notable changes to PinyinTab are documented here. The project follows Semantic Versioning.

## [Unreleased]

### Documentation

- Shortened the bilingual project description and public documentation; installation, verification and compatibility instructions are retained.
- Clarified the project description to say "complete the Chinese path".
- Kept the PinFS source imports (0.1.0 and 0.2.0–0.2.4) on `archive/early-prototypes` and their tags; removed the backfilled Release entries to avoid mixing import dates with the release chronology. The current release remains 0.6.1.

### Planned

- Configurable polyphonic phrase dictionary.
- Fish integration and additional release architectures.

## [0.6.1] - 2026-10-27

- First published release of complete-name switching and `ptab update`.
- Bound retries for Linux `ETXTBSY` when starting a freshly copied test fixture; do not retry or mask updater failures.

## [0.6.0] - 2026-10-27

> Tag retained for traceability. The release workflow stopped on an intermittent Linux test-fixture startup error before publishing archives; use v0.6.1.

### Added

- Switch a complete existing Chinese name to whole-name Pinyin/initial counterparts with Control+X then e, or back with c, without a previous Tab snapshot. Numbers, extensions and command filters remain significant.
- Added `ptab update` for installed releases, with platform selection, SHA-256 and binary validation, no automatic downgrade, staged replacement, rollback and bounded cleanup. Startup settings and personal files are preserved.

### Fixed

- Explicit language requests with multiple matches display candidates without replacing the query with an unrelated common prefix.
- Validate archive paths and reject links/special entries before extracting online downloads.

### Testing

- Added complete-name, CLI-dispatch, real-terminal and offline update-transaction regression tests, including failed-download, checksum, rollback and cleanup cases.
- Existing release targets, default-off policy and native Control+C/E bindings are unchanged.

## [0.5.1] - 2026-10-27

### Fixed

- Used Readline's supported `vi-insert` keymap name instead of `vi-insertion`, removing Bash enable/disable warnings and registering the selectors in vi insertion mode.
- Added an assertion that interactive startup contains no invalid-keymap diagnostic.

### Testing

- Run the full real-terminal regression suite separately in default and vi insertion editing modes on both Bash 5 and Zsh.
- Retain v0.5.0's four language-selection operations, exact-name precedence, default-off installation and release platforms.

## [0.5.0] - 2026-10-27

> Superseded by v0.5.1: the Bash vi keymap name in v0.5.0 could produce binding warnings and leave selectors unregistered in vi mode. Tags and archives are retained unchanged.

### Added

- Added one-shot Chinese/non-Han selection: Control+X then c/e in Bash 5 and Zsh, before completion or immediately after an unchanged Tab result.
- Retained the original query while switching groups, including numbered collisions and nested paths. Editing the line or moving the cursor prevents stale-query replacement.
- Added `--language all|auto|chinese|english` before the directory in both diagnostic completion interfaces; language selection still obeys command and type filters.
- Installed a standalone uninstaller under `~/.local/share/pinyintab/uninstall.sh`.

### Fixed

- Complete real names such as `c.py` and `cs1.py` no longer expand as abbreviated stems under normal Tab.
- Non-empty interactive queries prefer non-Han names when available; otherwise Pinyin completion remains available. Empty words show both groups.
- Chinese-only misses do not fall back to native English filename completion.
- Restored previous Tab and selector bindings on `ptab off`; bare Control+C/E remain native.
- Respected Zsh's `ZDOTDIR` during install and uninstall.

### Documentation and tests

- Made Chinese the default README, retained English at `README.en.md` and the old Chinese URL as a compatibility link.
- Split beginner installation into download, check, install, reopen, verify and enable steps; clarified network failures, SHA-256 and offline installation.
- Added exact-name, language-group, numeric-collision, CLI and real-terminal key regressions. Vim's normal-mode `p` paste was diagnosed separately and is not a PinyinTab code-generation feature.
- Kept release platforms, default-off installation and Tab-before-Enter semantics unchanged.

## [0.4.2] - 2026-09-03

### Added

- Added structured help with command descriptions, options, examples and scope notes.
- Added explicit Chinese help (`ptab help zh`) and a separate advanced protocol reference (`ptab help advanced [en|zh]`).

### Fixed

- Unified Bash, Zsh and binary help through one versioned reference; normal help now uses stdout and exits successfully.
- Added actionable stderr diagnostics for unknown commands and invalid help arguments.
- Rejected extra arguments to shell state and informational commands before changing state.
- Exposed the documented `complete-command` diagnostic interface through both shell wrappers.

### Testing

- Added help selection/rendering unit tests, CLI stream/exit-status tests, and shell help parity/state-preservation tests.
- Validated help from installed Release archives on the existing platform matrix.

### Compatibility

- Completion matching, release targets and the default-off installation policy are unchanged.

## [0.4.1] - 2026-09-03

### Fixed

- Connected command-position completion for `./`, `../`, and absolute executable paths in Bash 5 and Zsh, including common wrappers and pipelines.
- Kept directories as intermediate path candidates for file commands.
- Centralized command context classification; left common pattern, expression, permission, module and numeric operands unchanged.
- Added native-tool bindings, Zsh file-redirection handling and reversible command-position hooks.
- Skipped filenames containing control characters in the line-based protocol.
- Added timeouts and retries to all online-installer downloads, including checksums, and cleaned staging files after successful installation.

### Testing

- Added executable-permission, symlink, control-character, command-context and CLI regressions.
- Added real PTY Tab-key tests for Bash/Zsh: buffer insertion, spaces, harmless executable invocation and off restoration.

### Compatibility

- Release platforms and the default-off policy remain unchanged.
- `PINYINTAB_EXTRA_COMMANDS` optionally registers local-path tools; complex option grammars and remote paths still require adapters.

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
