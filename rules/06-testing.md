# 6. Testing

Every change must pass these before it's merged. CI runs the automated ones on each
push and pull request.

## Automated

```bash
bash -n g3rm0n install.sh lib/*.sh completions/g3rm0n.bash tests/*.sh   # syntax
zsh -n completions/_g3rm0n; fish --no-execute completions/g3rm0n.fish   # syntax
shellcheck -x g3rm0n install.sh lib/*.sh completions/g3rm0n.bash tests/*.sh   # lint, zero findings
tests/smoke.sh                                                 # behavior, no network
tests/shells.sh                                                # every installed shell
tests/ui.sh                                                    # folding, keys, mouse
tests/platform.sh                                              # backend contract, macOS fixtures, native backend
tests/install.sh                                               # run-time files only, tarball, bash 3.2
tests/docs.sh                                                  # docs match the code
```

**The same suites run on every platform.** CI runs all of them on Ubuntu 22.04 and
24.04 and on macOS 14 and 15. Write assertions about features, not about one OS:
use the helpers in `tests/lib/common.sh` (`pty_run`, `file_mode`, `with_timeout`,
`iso_utc`) instead of `script -c`, `stat -c` or `date -d`, so a test never needs a
macOS twin.

`tests/platform.sh` checks every backend against the platform contract, runs the
macOS backend against recorded macOS output in `tests/mock/darwin/` (so its parsing is
tested on Linux too), and holds the native backend to the same checks on Linux and
macOS. Any new `plat_` function, or a change in what a backend reads, needs a case
there and, for macOS, a fixture.

`tests/install.sh` checks that only run-time files are installed, with only the
installing OS's backend, that the installed copy runs on its own, that release
tarballs carry no dev files, that the latest release is found without the
rate-limited GitHub API (with a clear message when it can't be), and that the
installer works under bash 3.2 (CI's macOS
`/bin/bash`; locally, point `G3_TEST_BASH32` at one).

`tests/ui.sh` unit-tests the pure pieces of the interactive dashboard (input
decoding, key bindings, fold state, titles, layout and hit-testing) and then drives
the live dashboard in a pseudo-terminal with real key presses and SGR mouse clicks.
Any change to input, keys, folding or panel layout needs a case there. It also
checks that only `q` quits (every other key, click, wheel event and miss is
harmless), and that rewriting `g3rm0n` while it runs never produces a parse error
on exit.

`tests/docs.sh` is the documentation drift check described in
[documentation](08-documentation.md); the pre-commit hook runs it with `--staged`.

Both suites run against temporary config and cache folders and put
`tests/mock/curl` first on `PATH`, so they never touch your real setup or real APIs.

`tests/shells.sh` starts the dashboard, `g3rm0n setup` (interactively, in a
pseudo-terminal), the installer and the completions from bash, zsh, fish, dash/sh,
ksh, mksh, tcsh and busybox sh. Shells that aren't installed are reported as `skip`;
CI installs all of them, so a skip locally is fine but a `FAIL` never is. Anything
that prints a command for the user to type, or that touches the installer or the
completions, needs a case here.

## Manual, for anything that changes output

- `g3rm0n --once` in a terminal at 100 columns and at 60 columns.
- `g3rm0n --once | cat` prints no escape codes.
- The live dashboard redraws without flicker or scrolling, `q` quits, and the terminal
  is restored after `q` and after Ctrl-C (no stray characters when you move the mouse
  afterwards).
- If you touched folding or input: click titles in at least one terminal, inside tmux
  with `mouse on`, and with `--no-mouse`.
- Resizing the window while the dashboard runs redraws cleanly.
- If you touched setup: `g3rm0n setup` with arrows, space, `a`, enter and `q`, using
  a temporary `XDG_CONFIG_HOME`.
- If you touched an AI provider: the success, `401`, `nologin`, `429` and offline states.

## Rules for tests

- No real credentials, account IDs or email addresses anywhere in `tests/`.
- Tests must pass on a machine with no AI logins at all.
- Never point tests at your real `~/.config/g3rm0n` or `~/.cache/g3rm0n`.
