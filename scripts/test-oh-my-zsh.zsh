#!/usr/bin/env zsh
set -euo pipefail

project_dir="${0:A:h:h}"
: "${PINYINTAB_BINARY:=$project_dir/target/release/ptab}"
export PINYINTAB_BINARY

if [[ ! -x "$PINYINTAB_BINARY" ]]; then
  print -u2 -- "FAIL: missing ptab binary: $PINYINTAB_BINARY"
  exit 1
fi

temporary_home="$(mktemp -d)"
trap 'rm -rf -- "$temporary_home"' EXIT
export HOME="$temporary_home"

source "$project_dir/pinyintab.plugin.zsh"

if (( ! _pinyintab_active )); then
  print -u2 -- "FAIL: plugin entry point did not enable PinyinTab"
  exit 1
fi

if [[ "$(ptab status)" != "PinyinTab completion: ON (Zsh)" ]]; then
  print -u2 -- "FAIL: unexpected plugin status"
  exit 1
fi

ptab off >/dev/null
print -- "PASS: PinyinTab Oh My Zsh entry-point test"
