#!/usr/bin/env bash
set -euo pipefail

repository="${PINYINTAB_REPOSITORY:-hhhSyyyShhh/pinyintab}"
if [[ ! "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "error: invalid GitHub repository: $repository" >&2
    echo "expected format: owner/repository" >&2
    exit 1
fi

case "$(uname -s)/$(uname -m)" in
    Linux/x86_64)
        target="x86_64-unknown-linux-gnu"
        ;;
    Darwin/arm64)
        target="aarch64-apple-darwin"
        ;;
    *)
        echo "error: PinyinTab supports Linux x86_64 and macOS arm64 in this release" >&2
        exit 1
        ;;
esac

temp_dir="$(mktemp -d)"
trap 'rm -rf -- "$temp_dir"' EXIT

release_json="$(curl --proto '=https' --tlsv1.2 -fsSL "https://api.github.com/repos/$repository/releases/latest")"
tag="$(printf '%s\n' "$release_json" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)"
if [[ -z "$tag" ]]; then
    echo "error: could not determine the latest PinyinTab release" >&2
    exit 1
fi

archive="pinyintab-${tag}-${target}.tar.gz"
base_url="https://github.com/$repository/releases/download/$tag"
curl --proto '=https' --tlsv1.2 -fL "$base_url/$archive" -o "$temp_dir/$archive"
curl --proto '=https' --tlsv1.2 -fL "$base_url/$archive.sha256" -o "$temp_dir/$archive.sha256"

if command -v sha256sum >/dev/null 2>&1; then
    (cd "$temp_dir" && sha256sum -c "$archive.sha256")
else
    expected="$(awk '{print $1}' "$temp_dir/$archive.sha256")"
    actual="$(shasum -a 256 "$temp_dir/$archive" | awk '{print $1}')"
    [[ "$actual" == "$expected" ]] || {
        echo "error: checksum verification failed" >&2
        exit 1
    }
fi

tar -xzf "$temp_dir/$archive" -C "$temp_dir"
exec "$temp_dir/pinyintab-${tag}-${target}/install.sh" "$@"
