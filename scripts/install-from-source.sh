#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

if ! command -v cargo >/dev/null 2>&1; then
    echo "error: Rust/Cargo is required for a source installation" >&2
    exit 1
fi

cargo test --locked
cargo build --release --locked
exec "$project_dir/install.sh" "$@"
