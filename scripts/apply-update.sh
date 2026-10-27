#!/usr/bin/env bash
# Apply only an already verified release. No shell startup file is edited.
set -euo pipefail

package="${1:-}"
prefix="${PINYINTAB_INSTALL_ROOT:-$HOME/.local}"
[[ $# == 1 && -d "$package" && "$prefix" == /* && "$prefix" != / ]] || {
    echo 'error: invalid update package or installation prefix' >&2
    exit 2
}
bin_dir="$prefix/bin"
share_dir="$prefix/share/pinyintab"
[[ -f "$bin_dir/ptab" && ! -L "$bin_dir/ptab" && -d "$share_dir" && ! -L "$share_dir" ]] || {
    echo 'error: no regular PinyinTab installation found; run the installer instead' >&2
    exit 1
}
for source in bin/ptab shell/pinyintab.bash shell/pinyintab.zsh shell/keybindings.bash shell/keybindings.zsh uninstall.sh update.sh; do
    [[ -f "$package/$source" && ! -L "$package/$source" ]] || {
        echo "error: incomplete update package: $source" >&2
        exit 1
    }
done

# Same-filesystem renames avoid truncating a running Linux executable. An
# exclusive directory prevents two update transactions from racing.
lock="$prefix/.pinyintab-update-lock"
mkdir "$lock" 2>/dev/null || {
    echo "error: another update may be running ($lock); do not remove a live lock" >&2
    exit 1
}
stage=""
committed=0
cleanup() {
    result=$?
    trap - EXIT HUP INT TERM
    recovery_ok=1
    if [[ "$committed" == 0 && -n "$stage" ]]; then
        # Infer completed renames from backups rather than in-memory flags:
        # a signal may arrive between a rename and a flag assignment.
        if [[ -f "$stage/old-binary" ]]; then
            if [[ -e "$bin_dir/ptab" ]] && ! mv "$bin_dir/ptab" "$stage/failed-binary"; then
                recovery_ok=0
            else
                mv "$stage/old-binary" "$bin_dir/ptab" || recovery_ok=0
            fi
        fi
        if [[ -d "$stage/old-share" ]]; then
            if [[ -e "$share_dir" ]] && ! mv "$share_dir" "$stage/failed-share"; then
                recovery_ok=0
            else
                mv "$stage/old-share" "$share_dir" || recovery_ok=0
            fi
        fi
    fi
    # Only the unique directory created below is recursively removed.
    if [[ "$recovery_ok" == 0 ]]; then
        echo "error: rollback needs manual recovery; backups retained at $stage" >&2
        exit 1
    fi
    if [[ -n "$stage" && "$stage" == "$prefix"/.pinyintab-update.* ]]; then
        rm -rf -- "$stage"
    fi
    rmdir "$lock"
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM
stage="$(mktemp -d "$prefix/.pinyintab-update.XXXXXX")"
mkdir "$stage/share"
# Unknown user files/configuration are retained, not guessed to be old data.
cp -pR "$share_dir/." "$stage/share/"
for integration in pinyintab.bash pinyintab.zsh keybindings.bash keybindings.zsh; do
    rm -f -- "$stage/share/$integration"
    install -m 644 "$package/shell/$integration" "$stage/share/$integration"
done
rm -f -- "$stage/share/uninstall.sh" "$stage/share/update.sh"
install -m 755 "$package/uninstall.sh" "$stage/share/uninstall.sh"
install -m 755 "$package/update.sh" "$stage/share/update.sh"
install -m 755 "$package/bin/ptab" "$stage/new-binary"
expected="$("$package/bin/ptab" version)"
[[ "$("$stage/new-binary" version)" == "$expected" ]]
installed="$("$bin_dir/ptab" version)"
from="${installed#PinyinTab }"
to="${expected#PinyinTab }"
[[ "$from" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$to" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo 'error: cannot compare installed and staged versions' >&2
    exit 1
}
awk -v current="$from" -v upcoming="$to" 'BEGIN {
    split(current,c,"."); split(upcoming,n,".");
    for(i=1;i<=3;i++) {if(n[i]+0>c[i]+0) exit 0; if(n[i]+0<c[i]+0) exit 1}
    exit 1
}' || { echo 'error: installed version is no longer older; run ptab update again' >&2; exit 1; }

mv "$share_dir" "$stage/old-share"
mv "$stage/share" "$share_dir"
mv "$bin_dir/ptab" "$stage/old-binary"
mv "$stage/new-binary" "$bin_dir/ptab"
[[ "$("$bin_dir/ptab" version)" == "$expected" ]]
"$bin_dir/ptab" doctor >/dev/null
committed=1
