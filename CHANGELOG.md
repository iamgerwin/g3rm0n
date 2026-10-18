# Changelog

All notable changes to g3rm0n are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- **macOS: two columns and the full height again.** The dashboard measured the
  window with `tput`, which on macOS can't see the terminal from where g3rm0n asked
  and always answered 80×24. So Macs always got one column, the short footer, and
  frames cut at 24 rows. g3rm0n now asks the terminal itself, the same way on every
  platform.
- **macOS: the Claude panel appears.** Claude Code keeps its login in the macOS
  Keychain, so g3rm0n never found it. It now finds the `Claude Code-credentials` item
  (reading only its name), and reads the token only when the panel refreshes.
  `g3rm0n setup` shows `found · macOS Keychain`.
- Folded titles whose summary was too long showed no summary at all. Common on Macs
  (`612 tasks · WindowServer 12%`). Now only the last parts are dropped
  (`612 tasks`).
- Numbers no longer depend on the locale. With a comma-decimal locale (German, French,
  Dutch, …) money showed `$8.2 left of $25,00` and timing could break; g3rm0n now
  formats numbers with `.` everywhere and keeps your character set.
- The folded Disk title on macOS said `/` but showed the data volume; it now says `~`.

### Added

- Credential references can point at the macOS Keychain: `keychain:<service>`.
- Tests:
  - `tests/ui.sh`: the live layout under a stand-in for macOS's `tput` (two columns,
    full height, never overflowing) and summary trimming.
  - `tests/platform.sh`: Keychain logins, the same layout and summaries from both
    backends, and comma-decimal locales.

### Fixed

- The installer no longer fails with `curl: (56) … 403` on networks that share one
  public IP (offices, schools, CI machines). It finds the latest release through
  GitHub's `releases/latest` redirect instead of the rate-limited API, which is
  kept as a fallback.

## [0.1.4] - 2026-10-18

### Fixed

- Clicking anywhere other than a panel title (a panel's rows, the gap between
  columns, empty space) quit the dashboard. Such clicks are now ignored; only a
  title click folds, and only `q` or Ctrl-C quits.
- Updating g3rm0n while it was running (reinstalling, or a `git pull` in a linked
  checkout) could print `syntax error near unexpected token` when it exited,
  because bash went on reading the changed file. g3rm0n now exits without reading
  any further.
- The macOS installer's "Using bash …" line no longer runs the version into the path.

## [0.1.3] - 2026-10-18

### Added

- **macOS support** (macOS 12 or newer, Apple silicon and Intel), with the same
  panels, keys, folding, setup and AI usage as on Linux. A new platform backend reads
  the Mac with its stock tools (`sysctl`, `vm_stat`, `iostat`, `netstat`, `ioreg`,
  `pmset`, `df`, `ps`, `route`) and never needs `sudo`. Memory follows Activity Monitor,
  and the disk panel shows the data volume where your files live. The Apple GPU is shown.
  Where macOS keeps a reading for root, g3rm0n shows the closest one any user can
  get: the core layout instead of per-core load, and no temperature.
- **The installer works on macOS.** The same one-line `curl … | bash` runs with
  macOS's own bash 3.2, finds Homebrew's bash 5 (or says `brew install bash`), and
  gives macOS-style `PATH` hints (`~/.zshrc`, `~/.bash_profile`).
- g3rm0n finds a bash 5 by itself when it's started by an older bash (macOS's
  `/bin/bash`) or by bash in POSIX mode (`sh g3rm0n` where `sh` is bash).
- `install.sh --from DIR` installs offline from an unpacked release or a checkout.
- README: a **Platforms** section that lists what each platform reads and where
  readings differ.

### Changed

- **Only run-time files are installed**: the program, its modules, the backend for
  your operating system, the completions and the license, about 100 KB instead of
  the whole repository. Reinstalling removes files left by older installs, and
  release tarballs no longer carry tests, rules, CI or contributor docs.
