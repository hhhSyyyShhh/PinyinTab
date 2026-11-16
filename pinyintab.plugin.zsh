# Oh My Zsh and Zsh plugin-manager entry point for PinyinTab.

() {
  local plugin_file="${(%):-%x}"
  local plugin_root="${plugin_file:A:h}"
  local candidate

  # Prefer an explicit binary, then a user installation, a release bundle,
  # and finally a local source build.
  if [[ -z "${PINYINTAB_BINARY:-}" ]]; then
    for candidate in \
      "$HOME/.local/bin/ptab" \
      "$plugin_root/bin/ptab" \
      "$plugin_root/target/release/ptab"; do
      if [[ -x "$candidate" ]]; then
        export PINYINTAB_BINARY="$candidate"
        break
      fi
    done
  fi

  # The plugin-manager entry opts in by default, unless a mode was saved.
  if [[ -x "${PINYINTAB_BINARY:-$HOME/.local/bin/ptab}" ]]; then
    typeset -g _pinyintab_plugin_default=1
    source "$plugin_root/shell/pinyintab.zsh"
  else
    print -u2 -- "PinyinTab: ptab binary not found; install a Release or build the project first."
  fi
}
