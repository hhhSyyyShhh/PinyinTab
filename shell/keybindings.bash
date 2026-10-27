# Readline macros wrap its native `complete` action; no shell parser is added.
# Bash 5 is the released interactive target. Bash 3 keeps argument completion
# but does not install these widgets (it lacks bind -X and complete -I).
_pinyintab_saved_key_maps=()
_pinyintab_saved_key_sequences=()
_pinyintab_saved_key_types=()
_pinyintab_saved_key_values=()
_pinyintab_next_language=auto
_pinyintab_snapshot_valid=0
_pinyintab_query_line=''
_pinyintab_query_point=0
_pinyintab_result_line=''
_pinyintab_result_point=0
_pinyintab_did_complete=0

_pinyintab_readline_before() {
    local language="$1"
    if [[ "$language" != auto && "$_pinyintab_snapshot_valid" == 1 &&
          "$READLINE_LINE" == "$_pinyintab_result_line" &&
          "$READLINE_POINT" == "$_pinyintab_result_point" ]]; then
        READLINE_LINE="$_pinyintab_query_line"
        READLINE_POINT=$_pinyintab_query_point
    else
        _pinyintab_query_line="$READLINE_LINE"
        _pinyintab_query_point=$READLINE_POINT
    fi
    _pinyintab_next_language="$language"
    _pinyintab_did_complete=0
}
_pinyintab_readline_auto() { _pinyintab_readline_before auto; }
_pinyintab_readline_chinese() { _pinyintab_readline_before chinese; }
_pinyintab_readline_english() { _pinyintab_readline_before english; }
_pinyintab_readline_after() {
    _pinyintab_result_line="$READLINE_LINE"
    _pinyintab_result_point=$READLINE_POINT
    _pinyintab_snapshot_valid=$_pinyintab_did_complete
    _pinyintab_next_language=auto
}

_pinyintab_bash_install_keys() {
    [[ $- == *i* && ${BASH_VERSINFO[0]} -ge 5 ]] || return 0
    local map key kind definition saved index=0
    _pinyintab_saved_key_maps=()
    _pinyintab_saved_key_sequences=()
    _pinyintab_saved_key_types=()
    _pinyintab_saved_key_values=()
    for map in emacs-standard vi-insert; do
        for key in '\C-i' '\C-xc' '\C-xe' '\C-xt' '\C-xu' '\C-xv' '\C-xw' '\C-xy'; do
            saved=''
            kind=''
            for kind in p s X; do
                while IFS= read -r definition; do
                    if [[ "$definition" == "\"$key\":"* ]]; then
                        saved="$definition"
                        break
                    fi
                done < <(bind -m "$map" -"$kind" 2>/dev/null)
                [[ -n "$saved" ]] && break
            done
            _pinyintab_saved_key_maps[$index]="$map"
            _pinyintab_saved_key_sequences[$index]="$key"
            _pinyintab_saved_key_types[$index]="$kind"
            _pinyintab_saved_key_values[$index]="$saved"
            index=$((index + 1))
        done
        bind -m "$map" -x '"\C-xt":_pinyintab_readline_auto'
        bind -m "$map" -x '"\C-xu":_pinyintab_readline_chinese'
        bind -m "$map" -x '"\C-xy":_pinyintab_readline_english'
        bind -m "$map" '"\C-xv":complete'
        bind -m "$map" -x '"\C-xw":_pinyintab_readline_after'
        bind -m "$map" '"\C-i":"\C-xt\C-xv\C-xw"'
        bind -m "$map" '"\C-xc":"\C-xu\C-xv\C-xw"'
        bind -m "$map" '"\C-xe":"\C-xy\C-xv\C-xw"'
    done
    _pinyintab_snapshot_valid=0
}

_pinyintab_bash_restore_keys() {
    local index map key kind value
    for ((index=0; index<${#_pinyintab_saved_key_maps[@]}; index++)); do
        map="${_pinyintab_saved_key_maps[$index]}"
        key="${_pinyintab_saved_key_sequences[$index]}"
        kind="${_pinyintab_saved_key_types[$index]}"
        value="${_pinyintab_saved_key_values[$index]}"
        bind -m "$map" -r "$key"
        if [[ -n "$value" ]]; then
            if [[ "$kind" == X ]]; then
                bind -m "$map" -x "$value"
            else
                bind -m "$map" "$value"
            fi
        fi
    done
    _pinyintab_saved_key_maps=()
    _pinyintab_snapshot_valid=0
    _pinyintab_next_language=auto
}
