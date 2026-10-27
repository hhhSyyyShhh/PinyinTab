#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: this installer is for macOS" >&2
    exit 1
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
binary="$project_dir/target/release/pinfs-demo"

if [[ ! -x "$binary" ]]; then
    echo "error: release binary not found; run cargo build --release first" >&2
    exit 1
fi

install -d "$HOME/.local/bin" "$HOME/.local/share/pinfs"
install -m 755 "$binary" "$HOME/.local/bin/pinfs"
install -m 644 "$project_dir/shell/pinfs.zsh" "$HOME/.local/share/pinfs/pinfs.zsh"

echo
echo "Installed. Activate it in this terminal with:"
echo "  source \"$HOME/.local/share/pinfs/pinfs.zsh\""
echo "  pinfs on"
echo
echo "To load it in every new Zsh terminal, add this line to ~/.zshrc:"
echo "  source \"$HOME/.local/share/pinfs/pinfs.zsh\""
