# PinyinTab Bash integration. Source this file; do not execute it directly.

_pinyintab_binary="${PINYINTAB_BINARY:-$HOME/.local/bin/ptab}"
_pinyintab_active=0
_pinyintab_saved_default=""
_pinyintab_saved_specs=()
_pinyintab_commands=(
    cd python python3 python3.10 python3.11 python3.12 python3.13 python3.14
    cat vim vi nano less head tail
    cp mv rm touch mkdir rmdir java javac julia node ruby perl bash sh
    cargo rustc gcc clang swift swiftc
)

_pinyintab_complete() {
    local current candidate mode command index token
    current="${COMP_WORDS[COMP_CWORD]}"
    mode=""
    command="${COMP_WORDS[0]}"
    COMPREPLY=()

    if [[ ! -x "$_pinyintab_binary" ]]; then
        return 0
    fi

    for ((index = COMP_CWORD - 1; index >= 0; index--)); do
        token="${COMP_WORDS[index]}"
        case "$token" in
            '|'|'||'|'&&'|';')
                command="${COMP_WORDS[index + 1]}"
                break
                ;;
        esac
    done
    if [[ "$command" == "sudo" && $((index + 2)) -le $COMP_CWORD ]]; then
        command="${COMP_WORDS[index + 2]}"
    fi

    case "$command" in
        cd|rmdir)
            mode="--directories"
            ;;
        java)
            mode="--java-classes"
            ;;
        cat|python|python[0-9]*|javac|julia|node|ruby|perl|bash|sh|less|head|tail|gcc|clang|rustc|swift|swiftc)
            mode="--files"
            ;;
    esac

    while IFS= read -r candidate; do
        COMPREPLY[${#COMPREPLY[@]}]="$candidate"
    done < <("$_pinyintab_binary" complete "$PWD" "$current" $mode 2>/dev/null)
    compopt -o filenames 2>/dev/null || true
    for candidate in "${COMPREPLY[@]-}"; do
        if [[ "$candidate" == */ ]]; then
            compopt -o nospace 2>/dev/null || true
            break
        fi
    done
}

ptab() {
    local command spec index
    case "${1:-}" in
        on)
            if [[ "$_pinyintab_active" == 1 ]]; then
                echo "PinyinTab completion: already ON"
                return 0
            fi

            _pinyintab_saved_specs=()
            index=0
            for command in "${_pinyintab_commands[@]}"; do
                spec="$(complete -p "$command" 2>/dev/null || true)"
                _pinyintab_saved_specs[$index]="$spec"
                index=$((index + 1))
            done

            if help complete 2>/dev/null | grep -q -- '-D'; then
                _pinyintab_saved_default="$(complete -p -D 2>/dev/null || true)"
                complete -F _pinyintab_complete -D
            fi
            complete -F _pinyintab_complete "${_pinyintab_commands[@]}"
            _pinyintab_active=1
            echo "PinyinTab completion: ON"
            ;;
        off)
            if [[ "$_pinyintab_active" != 1 ]]; then
                echo "PinyinTab completion: already OFF"
                return 0
            fi

            if help complete 2>/dev/null | grep -q -- '-D'; then
                complete -r -D 2>/dev/null || true
                if [[ -n "$_pinyintab_saved_default" ]]; then
                    eval "$_pinyintab_saved_default"
                fi
            fi

            index=0
            for command in "${_pinyintab_commands[@]}"; do
                complete -r "$command" 2>/dev/null || true
                spec="${_pinyintab_saved_specs[$index]}"
                if [[ -n "$spec" ]]; then
                    eval "$spec"
                fi
                index=$((index + 1))
            done
            _pinyintab_active=0
            echo "PinyinTab completion: OFF"
            ;;
        status)
            if [[ "$_pinyintab_active" == 1 ]]; then
                echo "PinyinTab completion: ON (Bash)"
            else
                echo "PinyinTab completion: OFF (Bash)"
            fi
            ;;
        doctor)
            "$_pinyintab_binary" doctor
            echo "shell: bash ${BASH_VERSION}"
            ptab status
            ;;
        version|--version|-V)
            "$_pinyintab_binary" version
            ;;
        alias|complete)
            "$_pinyintab_binary" "$@"
            ;;
        help|--help|-h|'')
            echo "Usage: ptab on | off | status | doctor | version"
            ;;
        *)
            echo "Usage: ptab on | off | status | doctor | version" >&2
            return 2
            ;;
    esac
}
