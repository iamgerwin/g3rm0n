# 8. Documentation

The docs are part of the product. A change isn't done until the docs that describe
it are true again. Drift is caught by a deterministic check, not by memory.

## The drift check

`tests/docs.sh` compares the docs with the code and fails on any mismatch. It runs in
three places, so drift can't reach `main`:

| Where | When | Command |
|-------|------|---------|
| Git pre-commit hook (`.githooks/pre-commit`) | every `git commit` | `tests/docs.sh --staged` |
| Coding-agent stop hook (`.claude/hooks/docs-drift.sh`) | before an agent hands back | `tests/docs.sh --since <merge-base with main>` |
| CI (`.github/workflows/ci.yml`) | every push and pull request | `tests/docs.sh`, plus `--since` the base branch on pull requests |

Enable the git hook once per clone:

```bash
git config core.hooksPath .githooks
```

`git commit --no-verify` skips it locally, but CI runs the same check, so a skipped
check only moves the failure to the pull request.

## What it enforces

- **Version:** `G3_VERSION` in `lib/core.sh` is `MAJOR.MINOR.PATCH`, equals the newest
  dated release in `CHANGELOG.md`, and equals every `--version X.Y.Z` example in
  `README.md` and `install.sh`.
- **Changelog format:** a `## [Unreleased]` section; releases as `## [X.Y.Z] - YYYY-MM-DD`;
  only the categories Added, Changed, Deprecated, Removed, Fixed and Security; a link
  reference for every version, with `[Unreleased]` comparing the current tag to `HEAD`.
- **Changelog entries:** any change to `g3rm0n`, `install.sh`, `lib/` or
  `completions/` must come with a `CHANGELOG.md` change in the same commit
  (pre-commit) or pull request (CI).
- **Surface area:** every section, every option in `g3rm0n help`, and every
  `g3rm0n setup` option appears in `README.md` and in the bash, fish and zsh
  completions. Every provider has a row in the README providers table, and every
  credential variable it reads is named in the README.
- **Project docs:** every rule file is linked from `rules/README.md`; every
  `tests/*.sh` suite runs in CI and is listed in [testing](06-testing.md);
  `AGENTS.md` points to `rules/` and names the check; `CLAUDE.md` imports `AGENTS.md`.

When the check can't know something (for example, whether README prose still reads
true after a `lib/` change), it prints a `note` instead of failing. Read it.

## What to update, by kind of change

| You changed | Also update |
|-------------|-------------|
| A flag, subcommand or setup option | `usage`/`setup_usage`, README **Usage** or **Setup**, all three completions, CHANGELOG |
| A section | `G3_SECTIONS` and its label and note, README, all three completions, CHANGELOG |
| An AI provider | README providers table, credential variables, troubleshooting row if it has a new state, CHANGELOG ([adding a provider](05-adding-a-provider.md)) |
| Config keys or files | README **Configuration**, `setup_write`, CHANGELOG (a removed or renamed key is a MAJOR change) |
| Installer behavior | README **Install**/**Uninstall**, the header comment and `usage` in `install.sh`, CHANGELOG |
| Shell-specific behavior | README **Shells**, `tests/shells.sh` |
| A convention | the matching file in `rules/`, and `AGENTS.md` if agents must know it |
| Tests or CI | [testing](06-testing.md) |

## Writing the changelog

`CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

- Add entries under `## [Unreleased]` as you go, in the category that fits:
  **Added** (new capability), **Changed** (existing behavior is different),
  **Deprecated**, **Removed**, **Fixed** (a bug), **Security** (a vulnerability fix).
- Write for users, not for the diff: say what they can now do or what no longer goes
  wrong, e.g. "`sh g3rm0n` now hands over to bash instead of failing with syntax errors".
- One entry per user-visible change, starting with a capital letter. Name commands,
  flags and files in backticks.
- Internal-only changes (refactors, tests, CI) go under **Changed** with a short
  note, or are left out when they have no effect at all on users. The pre-commit
  check only asks for an entry when product code changes.
- Never edit a released section, except to fix a typo or a broken link.

## Versions

Never edit the version by hand. Run `scripts/bump-version.sh patch|minor|major` (see
[git & releases](07-git-and-releases.md)). It updates `G3_VERSION`, cuts the dated
CHANGELOG section, rewrites the compare links and refreshes the `--version`
examples, then runs the drift check.
