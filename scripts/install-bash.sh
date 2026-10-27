#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install -d "$HOME/.local/bin" "$HOME/.local/share/pinfs"
install -m 755 "$project_dir/target/release/pinfs-demo" "$HOME/.local/bin/pinfs"
install -m 644 "$project_dir/shell/pinfs.bash" "$HOME/.local/share/pinfs/pinfs.bash"

echo
echo "Installed. Activate it in this terminal with:"
echo "  source \"$HOME/.local/share/pinfs/pinfs.bash\""
echo "  pinfs on"
