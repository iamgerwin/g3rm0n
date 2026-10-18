# Instructions for coding agents

Before changing anything in this repository, read every file in [`rules/`](rules/README.md)
and [ARCHITECTURE.md](ARCHITECTURE.md), and follow them. In particular:

- g3rm0n is a **read-only monitor**. Never add anything that changes the system or
  an account ([scope](rules/01-scope.md)).
- Never read, print, store or commit credentials ([security](rules/03-security-privacy.md)).
- New panels follow the standard layout ([UI conventions](rules/04-ui-conventions.md)) and
  are added through the panel registry, never wired into the loop by hand ([architecture](ARCHITECTURE.md)).
- Keep each module to its role: renderers format, the controller decides, `input.sh`
  decodes. Bindings and other behavior that is data belong in tables.
- Users start g3rm0n from many shells; never phrase a hint in bash-only syntax ([code style](rules/02-code-style.md)).
- g3rm0n runs on Linux and macOS with the same features. OS-specific code goes only in
  `lib/platform/<os>.sh` behind the platform contract; shared code and tests use no
  GNU-only or BSD-only flags. `install.sh` stays bash 3.2 compatible ([architecture](ARCHITECTURE.md#platforms)).
- **Docs move with the code.** Update the README, completions, rules and
  `CHANGELOG.md` (under `## [Unreleased]`) in the same change. `tests/docs.sh` checks
  this deterministically and runs from the pre-commit hook, the agent stop hook in
  `.claude/settings.json`, and CI ([documentation](rules/08-documentation.md)). If it
  reports drift, fix the docs; never weaken the check to make it pass.
- Never edit the version by hand: `scripts/bump-version.sh patch|minor|major`
  ([git & releases](rules/07-git-and-releases.md)).
- These must pass before you hand back: `bash -n`, `shellcheck -x`, `tests/smoke.sh`,
  `tests/shells.sh`, `tests/ui.sh`, `tests/platform.sh`, `tests/install.sh`,
  `tests/docs.sh` ([testing](rules/06-testing.md)). CI runs them on Linux and macOS.
- Don't commit, push, tag or release unless a maintainer asks. Commits carry no tool
  signatures or co-author trailers ([git & releases](rules/07-git-and-releases.md)).

## Quick map

| Path | What it is |
|------|------------|
| `g3rm0n` | entry point (argument parsing and dispatch) |
| `lib/` | `core` · `ui` · `panel` · `fold` · `input` · `keymap` · `system` · `ai` · `dashboard` · `setup` ([ARCHITECTURE.md](ARCHITECTURE.md)) |
| `lib/platform/` | `linux.sh`, `darwin.sh`: one backend per OS, same contract |
| `completions/` | bash, zsh, fish |
| `tests/` | `smoke.sh`, `shells.sh`, `ui.sh`, `platform.sh`, `install.sh`, `docs.sh`; `lib/` helpers; `mock/` fixtures |
| `scripts/bump-version.sh` | version bump and changelog cut |
| `.githooks/pre-commit` | runs `tests/docs.sh --staged` |
