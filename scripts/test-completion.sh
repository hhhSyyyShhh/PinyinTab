#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
binary="${PINFS_BINARY:-$project_dir/target/release/pinfs-demo}"
readonly PINFS_BASH_TEST_FIXTURE="$(mktemp -d)"
trap 'rm -rf -- "$PINFS_BASH_TEST_FIXTURE"' EXIT

mkdir -p "$PINFS_BASH_TEST_FIXTURE/测试目录/内部文件夹" "$PINFS_BASH_TEST_FIXTURE/你好"
touch "$PINFS_BASH_TEST_FIXTURE/测试.py"
touch "$PINFS_BASH_TEST_FIXTURE/测视.py"
touch "$PINFS_BASH_TEST_FIXTURE/九九乘法表.py"
touch "$PINFS_BASH_TEST_FIXTURE/乘法口诀表.py"
touch "$PINFS_BASH_TEST_FIXTURE/乘法口诀表.class"
touch "$PINFS_BASH_TEST_FIXTURE/乘法口诀表\$内部.class"
touch "$PINFS_BASH_TEST_FIXTURE/测试目录/内部脚本.py"
touch "$PINFS_BASH_TEST_FIXTURE/项目 说明.md"
touch "$PINFS_BASH_TEST_FIXTURE/录屏 2026-07-17.mov"
touch "$PINFS_BASH_TEST_FIXTURE/README.md"
touch "$PINFS_BASH_TEST_FIXTURE/.隐藏文件"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

contains_line() {
    local output="$1" expected="$2"
    grep -Fqx -- "$expected" <<<"$output" || fail "missing completion: $expected"
}

result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" ce)"
contains_line "$result" "测试.py"
contains_line "$result" "测视.py"

result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" cs)"
contains_line "$result" "测试.py"

# The extension is compared separately from the abbreviated filename stem.
result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" jiujiu.py --files)"
contains_line "$result" "九九乘法表.py"

result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" cfkjb.py --files)"
contains_line "$result" "乘法口诀表.py"

result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" cfkjb --java-classes)"
contains_line "$result" "乘法口诀表"
if grep -Fq '.class' <<<"$result"; then
    fail "java class completion included the .class suffix"
fi

result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" 测)"
contains_line "$result" "测试.py"

result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" README)"
contains_line "$result" "README.md"

result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" xiangmu)"
contains_line "$result" "项目 说明.md"

result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" 测试目录/nei)"
contains_line "$result" "测试目录/内部文件夹/"
contains_line "$result" "测试目录/内部脚本.py"

# V2 resolves a pinyin parent directory before completing its child.
result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" ceshimulu/nei)"
contains_line "$result" "测试目录/内部文件夹/"
contains_line "$result" "测试目录/内部脚本.py"

# A trailing slash means: list entries inside the resolved directory.
result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" ceshimulu/)"
contains_line "$result" "测试目录/内部文件夹/"
contains_line "$result" "测试目录/内部脚本.py"

result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" 测试目录/)"
contains_line "$result" "测试目录/内部文件夹/"

result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" luping --files)"
contains_line "$result" "录屏 2026-07-17.mov"

result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" ce --directories)"
contains_line "$result" "测试目录/"
if grep -Fqx -- "测试.py" <<<"$result"; then
    fail "directory-only completion returned a file"
fi

result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" nihao --files)"
[[ -z "$result" ]] || fail "file-only completion returned a directory"

result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" nihao --directories)"
contains_line "$result" "你好/"

result="$($binary complete "$PINFS_BASH_TEST_FIXTURE" '')"
if grep -Fqx -- ".隐藏文件" <<<"$result"; then
    fail "empty input unexpectedly returned a hidden file"
fi

export PINFS_BINARY="$binary"
# shellcheck source=../shell/pinfs.bash
source "$project_dir/shell/pinfs.bash"
cd "$PINFS_BASH_TEST_FIXTURE"
COMP_WORDS=(python3 ce)
COMP_CWORD=1
_pinfs_complete
contains_line "$(printf '%s\n' "${COMPREPLY[@]}")" "测试.py"

# cat accepts files, so it must not turn a directory into `你好/`.
COMP_WORDS=(cat nihao)
COMP_CWORD=1
_pinfs_complete
[[ -z "${COMPREPLY[*]-}" ]] || fail "cat completion returned a directory"

COMP_WORDS=(cd nihao)
COMP_CWORD=1
_pinfs_complete
contains_line "$(printf '%s\n' "${COMPREPLY[@]}")" "你好/"

COMP_WORDS=(python3 ceshimulu/neibu)
COMP_CWORD=1
_pinfs_complete
contains_line "$(printf '%s\n' "${COMPREPLY[@]}")" "测试目录/内部脚本.py"

COMP_WORDS=(python3.12 cfkjb.py)
COMP_CWORD=1
_pinfs_complete
contains_line "$(printf '%s\n' "${COMPREPLY[@]}")" "乘法口诀表.py"

COMP_WORDS=(java cfkjb)
COMP_CWORD=1
_pinfs_complete
contains_line "$(printf '%s\n' "${COMPREPLY[@]}")" "乘法口诀表"

# The completer only uses the current word, so it also works after a pipe.
COMP_WORDS=(cat README.md '|' python3 ce)
COMP_CWORD=4
_pinfs_complete
contains_line "$(printf '%s\n' "${COMPREPLY[@]}")" "测试.py"

# Enabling and disabling PinFS must restore a command's previous completer.
complete -W 'original-value' python3
before_spec="$(complete -p python3)"
pinfs on >/dev/null
pinfs off >/dev/null
after_spec="$(complete -p python3)"
[[ "$before_spec" == "$after_spec" ]] || fail "pinfs off did not restore previous completion"

echo "PASS: PinFS completion compatibility tests"
