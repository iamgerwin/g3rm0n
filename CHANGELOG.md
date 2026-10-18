# Changelog

All notable changes to g3rm0n are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- zsh completions (`completions/_g3rm0n`), installed by `install.sh`.
- Hints that tell you what to type (exporting an API key, adding to `PATH`) now use
  the syntax of the shell you started g3rm0n or the installer from: bash, zsh, fish,
  ksh, tcsh/csh, nushell, xonsh or elvish.
- `g3rm0n setup --show` explains that API keys must be exported.
- Cross-shell test suite (`tests/shells.sh`): the dashboard, interactive setup, the
  installer and completions, started from bash, zsh, fish, dash, ksh, mksh, tcsh and
  busybox sh. CI installs every one of them.

### Fixed

- `sh g3rm0n` (or dash/ksh/zsh) now hands over to bash instead of failing with syntax errors.
- `curl … | sh` now stops with "run this installer with bash" instead of a
  misleading "Linux only" error.
- `install.sh --help` works when the installer is piped.
- A piped install run from inside a folder that looks like a g3rm0n checkout no
  longer links that folder instead of downloading the release.
- Completing a comma-separated `--sections` list in bash and fish keeps the items
  already typed (`cpu,me` → `cpu,memory`).
- The setup checklist accepts arrow keys from terminals in application cursor mode.
- Home-folder paths in setup are shortened to `~` without a regular expression, so a
  `$HOME` containing special characters displays correctly.

### Changed

- Installer: checkout detection rewritten so older ShellCheck releases lint it cleanly (no behavior change).

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

[Unreleased]: https://github.com/iamgerwin/g3rm0n/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/iamgerwin/g3rm0n/releases/tag/v0.1.0
