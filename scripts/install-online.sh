#!/usr/bin/env bash
set -euo pipefail

repository="${PINYINTAB_REPOSITORY:-hhhSyyyShhh/PinyinTab}"
update_version=""
if [[ "${1:-}" == --update ]]; then
    update_version="${2:-}"
    [[ "$update_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $# == 2 ]] || {
        echo 'error: expected --update <installed-version>' >&2
        exit 2
    }
    shift 2
fi
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
trap 'exit 130' INT
trap 'exit 143' HUP TERM

# Bound each request. An HTTP/2 transport failure can happen even after
# GitHub returned the version metadata. Retry that request once over HTTP/1.1.
download() {
    local status
    local -a limits=(--proto '=https' --tlsv1.2 --connect-timeout 10 --max-time 120)
    if curl "${limits[@]}" --retry 2 --retry-delay 2 "$@"; then
        return 0
    else
        status=$?
    fi
    case "$status" in
        16|92)
            printf '%s\n' 'HTTP/2 transfer failed; retrying over HTTPS with HTTP/1.1.' >&2
            curl "${limits[@]}" --http1.1 --retry 0 "$@"
            ;;
        *) return "$status" ;;
    esac
}

printf '%s\n' '[1/4] Checking the latest release...' >&2
if ! download -fsSL "https://api.github.com/repos/$repository/releases/latest" -o "$temp_dir/latest.json"; then
    echo 'error: could not check the latest release; installed files were not changed' >&2
    echo "Check GitHub connectivity/API limits, or install manually from https://github.com/$repository/releases/latest" >&2
    exit 1
fi
tag="$(sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' "$temp_dir/latest.json" | head -n 1)"
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: latest release does not have a supported version tag" >&2
    exit 1
fi
if [[ -n "$update_version" ]]; then
    newest="${tag#v}"
    # Numeric fields, not lexical sorting (0.10 is newer than 0.9).
    if ! awk -v current="$update_version" -v latest="$newest" 'BEGIN {
        split(current, c, "."); split(latest, n, ".");
        for (i=1; i<=3; i++) {
            if (n[i]+0 > c[i]+0) exit 0;
            if (n[i]+0 < c[i]+0) exit 1;
        }
        exit 1;
    }'; then
        echo "PinyinTab $update_version is up to date (latest stable: $newest)."
        exit 0
    fi
    echo "Updating PinyinTab $update_version -> $newest"
fi

archive="pinyintab-${tag}-${target}.tar.gz"
base_url="https://github.com/$repository/releases/download/$tag"
printf '[2/4] Downloading %s...\n' "$archive" >&2
if [[ -t 2 && "${TERM:-dumb}" != dumb ]]; then
    archive_options=(-fL --progress-bar)
else
    archive_options=(-fsSL)
fi
if ! download "${archive_options[@]}" "$base_url/$archive" -o "$temp_dir/$archive"; then
    printf '%s\n' 'error: could not download the archive; installed files were not changed' >&2
    exit 1
fi
printf '%s\n' '[3/4] Checking SHA-256 and package contents...' >&2
if ! download -fsSL "$base_url/$archive.sha256" -o "$temp_dir/$archive.sha256"; then
    printf '%s\n' 'error: could not download the checksum; installed files were not changed' >&2
    exit 1
fi

expected="$(awk 'NR == 1 {print tolower($1)} END {if (NR != 1) exit 1}' "$temp_dir/$archive.sha256")"
[[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || {
    echo "error: invalid SHA-256 file" >&2
    exit 1
}
if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$temp_dir/$archive" | awk '{print $1}')"
else
    actual="$(shasum -a 256 "$temp_dir/$archive" | awk '{print $1}')"
fi
[[ "$actual" == "$expected" ]] || {
    echo "error: checksum verification failed; installed files were not changed" >&2
    exit 1
}

package_name="pinyintab-${tag}-${target}"
# Reject traversal, foreign roots and archive links before extraction. The
# official package contains only regular files and directories.
tar -tzf "$temp_dir/$archive" >"$temp_dir/members"
awk -v root="$package_name" '
    $0 != root && index($0, root "/") != 1 { exit 1 }
    /(^|\/)\.\.?(\/|$)/ || /^\// { exit 1 }
' "$temp_dir/members" || { echo 'error: unsafe archive path' >&2; exit 1; }
if tar -tvzf "$temp_dir/$archive" | awk 'substr($0,1,1) != "-" && substr($0,1,1) != "d" {bad=1} END {exit !bad}'; then
    echo 'error: archive links and special files are not supported' >&2
    exit 1
fi
tar -xzf "$temp_dir/$archive" -C "$temp_dir"
package="$temp_dir/$package_name"
[[ "$("$package/bin/ptab" version)" == "PinyinTab ${tag#v}" ]] || {
    echo 'error: downloaded binary version does not match the release' >&2
    exit 1
}
if [[ -n "$update_version" ]]; then
    printf '%s\n' '[4/4] Replacing the installed version...' >&2
    bash "$package/apply-update.sh" "$package"
    echo "Updated to PinyinTab ${tag#v}. Temporary downloads and the old managed installation were removed."
    echo 'Restart the terminal (or reconnect SSH), then run: ptab version; ptab on'
else
    printf '%s\n' '[4/4] Installing PinyinTab...' >&2
    "$package/install.sh" "$@"
fi
