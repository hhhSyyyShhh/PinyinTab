#!/usr/bin/env bash
set -euo pipefail

owner="${1:-}"
if [[ ! "$owner" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo "Usage: $0 <github-user-or-organization>" >&2
    exit 2
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
current_owner="$(sed -n 's|^repository = "https://github.com/\([^/]*\)/pinyintab"|\1|p' "$project_dir/Cargo.toml" | head -n 1)"
if [[ -z "$current_owner" ]]; then
    echo "error: could not determine the current GitHub owner from Cargo.toml" >&2
    exit 1
fi

files=(
    "$project_dir/README.md"
    "$project_dir/README.zh-CN.md"
    "$project_dir/Cargo.toml"
    "$project_dir/docs/RELEASE_GUIDE.md"
    "$project_dir/scripts/install-online.sh"
)

for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue
    CURRENT_OWNER="$current_owner" OWNER="$owner" perl -pi -e '
        s/YOUR_GITHUB_USERNAME/$ENV{OWNER}/g;
        s/\Q$ENV{CURRENT_OWNER}\E/$ENV{OWNER}/g;
    ' "$file"
done

echo "Repository references configured for: $owner/pinyintab"
