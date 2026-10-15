# OmDrop for Linux Mint: the details

Everything the [front page](../README.md) leaves out: what the installer does
step by step, the commands, supported Wi-Fi cards, how it works, and known
issues.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/kwilliam208/mint-omdrop-T4T5/main/install.sh | sh
```

From a private copy, or with no `curl`, clone it and run it there:

```sh
git clone https://github.com/kwilliam208/mint-omdrop-T4T5.git && mint-omdrop-T4T5/install.sh
```

From a fork, name it twice:

```sh
curl -fsSL https://raw.githubusercontent.com/someone/linux-omdrop-installer/main/install.sh | OMDROP_REPO=https://github.com/someone/linux-omdrop-installer sh
```

Run it as yourself; it asks for your password once. It needs systemd,
NetworkManager, Python 3.10+, and a Wi-Fi card with monitor mode. It knows
apt, dnf, zypper and pacman.

### What happens next

```
install.sh
├─ git and Python GObject missing? → installs them
├─ fetches the source to ~/.local/share/omdrop-installer/src
└─ a display and a tray library?
   ├─ yes → the OmDrop icon appears in the panel: click it to set up
   └─ no  → the same steps in the terminal

1. Compatibility                                  omdrop-installer check
   NO-GO: no systemd, Python < 3.10, no Wi-Fi, no monitor mode,
          NetworkManager not running                       → stops
   warn:  no ad-hoc or active monitor (shared only), Wi-Fi not connected
          (shared can't be tried), no Bluetooth, unknown package manager
2. Install (one password prompt)                  omdrop-installer install
   dependencies → build OWL with patches/ → /usr/lib/omdrop, polkit,
   NetworkManager, udev and systemd files → firewall rule (UFW, firewalld)
   → the omdrop CLI → the panel icon, started at login
3. Detect HW (Run)                                 omdrop-installer detect
   tries Shared (Wi-Fi stays on), then the best single-radio mode:
   Single radio (ad-hoc) if the card has it, else Active monitor
   each ~20 s: did OmDrop come up, were devices heard, does the router answer?
   score: up 10, +5 a device (max 3), +3 router, +2 the card's tested mode,
          +1 Shared; highest is recommended, nothing up → no recommendation
4. Mode: recommended first; modes that failed are greyed out    omdrop-installer configure
   → saved as this card's profile in /etc/omdrop/owl-profiles
```

In the tray this is one window that stays put, one step a page; each step's
circle fills as it's done, and Next turns green when you can go on.

### Configure

Right-click the OmDrop icon, **Configure…**: the same window, but any step
can be run again (check, reinstall, Detect HW, mode). The Mode page also has
**Legacy (Troubleshooting)**, which sends at the old 12 Mbit/s if sends stall
on your card. Its corner lists where things live and has **Uninstall…**.

## Use

Click the OmDrop icon: pick how long to stay visible (1m to ∞) and **Turn On**. While
on, it shows the time left, the transfer speed, and what has been
transferred (in and out, with a file count; **Reset** clears it). The folder
button opens your downloads.

**Send Files…** finds nearby devices while you pick files, checks the files,
then lists devices to tick; **Send** sends to each in turn while the icon
fills a blue ring.

From a terminal: `omdrop on 10m`, `omdrop peers -n`, `omdrop send NAME FILE`,
`omdrop off`. Set the iPhone to receive from Everyone for 10 Minutes to send to
it.

### Uninstall

The install keeps a ledger of everything it changes, and of the machine
before it: files and folders it added or replaced (originals kept), packages
it installed, its firewall rule, and the omdrop command if it set that up.
`omdrop-installer ledger` shows it. Uninstall undoes the ledger backwards:
**Configure…**, **Uninstall…** in its corner, then **Uninstall**; or

```sh
omdrop-installer uninstall
```

Packages it installed are removed only if nothing else needs them. Received
files and your OmDrop name stay.

## Supported hardware

**Status:** ✅ both directions work, ⚠️ both have worked but not reliably ([known issues](#known-issues)), ❌ tried and fails, ❓ untested\
**Modes:** *Shared* keeps Wi-Fi connected; *Exclusive* turns it off while visible ([why](#exclusive-mode))

| Card | Driver | Status | Tested on |
|---|---|---|---|
| MediaTek MT7925 | `mt7925e` | ✅ Shared | Framework 13, `14c3:0717`, Omarchy 4.0.4 (kernel 7.2.5) |
| MediaTek MT7612U (USB) | `mt76x2u` | ✅ Exclusive | `0e8d:7612` (kernel 7.2.9) |
| Realtek RTL8822BE | `rtw88_8822be` | ✅ Exclusive; shared untested | Crosshair VII Hero, `10ec:b822`, NixOS 26.11 (kernel 7.2.9) |
| Realtek RTL8852AE | `rtw89_8852ae` | ✅ Shared (Detect HW) | ThinkPad P14s Gen 2a, `10ec:8852`, Ubuntu 26.04.1 (kernel 7.0) |
| Realtek RTL8852CE | `rtw89_8852ce` | ✅ Shared (Detect HW) | Legion Slim 5 16AHP9, `10ec:c852`, Omarchy 4.0.4 (kernel 7.2.5) |
| Intel 9560 | `iwlwifi` | ✅ Exclusive | Lenovo 81SY, `8086:a370`, Omarchy 4.0.0 (kernel 7.2.8) |
| Intel AX200 | `iwlwifi` | ✅ Exclusive | ThinkPad X1 Yoga, `8086:2723`, NixOS 26.05 (kernel 6.19.8) |
| Intel AX201 | `iwlwifi` | ✅ Exclusive | • Ubuntu 24.04 (kernel 6.8)<br>• CachyOS (kernel 7.2.9) |
| Intel AX211 | `iwlwifi` | ✅ Exclusive | • ThinkPad X1, `8086:51f1`, Ubuntu 26.04 (kernel 7.0)<br>• XPS 9320, `8086:51f0`, Arch (kernel 7.2.3)<br>• Legion Pro 7 16IRX8H, `8086:7a70`, Omarchy 4.0.4 (kernel 7.2.3) |
| Intel BE (Panther Lake) | `iwlwifi` | ✅ Exclusive | XPS 16, `8086:e440`, Arch (kernel 7.2) |
| MediaTek MT7921 | `mt7921e` | ⚠️ Exclusive; Detect HW; shared fails ([#14](https://github.com/t4t5/omdrop-owl/issues/14)) | `14c3:7961`, CachyOS (kernel 7.2.9) |
| MediaTek MT7922 (RZ616) | `mt7921e` | ⚠️ Exclusive; Detect HW; shared fails ([#14](https://github.com/t4t5/omdrop-owl/issues/14)) | Minisforum MS-A2, `14c3:0616`, NixOS 26.05 (kernels 6.18 and 7.2.5) |
| MediaTek MT7927 | `mt7925e` | ❌ Shared and exclusive ([#44](https://github.com/t4t5/omdrop-owl/issues/44)) | TP-Link Archer TBE550E, `14c3:7927`, CachyOS (kernel 7.2.9) |
| Qualcomm WCN6855 (QCNFA765) | `ath11k_pci` | ❌ Shared ([#45](https://github.com/t4t5/omdrop-owl/issues/45)); no ad-hoc mode for exclusive | ThinkPad, `17cb:1103`, CachyOS (kernel 7.2.9) |
| Realtek RTL8852BE | `rtw89_8852be` | ❓ Untested (Detect HW) | — |
| Qualcomm WCN7850 (FastConnect 7800) | `ath12k` | ❓ Untested (Detect HW) | — |
| Intel 9260 | `iwlwifi` | ❓ Exclusive untested | — |
| Intel AX210 | `iwlwifi` | ❓ Exclusive untested | — |
| Intel BE200 | `iwlwifi` | ❓ Exclusive untested | — |

One card name can cover chips that behave differently, so a report from a machine, PCI ID
(`lspci -nn`) or kernel not listed here helps too.

## How it works

AWDL (the Wi-Fi link iPhones share files over) is provided by [jedbillyb's OWL fork](https://github.com/jedbillyb/owl).
omdrop's receiver and sender run over
it unchanged. Discovery and transfer tools are reused from omdrop-awdl,
fetched at a pinned commit by `tools/stage.sh`.

### Shared mode

Wi-Fi stays connected on channel **6, 44 or 149**. OWL injects frames through
a monitor interface using the station's MAC, and advertises only the phone's
slots on that channel (`-S intersect`). On the MT7925, the station handles
ACKs. OWL exposes `awdl0` for omdrop's receiver and its announcements.

### Exclusive mode

No Intel card tested works in shared mode, so `iwlwifi` disconnects Wi-Fi
while the machine is visible and restores it on `stop`.

- An ad-hoc (IBSS) interface joins AWDL's BSSID to handle ACKs. Some AX211s
  need the Wi-Fi interface itself repurposed for this.
- The cell uses HT20 on channel 6 because the tested Intel cards reject
  5 GHz IBSS. Beacons every 10 seconds fix discovery after an iPhone restart.
- OWL injects through a monitor interface, advertises our channel in all
  16 slots (`-S pin`), and elects its sync master by metric (`-E`). Unicast
  frames are sent once to avoid retries stalling the queue.
- Cards with no ad-hoc mode (the MediaTek MT7921, MT7922 and MT7612U) use
  `mode active-monitor` instead: an active monitor carrying the station's MAC
  ACKs in place of the IBSS interface
  ([#24](https://github.com/t4t5/omdrop-owl/pull/24), from kmod-midori's
  [#13](https://github.com/t4t5/omdrop-owl/pull/13)).

## Known issues

- **Shared mode needs your AP on channel 6, 44 or 149.** On any other channel,
  `start` refuses and says so.
- **The MT7925 drops off Wi-Fi when the monitor interface is removed** (an
  mt76/firmware bug), so `stop` reconnects Wi-Fi straight after.
- **The MT7927 starts but is never heard.** It uses the MT7925's driver, so
  it runs the MT7925's shared profile, but its monitor
  interface doesn't receive the phone's frames, and the driver has no ad-hoc
  mode for exclusive ([#44](https://github.com/t4t5/omdrop-owl/issues/44)).
- **The MT7925 sends slower than it receives** (about 490 kB/s against
  1.3 MB/s): injected frames leave at most one every ~2.5 ms.
- **A firewall can block the receiver.** Setup opens TCP 8771 on `awdl0`
  only, for UFW or firewalld; other firewalls need that rule by hand.
- **Intel cards are slow**: an iPhone spends about 2 of its 16 AWDL slots on
  channel 6 when idle, the only time it can hear us. Data goes at HT MCS 3,
  three to five times faster on an AX201 than OWL's old 12 Mbit/s. If sends
  stall on your card, tick **Legacy (Troubleshooting)** under Configure, Mode. `tools/rate-sweep.sh` compares
  rates on a card.
- **The MT7921/MT7922 are unreliable.** `mt7921e` sends injected unicast at
  1 Mbit/s whatever rate is asked for, and not at all on 5 GHz, so discovery
  and the handshake often stall. Close and reopen the share sheet to retry.

## Development

`tools/run-tests.sh` runs the unit tests (bats and Python; no radio, no
root). `tools/build-owl.sh` and `tools/stage.sh` build into `build/lib`
without installing.

## License

omdrop-owl is GPL-3.0-or-later ([LICENSE](../LICENSE)), and so are this project's
additions. The projects it builds on keep their own licenses; see
[CREDITS.md](../CREDITS.md).
