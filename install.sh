#!/usr/bin/env bash
set -euo pipefail

readonly PRODUCT="PinyinTab"
readonly INSTALL_ROOT="${PINYINTAB_INSTALL_ROOT:-$HOME/.local}"
readonly BIN_DIR="$INSTALL_ROOT/bin"
readonly SHARE_DIR="$INSTALL_ROOT/share/pinyintab"
readonly START_MARKER="# >>> PinyinTab >>>"
readonly END_MARKER="# <<< PinyinTab <<<"

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
modify_shell=1
requested_shell=""

usage() {
    cat <<'EOF'
Usage: ./install.sh [--no-modify-shell] [--shell bash|zsh]

Installs PinyinTab for the current user. No sudo is required.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-modify-shell)
            modify_shell=0
            ;;
        --shell)
            shift
            requested_shell="${1:-}"
            if [[ "$requested_shell" != "bash" && "$requested_shell" != "zsh" ]]; then
                echo "error: --shell must be bash or zsh" >&2
                exit 2
            fi
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

os="$(uname -s)"
arch="$(uname -m)"
case "$os/$arch" in
    Linux/x86_64)
        default_shell="bash"
        ;;
    Darwin/arm64)
        default_shell="zsh"
        ;;
    *)
        echo "error: this release supports Linux x86_64 and macOS arm64 only (found $os/$arch)" >&2
        exit 1
        ;;
esac

shell_name="${requested_shell:-$default_shell}"
release_binary="$project_dir/bin/ptab"
source_binary="$project_dir/target/release/ptab"
if [[ -x "$release_binary" ]]; then
    binary="$release_binary"
elif [[ -x "$source_binary" ]]; then
    binary="$source_binary"
else
    echo "error: ptab binary not found" >&2
    echo "If this is a source checkout, run: ./scripts/install-from-source.sh" >&2
    exit 1
fi

for integration in "$project_dir/shell/pinyintab.bash" "$project_dir/shell/pinyintab.zsh"; do
    if [[ ! -f "$integration" ]]; then
        echo "error: missing shell integration: $integration" >&2
        exit 1
    fi
done

install -d "$BIN_DIR" "$SHARE_DIR"
install -m 755 "$binary" "$BIN_DIR/ptab"
install -m 644 "$project_dir/shell/pinyintab.bash" "$SHARE_DIR/pinyintab.bash"
install -m 644 "$project_dir/shell/pinyintab.zsh" "$SHARE_DIR/pinyintab.zsh"

if [[ "$shell_name" == "zsh" ]]; then
    rc_file="$HOME/.zshrc"
    integration_file="$SHARE_DIR/pinyintab.zsh"
else
    rc_file="$HOME/.bashrc"
    integration_file="$SHARE_DIR/pinyintab.bash"
fi

if [[ "$modify_shell" == 1 ]]; then
    touch "$rc_file"
    if ! grep -Fq "$START_MARKER" "$rc_file"; then
        if [[ ! -e "$rc_file.pinyintab.bak" ]]; then
            cp "$rc_file" "$rc_file.pinyintab.bak"
        fi
        {
            printf '\n%s\n' "$START_MARKER"
            printf 'source "%s"\n' "$integration_file"
            printf 'ptab on >/dev/null\n'
            printf '%s\n' "$END_MARKER"
        } >>"$rc_file"
    fi
fi

echo
echo "$PRODUCT installed successfully."
echo "  platform: $os/$arch"
echo "  binary:   $BIN_DIR/ptab"
echo "  shell:    $shell_name"
if [[ "$modify_shell" == 1 ]]; then
    echo "  startup:  $rc_file"
    echo
    echo "Restart the terminal, or activate now with:"
    echo "  source \"$rc_file\""
else
    echo
    echo "Shell configuration was not changed. Activate manually with:"
    echo "  source \"$integration_file\""
    echo "  ptab on"
fi
