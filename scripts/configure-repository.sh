#!/usr/bin/env bash
set -euo pipefail

owner="${1:-}"
if [[ ! "$owner" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo "Usage: $0 <github-user-or-organization>" >&2
    exit 2
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
files=(
    "$project_dir/README.md"
    "$project_dir/README.zh-CN.md"
    "$project_dir/scripts/install-online.sh"
)

for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue
    OWNER="$owner" perl -pi -e 's/YOUR_GITHUB_USERNAME/$ENV{OWNER}/g' "$file"
done

echo "Repository references configured for: $owner/pinyintab"
