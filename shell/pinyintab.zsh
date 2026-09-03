# PinyinTab Zsh integration. Source this file; do not execute it directly.

typeset -g _pinyintab_binary="${PINYINTAB_BINARY:-$HOME/.local/bin/ptab}"
typeset -gi _pinyintab_active=0
typeset -gA _pinyintab_saved_comps
typeset -g _pinyintab_saved_default=""
typeset -g _pinyintab_saved_command=""
typeset -g _pinyintab_saved_redirect=""
typeset -ga _pinyintab_commands
_pinyintab_commands=(
  cd python python3 python3.10 python3.11 python3.12 python3.13 python3.14
  cat vim vi nano less head tail
  cp mv rm touch mkdir rmdir java javac julia node ruby perl bash sh
  cargo rustc gcc clang swift swiftc
  ls stat file wc sort uniq diff du find grep egrep fgrep sed awk gawk
  chmod chown chgrp ln readlink realpath tee cut tr tar gzip gunzip unzip
  sudo env command exec source pushd zsh
)
(( ${+PINYINTAB_EXTRA_COMMANDS} )) && _pinyintab_commands+=("${PINYINTAB_EXTRA_COMMANDS[@]}")

# Preserve ordinary executable/PATH completion when no path was typed.
_pinyintab_zsh_command() {
  if [[ "$PREFIX" != */* ]]; then
    if [[ -n "$_pinyintab_saved_command" ]]; then
      "$_pinyintab_saved_command" "$@"
    else
      _command_names "$@"
    fi
    return
  fi
  local _pinyintab_context_filter=--executables
  _pinyintab_zsh_complete
}

_pinyintab_zsh_redirect() {
  # The redirect hook also receives heredoc delimiters and file descriptors.
  # Only operators whose operand is a path may query the filesystem.
  case "${compstate[redirect]-}" in
    '<'|'>'|'>>'|'<>'|'>|'|'&>'|'&>>') ;;
    *) return 0 ;;
  esac
  local _pinyintab_context_filter=--paths
  _pinyintab_zsh_complete
}

# Store the longest literal prefix shared by every candidate in REPLY.
# Zsh calculates insertion text from real filenames, not from their Pinyin
# aliases. Knowing this prefix lets us avoid deleting a semantic query such as
# `t` when its candidates are the unrelated real names `test/` and `图片/`.
_pinyintab_common_prefix() {
  local prefix="${1:-}" candidate
  shift || return 0

  for candidate in "$@"; do
    while [[ -n "$prefix" && "$candidate" != "$prefix"* ]]; do
      prefix="${prefix[1,-2]}"
    done
  done

  REPLY="$prefix"
}

_pinyintab_zsh_complete() {
  local current candidate output common_prefix cursor
  local -a candidates directories files request_words
  current="$PREFIX"

  [[ -x "$_pinyintab_binary" ]] || return 0
  if [[ -n "${_pinyintab_context_filter-}" ]]; then
    output="$("$_pinyintab_binary" complete "$PWD" "$current" "$_pinyintab_context_filter" 2>/dev/null)"
  else
    request_words=("${words[@]}")
    cursor=${CURRENT:-${#words[@]}}
    request_words[$cursor]="$current"
    output="$("$_pinyintab_binary" complete-command "$PWD" "$((cursor - 1))" "${request_words[@]}" 2>/dev/null)"
  fi
  [[ -n "$output" ]] || return 0
  candidates=("${(@f)output}")
  # An empty result must never be passed as a candidate to compadd.
  (( ${#candidates[@]} > 0 )) || return 0
  # -U is required because the real Chinese candidate does not literally start
  # with the pinyin text currently present in PREFIX.
  #
  # When several semantic matches have no safe literal extension, passing them
  # directly to compadd would erase part or all of the user's Pinyin. Display a
  # read-only candidate list instead; after the user types enough to make the
  # result unique, the normal compadd path below inserts the real filename.
  if (( ${#candidates[@]} > 1 )); then
    _pinyintab_common_prefix "${candidates[@]}"
    common_prefix="$REPLY"
    if [[ -z "$common_prefix" ||
          ( "$current" == "$common_prefix"* && "$current" != "$common_prefix" ) ]]; then
      _message -r "${(j:  :)candidates}"
      return 0
    fi
  fi

  for candidate in "${candidates[@]}"; do
    if [[ "$candidate" == */ ]]; then
      directories+=("$candidate")
    else
      files+=("$candidate")
    fi
  done
  (( ${#files[@]} > 0 )) && compadd -U -f -- "${files[@]}"
  (( ${#directories[@]} > 0 )) && compadd -U -f -S '' -- "${directories[@]}"
  return 0
}

ptab() {
  local command previous

  case "${1:-}" in
    on)
      if (( _pinyintab_active )); then
        echo "PinyinTab completion: already ON"
        return 0
      fi

      if (( ! $+functions[compdef] )); then
        autoload -Uz compinit
        compinit
      fi

      _pinyintab_saved_comps=()
      for command in "${_pinyintab_commands[@]}"; do
        _pinyintab_saved_comps[$command]="${_comps[$command]-}"
        compdef _pinyintab_zsh_complete "$command"
      done

      _pinyintab_saved_default="${_comps[-default-]-}"
      _comps[-default-]=_pinyintab_zsh_complete
      _pinyintab_saved_command="${_comps[-command-]-}"
      _pinyintab_saved_redirect="${_comps[-redirect-]-}"
      _comps[-command-]=_pinyintab_zsh_command
      _comps[-redirect-]=_pinyintab_zsh_redirect
      _pinyintab_active=1
      echo "PinyinTab completion: ON"
      ;;
    off)
      if (( ! _pinyintab_active )); then
        echo "PinyinTab completion: already OFF"
        return 0
      fi

      for command in "${_pinyintab_commands[@]}"; do
        compdef -d "$command"
        previous="${_pinyintab_saved_comps[$command]-}"
        [[ -n "$previous" ]] && compdef "$previous" "$command"
      done

      unset '_comps[-default-]'
      [[ -n "$_pinyintab_saved_default" ]] && _comps[-default-]="$_pinyintab_saved_default"
      unset '_comps[-command-]' '_comps[-redirect-]'
      [[ -n "$_pinyintab_saved_command" ]] && _comps[-command-]="$_pinyintab_saved_command"
      [[ -n "$_pinyintab_saved_redirect" ]] && _comps[-redirect-]="$_pinyintab_saved_redirect"
      _pinyintab_active=0
      echo "PinyinTab completion: OFF"
      ;;
    status)
      if (( _pinyintab_active )); then
        echo "PinyinTab completion: ON (Zsh)"
      else
        echo "PinyinTab completion: OFF (Zsh)"
      fi
      ;;
    doctor)
      "$_pinyintab_binary" doctor
      echo "shell: zsh ${ZSH_VERSION}"
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
