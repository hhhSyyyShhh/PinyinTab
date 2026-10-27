# ZLE widgets used only while PinyinTab is enabled. Never bind bare ^C or ^E.
typeset -gA _pinyintab_saved_keys _pinyintab_tab_widgets
typeset -g _pinyintab_language=auto
typeset -g _pinyintab_query_buffer='' _pinyintab_result_buffer=''
typeset -gi _pinyintab_query_cursor=0 _pinyintab_result_cursor=0
typeset -gi _pinyintab_snapshot_valid=0 _pinyintab_did_complete=0

_pinyintab_zsh_tab() {
  local map="$KEYMAP" original
  _pinyintab_language=auto
  _pinyintab_query_buffer="$BUFFER"
  _pinyintab_query_cursor=$CURSOR
  _pinyintab_did_complete=0
  original="${_pinyintab_tab_widgets[$map]:-${_pinyintab_tab_widgets[main]}}"
  zle "$original"
  _pinyintab_result_buffer="$BUFFER"
  _pinyintab_result_cursor=$CURSOR
  _pinyintab_snapshot_valid=$_pinyintab_did_complete
}

_pinyintab_zsh_select() {
  # Restore only immediately after our completion, at the unchanged cursor.
  # Typing, moving the cursor, accepting a line or starting another argument
  # makes the current text the new query, rather than editing an old argument.
  if (( _pinyintab_snapshot_valid )) &&
      [[ "$BUFFER" == "$_pinyintab_result_buffer" &&
         "$CURSOR" == "$_pinyintab_result_cursor" &&
         "$LASTWIDGET" == (_pinyintab_zsh_tab|_pinyintab_zsh_chinese|_pinyintab_zsh_english) ]]; then
    BUFFER="$_pinyintab_query_buffer"
    CURSOR=$_pinyintab_query_cursor
  else
    _pinyintab_query_buffer="$BUFFER"
    _pinyintab_query_cursor=$CURSOR
  fi
  _pinyintab_did_complete=0
  zle _pinyintab_zsh_filtered
  _pinyintab_result_buffer="$BUFFER"
  _pinyintab_result_cursor=$CURSOR
  _pinyintab_snapshot_valid=$_pinyintab_did_complete
  _pinyintab_language=auto
}

_pinyintab_zsh_chinese() { _pinyintab_language=chinese; _pinyintab_zsh_select; }
_pinyintab_zsh_english() { _pinyintab_language=english; _pinyintab_zsh_select; }

_pinyintab_zsh_filtered_complete() {
  if [[ "${compstate[context]-}" == redirect ]]; then
    _pinyintab_zsh_redirect
  else
    _pinyintab_zsh_complete
  fi
}

_pinyintab_zsh_install_keys() {
  [[ -o interactive ]] || return 0
  local map key binding original
  _pinyintab_saved_keys=()
  _pinyintab_tab_widgets[main]="${${(z)$(bindkey '^I')}[-1]}"
  zle -N _pinyintab_zsh_tab
  zle -N _pinyintab_zsh_chinese
  zle -N _pinyintab_zsh_english
  zle -C _pinyintab_zsh_filtered complete-word _pinyintab_zsh_filtered_complete
  for map in emacs viins; do
    for key in '^I' '^Xc' '^Xe'; do
      # bindkey -L returns a shell-quoted command, including macro bindings.
      _pinyintab_saved_keys[$map:$key]="$(bindkey -L -M "$map" "$key")"
    done
    original="${${(z)$(bindkey -M "$map" '^I')}[-1]}"
    _pinyintab_tab_widgets[$map]="$original"
    # A user's Tab macro is not a ZLE widget. Leave it intact rather than
    # trying to execute its text as a widget; direct selectors still work.
    if [[ -n "${widgets[$original]-}" ]]; then
      bindkey -M "$map" '^I' _pinyintab_zsh_tab
    fi
    bindkey -M "$map" '^Xc' _pinyintab_zsh_chinese
    bindkey -M "$map" '^Xe' _pinyintab_zsh_english
  done
  _pinyintab_snapshot_valid=0
}

_pinyintab_zsh_restore_keys() {
  local binding
  for binding in "${(@v)_pinyintab_saved_keys}"; do
    # Only replay definitions produced by bindkey itself, never candidates.
    eval "$binding"
  done
  _pinyintab_saved_keys=()
  _pinyintab_snapshot_valid=0
  _pinyintab_language=auto
}
