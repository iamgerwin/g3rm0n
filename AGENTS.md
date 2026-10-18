# Instructions for coding agents

Before changing anything in this repository, read every file in [`rules/`](rules/README.md)
and follow them. In particular:

- g3rm0n is a **read-only monitor**. Never add anything that changes the system or
  an account ([scope](rules/01-scope.md)).
- Never read, print, store or commit credentials ([security](rules/03-security-privacy.md)).
- New panels follow the standard layout ([UI conventions](rules/04-ui-conventions.md)).
- `bash -n`, `shellcheck` and `tests/smoke.sh` must pass ([testing](rules/06-testing.md)).
- Don't commit, push, tag or release unless a maintainer asks
  ([git & releases](rules/07-git-and-releases.md)).
