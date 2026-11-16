# Shared Bash/Zsh activation policy. This file stores data, never shell code.
_pinyintab_local=0
_pinyintab_boot_id=''
_pinyintab_mode=off
_pinyintab_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/pinyintab"
[[ "$_pinyintab_state_dir" == /* ]] || _pinyintab_state_dir="$HOME/.local/state/pinyintab"

_pinyintab_get_boot_id() {
    [[ -n "$_pinyintab_boot_id" ]] && return 0
    case "$OSTYPE" in
        linux*) IFS= read -r _pinyintab_boot_id </proc/sys/kernel/random/boot_id ;;
        darwin*)
            _pinyintab_boot_id="$(/usr/sbin/sysctl -n kern.bootsessionuuid 2>/dev/null)" ||
                _pinyintab_boot_id="$(LC_ALL=C TZ=UTC0 /usr/sbin/sysctl -n kern.boottime 2>/dev/null)" ;;
    esac
    [[ -n "$_pinyintab_boot_id" ]]
}

_pinyintab_read_policy() {
    local record=''
    _pinyintab_shared=off
    if [[ ! -e "$_pinyintab_state_dir/activation" ]]; then
        if [[ "${_pinyintab_plugin_default:-0}" == 1 ]]; then _pinyintab_shared=startup; fi
        return 0
    fi
    [[ -f "$_pinyintab_state_dir/activation" && -r "$_pinyintab_state_dir/activation" ]] || return 0
    IFS= read -r record <"$_pinyintab_state_dir/activation" || return 0
    case "$record" in
        startup) _pinyintab_shared=startup ;;
        boot:*)
            if _pinyintab_get_boot_id && [[ "$record" == "boot:$_pinyintab_boot_id" ]]; then
                _pinyintab_shared=until-reboot
            fi ;;
    esac
    return 0
}

# Replace the small record atomically; concurrent requests are last-write-wins.
_pinyintab_write_policy() (
    umask 077
    local pending
    mkdir -p -- "$_pinyintab_state_dir" || return 1
    [[ ! -d "$_pinyintab_state_dir/activation" ]] || return 1
    pending="$(mktemp "$_pinyintab_state_dir/.activation.XXXXXX")" || return 1
    trap 'rm -f -- "$pending"' EXIT
    printf '%s\n' "$1" >"$pending" &&
        mv -f -- "$pending" "$_pinyintab_state_dir/activation"
)

# An unchanged v0.6.1 managed startup block calls plain ptab on. Interpret
# only that exact call as a startup preference; never rewrite a user's rc.
_pinyintab_legacy_line() {
    [[ -f "$1" ]] || return 1
    awk -v line="$2" '
        $0 == "# >>> PinyinTab >>>" { managed = 1 }
        $0 == "# <<< PinyinTab <<<" { managed = 0 }
        managed && (line == 0 || NR == line) && $0 == "ptab on >/dev/null" { found = 1 }
        END { exit(found ? 0 : 1) }
    ' "$1"
}

_pinyintab_has_legacy_call() {
    case "$1" in
        "$HOME/.bashrc"|"${ZDOTDIR:-$HOME}/.zshrc")
            [[ -n "$2" && "$2" != 0 ]] && _pinyintab_legacy_line "$1" "$2" ;;
        *) return 1 ;;
    esac
}

_pinyintab_legacy_on() {
    if [[ ! -e "$_pinyintab_state_dir/activation" ]]; then
        _pinyintab_write_policy startup || return 1
    fi
    _pinyintab_sync
}

_pinyintab_sync() {
    _pinyintab_read_policy
    _pinyintab_mode="$_pinyintab_shared"
    if [[ "$_pinyintab_mode" == off && "$_pinyintab_local" == 1 ]]; then
        _pinyintab_mode=current
    fi
    if [[ "$_pinyintab_mode" == off ]]; then
        if [[ "$_pinyintab_active" == 1 ]]; then _pinyintab_disable; fi
    else
        if [[ "$_pinyintab_active" == 0 ]]; then _pinyintab_enable || return 1; fi
    fi
    return 0
}

_pinyintab_policy_on() {
    if [[ $# -gt 1 ]]; then
        printf '%s\n' 'Usage: ptab on [--until-reboot | --startup]' >&2
        return 2
    fi
    case "${1:-}" in
        '') [[ $# == 0 ]] || return 2
            _pinyintab_read_policy
            if [[ "$_pinyintab_shared" == off ]]; then _pinyintab_local=1; fi ;;
        --until-reboot)
            _pinyintab_get_boot_id || {
                printf '%s\n' 'PinyinTab: cannot identify this boot; use ptab on or ptab on --startup.' >&2
                return 1
            }
            _pinyintab_write_policy "boot:$_pinyintab_boot_id" || return 1
            _pinyintab_local=0 ;;
        --startup)
            _pinyintab_write_policy startup || return 1
            _pinyintab_local=0 ;;
        *) printf '%s\n' 'Usage: ptab on [--until-reboot | --startup]' >&2; return 2 ;;
    esac
    _pinyintab_sync || return 1
    printf 'PinyinTab completion: ON [%s]\n' "$_pinyintab_mode"
}

_pinyintab_policy_off() {
    _pinyintab_read_policy
    if [[ "$_pinyintab_shared" != off ]]; then _pinyintab_write_policy off || return 1; fi
    _pinyintab_local=0
    _pinyintab_sync || return 1
    printf '%s\n' 'PinyinTab completion: OFF'
}

_pinyintab_policy_status() {
    _pinyintab_sync || return 1
    if [[ "$_pinyintab_active" == 1 ]]; then
        printf 'PinyinTab completion: ON (%s) [%s]\n' "$1" "$_pinyintab_mode"
    else
        printf 'PinyinTab completion: OFF (%s)\n' "$1"
    fi
}

# Preserve the previous command's exit status for the user's prompt.
_pinyintab_prompt_sync() {
    local previous_status=$?
    _pinyintab_sync || :
    return "$previous_status"
}

# Nonzero precmd hooks in Zsh would skip later hooks.
_pinyintab_zsh_prompt_sync() {
    _pinyintab_sync || :
}
