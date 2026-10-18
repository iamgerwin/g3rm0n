# Instructions for coding agents

Before changing anything in this repository, read every file in [`rules/`](rules/README.md)
and follow them. In particular:

- g3rm0n is a **read-only monitor**. Never add anything that changes the system or
  an account ([scope](rules/01-scope.md)).
- Never read, print, store or commit credentials ([security](rules/03-security-privacy.md)).
- New panels follow the standard layout ([UI conventions](rules/04-ui-conventions.md)).
- Users start g3rm0n from many shells; never phrase a hint in bash-only syntax ([code style](rules/02-code-style.md)).
- **Docs move with the code.** Update the README, completions, rules and
  `CHANGELOG.md` (under `## [Unreleased]`) in the same change. `tests/docs.sh` checks
  this deterministically and runs from the pre-commit hook, the agent stop hook in
  `.claude/settings.json`, and CI ([documentation](rules/08-documentation.md)). If it
  reports drift, fix the docs; never weaken the check to make it pass.
- Never edit the version by hand: `scripts/bump-version.sh patch|minor|major`
  ([git & releases](rules/07-git-and-releases.md)).
- These must pass before you hand back: `bash -n`, `shellcheck -x`, `tests/smoke.sh`,
  `tests/shells.sh`, `tests/docs.sh` ([testing](rules/06-testing.md)).
- Don't commit, push, tag or release unless a maintainer asks. Commits carry no tool
  signatures or co-author trailers ([git & releases](rules/07-git-and-releases.md)).

## Quick map

| Path | What it is |
|------|------------|
| `g3rm0n` | entry point (argument parsing and dispatch) |
| `lib/` | `core` · `ui` · `system` · `ai` · `dashboard` · `setup` |
| `completions/` | bash, zsh, fish |
| `tests/` | `smoke.sh`, `shells.sh`, `docs.sh`, mocks |
| `scripts/bump-version.sh` | version bump and changelog cut |
| `.githooks/pre-commit` | runs `tests/docs.sh --staged` |
