#!/bin/bash
# Assemble build/lib, laid out as /usr/lib/omdrop: our userspace/ beside
# omdrop-awdl's radio-independent tools (GPL-2.0-only, fetched at a pinned
# commit, never committed here).
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
UPSTREAM_REPO=https://github.com/brentkearney/omdrop-awdl.git
. "$ROOT/pins"
UPSTREAM_COMMIT=$OMDROP_AWDL_COMMIT
UP=$ROOT/upstream/omdrop-awdl
LIB=$ROOT/build/lib

# Everything here talks to awdl0 through sockets or to BlueZ over D-Bus; none
# of it touches the Broadcom firmware (that is omdrop-discoverable, awdl-up and
# brcm_iovar.py, which we replace).
FROM_UPSTREAM=(
  send-to-peer          # picks a peer and drives the sender
  airdrop-send.py       # the sender: /Discover, /Ask, /Upload
  awdl-af-parse.py      # imported by the sender
  awdl_identity.py      # identity, host name and record data for all of these
  awdl_debug.py         # imported by the sender
  ble-airdrop-adv.py    # the BLE Continuity advert that wakes a receiver
  awdl-airdrop-adv.py   # unsolicited receiver announcements on awdl0
  awdl-mdns-respond.py  # answers mDNS queries for our identity on awdl0
)

OWL_BIN=$ROOT/upstream/owl/build/daemon/owl
[ -x "$OWL_BIN" ] || { echo "no OWL build at $OWL_BIN; run tools/build-owl.sh first"; exit 1; }

if [ ! -d "$UP/.git" ]; then
  git clone -q "$UPSTREAM_REPO" "$UP"
fi
git -C "$UP" fetch -q origin || true
git -C "$UP" -c advice.detachedHead=false checkout -q "$UPSTREAM_COMMIT"

# Replace files rather than the directory: running these tools as root (as
# pkexec does) leaves a root-owned __pycache__ here, which a user can't delete
# and Python revalidates against the sources anyway.
mkdir -p "$LIB"
find "$LIB" -maxdepth 1 -type f -delete
for f in "${FROM_UPSTREAM[@]}"; do
  cp "$UP/userspace/$f" "$LIB/$f"
done
cp "$ROOT"/userspace/* "$LIB/"
cp "$OWL_BIN" "$LIB/owl"
chmod 755 "$LIB/send-to-peer" "$LIB/omdrop-discoverable" "$LIB/owl" "$LIB"/*.py

echo "staged $LIB: ${#FROM_UPSTREAM[@]} files from omdrop-awdl@${UPSTREAM_COMMIT:0:7}, $(ls "$ROOT/userspace" | wc -l) of ours, and owl"
