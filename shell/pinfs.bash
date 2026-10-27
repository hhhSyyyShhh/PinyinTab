# PinFS Bash integration. Source this file; do not execute it directly.

_pinfs_binary="${PINFS_BINARY:-$HOME/.local/bin/pinfs}"
_pinfs_active=0
_pinfs_saved_default=""
_pinfs_saved_specs=()
_pinfs_commands=(
    cd python python3 cat vim vi nano less head tail
    cp mv rm touch mkdir rmdir java javac julia cargo rustc
)

_pinfs_complete() {
    local current candidate mode
    current="${COMP_WORDS[COMP_CWORD]}"
    mode=""
    COMPREPLY=()

    if [[ ! -x "$_pinfs_binary" ]]; then
        return 0
    fi

    if [[ "${COMP_WORDS[0]}" == "cd" ]]; then
        mode="--directories"
    fi

    while IFS= read -r candidate; do
        COMPREPLY[${#COMPREPLY[@]}]="$candidate"
    done < <("$_pinfs_binary" complete "$PWD" "$current" $mode 2>/dev/null)
    compopt -o filenames 2>/dev/null || true
    for candidate in "${COMPREPLY[@]}"; do
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
                complete -o default -o bashdefault -F _pinfs_complete -D
            fi
            complete -o default -o bashdefault -F _pinfs_complete "${_pinfs_commands[@]}"
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
