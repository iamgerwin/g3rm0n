# Contributing to g3rm0n

Thanks for helping. Everything you need is in [`rules/`](rules/README.md). Please
read it before you start.

1. Check that your idea is in [scope](rules/01-scope.md). g3rm0n observes and never changes anything.
2. Branch from `main` (`feat/<topic>`, `fix/<topic>`, …) and enable the git hooks once:
   `git config core.hooksPath .githooks`. The pre-commit hook blocks docs drift and
   code changes without a changelog entry.
3. Follow the [code style](rules/02-code-style.md) and [UI conventions](rules/04-ui-conventions.md).
4. Run the [tests](rules/06-testing.md):

   ```bash
   bash -n g3rm0n install.sh lib/*.sh completions/g3rm0n.bash tests/*.sh
   shellcheck -x g3rm0n install.sh lib/*.sh completions/g3rm0n.bash tests/*.sh
   tests/smoke.sh
   tests/shells.sh   # bash, zsh, fish, dash, ksh, mksh, tcsh; missing shells are skipped
   tests/ui.sh       # folding, keys and mouse, in a pseudo-terminal
   tests/platform.sh # every OS backend against the same contract
   tests/install.sh  # what gets installed, and that it runs
   tests/docs.sh     # docs match the code
   ```

5. Update the docs your change affects ([documentation](rules/08-documentation.md)) and
   add an entry to `CHANGELOG.md` under **Unreleased**.
6. Open a pull request with a [Conventional Commit](rules/07-git-and-releases.md) title.

Report security issues privately to iamgerwin@live.com.
