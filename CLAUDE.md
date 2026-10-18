# g3rm0n project instructions

@AGENTS.md

## Hooks in this project

- `.claude/settings.json` registers a **Stop** hook, `.claude/hooks/docs-drift.sh`. It
  runs `tests/docs.sh --since <merge-base with main>` before you finish. If it blocks
  with drift findings, align the docs it names (README, completions, rules,
  CHANGELOG) and rerun `tests/docs.sh`; don't stop with drift outstanding.
- The git pre-commit hook (`.githooks/pre-commit`) runs the same check on staged files.
  Never bypass it with `--no-verify`.
