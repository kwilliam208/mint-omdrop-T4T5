#!/bin/sh
# Linux OmDrop Installer, one line:
#   curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/install.sh | sh
# A fork sets its own source: OMDROP_REPO=https://github.com/OWNER/REPO (and OMDROP_REF).
# Fetches the source, then continues in the tray's OmDrop icon when there is
# a display and a tray, or in this terminal when there isn't.
set -eu

REPO=${OMDROP_REPO:-https://github.com/kwilliam208/mint-omdrop-T4T5}
REF=${OMDROP_REF:-main}
DEST=${XDG_DATA_HOME:-$HOME/.local/share}/omdrop-installer/src

say() { printf '%s\n' "$*"; }
[ "$(id -u)" -ne 0 ] || { say "Run this as yourself, not root; it asks for your password when it needs it."; exit 1; }

root() { if command -v sudo >/dev/null; then sudo "$@"; else su -c "$*"; fi; }

# git, and the tray's own libraries, before anything else.
need=''
command -v git >/dev/null || need=git
python3 -c 'import gi' 2>/dev/null || need="$need gi"
if [ -n "$need" ]; then
  say "Installing: git, Python GObject"
  if command -v apt-get >/dev/null; then root apt-get update -qq && root apt-get install -y -qq git python3-gi gir1.2-gtk-3.0
  elif command -v dnf >/dev/null; then root dnf install -y -q git python3-gobject gtk3
  elif command -v zypper >/dev/null; then root zypper -n -q install git python3-gobject typelib-1_0-Gtk-3_0
  elif command -v pacman >/dev/null; then root pacman -S --noconfirm --needed git python-gobject gtk3
  else say "Install git and Python GObject (python3-gi), then run this again."; exit 1; fi
fi

# Run from a checkout (git clone ... && ./install.sh): use it as it is.
here=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
if [ -f "$here/tools/omdrop-installer" ] && [ -f "$here/install.sh" ]; then
  DEST=$here
  say "Using $DEST"
else
  say "Fetching $REPO ($REF)"
  mkdir -p "$(dirname "$DEST")"
  if [ -d "$DEST/.git" ]; then
    git -C "$DEST" fetch -q --depth 1 origin "$REF" && git -C "$DEST" reset -q --hard FETCH_HEAD
  else
    rm -rf "${DEST:?}"
    git clone -q --depth 1 --branch "$REF" "$REPO" "$DEST"
  fi
fi

if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && [ "$("$DEST/tools/omdrop-installer" check --json | grep -c '"tray: ')" -gt 0 ]; then
  OMDROP_GUI=1 setsid "$DEST/desktop/omdrop-tray" --setup >/dev/null 2>&1 < /dev/null &
  say "Click the OmDrop icon in your panel to finish setting up."
else
  exec "$DEST/tools/omdrop-installer" < /dev/tty
fi
