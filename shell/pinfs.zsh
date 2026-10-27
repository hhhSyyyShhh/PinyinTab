# PinFS Zsh integration. Source this file; do not execute it directly.

typeset -g _pinfs_binary="${PINFS_BINARY:-$HOME/.local/bin/pinfs}"
typeset -gi _pinfs_active=0
typeset -gA _pinfs_saved_comps
typeset -g _pinfs_saved_default=""
typeset -ga _pinfs_commands
_pinfs_commands=(
  cd python python3 python3.10 python3.11 python3.12 python3.13 python3.14
  cat vim vi nano less head tail
  cp mv rm touch mkdir rmdir java javac julia node ruby perl bash sh
  cargo rustc gcc clang swift swiftc
)

_pinfs_zsh_complete() {
  local current mode candidate command output
  local -a candidates directories files
  current="$PREFIX"
  mode=""
  command="${words[1]}"

  [[ -x "$_pinfs_binary" ]] || return 0
  [[ "$command" == "sudo" ]] && command="${words[2]}"

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

  output="$("$_pinfs_binary" complete "$PWD" "$current" $mode 2>/dev/null)"
  [[ -n "$output" ]] || return 0
  candidates=("${(@f)output}")
  # Returning success with no candidates prevents Zsh from falling back to its
  # generic file completer and re-introducing a directory for commands like cat.
  (( ${#candidates[@]} > 0 )) || return 0
  # -U is required because the real Chinese candidate does not literally start
  # with the pinyin text currently present in PREFIX.
  for candidate in "${candidates[@]}"; do
    if [[ "$candidate" == */ ]]; then
      directories+=("$candidate")
    else
      files+=("$candidate")
    fi
  done
  (( ${#files[@]} > 0 )) && compadd -U -f -- "${files[@]}"
  (( ${#directories[@]} > 0 )) && compadd -U -f -S '' -- "${directories[@]}"
}

pinfs() {
  local command previous

  case "${1:-}" in
    on)
      if (( _pinfs_active )); then
        echo "PinFS pinyin completion: already ON"
        return 0
      fi

      if (( ! $+functions[compdef] )); then
        autoload -Uz compinit
        compinit
      fi

      _pinfs_saved_comps=()
      for command in "${_pinfs_commands[@]}"; do
        _pinfs_saved_comps[$command]="${_comps[$command]-}"
        compdef _pinfs_zsh_complete "$command"
      done

      _pinfs_saved_default="${_comps[-default-]-}"
      _comps[-default-]=_pinfs_zsh_complete
      _pinfs_active=1
      echo "PinFS pinyin completion: ON"
      ;;
    off)
      if (( ! _pinfs_active )); then
        echo "PinFS pinyin completion: already OFF"
        return 0
      fi

      for command in "${_pinfs_commands[@]}"; do
        compdef -d "$command"
        previous="${_pinfs_saved_comps[$command]-}"
        [[ -n "$previous" ]] && compdef "$previous" "$command"
      done

      unset '_comps[-default-]'
      [[ -n "$_pinfs_saved_default" ]] && _comps[-default-]="$_pinfs_saved_default"
      _pinfs_active=0
      echo "PinFS pinyin completion: OFF"
      ;;
    *)
      echo "Usage: pinfs on | pinfs off"
      return 2
      ;;
  esac
}
