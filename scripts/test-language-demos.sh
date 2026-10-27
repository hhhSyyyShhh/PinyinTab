#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$project_dir/demo-source"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

passed=0
skipped=0

check_output() {
    local language="$1" output="$2"
    if grep -Fq '9×9=81' "$output"; then
        echo "PASS: $language"
        passed=$((passed + 1))
    else
        echo "FAIL: $language did not print the complete multiplication table" >&2
        exit 1
    fi
}

skip_runtime() {
    echo "SKIP: $1 (runtime not installed)"
    skipped=$((skipped + 1))
}

if command -v python3 >/dev/null 2>&1; then
    python3 "$source_dir/九九乘法表.py" > "$temporary_dir/python.txt"
    check_output Python "$temporary_dir/python.txt"
else
    skip_runtime Python
fi

if command -v javac >/dev/null 2>&1 && command -v java >/dev/null 2>&1; then
    javac -encoding UTF-8 -d "$temporary_dir" "$source_dir/乘法口诀表.java"
    java -cp "$temporary_dir" 乘法口诀表 > "$temporary_dir/java.txt"
    check_output Java "$temporary_dir/java.txt"
else
    skip_runtime Java
fi

if command -v julia >/dev/null 2>&1; then
    julia --startup-file=no "$source_dir/乘法口诀表.jl" > "$temporary_dir/julia.txt"
    check_output Julia "$temporary_dir/julia.txt"
else
    skip_runtime Julia
fi

if command -v node >/dev/null 2>&1; then
    node "$source_dir/乘法口诀表.js" > "$temporary_dir/javascript.txt"
    check_output JavaScript "$temporary_dir/javascript.txt"
else
    skip_runtime JavaScript
fi

if command -v ruby >/dev/null 2>&1; then
    ruby "$source_dir/乘法口诀表.rb" > "$temporary_dir/ruby.txt"
    check_output Ruby "$temporary_dir/ruby.txt"
else
    skip_runtime Ruby
fi

if command -v perl >/dev/null 2>&1; then
    perl "$source_dir/乘法口诀表.pl" > "$temporary_dir/perl.txt"
    check_output Perl "$temporary_dir/perl.txt"
else
    skip_runtime Perl
fi

if command -v clang >/dev/null 2>&1; then
    clang "$source_dir/乘法口诀表.c" -o "$temporary_dir/multiplication-c"
    "$temporary_dir/multiplication-c" > "$temporary_dir/c.txt"
    check_output C "$temporary_dir/c.txt"
else
    skip_runtime C
fi

if command -v rustc >/dev/null 2>&1; then
    rustc "$source_dir/乘法口诀表.rs" -o "$temporary_dir/multiplication-rust"
    "$temporary_dir/multiplication-rust" > "$temporary_dir/rust.txt"
    check_output Rust "$temporary_dir/rust.txt"
else
    skip_runtime Rust
fi

if command -v swiftc >/dev/null 2>&1; then
    swiftc "$source_dir/乘法口诀表.swift" -o "$temporary_dir/multiplication-swift"
    "$temporary_dir/multiplication-swift" > "$temporary_dir/swift.txt"
    check_output Swift "$temporary_dir/swift.txt"
else
    skip_runtime Swift
fi

bash "$source_dir/乘法口诀表.sh" > "$temporary_dir/bash.txt"
check_output Bash "$temporary_dir/bash.txt"

echo "Language demo summary: $passed passed, $skipped skipped"
