#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "error: this test entrypoint is for Linux" >&2
    exit 1
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

echo "[1/4] Rust unit tests"
cargo test

echo "[2/4] Release build"
cargo build --release

echo "[3/4] Bash completion compatibility tests"
PINFS_BINARY="$project_dir/target/release/pinfs-demo" \
    "$project_dir/scripts/test-completion.sh"

echo "[4/4] Environment information"
"$project_dir/target/release/pinfs-demo" doctor
echo "bash: $BASH_VERSION"

echo "PASS: PinFS Linux v0.2.3 test suite"
