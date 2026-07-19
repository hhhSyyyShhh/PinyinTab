# Contributing to PinyinTab

Thank you for improving PinyinTab. Small, reproducible changes with regression tests are preferred.

## Development setup

Rust 1.66 or newer, Bash, and Zsh are required for the full local test suite.

```bash
cargo test --locked
cargo build --release --locked
PINYINTAB_BINARY="$PWD/target/release/ptab" ./scripts/test-completion.sh
PINYINTAB_BINARY="$PWD/target/release/ptab" ./scripts/test-macos.zsh
```

Run formatting and lints before a pull request:

```bash
cargo fmt --all -- --check
cargo clippy --locked --all-targets -- -D warnings
```

## Completion changes

Every completion change should include a test containing:

- the real filename or directory;
- exactly what the user typed;
- the candidate list expected after Tab;
- the shell and command context;
- a negative assertion when the bug involved an unwanted candidate.

Do not silently rename real files, execute a candidate, or make completion depend on a network service.

## Pull requests

Keep a pull request focused. Explain compatibility effects, update user-facing documentation, and add an entry under `Unreleased` in `CHANGELOG.md` for visible behavior changes.

By contributing, you agree that your contribution is licensed under the project's MIT License.
