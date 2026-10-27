#!/usr/bin/env zsh
set -eu

project_dir="${0:A:h:h}"
binary="${PINFS_BINARY:-$project_dir/target/release/pinfs-demo}"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/测试目录/内部文件夹" "$fixture/你好"
touch "$fixture/测试.py" "$fixture/测视.py" "$fixture/项目 说明.md"
touch "$fixture/测试目录/内部脚本.py"

contains_line() {
  local output="$1" expected="$2"
  print -r -- "$output" | grep -Fqx -- "$expected" || {
    print -u2 -- "FAIL: missing completion: $expected"
    exit 1
  }
}

local result
result="$("$binary" complete "$fixture" ce)"
contains_line "$result" "测试.py"
contains_line "$result" "测视.py"

result="$("$binary" complete "$fixture" 测试目录/nei)"
contains_line "$result" "测试目录/内部文件夹/"

result="$("$binary" complete "$fixture" ceshimulu/neibu)"
contains_line "$result" "测试目录/内部脚本.py"

result="$("$binary" complete "$fixture" ceshimulu/)"
contains_line "$result" "测试目录/内部文件夹/"

result="$("$binary" complete "$fixture" nihao --files)"
[[ -z "$result" ]] || {
  print -u2 -- "FAIL: file-only completion returned a directory"
  exit 1
}

export PINFS_BINARY="$binary"
source "$project_dir/shell/pinfs.zsh"

# Mock compadd to verify that an empty Rust result does not become an empty Zsh
# candidate, which previously replaced the current word with a stray slash.
typeset -ga captured_compadd
compadd() { captured_compadd=("$@") }
cd "$fixture"
PREFIX=nihao
words=(cat nihao)
captured_compadd=()
_pinfs_zsh_complete
(( ${#captured_compadd[@]} == 0 )) || {
  print -u2 -- "FAIL: empty completion called compadd and may insert a slash"
  exit 1
}
unfunction compadd

autoload -Uz compinit
compinit -d "$fixture/.zcompdump"
compdef _original_pinfs_test python3
typeset original="${_comps[python3]}"
pinfs on >/dev/null
pinfs off >/dev/null
[[ "${_comps[python3]}" == "$original" ]] || {
  print -u2 -- "FAIL: pinfs off did not restore the previous Zsh completer"
  exit 1
}

print "PASS: PinFS macOS/Zsh compatibility tests"
