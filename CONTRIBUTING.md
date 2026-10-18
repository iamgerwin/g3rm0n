# Contributing to g3rm0n

Thanks for helping. Everything you need is in [`rules/`](rules/README.md). Please
read it before you start.

1. Check that your idea is in [scope](rules/01-scope.md). g3rm0n observes and never changes anything.
2. Branch from `main` (`feat/<topic>`, `fix/<topic>`, …).
3. Follow the [code style](rules/02-code-style.md) and [UI conventions](rules/04-ui-conventions.md).
4. Run the [tests](rules/06-testing.md):

   ```bash
   bash -n g3rm0n install.sh lib/*.sh completions/g3rm0n.bash
   shellcheck -x g3rm0n install.sh lib/*.sh completions/g3rm0n.bash
   tests/smoke.sh
   ```

5. Open a pull request with a [Conventional Commit](rules/07-git-and-releases.md) title,
   and add a line to `CHANGELOG.md` under **Unreleased**.

Report security issues privately to iamgerwin@live.com.
