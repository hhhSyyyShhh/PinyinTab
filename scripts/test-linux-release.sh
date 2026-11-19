#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive="${1:-}"
if [[ $# != 1 || ! -f "$archive" ]]; then
    echo "Usage: $0 <linux-release.tar.gz>" >&2
    exit 2
fi
archive="$(cd "$(dirname "$archive")" && pwd)/$(basename "$archive")"

if [[ "$(uname -sm)" != 'Linux x86_64' ]]; then
    echo 'FAIL: Linux release validation requires a Linux x86_64 runner' >&2
    exit 1
fi

for image in ubuntu:22.04 ubuntu:24.04 quay.io/centos/centos:stream9; do
    printf '\n== Testing the installed release on %s ==\n' "$image"
    docker run --rm \
        -v "$project_dir:/workspace:ro" \
        -v "$archive:/release.tar.gz:ro" \
        "$image" bash -c '
            set -e
            if ! command -v python3 >/dev/null; then
                if command -v apt-get >/dev/null; then
                    apt-get -qq update
                    apt-get -qq install -y --no-install-recommends python3
                else
                    dnf -qy install python3
                fi
            fi
            . /etc/os-release
            printf "%s; Bash %s\n" "$PRETTY_NAME" "$BASH_VERSION"
            /workspace/scripts/test-release-archive.sh /release.tar.gz --interactive
        '
done
