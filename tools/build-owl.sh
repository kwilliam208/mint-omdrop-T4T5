#!/bin/bash
# Build OWL (jedbillyb/owl at the pinned commit) into upstream/owl, with
# patches/ applied in order. No root, no radio. Edits in upstream/owl are lost
# on rebuild: put them in a patch.
#   01 -R data rate   02 -m AWDL address   03 -F fixed radio   04 -E election by metric
#   05 -F unicast without ACK   06 -S pin   07 Intel reliability
#   08 A-MSDU bound (tests/owl_amsdu.c)   09 iPhone MIF zero padding (tests/owl_padding.c)
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DIR=$ROOT/upstream/owl
OWL_REPO=https://github.com/jedbillyb/owl.git
. "$ROOT/pins"

# Asked of the compiler, not /usr/include: Nix keeps headers elsewhere.
echo '#include <ev.h>' | "${CC:-cc}" -E -x c - >/dev/null 2>&1 || { echo "libev headers missing (Linux Mint, Debian, Ubuntu: sudo apt install libev-dev; Fedora: sudo dnf install libev-devel; Arch: sudo pacman -S libev)"; exit 1; }

if [ ! -d "$DIR/.git" ]; then
  git clone -q --recurse-submodules "$OWL_REPO" "$DIR"
fi
git -C "$DIR" fetch -q origin || true
git -C "$DIR" checkout -q -- .
git -C "$DIR" -c advice.detachedHead=false checkout -q "$OWL_COMMIT"
git -C "$DIR" submodule update -q --init --recursive
for p in "$ROOT"/patches/owl-*.patch; do
  git -C "$DIR" apply "$p" || { echo "$(basename "$p") did not apply to owl@$OWL_COMMIT"; exit 1; }
done

# The policy minimum is for the bundled googletest, whose
# cmake_minimum_required predates 3.5, which CMake 4 refuses. Only the owl
# target is built: googletest fails under current GCC and isn't needed.
cmake -S "$DIR" -B "$DIR/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 >/dev/null
cmake --build "$DIR/build" --target owl -j"$(nproc)" >/dev/null

BIN=$DIR/build/daemon/owl
case "$("$BIN" -S intersect -R 12 -m 02:00:00:00:00:01 -F -E -h 2>&1 || true)" in
  *"invalid option"*|*"-R takes"*|*"-m takes"*) echo "$BIN lacks -S, -R, -m, -F or -E; did the patches apply?"; exit 1 ;;
esac
echo "built $BIN: owl@${OWL_COMMIT:0:7} + $(ls "$ROOT"/patches/owl-*.patch | wc -l) patches"
