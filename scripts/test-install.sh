#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/pinyintab-install-test.XXXXXX")"
trap 'rm -rf -- "$temporary_root"' EXIT

export HOME="$temporary_root/home"
export PINYINTAB_INSTALL_ROOT="$HOME/.local"
mkdir -p "$HOME"
printf '%s\n' 'export PINYINTAB_TEST_SETTING=preserved' >"$HOME/.bashrc"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

status_in_clean_bash() {
    bash --noprofile --norc -c 'source "$HOME/.bashrc"; ptab status'
}

[[ -x "$project_dir/target/release/ptab" ]] || {
    echo "error: build target/release/ptab before running this test" >&2
    exit 2
}

# A normal installation must load the management command without taking over
# completion in every newly opened shell.
"$project_dir/install.sh" --shell bash >/dev/null
[[ -x "$HOME/.local/bin/ptab" ]] || fail "binary was not installed"
[[ -f "$HOME/.local/share/pinyintab/pinyintab.bash" ]] || fail "Bash integration was not installed"
grep -Fq '# >>> PinyinTab >>>' "$HOME/.bashrc" || fail "managed startup block is missing"
if grep -Fq 'ptab on >/dev/null' "$HOME/.bashrc"; then
    fail "default installation enabled completion automatically"
fi
[[ "$(status_in_clean_bash)" == 'PinyinTab completion: OFF (Bash)' ]] || {
    fail "new Bash session did not start with completion disabled"
}

# Automatic activation remains available as an explicit opt-in. Reinstalling
# must replace, rather than duplicate, the managed configuration block.
"$project_dir/install.sh" --shell bash --enable-on-startup >/dev/null
[[ "$(grep -Fc '# >>> PinyinTab >>>' "$HOME/.bashrc")" == 1 ]] || {
    fail "managed startup block was duplicated"
}
grep -Fq 'ptab on >/dev/null' "$HOME/.bashrc" || fail "opt-in activation was not configured"
[[ "$(status_in_clean_bash)" == 'PinyinTab completion: ON (Bash)' ]] || {
    fail "opt-in Bash session did not start with completion enabled"
}

# Reinstalling with the new default migrates v0.3-style auto-start blocks back
# to opt-in behavior while preserving unrelated user configuration and backup.
"$project_dir/install.sh" --shell bash >/dev/null
if grep -Fq 'ptab on >/dev/null' "$HOME/.bashrc"; then
    fail "reinstall did not remove the previous automatic activation"
fi
grep -Fq 'PINYINTAB_TEST_SETTING=preserved' "$HOME/.bashrc" || {
    fail "unrelated Bash configuration was not preserved"
}
grep -Fq 'PINYINTAB_TEST_SETTING=preserved' "$HOME/.bashrc.pinyintab.bak" || {
    fail "initial Bash configuration backup is missing"
}

if "$project_dir/install.sh" --no-modify-shell --enable-on-startup >/dev/null 2>&1; then
    fail "conflicting installer options were accepted"
fi

"$project_dir/uninstall.sh" >/dev/null
grep -Fq 'PINYINTAB_TEST_SETTING=preserved' "$HOME/.bashrc" || {
    fail "uninstaller removed unrelated Bash configuration"
}
if grep -Fq '# >>> PinyinTab >>>' "$HOME/.bashrc"; then
    fail "uninstaller left the managed startup block behind"
fi
[[ ! -e "$HOME/.local/bin/ptab" ]] || fail "uninstaller left the binary behind"

if command -v zsh >/dev/null 2>&1; then
    export HOME="$temporary_root/zsh-home"
    export PINYINTAB_INSTALL_ROOT="$HOME/.local"
    mkdir -p "$HOME"
    : >"$HOME/.zshrc"

    "$project_dir/install.sh" --shell zsh >/dev/null
    zsh_status="$(zsh -f -c 'source "$HOME/.zshrc"; ptab status')"
    [[ "$zsh_status" == 'PinyinTab completion: OFF (Zsh)' ]] || {
        fail "new Zsh session did not start with completion disabled"
    }

    "$project_dir/install.sh" --shell zsh --enable-on-startup >/dev/null
    zsh_status="$(zsh -f -c 'source "$HOME/.zshrc"; ptab status')"
    [[ "$zsh_status" == 'PinyinTab completion: ON (Zsh)' ]] || {
        fail "opt-in Zsh session did not start with completion enabled"
    }
fi

echo "PASS: PinyinTab installer startup-policy tests"
