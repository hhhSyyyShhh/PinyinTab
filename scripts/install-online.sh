#!/usr/bin/env bash
set -euo pipefail

repository="${PINYINTAB_REPOSITORY:-hhhSyyyShhh/PinyinTab}"
if [[ ! "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "error: invalid GitHub repository: $repository" >&2
    echo "expected format: owner/repository" >&2
    exit 1
fi

for required_command in curl tar awk mktemp; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        echo "error: required command not found: $required_command" >&2
        exit 1
    fi
done

if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    echo "error: SHA-256 verification requires sha256sum or shasum" >&2
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

# Bound every request, including the checksum request after the archive.
download() {
    curl --proto '=https' --tlsv1.2 --connect-timeout 10 --max-time 120 \
        --retry 2 --retry-delay 2 "$@"
}

release_json="$(download -fsSL "https://api.github.com/repos/$repository/releases/latest")"
tag="$(printf '%s\n' "$release_json" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)"
if [[ -z "$tag" ]]; then
    echo "error: could not determine the latest PinyinTab release" >&2
    exit 1
fi

archive="pinyintab-${tag}-${target}.tar.gz"
base_url="https://github.com/$repository/releases/download/$tag"
download -fL "$base_url/$archive" -o "$temp_dir/$archive"
download -fL "$base_url/$archive.sha256" -o "$temp_dir/$archive.sha256"

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
"$temp_dir/pinyintab-${tag}-${target}/install.sh" "$@"
