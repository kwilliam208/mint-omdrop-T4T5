# Credits

Linux OmDrop Installer is [T4T5](https://github.com/t4t5)'s
[omdrop-owl](https://github.com/t4t5/omdrop-owl), extended by
[kwilliam208](https://github.com/kwilliam208) to install it on most Linux desktops.
It stands on the open-source work below. Each project keeps its own license.
None of them endorses or is affiliated with this project.

## Open-source community

| Project | Authors | How it is used | License |
|---|---|---|---|
| [omdrop-owl](https://github.com/t4t5/omdrop-owl) | [T4T5](https://github.com/t4t5) and [contributors](https://github.com/t4t5/omdrop-owl/graphs/contributors) | The base of this project: the radio helper (`userspace/`), the OWL patches (`patches/`), packaging, tests and tools | GPL-3.0-or-later |
| Active-monitor mode for MediaTek cards | [kmod-midori](https://github.com/kmod-midori) | Upstream [#13](https://github.com/t4t5/omdrop-owl/pull/13), merged as [#24](https://github.com/t4t5/omdrop-owl/pull/24) | GPL-3.0-or-later |
| [OWL](https://github.com/seemoo-lab/owl), an open AWDL implementation | [seemoo-lab](https://github.com/seemoo-lab) (Secure Mobile Networking Lab, TU Darmstadt) and contributors | Fetched and built at a pinned commit from [jedbillyb/owl](https://github.com/jedbillyb/owl), the fork by [jedbillyb](https://github.com/jedbillyb), with `patches/` applied | GPL-3.0 |
| [omdrop-awdl](https://github.com/brentkearney/omdrop-awdl) | [brentkearney](https://github.com/brentkearney) ([netmojo-systems](https://github.com/netmojo-systems)) | Its radio-independent tools (`send-to-peer`, the sender and its helpers), fetched at a pinned commit and shipped unmodified | GPL-2.0-only |
| [omdrop plugin](https://github.com/netmojo-systems/omdrop-plugin) | [netmojo-systems](https://github.com/netmojo-systems) | Not included. `omdrop-tray` drives its `omdrop` CLI, and follows its Omarchy panel (`Panel.qml`) for the status model and timings and its `omdrop watch` for counting received files | MIT |
| [radiotap-library](https://github.com/radiotap/radiotap-library) | Andy Green, Johannes Berg | OWL's bundled radiotap parser, built into `owl` | ISC |
| [XApp](https://github.com/linuxmint/xapp) | [Linux Mint](https://github.com/linuxmint) | `omdrop-tray`'s panel icon on Cinnamon, MATE and Xfce, from the system's library | LGPL-3.0 |
| [libayatana-appindicator](https://github.com/AyatanaIndicators/libayatana-appindicator) | [Ayatana Indicators](https://github.com/AyatanaIndicators) | `omdrop-tray`'s panel icon elsewhere, from the system's library | LGPL-3.0 |

The license texts ship with the packages: `/usr/share/doc/omdrop-owl/` in the
`.deb`, `/usr/share/licenses/omdrop-owl/` with pacman and rpm.

## This project's additions

The installer (`install.sh`, `tools/omdrop-installer`), hardware detection, the
NetworkManager fix and `omdrop-tray` with its icons are by
[kwilliam208](https://github.com/kwilliam208),
under GPL-3.0-or-later like the project they extend. The tray icons are
original drawings, not Apple's artwork.

#### Corporate licenses

<sub>[googletest](https://github.com/google/googletest) (Google, BSD-3-Clause)
is fetched as an OWL submodule; it is not built or shipped. AWDL,
iPhone and Apple are trademarks of Apple Inc., used only to describe what this
software interoperates with. This project is not affiliated with or endorsed
by Apple Inc. or Linux Mint.</sub>
