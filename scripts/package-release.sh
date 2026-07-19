#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

target="${1:-}"
case "$target" in
    x86_64-unknown-linux-gnu|aarch64-apple-darwin)
        ;;
    *)
        echo "Usage: $0 x86_64-unknown-linux-gnu|aarch64-apple-darwin" >&2
        exit 2
        ;;
esac

version="$(sed -n 's/^version = "\([^"]*\)"/\1/p' Cargo.toml | head -n 1)"
package_name="pinyintab-v${version}-${target}"
stage_dir="$project_dir/dist/$package_name"
archive="$project_dir/dist/$package_name.tar.gz"

cargo build --release --locked --target "$target"
rm -rf "$stage_dir" "$archive" "$archive.sha256"
install -d "$stage_dir/bin" "$stage_dir/shell"
install -m 755 "$project_dir/target/$target/release/ptab" "$stage_dir/bin/ptab"
install -m 755 "$project_dir/install.sh" "$stage_dir/install.sh"
install -m 755 "$project_dir/uninstall.sh" "$stage_dir/uninstall.sh"
install -m 644 "$project_dir/shell/pinyintab.bash" "$stage_dir/shell/pinyintab.bash"
install -m 644 "$project_dir/shell/pinyintab.zsh" "$stage_dir/shell/pinyintab.zsh"
install -m 644 "$project_dir/README.md" "$stage_dir/README.md"
install -m 644 "$project_dir/README.zh-CN.md" "$stage_dir/README.zh-CN.md"
install -m 644 "$project_dir/CHANGELOG.md" "$stage_dir/CHANGELOG.md"
install -m 644 "$project_dir/LICENSE" "$stage_dir/LICENSE"

tar -C "$project_dir/dist" -czf "$archive" "$package_name"
(
    cd "$project_dir/dist"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$(basename "$archive")" >"$(basename "$archive").sha256"
    else
        shasum -a 256 "$(basename "$archive")" >"$(basename "$archive").sha256"
    fi
)

echo "Created: $archive"
echo "Created: $archive.sha256"
