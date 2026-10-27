#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "error: this installer is for Linux" >&2
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
install -m 644 "$project_dir/shell/pinfs.bash" "$HOME/.local/share/pinfs/pinfs.bash"

echo
echo "PinFS Linux v0.2.4 installed."
echo "Activate it in this terminal with:"
echo "  source \"$HOME/.local/share/pinfs/pinfs.bash\""
echo "  pinfs on"
echo
echo "To load the plugin in every new Bash terminal, add these lines to ~/.bashrc:"
echo "  source \"$HOME/.local/share/pinfs/pinfs.bash\""
echo "  pinfs on"
