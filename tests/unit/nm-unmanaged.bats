#!/usr/bin/env bats
# packaging/99-omdrop-owl-unmanaged.conf against other distros' conf.d files,
# merged by NetworkManager itself and judged by packaging/check-nm-unmanaged.
# Skips where NetworkManager isn't installed.

load ../helpers

CHECK=packaging/check-nm-unmanaged

# A conf.d of its own, so nothing on this machine leaks in.
nm_check() {
  printf '[main]\n' > "$TMP/NetworkManager.conf"
  "$REPO/$CHECK" "$@" --config="$TMP/NetworkManager.conf" --config-dir="$TMP/conf.d" \
    --system-config-dir="$TMP/lib" --intern-config="$TMP/intern"
}

setup_file() {
  command -v NetworkManager >/dev/null || skip "NetworkManager isn't installed"
}

# What Linux Mint's ubuntu-system-adjustments package ships, sorting after 99-.
mint_adjustments() {
  printf '[keyfile]\nunmanaged-devices=none\n' > "$TMP/conf.d/ubuntu-system-adjustments.conf"
}

@test "the vendor file leaves OWL's interfaces unmanaged" {
  mkdir -p "$TMP/conf.d" "$TMP/lib"
  cp "$REPO/packaging/99-omdrop-owl-unmanaged.conf" "$TMP/lib/"
  run nm_check
  [ "$status" -eq 0 ] || fail "$output"
}

@test "it still applies after Linux Mint's unmanaged-devices=none" {
  mkdir -p "$TMP/conf.d" "$TMP/lib"
  cp "$REPO/packaging/99-omdrop-owl-unmanaged.conf" "$TMP/lib/"
  mint_adjustments
  run nm_check
  [ "$status" -eq 0 ] || fail "$output"
}

@test "it leaves the user's unmanaged-devices in place" {
  mkdir -p "$TMP/conf.d" "$TMP/lib"
  cp "$REPO/packaging/99-omdrop-owl-unmanaged.conf" "$TMP/lib/"
  printf '[keyfile]\nunmanaged-devices=interface-name:eth9\n' > "$TMP/conf.d/user.conf"
  printf '[main]\n' > "$TMP/NetworkManager.conf"
  run NetworkManager --print-config --config="$TMP/NetworkManager.conf" --config-dir="$TMP/conf.d" \
    --system-config-dir="$TMP/lib" --intern-config="$TMP/intern"
  [[ "$output" == *"unmanaged-devices=interface-name:eth9"* ]] || fail "$output"
}

@test "the check notices when nothing keeps them unmanaged" {
  mkdir -p "$TMP/conf.d" "$TMP/lib"
  mint_adjustments
  run nm_check
  [ "$status" -eq 1 ]
  [ "$output" = "NetworkManager would manage: awdl0 mon0 awdlibss0" ]
}

@test "the check accepts the older keyfile form" {
  mkdir -p "$TMP/conf.d" "$TMP/lib"
  printf '[keyfile]\nunmanaged-devices=interface-name:awdl0;interface-name:mon0;interface-name:awdlibss0\n' \
    > "$TMP/conf.d/zz-omdrop-owl-unmanaged.conf"
  run nm_check
  [ "$status" -eq 0 ] || fail "$output"
}

@test "the check names only the interfaces left managed" {
  mkdir -p "$TMP/conf.d" "$TMP/lib"
  printf '[keyfile]\nunmanaged-devices=interface-name:awdl0\n' > "$TMP/conf.d/partial.conf"
  run nm_check
  [ "$status" -eq 1 ]
  [ "$output" = "NetworkManager would manage: mon0 awdlibss0" ]
}

@test "the udev rule names the same interfaces" {
  run grep -c 'KERNEL=="awdl0|mon0|awdlibss0".*ENV{NM_UNMANAGED}="1"' "$REPO/packaging/86-omdrop-owl-unmanaged.rules"
  [ "$output" = 1 ]
}
