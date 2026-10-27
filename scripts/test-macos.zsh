#!/usr/bin/env zsh
set -eu

project_dir="${0:A:h:h}"
binary="${PINFS_BINARY:-$project_dir/target/release/pinfs-demo}"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/测试目录/内部文件夹"
touch "$fixture/测试.py" "$fixture/测视.py" "$fixture/项目 说明.md"

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

export PINFS_BINARY="$binary"
source "$project_dir/shell/pinfs.zsh"
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
