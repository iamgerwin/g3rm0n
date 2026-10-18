# Learnings

A living record of mistakes made on g3rm0n and what they taught us, so nobody (person or
coding agent) makes them twice. Read it before you change anything, and add to it whenever
a bug is fixed or a mistake is caught: what happened, why, the rule it led to, and what now
enforces that rule. Newest first. Entries are never deleted; if a lesson stops applying,
say so in a new entry.

Format of an entry:

```
## YYYY-MM-DD · area · short title
- **What happened:** the symptom, as the user saw it
- **Cause:** the real reason
- **Lesson:** the rule to follow from now on
- **Enforced by:** the test, check or rule that catches it (or "review only")
```

---

## 2026-10-18 · tests · A loop variable overwrote the script's own option
- **What happened:** after adding a loop to `tests/docs.sh`, a plain run started
  reporting "code changed … but CHANGELOG.md was not updated".
- **Cause:** the loop variable was named `mode`, which the script already used for
  `--staged`/`--since`; globals in bash scripts are shared by everything below them.
- **Lesson:** before naming a variable in a script's top level, search the file for it;
  prefer specific names (`screen`, not `mode`), and put loops in functions with `local`.
- **Enforced by:** review only.

## 2026-10-18 · docs · The README's sample screen was typed by hand
- **What happened:** the sample showed an old header, no fold markers and no footer.
- **Cause:** a hand-written sample can't follow the renderer.
- **Lesson:** generate examples from the real code with fixed sample data, and check
  them like any other docs.
- **Enforced by:** `scripts/readme-sample.sh` and its check in tests/docs.sh.

## 2026-10-18 · process · A regression "proof" that compared the fix with itself
- **What happened:** to show new tests fail on the old code, `git stash -- lib` was used,
  but the fix was already committed, so nothing was stashed and both runs tested new code.
- **Cause:** `git stash` only holds uncommitted changes.
- **Lesson:** prove a regression test against the previous release: `git worktree add
  <dir> v<previous>`, copy the new `tests/` in, run them there, then remove the worktree.
- **Enforced by:** review only (rules/06-testing.md describes the procedure).

## 2026-10-18 · process · `git commit --no-verify` used for a debug commit
- **What happened:** a broken CI diagnostic was committed with the hook skipped and would
  have reached `main` through a rebase merge.
- **Cause:** bypassing the pre-commit hook to save a step.
- **Lesson:** never pass `--no-verify`. If a temporary commit is unavoidable, squash-merge
  the pull request so it never lands on `main`.
- **Enforced by:** CLAUDE.md, rules/08-documentation.md, CI runs the same checks.

## 2026-10-18 · macOS · "Temperature needs root" was assumed, not checked
- **What happened:** Apple silicon Macs showed `no sensors exposed`, while iStat Menus
  showed CPU temperatures without admin rights.
- **Cause:** assuming `powermetrics` (root) was the only source. The IOKit HID sensors are
  readable by any user.
- **Lesson:** before declaring a reading impossible on a platform, check how the popular
  unprivileged tools for that platform get it. Say "unverified" until real hardware shows it.
- **Enforced by:** tests/platform.sh (IOKit fixtures), `g3rm0n sensors` notes for diagnosis.

## 2026-10-18 · AI · Claude rate limits from polling every minute
- **What happened:** the Claude panel showed `rate limited · retrying in 5m` and `stale`.
- **Cause:** a strict endpoint polled every 60 s from every open window, a fixed backoff
  that ignored `Retry-After`, and an error row that hid good cached numbers.
- **Lesson:** match the polling rate to how fast the data changes, honour `Retry-After`,
  back off exponentially, share one request across processes, and prefer the last good
  reading (with its age) to an error.
- **Enforced by:** tests/ai.sh, rules/03-security-privacy.md.

## 2026-10-18 · locale · Decimal commas broke numbers
- **What happened:** with a German/French/Dutch locale, money read `$8.2 left of $25,00`.
- **Cause:** `EPOCHREALTIME`, `printf %.2f`, `read -t` and `awk` follow `LC_NUMERIC`.
- **Lesson:** pin `LC_NUMERIC=C` at start-up and keep only the user's character set.
- **Enforced by:** tests/platform.sh (comma-decimal locale checks; macOS CI has one).

## 2026-10-18 · macOS · `tput` reported 80×24 for every window
- **What happened:** the Mac dashboard was always one column with the short footer.
- **Cause:** macOS's `tput` only asks stdout, which is a pipe inside `$(...)`.
- **Lesson:** measure the terminal with `stty size` on `/dev/tty` (`ui_term_size`), never
  `tput cols`/`tput lines`. Silence stderr *before* opening `/dev/tty` (`2>/dev/null </dev/tty`).
- **Enforced by:** tests/ui.sh (live layout under `tests/mock/tput-pipe`), rules/04.

## 2026-10-18 · macOS · Claude Code's login lives in the Keychain
- **What happened:** no Claude panel on macOS.
- **Cause:** only `~/.claude/.credentials.json` was checked; on macOS it's a Keychain item.
- **Lesson:** for every provider, check where its CLI stores credentials on each platform.
- **Enforced by:** tests/platform.sh (Keychain fixtures), rules/05-adding-a-provider.md.

