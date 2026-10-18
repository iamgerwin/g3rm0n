# Changelog

All notable changes to g3rm0n are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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
