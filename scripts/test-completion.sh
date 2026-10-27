#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
binary="${PINFS_BINARY:-$project_dir/target/release/pinfs-demo}"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/测试目录/内部文件夹"
touch "$fixture/测试.py"
touch "$fixture/测视.py"
touch "$fixture/项目 说明.md"
touch "$fixture/README.md"
touch "$fixture/.隐藏文件"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

contains_line() {
    local output="$1" expected="$2"
    grep -Fqx -- "$expected" <<<"$output" || fail "missing completion: $expected"
}

result="$($binary complete "$fixture" ce)"
contains_line "$result" "测试.py"
contains_line "$result" "测视.py"

result="$($binary complete "$fixture" cs)"
contains_line "$result" "测试.py"

result="$($binary complete "$fixture" 测)"
contains_line "$result" "测试.py"

result="$($binary complete "$fixture" README)"
contains_line "$result" "README.md"

result="$($binary complete "$fixture" xiangmu)"
contains_line "$result" "项目 说明.md"

result="$($binary complete "$fixture" 测试目录/nei)"
contains_line "$result" "测试目录/内部文件夹/"

result="$($binary complete "$fixture" ce --directories)"
contains_line "$result" "测试目录/"
if grep -Fqx -- "测试.py" <<<"$result"; then
    fail "directory-only completion returned a file"
fi

result="$($binary complete "$fixture" '')"
if grep -Fqx -- ".隐藏文件" <<<"$result"; then
    fail "empty input unexpectedly returned a hidden file"
fi

export PINFS_BINARY="$binary"
# shellcheck source=../shell/pinfs.bash
source "$project_dir/shell/pinfs.bash"
cd "$fixture"
COMP_WORDS=(python3 ce)
COMP_CWORD=1
_pinfs_complete
contains_line "$(printf '%s\n' "${COMPREPLY[@]}")" "测试.py"

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
