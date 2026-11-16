#!/usr/bin/env bash
# Tests for kernel-fallback.sh. Run: scripts/vyos/test-kernel-fallback.sh
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/vyos/kernel-fallback.sh
. "$HERE/kernel-fallback.sh"

fails=0
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# check <name> <defaults.toml body> <Packages body> <want version> <want revision>
check() {
    printf '%s\n' "$2" > "$T/defaults.toml"
    vyos_pin_kernel "$T/defaults.toml" "$3" > /dev/null
    local v r
    v=$(sed -n 's/^kernel_version = "\(.*\)"/\1/p' "$T/defaults.toml")
    r=$(sed -n 's/^kernel_revision = "\(.*\)"/\1/p' "$T/defaults.toml")
    if [ "$v" = "$4" ] && [ "$r" = "$5" ]; then
        echo "ok   $1"
    else
        echo "FAIL $1: got version=$v revision=$r, want version=$4 revision=$5"
        fails=$((fails + 1))
    fi
}

MIRROR='Package: linux-image-6.18.62-1-vyos
Package: linux-image-6.18.62-1-vyos-dbg
Package: linux-image-6.12.40-1-vyos
Package: linux-headers-6.18.62-1-vyos'

check "configured kernel is in the mirror: unchanged" \
    'kernel_version = "6.18.62"
kernel_revision = "1"' "$MIRROR" 6.18.62 1

check "configured kernel missing: newest mirror kernel, version and revision split" \
    'kernel_version = "6.18.63"
kernel_revision = "1"' "$MIRROR" 6.18.62 1

check "mirror revision differs: revision updated too" \
    'kernel_version = "6.18.63"
kernel_revision = "2"' "$MIRROR" 6.18.62 1

check "old config without kernel_revision: version only" \
    'kernel_version = "6.1.99"' 'Package: linux-image-6.1.100-vyos' 6.1.100 ""

check "no mirror listing (offline): unchanged" \
    'kernel_version = "6.18.63"
kernel_revision = "1"' "" 6.18.63 1

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
