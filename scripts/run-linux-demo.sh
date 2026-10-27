#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mount_dir="${1:-/tmp/pinfs-demo-mount}"

mkdir -p "$mount_dir"
cargo build --release --manifest-path "$project_dir/Cargo.toml"
"$project_dir/target/release/pinfs-demo" preview "$project_dir/demo-source"

echo "PinFS is mounted at $mount_dir; keep this terminal open."
exec "$project_dir/target/release/pinfs-demo" mount "$project_dir/demo-source" "$mount_dir"