## 2026-10-18 · UI · Values that fit on Linux didn't fit on a Mac
- **What happened:** the folded Processes title lost its whole summary on a Mac.
- **Cause:** Macs run hundreds of processes with long names; the summary was all or nothing.
- **Lesson:** design every width for the longest realistic value on every platform, and
  degrade gracefully (drop trailing parts) instead of all at once.
- **Enforced by:** tests/ui.sh (summary trimming), rules/04-ui-conventions.md.

## 2026-10-18 · dashboard · A click beside a title quit the dashboard
- **What happened:** clicking anywhere except a panel title exited g3rm0n.
- **Cause:** a lookup that found nothing returned 1, and the loop treated any non-zero
  return as "quit".
- **Lesson:** never signal control flow (quit, stop) with a return code a failure can also
  produce. Use an explicit flag.
- **Enforced by:** tests/ui.sh (every non-quit event keeps it running), rules/02.

## 2026-10-18 · bash · Editing a running script broke it on exit
- **What happened:** `syntax error near unexpected token 'in'` when g3rm0n exited.
- **Cause:** bash reads a script while running it; the file was rewritten in place
  mid-run (the user's install linked to a checkout being edited).
- **Lesson:** end `g3rm0n` with `main "$@"; exit` on one line. Never link a user's install
  to a working checkout you're editing; install a release copy.
- **Enforced by:** tests/ui.sh (rewrite-while-running test, last-line check).

## 2026-10-18 · install · GitHub API rate limit, then a silent `set -e` exit
- **What happened:** `curl: (56) … 403` on shared networks, then no message at all.
- **Cause:** the unauthenticated API allows 60 requests an hour per IP; and a failing
  `var=$(func)` exits silently under `set -e`.
- **Lesson:** find the latest release through the `releases/latest` redirect; write
  `var=$(func) || var=""` and report the failure yourself.
- **Enforced by:** tests/install.sh (latest-release lookups with the mock curl).

## 2026-10-18 · macOS · UTF-8 next to `$name` broke characters
- **What happened:** `CPU � 23%` in folded titles on macOS only.
- **Cause:** macOS's libc treats UTF-8 lead bytes as identifier characters, so `$c_dim·`
  read a variable named `c_dim` plus half the dot.
- **Lesson:** always brace a variable that touches a non-ASCII character: `${c_dim}·`.
- **Enforced by:** tests/platform.sh (portable code check).

## 2026-10-18 · portability · GNU-only habits (and a GNU-only helper in fish)
- **What happened:** macOS failures from `date -d`, `stat -c`, `sed -i`, `readlink -f`,
  `df --output`, `ps --sort`, `wc -l` padding, `script -c`, and fish's own
  `__fish_complete_list` (GNU `sed \+`).
- **Cause:** code and tests written on Linux only.
- **Lesson:** OS-specific calls live in `lib/platform/<os>.sh`; shared code and tests use
  forms both GNU and BSD accept (or `tests/lib/common.sh` helpers). Run every suite on
  macOS too.
- **Enforced by:** tests/platform.sh (no OS-specific commands in shared code), CI on macOS.

## 2026-10-18 · shells · `sh` isn't always dash, and zsh doesn't split `$PATH`
- **What happened:** `curl … | sh` ran the installer in POSIX mode on macOS; `zsh g3rm0n`
  couldn't find bash.
- **Cause:** `/bin/sh` is bash in POSIX mode on macOS and Fedora; zsh doesn't word-split
  unquoted variables.
- **Lesson:** treat POSIX-mode bash as `sh`; use explicit candidate lists, not `$PATH`
  splitting, in code that may run under zsh. Keep `install.sh` bash 3.2 compatible.
- **Enforced by:** tests/shells.sh, tests/install.sh (bash 3.2), rules/02.

## 2026-10-18 · tests · Traps in test scripts themselves
- **What happened:** checks passed that shouldn't have, or failed on one runner only.
- **Cause:** `! cmd` never trips `set -e`; `env -i` clears variables set before it;
  `wc -l` pads on macOS; GitHub runners report no terminal width.
- **Lesson:** use explicit `if … then exit 1`; put variables inside `env -i …`; compare
  counts arithmetically; never assume a width in non-tty tests.
- **Enforced by:** review only.

## 2026-10-18 · docs · The README drifted from the CLI
- **What happened:** `--interval`, `--sections` and `--no-color` were never documented.
- **Cause:** docs were updated by memory.
- **Lesson:** docs drift is checked deterministically, never by memory.
- **Enforced by:** tests/docs.sh in the pre-commit hook, the agent stop hook and CI.

## 2026-10-18 · licensing · Starting from someone else's MIT code
- **What happened:** g3rm0n began as an idea prototyped inside another MIT project.
- **Cause:** copying that code would require keeping its copyright notice.
- **Lesson:** write product code fresh; never copy code without its license notice.
- **Enforced by:** review only.
