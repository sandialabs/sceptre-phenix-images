#!/bin/bash
# Stage the parseus offline bundle (parseus's own `make stage` (the dir `make package` tars): manage_parseus.py plus every container
# image its compose files use, saved as docker archives) into an overlay for the kali-purple image.
# Run on a host WITH a docker daemon (the image build is a chroot and has none); `make kali-purple-bundle`
# calls this. Output: <overlay-dir>/opt/parseus-bundle/ (git-ignored, ~2 GB gzipped).
#
# The bundle holds what compose.images.yaml at PARSEUS_REF lists (the base stack); in offline mode the image
# build ignores PARSEUS_REPO/PARSEUS_REF (BUNDLE_SOURCE records them) and integrations are untested offline.
#
# usage: parseus-bundle.sh <overlay-dir>
# env:   PARSEUS_REPO, PARSEUS_REF  same defaults as kali-purple.sh; the bundle is pinned to this ref
#        DOCKER_PLATFORM            default linux/amd64, matching `make kali-purple` (phenix builds x86_64
#                                   images). Set linux/arm64 for an arm64 image. When it differs from the
#                                   docker host's arch this builds under emulation and, on a classic image
#                                   store, retags local images of the same name: point DOCKER_HOST at a
#                                   throwaway daemon.
set -euo pipefail

OUT=${1:?usage: parseus-bundle.sh <overlay-dir>}
PARSEUS_REPO="${PARSEUS_REPO:-https://github.com/sandialabs/parseus.git}"
PARSEUS_REF="${PARSEUS_REF:-main}"
export DOCKER_DEFAULT_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone --depth 1 --branch "$PARSEUS_REF" "$PARSEUS_REPO" "$tmp/src"
# parseus's Makefile exports PARSEUS_VERSION from pyproject.toml (needs python >= 3.11 for tomllib)
make -C "$tmp/src" stage PYTHON="${PYTHON:-python3}"

rm -rf "$OUT"
mkdir -p "$OUT/opt"
cp -a "$tmp"/src/dist/parseus-*/ "$OUT/opt/parseus-bundle"
# parseus's bundle loader takes .tar/.tgz/.tar.gz; gzip keeps the overlay (and the build) smaller.
gzip -1 "$OUT"/opt/parseus-bundle/images/*.tar
printf '%s %s\n' "$PARSEUS_REPO" "$PARSEUS_REF" > "$OUT/opt/parseus-bundle/BUNDLE_SOURCE"
du -sh "$OUT/opt/parseus-bundle" "$OUT"/opt/parseus-bundle/images/* >&2
