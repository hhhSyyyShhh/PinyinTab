#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/pinyintab-activation.XXXXXX")"
trap 'rm -rf -- "$fixture"' EXIT
export HOME="$fixture/home" ZDOTDIR="$fixture/home" XDG_STATE_HOME="$fixture/state"
export PINYINTAB_BINARY="$project_dir/target/release/ptab"
mkdir -p "$HOME"
state="$XDG_STATE_HOME/pinyintab/activation"

shell_name="${1:-bash}"
case "$shell_name" in
    bash) program=(bash --noprofile --norc -c); label=Bash ;;
    zsh) program=(zsh -f -c); label=Zsh ;;
    *) exit 2 ;;
esac
entry="$project_dir/shell/pinyintab.$shell_name"
run() { "${program[@]}" 'source "$1" && eval "$2"' "$shell_name" "$entry" "$1"; }
mode() { [[ "$(run 'ptab status')" == "PinyinTab completion: $1 ($label)${2:+ [$2]}" ]]; }
off() { run 'ptab off' >/dev/null; mode OFF; }

mode OFF
[[ "$(run 'ptab on >/dev/null; ptab status')" == "PinyinTab completion: ON ($label) [current]" ]]
mode OFF
if run 'ptab on --startup --until-reboot' >/dev/null 2>&1; then
    echo 'FAIL: incompatible options were accepted' >&2; exit 1
fi
[[ ! -e "$state" ]]

# Write through the real CLI and inspect from a fresh process. Simulate a
# reboot by replacing only the fixture's stored boot ID, not the OS reader.
run 'ptab on --until-reboot' >/dev/null
mode ON until-reboot
off
run 'ptab on --until-reboot' >/dev/null
printf '%s\n' 'boot:stale-test-id' >"$state"
mode OFF
run 'ptab on --startup' >/dev/null
mode ON startup
off

# A generic prompt/status refresh picks up changes made by a different shell
# without borrowing the local activation of an unrelated terminal.
run '(ptab on --startup >/dev/null); _pinyintab_sync; [[ "$_pinyintab_active" == 1 ]]; (ptab off >/dev/null); _pinyintab_sync; [[ "$_pinyintab_active" == 0 ]]'
run 'ptab on >/dev/null; (ptab on --startup >/dev/null; ptab off >/dev/null); [[ "$(ptab status)" == *"[current]" ]]'

# Verified update leaves the old startup file unchanged. Its exact managed
# call must migrate the preference once and honor off on future startups.
legacy="$HOME/.${shell_name}rc"
printf '%s\n' '# >>> PinyinTab >>>' "source \"$entry\"" 'ptab on >/dev/null' '# <<< PinyinTab <<<' >"$legacy"
rm -f -- "$state"
legacy_status() { "${program[@]}" 'source "$1"; ptab status' "$shell_name" "$legacy"; }
[[ "$(legacy_status)" == "PinyinTab completion: ON ($label) [startup]" ]]
off
[[ "$(legacy_status)" == "PinyinTab completion: OFF ($label)" ]]
[[ "$(grep -Fc 'ptab on >/dev/null' "$legacy")" == 1 ]]
printf 'PASS: %s activation modes, shared refresh, stale boot and legacy migration\n' "$label"
