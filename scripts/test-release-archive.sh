#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

archive="${1:-}"
mode="${2:-}"
if [[ -z "$archive" || ! -f "$archive" || ( -n "$mode" && "$mode" != --interactive ) || $# -gt 2 ]]; then
    echo "Usage: $0 <pinyintab-release.tar.gz> [--interactive]" >&2
    exit 2
fi

archive="$(cd "$(dirname "$archive")" && pwd)/$(basename "$archive")"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/pinyintab-release-test.XXXXXX")"
trap 'rm -rf -- "$temporary_root"' EXIT

tar -xzf "$archive" -C "$temporary_root"
package_dir="$(find "$temporary_root" -mindepth 1 -maxdepth 1 -type d -name 'pinyintab-*' -print -quit)"
[[ -n "$package_dir" ]] || {
    echo "FAIL: release package directory was not found" >&2
    exit 1
}

export HOME="$temporary_root/home"
export PINYINTAB_INSTALL_ROOT="$HOME/.local"
export PINYINTAB_RELEASE_FIXTURE="$temporary_root/fixture"
mkdir -p "$HOME" "$PINYINTAB_RELEASE_FIXTURE"
printf '%s\n' 'print("release archive test")' >"$PINYINTAB_RELEASE_FIXTURE/测试.py"
printf '%s\n' 'int main(void) { return 0; }' >"$PINYINTAB_RELEASE_FIXTURE/C语言.c"
printf '%s\n' '#!/bin/sh' 'printf "PTAB_RELEASE_EXEC_OK\n"' >"$PINYINTAB_RELEASE_FIXTURE/运行程序"
chmod +x "$PINYINTAB_RELEASE_FIXTURE/运行程序"

"$package_dir/install.sh" --shell bash >/dev/null
installed_ptab="$PINYINTAB_INSTALL_ROOT/bin/ptab"
version="$(sed -n 's/^version = "\([^"]*\)"/\1/p' "$project_dir/Cargo.toml" | head -n 1)"
[[ "$("$installed_ptab" version)" == "PinyinTab $version" ]] || {
    echo "FAIL: installed archive version does not match Cargo.toml" >&2
    exit 1
}
[[ -x "$HOME/.local/share/pinyintab/update.sh" && -f "$package_dir/apply-update.sh" ]] || {
    echo 'FAIL: release is missing update helpers' >&2
    exit 1
}
# The compatibility containers need not have diffutils. Hash stdin so the
# comparison ignores the filename but still checks every byte.
if command -v sha256sum >/dev/null 2>&1; then
    checksum=(sha256sum)
else
    checksum=(shasum -a 256)
fi
expected_updater="$("${checksum[@]}" <"$project_dir/scripts/install-online.sh")"
for updater in "$package_dir/update.sh" "$HOME/.local/share/pinyintab/update.sh"; do
    [[ "$("${checksum[@]}" <"$updater")" == "$expected_updater" ]] || {
        printf 'FAIL: updater does not match the tested source: %s\n' "$updater" >&2
        exit 1
    }
done

status="$(bash --noprofile --norc -c 'source "$HOME/.bashrc"; ptab status')"
[[ "$status" == 'PinyinTab completion: OFF (Bash)' ]] || {
    echo "FAIL: release installation did not start disabled: $status" >&2
    exit 1
}

# Validate the installed text, not just the source checkout's helper.
help_text="$(bash --noprofile --norc -c 'source "$HOME/.bashrc"; ptab --help')"
[[ "$help_text" == *'Shell commands'* && "$help_text" == *'Examples:'* ]] || {
    echo "FAIL: installed help page is incomplete" >&2
    exit 1
}
chinese_help="$("$HOME/.local/bin/ptab" help zh)"
[[ "$chinese_help" == *'开启当前终端'* ]] || {
    echo "FAIL: installed Chinese help is missing" >&2
    exit 1
}

candidates="$(bash --noprofile --norc -c '
    source "$HOME/.bashrc"
    ptab on >/dev/null
    cd "$PINYINTAB_RELEASE_FIXTURE"
    COMP_WORDS=(python3 ceshi.py)
    COMP_CWORD=1
    _pinyintab_complete
    printf "%s\n" "${COMPREPLY[@]}"
')"
[[ "$candidates" == *'测试.py'* ]] || {
    echo "FAIL: installed Bash integration did not return the Chinese path" >&2
    exit 1
}

executable_candidate="$("$HOME/.local/bin/ptab" complete-command "$PINYINTAB_RELEASE_FIXTURE" 0 ./yunxing)"
[[ "$executable_candidate" == './运行程序' ]] || {
    echo "FAIL: installed executable-path completion" >&2
    exit 1
}
(cd "$PINYINTAB_RELEASE_FIXTURE" && "$executable_candidate")
for query in cyuyan Cyuyan.c CYUYAN.C; do
    mixed_candidate="$("$installed_ptab" complete-command --language auto "$PINYINTAB_RELEASE_FIXTURE" 1 gcc "$query")"
    if [[ "$mixed_candidate" != C语言.c ]]; then
        printf 'FAIL: mixed-case completion for %s returned %s\n' "$query" "$mixed_candidate" >&2
        exit 1
    fi
done
if [[ "$mode" == --interactive ]]; then
    PINYINTAB_BINARY="$installed_ptab" \
        PINYINTAB_TEST_INTEGRATION="$PINYINTAB_INSTALL_ROOT/share/pinyintab/pinyintab.bash" \
        PINYINTAB_TEST_LOCALE=C.UTF-8 \
        python3 "$project_dir/scripts/test-interactive.py" bash
    PINYINTAB_BINARY="$installed_ptab" \
        PINYINTAB_TEST_INTEGRATION="$PINYINTAB_INSTALL_ROOT/share/pinyintab/pinyintab.bash" \
        PINYINTAB_TEST_LOCALE=C.UTF-8 \
        python3 "$project_dir/scripts/test-interactive.py" bash --vi
fi
"$installed_ptab" doctor
echo "PASS: PinyinTab release archive on $(uname -s) $(uname -m)"
