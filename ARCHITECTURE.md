# Architecture

g3rm0n is a small bash program organized like an interactive UI application: a
**model** that samples the machine, **views** that turn samples into panels, and a
**controller** that turns input into actions. Each module owns one concern and
talks to the others through a few documented globals and function contracts.

`tests/docs.sh` fails if a module under `lib/` is missing from this file.

## Modules

```
g3rm0n ──► lib/core.sh ──► lib/ui.sh ──► lib/panel.sh ──► lib/fold.sh ──► lib/input.sh ──► lib/keymap.sh ──► lib/header.sh
(load order) ──► lib/platform/<os>.sh ──► lib/system.sh ──► lib/ai.sh ──► lib/dashboard.sh ──► lib/setup.sh
```

| Module | Role | Owns |
|--------|------|------|
| `g3rm0n` | Entry point | Finding bash 5, choosing the platform backend, argument parsing, dispatch to dashboard or setup |
| `lib/core.sh` | Foundation | Version, paths (config, cache, state), sections, colors, config parsing, formatting helpers |
| `lib/ui.sh` | View primitives | Titles, bars, sparklines, padding, the two-column grid and its hit map (`UI_HITS`) |
| `lib/panel.sh` | Panel registry and composition | `panel_register`, `panel_render_all` (sample step), `panel_compose` (render step), `panel_at` (hit-testing) |
| `lib/fold.sh` | Fold state (model) | `FOLD` map, toggles and groups, `--fold` lists, persistence in `$G3_STATE_DIR/folded` |
| `lib/input.sh` | Input adapter | Raw terminal bytes in, normalized events out (`key`, `click`, `wheel`, `none`); mouse on/off |
| `lib/keymap.sh` | Key bindings (data) | `KEYMAP` (key → action) and `KEYMAP_HELP` (what help and the README show) |
| `lib/header.sh` | Header components | `HDR_FN` (id → component), `hdr_render` (order, separators, dropping what doesn't fit) |
| `lib/platform/linux.sh` | Linux backend | The platform contract, from `/proc`, `/sys`, `df`, `ps`, `ip` |
| `lib/platform/darwin.sh` | macOS backend | The platform contract, from `sysctl`, `vm_stat`, `iostat`, `netstat`, `ioreg`, `pmset`, `df`, `ps`, `route` |
| `lib/system.sh` | System model and renderers | Rates from the backend's counters, the health score, the six system panel renderers, `SYS_CONTRACT` |
| `lib/ai.sh` | AI model and renderers | Provider fetchers, cache and background refresh, the AI panel renderer |
| `lib/dashboard.sh` | Controller | Panel registration, the live loop, event → action dispatch (`dash_do`), terminal restore |
| `lib/setup.sh` | Setup flow | `g3rm0n setup`: the checklist UI and writing the config |

## Patterns

**Registry (panels).** Every panel is registered once with an id, section, grid group,
icon, title and renderer (`panel_register` in `dash_register`). Nothing else keeps a
list of panels: composition, folding, hit-testing, `--fold` and the section shortcuts
all read the registry. Adding a panel means registering it; no other code changes.

**Renderer contract (strategy).** A renderer fills `PANEL_BODY` with rows (no title)
and may set `PANEL_SUM` to a one-line summary for the folded title. System panels
(`sys_panel_<section>`) and AI panels (`ai_panel <id>`, one shape per kind) are
interchangeable to the composer.

**Sample / render split.** `dash_sample` reads the machine and runs every renderer once
per interval. `dash_render` builds the frame from those results and the fold state.
Folding, clicking and resizing only re-render, so rates and sparklines are never
skewed by input, and redraws are fast.

**Adapter (input).** `in_read` does the I/O and `in_decode` is a pure function from a
byte sequence to an event. Terminal quirks (SGR mouse, application cursor keys,
releases, drags) are handled there and nowhere else, and `in_decode` is unit-tested
with plain strings.

**Command table (keys).** `KEYMAP` maps keys to named actions (`quit`, `refresh`,
`section <name>`, `fold-all`, `unfold-all`, `panel <id>`). `dash_do` is the single
dispatcher. Quitting is an explicit flag (`DASH_QUIT`), never a return code, so an
event that resolves to nothing (a click beside the titles, an empty section) can't
end the dashboard; `dash_event` always returns 0. A new shortcut is one table entry plus a `KEYMAP_HELP` line; the docs
check makes sure the README lists it. Unbound keys refresh, as they always have.

**Environment, once.** `g3rm0n` fixes the locale at start-up (UTF-8 character set,
`LC_NUMERIC=C`) and `ui_term_size` measures the terminal with `stty size` on
`/dev/tty`. Both behave the same on every platform; modules never ask the system
for either again.

**State as data.** Fold state is a map of panel ids, saved as one line of ids and
parsed with a whitelist (never sourced). The config is parsed the same way. Neither
holds anything but layout and preferences.

**Components (header).** The header is a list of component ids rendered in order
(`hdr_render`). Each component (`logo`, `health`, `host`, `os`, `kernel`, `date`, `time`)
is one function that sets `HDR_TEXT` from data the samplers already hold. Separators
come from the pair of neighbours (`HDR_LEAD`, `HDR_JOIN`), so components never format
their surroundings, and `HDR_DROP` says what gives way first when the line is too wide.
The order comes from `header` in the config (default `G3_HEADER`), so letting users
arrange it later only needs a UI that writes that list.

**Strategy (platforms).** Everything that depends on the operating system sits behind
the platform contract below. `g3rm0n` loads exactly one backend
(`lib/platform/<os>.sh`) and the rest of the program never asks which one it got.
`sys_static` refuses to start with a backend that doesn't define the whole contract,
and `tests/platform.sh` checks every backend file against it.

## Platforms

A backend is a file of `plat_` functions that fill globals. Shared code turns those
into rates, panels and the health score, so features can't differ between platforms.

| Function | Fills | Linux | macOS |
|----------|-------|-------|-------|
| `plat_static` | `S_OS` `S_MODEL` `S_THREADS` `S_GPU` (once) | os-release, cpuinfo, `nproc` | `sw_vers`, `sysctl` |
| `plat_cpu` | `S_CPU` (0–100), `S_CORES` (the Cores row) | `/proc/stat` deltas, per-core strip | background 1 s `iostat`, core layout |
| `plat_load` | `S_L1` `S_L5` `S_L15` `S_TASKS` | `/proc/loadavg` | `sysctl vm.loadavg`, `ps` |
| `plat_mem` | `S_MEM_T` `S_MEM_A` `S_CACHE` `S_SWAP_T` `S_SWAP_F` (bytes) | `/proc/meminfo` | `vm_stat`, `sysctl` |
| `plat_net_bytes` | `NET_RX` `NET_TX` (cumulative bytes) | `/proc/net/dev` | `netstat -ibn` |
| `plat_disk_bytes` | `DIO_R` `DIO_W` (cumulative bytes) | `/proc/diskstats` | `ioreg` block storage statistics |
| `plat_temp` | prints this frame's sensor lines (see `plat_sensors`) | `plat_sensors` (sysfs is instant) | the last background reading |
| `plat_sensors` | prints `kind °C name` per temperature sensor, `kind` = `cpu` or `other` | thermal zones, hwmon (`coretemp`, `k10temp`, … are CPU) | IOKit HID sensors via JavaScript for Automation (`pACC`/`eACC` clusters and `tdie` dies are CPU) |
| `plat_uptime` | `S_UP` (seconds) | `/proc/uptime` | `sysctl kern.boottime` |
| `plat_root_pct` | `S_ROOT_P` `S_ROOT_LABEL` (health score, folded Disk title) | `df /`, labelled `/` | `df` of the data volume, labelled `~` |
| `plat_disks` | prints `mount fstype size used pct` rows | `df -B1 --output` | `df -kP`, `mount` |
| `plat_battery` | `BAT_CAP` `BAT_STATUS` `BAT_AC` | `/sys/class/power_supply` | `pmset -g batt` |
| `plat_gpu` | `GPU_UTIL` [`GPU_MEM_U` `GPU_MEM_T` `GPU_TEMP`] | `nvidia-smi`, AMD sysfs | `ioreg` IOAccelerator |
| `plat_top` | prints `pcpu rss_kb name`, busiest first | `ps --sort` | `ps -r -c` |
| `plat_link` | `LINK_DEV` `LINK_ADDR` | `ip route get` | `route get default`, `ipconfig` |
| `plat_vpn` | `VPN_DEV` `VPN_ADDR` | wg/tun/tailscale/ppp interfaces | tunnels with an IPv4 address (`ifconfig`) |
| `plat_mtime` | prints a file's modification time | `stat -c %Y` | `stat -f %m` |
| `plat_keychain_has` | true when the OS credential store has an item (attributes only, no secret) | always false (logins are files) | `security find-generic-password -s` |
| `plat_keychain_read` | prints an item's secret, only when its provider is called | nothing | `security find-generic-password -s … -w` |
| `plat_cleanup` | stops background work, removes its files | nothing to do | stops the CPU measurement |

Rules for backends:

- Read-only, no root, stock tools of that OS only. If a reading needs root, return
  the closest unprivileged equivalent (and say so in the README platform table).
- Never block a frame. Anything that needs a time window runs in the background
  between frames, like the macOS CPU measurement.
- Shared code stays portable: no GNU-only or BSD-only flags outside `lib/platform/`.
  `tests/platform.sh` runs the macOS backend against recorded macOS output
  (`tests/mock/darwin/`) on every machine, and CI runs every suite natively on Linux
  and macOS.
- A new OS (Windows is next) is one new file plus a case in `g3rm0n`'s platform
  switch and `install.sh`'s `platform`.

## Installation

`install.sh` copies only the run-time files (`runtime_files`): `g3rm0n`, `lib/*.sh`,
the one backend for the installing OS, the three completions and `LICENSE`. It stages
them next to the install folder and swaps them in, so an update never leaves files
from an older layout behind. `.gitattributes` keeps tests, rules, CI, scripts and the
contributor docs out of the release tarballs as well. The installer itself stays
compatible with bash 3.2, because on macOS `curl … | bash` runs the system bash.
`tests/install.sh` checks all of this.

## AI refresh policy

Each provider's usage is fetched in the background by `ai_refresh` and cached as one
row of numbers (`<id>.row`). Frames only ever read the cache.

- **How often:** `ai_ttl` gives 60 s by default, a longer per-provider default from
  `AI_REFRESH` (Claude 300 s), or `<id>.refresh` from the config.
- **Shared:** `<id>.status` holds `code next-attempt consecutive-429s`. Every running
  g3rm0n reads it, and `<id>.lock` lets only one of them call the provider.
- **After a 429:** `ai_backoff` waits `Retry-After` when the server asks for longer,
  otherwise 5, 10, 20 … up to 60 minutes. Any success resets it.
- **Meanwhile:** the panel keeps the last good row and says how old it is and when the
  next try is. A window whose reset time has passed is shown as a new, empty window,
  marked `~` as an estimate.

## The live loop

```
dash_run
 ├─ sys_static, dash_register, fold_load, mouse on, alternate screen
 └─ loop
     ├─ if due:  dash_sample  ─► sys_sample, sys_health, ai_tick, panel_render_all
     ├─ dash_render  ─► header, panel_compose (fold markers, summaries, UI_HITS), footer
     └─ wait for the next sample, in ≤250 ms slices (a resize can't interrupt read):
          in_read ─► IN_EVENT ─► dash_event ─► keymap_action / panel_at ─► dash_do
```

The entry point ends with `main "$@"; exit` on one line. Bash reads a script while it
runs it, so if `g3rm0n` is rewritten while running (an update, a `git pull` in a
linked checkout), the running copy must never read past `main`. Modules are
`source`d whole at start-up and aren't affected.

Exit paths (`q`, Ctrl-C, `TERM`, any error) all run `dash_restore`, which turns mouse
reporting off and leaves the alternate screen, so the terminal is always given back
clean.

## One-shot mode

`--once` (automatic when piped) registers the same panels, fetches AI usage in
parallel, samples once and renders with `live = 0`: no markers, no shortcut digits,
and no saved folds unless `--fold` is given. The output is the same as before folding
existed.

## Extending

| To add | Touch |
|--------|-------|
| A system panel | a renderer in `lib/system.sh`, its icon/title in `SYS_ICON`/`SYS_TITLE`, the section in `G3_SECTIONS` (`lib/core.sh`), any new reading as a `plat_` function in every backend, the docs |
| A platform | `lib/platform/<os>.sh` with the whole contract, the platform switch in `g3rm0n` and `install.sh`, fixtures in `tests/mock/<os>/`, a CI runner, the README platforms table |
| An AI provider | `lib/ai.sh` only ([rules/05](rules/05-adding-a-provider.md)); it registers itself through `dash_register` |
| A key binding | `KEYMAP` and `KEYMAP_HELP` in `lib/keymap.sh`, an action in `dash_do` if it's new, the README keys table |
| A mouse gesture | `in_decode` (new event), `dash_event` (event → action) |
