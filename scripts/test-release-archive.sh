#!/usr/bin/env bash
set -euo pipefail

archive="${1:-}"
if [[ -z "$archive" || ! -f "$archive" ]]; then
    echo "Usage: $0 <pinyintab-release.tar.gz>" >&2
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

"$package_dir/install.sh" --shell bash >/dev/null

status="$(bash --noprofile --norc -c 'source "$HOME/.bashrc"; ptab status')"
[[ "$status" == 'PinyinTab completion: OFF (Bash)' ]] || {
    echo "FAIL: release installation did not start disabled: $status" >&2
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

"$HOME/.local/bin/ptab" doctor
echo "PASS: PinyinTab release archive on $(uname -s) $(uname -m)"
