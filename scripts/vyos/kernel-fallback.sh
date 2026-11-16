#!/usr/bin/env bash
# Sourced by build-vyos.sh; tested by test-kernel-fallback.sh.

# vyos_pin_kernel <defaults.toml> <Packages list>
#
# vyos-build installs linux-image-<kernel_version>-<kernel_revision>-vyos
# (older vyos-build without kernel_revision: linux-image-<kernel_version>-vyos).
# If that package is not in the VyOS mirror's Packages list, point
# defaults.toml at the newest kernel the mirror does have, splitting its
# version and revision. An empty list (mirror unreachable) changes nothing.
vyos_pin_kernel() {
    local toml=$1 list=$2 version revision want available
    [ -n "$list" ] || return 0

    version=$(sed -n 's/^kernel_version = "\(.*\)"/\1/p' "$toml")
    revision=$(sed -n 's/^kernel_revision = "\(.*\)"/\1/p' "$toml")
    want=$version${revision:+-$revision}
    grep -Fxq "Package: linux-image-${want}-vyos" <<< "$list" && return 0

    available=$(awk -F': ' '$1=="Package" && $2 ~ /^linux-image-[0-9].*-vyos$/ { sub(/^linux-image-/, "", $2); sub(/-vyos$/, "", $2); print $2 }' <<< "$list" | sort -V | tail -n1)
    [ -n "$available" ] || return 0

    echo "WARNING: Kernel ${want} not found in VyOS repository; using available ${available}"
    if grep -q '^kernel_revision = ' "$toml"; then
        sed -i -e "s/^kernel_version = .*/kernel_version = \"${available%-*}\"/" \
            -e "s/^kernel_revision = .*/kernel_revision = \"${available##*-}\"/" "$toml"
    else
        sed -i "s/^kernel_version = .*/kernel_version = \"${available}\"/" "$toml"
    fi
}
