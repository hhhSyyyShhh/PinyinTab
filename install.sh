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
enable_on_startup=0

usage() {
    cat <<'EOF'
Usage: ./install.sh [--no-modify-shell] [--shell bash|zsh] [--enable-on-startup]

Installs PinyinTab for the current user. No sudo is required.

By default, the installer loads the `ptab` command in new shells but leaves
completion disabled until `ptab on` is run. Use --enable-on-startup to opt in
to automatic activation for every new shell.
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
        --enable-on-startup)
            enable_on_startup=1
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

if [[ "$modify_shell" == 0 && "$enable_on_startup" == 1 ]]; then
    echo "error: --enable-on-startup cannot be combined with --no-modify-shell" >&2
    exit 2
fi

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

if ! binary_version="$("$binary" version 2>&1)"; then
    echo "error: the bundled ptab binary cannot run on this system" >&2
    printf '%s\n' "$binary_version" >&2
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
    if [[ ! -e "$rc_file.pinyintab.bak" ]]; then
        cp "$rc_file" "$rc_file.pinyintab.bak"
    fi

    # Replace only the block managed by PinyinTab. This also migrates older
    # installations that enabled completion unconditionally at startup.
    temporary_rc="$(mktemp "${TMPDIR:-/tmp}/pinyintab-rc.XXXXXX")"
    awk -v start="$START_MARKER" -v end="$END_MARKER" '
        $0 == start { managed = 1; next }
        $0 == end && managed { managed = 0; next }
        !managed { print }
    ' "$rc_file" >"$temporary_rc"
    cat "$temporary_rc" >"$rc_file"
    rm -f "$temporary_rc"

    {
        printf '\n%s\n' "$START_MARKER"
        printf 'source "%s"\n' "$integration_file"
        if [[ "$enable_on_startup" == 1 ]]; then
            printf 'ptab on >/dev/null\n'
        fi
        printf '%s\n' "$END_MARKER"
    } >>"$rc_file"
fi

echo
echo "$PRODUCT installed successfully."
echo "  platform: $os/$arch"
echo "  binary:   $BIN_DIR/ptab"
echo "  shell:    $shell_name"
if [[ "$modify_shell" == 1 ]]; then
    echo "  startup:  $rc_file"
    if [[ "$enable_on_startup" == 1 ]]; then
        echo "  completion: enabled automatically in new shells"
    else
        echo "  completion: disabled by default"
    fi
    echo
    echo "Restart the terminal, then enable completion when needed with:"
    echo "  ptab on"
    echo
    echo "To activate it in the current shell now:"
    echo "  source \"$integration_file\""
    echo "  ptab on"
else
    echo
    echo "Shell configuration was not changed. Activate manually with:"
    echo "  source \"$integration_file\""
    echo "  ptab on"
fi
