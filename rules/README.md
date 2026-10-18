# Contribution rules

These rules apply to everyone who changes g3rm0n, whether you are a person or an
automated coding agent. Read them before opening a pull request. When a rule and
the code disagree, the rule wins: fix the code or propose a change to the rule.

| # | Rule | What it covers |
|---|------|----------------|
| 1 | [Product scope](01-scope.md) | What g3rm0n is and what it never becomes |
| 2 | [Code style](02-code-style.md) | Bash conventions, module layout, naming |
| 3 | [Security & privacy](03-security-privacy.md) | Credentials, network calls, caching |
| 4 | [UI conventions](04-ui-conventions.md) | Panel layout, widths, colors, wording |
| 5 | [Adding an AI provider](05-adding-a-provider.md) | The provider contract, step by step |
| 6 | [Testing](06-testing.md) | What must pass before a change is merged |
| 7 | [Git & releases](07-git-and-releases.md) | Branches, commits, versioning, release steps |
| 8 | [Documentation](08-documentation.md) | The drift check, what to update for each change, changelog style |

## The short version

1. g3rm0n **only observes**. It never changes the system it runs on.
2. Credentials are **referenced, never stored**, and only ever sent to their own provider.
3. Every panel follows the **same layout**: 46 columns wide, a 7-column label column, one fact per row.
4. `bash -n`, `shellcheck` and every suite in `tests/` (`smoke`, `shells`, `ui`, `platform`, `install`, `docs`) must pass, on Linux and macOS.
5. Features are the same on every platform; OS-specific code lives only in a platform backend.
6. Docs change in the same commit as the code they describe, with a `CHANGELOG.md` entry.
7. One logical change per commit, written in the imperative mood, authored by the person responsible for it.

## For automated agents

- Read every file in this folder before your first edit, and re-read the relevant rule before each change.
- Stay inside the scope of the request. Don't add features, dependencies or files that weren't asked for.
- Never read, print, log or commit real credentials, including in test fixtures and command output.
- Never commit, push, tag or publish a release unless a maintainer explicitly asked for it.
- Report honestly: if a check fails or was skipped, say so with the output.
