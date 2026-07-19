#!/usr/bin/env zsh
set -eu

project_dir="${0:A:h:h}"
binary="${PINYINTAB_BINARY:-$project_dir/target/release/ptab}"
typeset -gr PINYINTAB_MACOS_TEST_FIXTURE="$(mktemp -d)"
trap 'rm -rf -- "$PINYINTAB_MACOS_TEST_FIXTURE"' EXIT

mkdir -p "$PINYINTAB_MACOS_TEST_FIXTURE/测试目录/内部文件夹" "$PINYINTAB_MACOS_TEST_FIXTURE/你好"
touch "$PINYINTAB_MACOS_TEST_FIXTURE/测试.py" "$PINYINTAB_MACOS_TEST_FIXTURE/测视.py" "$PINYINTAB_MACOS_TEST_FIXTURE/项目 说明.md"
touch "$PINYINTAB_MACOS_TEST_FIXTURE/九九乘法表.py" "$PINYINTAB_MACOS_TEST_FIXTURE/乘法口诀表.py"
touch "$PINYINTAB_MACOS_TEST_FIXTURE/九九测试程序.py"
touch "$PINYINTAB_MACOS_TEST_FIXTURE/乘法口诀表.class"
touch "$PINYINTAB_MACOS_TEST_FIXTURE/测试目录/内部脚本.py"

contains_line() {
  local output="$1" expected="$2"
  print -r -- "$output" | grep -Fqx -- "$expected" || {
    print -u2 -- "FAIL: missing completion: $expected"
    exit 1
  }
}

local result
result="$("$binary" complete "$PINYINTAB_MACOS_TEST_FIXTURE" ce)"
contains_line "$result" "测试.py"
contains_line "$result" "测视.py"

result="$("$binary" complete "$PINYINTAB_MACOS_TEST_FIXTURE" 测试目录/nei)"
contains_line "$result" "测试目录/内部文件夹/"

result="$("$binary" complete "$PINYINTAB_MACOS_TEST_FIXTURE" ceshimulu/neibu)"
contains_line "$result" "测试目录/内部脚本.py"

result="$("$binary" complete "$PINYINTAB_MACOS_TEST_FIXTURE" ceshimulu/)"
contains_line "$result" "测试目录/内部文件夹/"

result="$("$binary" complete "$PINYINTAB_MACOS_TEST_FIXTURE" jiujiu.py --files)"
contains_line "$result" "九九乘法表.py"

result="$("$binary" complete "$PINYINTAB_MACOS_TEST_FIXTURE" jj --files)"
contains_line "$result" "九九乘法表.py"
contains_line "$result" "九九测试程序.py"

result="$("$binary" complete "$PINYINTAB_MACOS_TEST_FIXTURE" 九九cf --files)"
contains_line "$result" "九九乘法表.py"
[[ "$result" != *'九九测试程序.py'* ]] || {
  print -u2 -- "FAIL: mixed Chinese+pinyin input did not narrow candidates"
  exit 1
}

result="$("$binary" complete "$PINYINTAB_MACOS_TEST_FIXTURE" 九九cs --files)"
contains_line "$result" "九九测试程序.py"

result="$("$binary" complete "$PINYINTAB_MACOS_TEST_FIXTURE" cfkjb.py --files)"
contains_line "$result" "乘法口诀表.py"

result="$("$binary" complete "$PINYINTAB_MACOS_TEST_FIXTURE" cfkjb --java-classes)"
contains_line "$result" "乘法口诀表"
[[ "$result" != *'.class'* ]] || {
  print -u2 -- "FAIL: Java completion included the .class suffix"
  exit 1
}

result="$("$binary" complete "$PINYINTAB_MACOS_TEST_FIXTURE" nihao --files)"
[[ -z "$result" ]] || {
  print -u2 -- "FAIL: file-only completion returned a directory"
  exit 1
}

export PINYINTAB_BINARY="$binary"
source "$project_dir/shell/pinyintab.zsh"

# Mock compadd to verify that an empty Rust result does not become an empty Zsh
# candidate, which previously replaced the current word with a stray slash.
typeset -ga captured_compadd
compadd() { captured_compadd=("$@") }
cd "$PINYINTAB_MACOS_TEST_FIXTURE"
PREFIX=nihao
words=(cat nihao)
captured_compadd=()
_pinyintab_zsh_complete
(( ${#captured_compadd[@]} == 0 )) || {
  print -u2 -- "FAIL: empty completion called compadd and may insert a slash"
  exit 1
}
unfunction compadd

autoload -Uz compinit
compinit -d "$PINYINTAB_MACOS_TEST_FIXTURE/.zcompdump"
compdef _original_pinyintab_test python3
typeset original="${_comps[python3]}"
ptab on >/dev/null
ptab off >/dev/null
[[ "${_comps[python3]}" == "$original" ]] || {
  print -u2 -- "FAIL: ptab off did not restore the previous Zsh completer"
  exit 1
}

print "PASS: PinyinTab macOS/Zsh compatibility tests"