- Everything OS-specific moved into platform backends (`lib/platform/linux.sh`,
  `lib/platform/darwin.sh`) behind one documented contract. g3rm0n refuses to start
  with an incomplete backend. Linux output is unchanged.
- Claude reset times are parsed in `jq` instead of with GNU `date`, so they behave
  the same everywhere.
- The header shows the short host name (`mac-mini`, not `mac-mini.local`) and
  shortens very long ones, so the OS and kernel always stay visible.
- For contributors: every test suite now runs on Ubuntu 22.04 and 24.04 and on macOS
  14 and 15, through shared portable helpers (`tests/lib/common.sh`). Two new suites
  join them. `tests/platform.sh` checks every backend against the contract and runs
  the macOS backend on recorded macOS output on any machine. `tests/install.sh` checks
  the installed file set, release tarballs and the installer under bash 3.2.
  `scripts/bump-version.sh` works with BSD sed, and a `release-check` workflow
  installs every published release with the one-line installer on Linux and macOS.

### Fixed

- `curl … | sh` is now refused with the "run this installer with bash" hint on
  systems where `sh` is bash (macOS, Fedora), instead of running in POSIX mode.
- `zsh g3rm0n` finds bash correctly (zsh doesn't split an unquoted `$PATH`).
- fish: completing a comma-separated `--sections` or `--fold` list works on macOS too
  (fish's own list helper needs GNU sed).

## [0.1.2] - 2026-10-18

### Added

- **Folding panels.** Every panel folds, like an accordion, into a single title line
  that keeps its key numbers, e.g. `▸ ◫ Memory · 44% · 13.9G/31.2G`. Open panels show
  `▾`, folded ones `▸`.
- **Click to fold.** Click a panel's title to fold or unfold it, per AI provider too.
  This uses the standard xterm mouse protocol, so it works in the usual terminals on
  Linux, macOS and Windows (Windows Terminal, iTerm2, Terminal.app, GNOME Terminal,
  Konsole, kitty, Alacritty, WezTerm, VS Code, and tmux with `mouse on`).
- **Keyboard shortcuts.** `1`–`8` fold or unfold a section (the digit is shown on
  each title), `-` folds everything, `+` unfolds everything, `r` or space refreshes,
  and `q` quits. `g3rm0n help` lists them.
- Folds are remembered between runs (`~/.local/state/g3rm0n/folded`).
- `-f`, `--fold LIST`: start with sections or panels folded (`all` and `none` work
  too). With `--once`, it gives a compact snapshot.
- `--no-mouse` and the config key `mouse = off` leave the mouse to the terminal, for
  its own text selection.
- `ARCHITECTURE.md`: the module map, the design patterns and the live loop.

### Changed

- The live dashboard redraws immediately after a key press, click or window resize,
  without re-sampling the machine, so rates stay accurate. Frames render about
  twice as fast.
- Panels are built through a registry (`lib/panel.sh`), with input, key bindings and
  fold state in their own modules (`lib/input.sh`, `lib/keymap.sh`, `lib/fold.sh`).
- `g3rm0n setup` keeps config keys it doesn't manage (such as `mouse`) instead of
  dropping them.
- One-shot output (`--once`, or piped) is unchanged and ignores saved folds unless
  `--fold` is given.
- For contributors: a new suite, `tests/ui.sh`, unit-tests input decoding, the keymap,
  fold state, titles and hit-testing, and drives the live dashboard with real keys
  and mouse clicks in a pseudo-terminal. The docs check also covers key bindings,
  config keys and `ARCHITECTURE.md`.

## [0.1.1] - 2026-10-18

### Added

- **zsh completions** (`completions/_g3rm0n`). `install.sh` installs them to
  `~/.local/share/zsh/site-functions` and prints the `fpath` line to add.
- **Hints in your shell's syntax.** When g3rm0n or its installer tells you what to type
  (exporting an API key, adding `~/.local/bin` to `PATH`), it now uses the syntax of
  the shell you started it from: bash, zsh, fish, ksh, tcsh/csh, nushell, xonsh or elvish.
- `g3rm0n setup --show` explains that API keys must be exported to be seen.
- README: a **Shells** section (completions and key-export syntax per shell), a full
  options table, and troubleshooting rows for unexported keys and a missing `PATH` entry.
- For contributors:
  - **Documentation drift check** (`tests/docs.sh`). It fails when the README,
    completions, rules or changelog disagree with the code, and when product code
    changes arrive without a `CHANGELOG.md` entry. It runs from a git pre-commit
    hook (`.githooks/pre-commit`), a coding-agent stop hook (`.claude/settings.json`)
    and CI.
  - `scripts/bump-version.sh` bumps the version and cuts the changelog section in one step.
  - Cross-shell test suite (`tests/shells.sh`). It runs the dashboard, interactive
    setup, installer and completions from bash, zsh, fish, dash, ksh, mksh, tcsh and
    busybox sh.
  - New rule: [documentation](rules/08-documentation.md). There is also a project
    `CLAUDE.md`, and `AGENTS.md` is expanded.

### Fixed

- `sh g3rm0n` (and dash, ksh, mksh, zsh or busybox sh) now hands over to bash instead
  of failing with syntax errors.
- `curl … | sh` now stops with "run this installer with bash" instead of a misleading
  "Linux only" error.
- `install.sh --help` works when the installer is piped.
- A piped install run from inside a folder that looks like a g3rm0n checkout no longer
  links that folder instead of downloading the release.
- Completing a comma-separated `--sections` list in bash and fish keeps the items
  already typed (`cpu,me` → `cpu,memory`).
- The setup checklist accepts arrow keys from terminals in application cursor mode.
- Setup shortens home-folder paths to `~` correctly even when `$HOME` contains
  special characters.
- The README now documents `--interval`, `--sections` and `--no-color`.

### Changed

- `install.sh --uninstall` also removes the zsh completion.
- The installer's checkout detection was rewritten so older ShellCheck releases lint
  it cleanly.

## [0.1.0] - 2026-10-18

First release.

### Added

- Live dashboard (`g3rm0n`) with flicker-free redraws on the alternate screen; `q`
  quits and any other key refreshes.
- System panels: CPU (usage, per-core strip, load, model), Memory (used, swap,
  available, cache), Disk (space on `/` and `$HOME`, read/write rates), Power (battery,
  NVIDIA/AMD GPU, hottest sensor, uptime), Processes (task count, top three by CPU),
  Network (throughput sparklines, interface, VPN).
- Health score in the header (Healthy / Busy / Strained / Critical).
- **AI Tokens** panels for subscription limits: Claude, Codex, Z.ai (5-hour and
  weekly windows, time to reset, headroom, plan).
- **AI Credits** panels for prepaid APIs: DeepSeek (balance, topped-up/granted split)
  and OpenRouter (credits left, spend per day/week/month, key cap).
- `g3rm0n setup`: an interactive picker for sections, AI providers and refresh
  interval, plus `--defaults`, `--show` and `--reset`. It references credentials
  (`file:` / `env:`) and never stores them.
- One-shot mode (`--once`, automatic when piped), `--interval`, `--sections`,
  `--no-ai`, `--no-color` and `NO_COLOR` support.
- User-level installer with fish PATH setup, bash and fish completions, and uninstall.
- Contribution rules in `rules/`, smoke tests with a mock `curl`, and CI on Ubuntu 22.04 and 24.04.

[Unreleased]: https://github.com/iamgerwin/g3rm0n/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/iamgerwin/g3rm0n/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/iamgerwin/g3rm0n/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/iamgerwin/g3rm0n/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/iamgerwin/g3rm0n/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/iamgerwin/g3rm0n/releases/tag/v0.1.0
