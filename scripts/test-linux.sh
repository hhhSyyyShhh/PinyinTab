#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "error: this test entrypoint is for Linux" >&2
    exit 1
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

echo "[1/4] Rust unit tests"
cargo test --locked

echo "[2/4] Release build"
cargo build --release --locked

echo "[3/4] Bash completion compatibility tests"
PINYINTAB_BINARY="$project_dir/target/release/ptab" \
    "$project_dir/scripts/test-completion.sh"

echo "[4/4] Environment information"
"$project_dir/target/release/ptab" doctor
echo "bash: $BASH_VERSION"

echo "PASS: PinyinTab Linux v0.3.0 test suite"
