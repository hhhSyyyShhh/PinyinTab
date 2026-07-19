#!/usr/bin/env bash
set -euo pipefail

readonly INSTALL_ROOT="${PINYINTAB_INSTALL_ROOT:-$HOME/.local}"
readonly START_MARKER="# >>> PinyinTab >>>"
readonly END_MARKER="# <<< PinyinTab <<<"

remove_startup_block() {
    local rc_file="$1"
    local temp_file
    [[ -f "$rc_file" ]] || return 0
    temp_file="$(mktemp)"
    awk -v start="$START_MARKER" -v end="$END_MARKER" '
        $0 == start { skipping = 1; next }
        $0 == end   { skipping = 0; next }
        !skipping   { print }
    ' "$rc_file" >"$temp_file"
    mv "$temp_file" "$rc_file"
}

remove_startup_block "$HOME/.bashrc"
remove_startup_block "$HOME/.zshrc"
rm -f "$INSTALL_ROOT/bin/ptab"
rm -rf "$INSTALL_ROOT/share/pinyintab"

echo "PinyinTab was removed. Restart the terminal to clear the loaded shell function."
