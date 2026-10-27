# PinFS Bash integration. Source this file; do not execute it directly.

_pinfs_binary="${PINFS_BINARY:-$HOME/.local/bin/pinfs}"
_pinfs_active=0
_pinfs_saved_default=""
_pinfs_saved_specs=()
_pinfs_commands=(
    cd python python3 python3.10 python3.11 python3.12 python3.13 python3.14
    cat vim vi nano less head tail
    cp mv rm touch mkdir rmdir java javac julia node ruby perl bash sh
    cargo rustc gcc clang swift swiftc
)

_pinfs_complete() {
    local current candidate mode command index token reply_count
    current="${COMP_WORDS[COMP_CWORD]}"
    mode=""
    command="${COMP_WORDS[0]}"
    COMPREPLY=()

    if [[ ! -x "$_pinfs_binary" ]]; then
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
    done < <("$_pinfs_binary" complete "$PWD" "$current" $mode 2>/dev/null)

    reply_count=0
    for candidate in "${COMPREPLY[@]-}"; do
        [[ -n "$candidate" ]] && reply_count=$((reply_count + 1))
    done

    if [[ $reply_count -gt 1 \
        && "$current" == *[一-龥]* \
        && "$current" == *[A-Za-z]* ]]; then
        printf '\nPinFS candidates (input preserved; refine it and press Tab again):\n' >&2
        for candidate in "${COMPREPLY[@]}"; do
            printf '  %s\n' "$candidate" >&2
        done
        COMPREPLY=()
        return 0
    fi

    compopt -o filenames 2>/dev/null || true
    for candidate in "${COMPREPLY[@]-}"; do
        if [[ "$candidate" == */ ]]; then
            compopt -o nospace 2>/dev/null || true
            break
        fi
    done
}

pinfs() {
    local command spec index
    case "${1:-}" in
        on)
            if [[ "$_pinfs_active" == 1 ]]; then
                echo "PinFS pinyin completion: already ON"
                return 0
            fi

            _pinfs_saved_specs=()
            index=0
            for command in "${_pinfs_commands[@]}"; do
                spec="$(complete -p "$command" 2>/dev/null || true)"
                _pinfs_saved_specs[$index]="$spec"
                index=$((index + 1))
            done

            if help complete 2>/dev/null | grep -q -- '-D'; then
                _pinfs_saved_default="$(complete -p -D 2>/dev/null || true)"
                complete -F _pinfs_complete -D
            fi
            complete -F _pinfs_complete "${_pinfs_commands[@]}"
            _pinfs_active=1
            echo "PinFS pinyin completion: ON"
            ;;
        off)
            if [[ "$_pinfs_active" != 1 ]]; then
                echo "PinFS pinyin completion: already OFF"
                return 0
            fi

            if help complete 2>/dev/null | grep -q -- '-D'; then
                complete -r -D 2>/dev/null || true
                if [[ -n "$_pinfs_saved_default" ]]; then
                    eval "$_pinfs_saved_default"
                fi
            fi

            index=0
            for command in "${_pinfs_commands[@]}"; do
                complete -r "$command" 2>/dev/null || true
                spec="${_pinfs_saved_specs[$index]}"
                if [[ -n "$spec" ]]; then
                    eval "$spec"
                fi
                index=$((index + 1))
            done
            _pinfs_active=0
            echo "PinFS pinyin completion: OFF"
            ;;
        *)
            echo "Usage: pinfs on | pinfs off"
            return 2
            ;;
    esac
}
