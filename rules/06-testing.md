# 6. Testing

Every change must pass these before it's merged. CI runs the automated ones on each
push and pull request.

## Automated

```bash
bash -n g3rm0n install.sh lib/*.sh completions/g3rm0n.bash   # syntax
shellcheck -x g3rm0n install.sh lib/*.sh completions/g3rm0n.bash   # lint, zero findings
tests/smoke.sh                                                 # behavior, no network
```

`tests/smoke.sh` runs against temporary config and cache folders and puts
`tests/mock/curl` first on `PATH`, so it never touches your real setup or real APIs.

## Manual, for anything that changes output

- `g3rm0n --once` in a terminal at 100 columns and at 60 columns.
- `g3rm0n --once | cat` prints no escape codes.
- The live dashboard redraws without flicker or scrolling, `q` quits, and the terminal
  is restored after `q` and after Ctrl-C.
- Resizing the window while the dashboard runs redraws cleanly.
- If you touched setup: `g3rm0n setup` with arrows, space, `a`, enter and `q`, using
  a temporary `XDG_CONFIG_HOME`.
- If you touched an AI provider: the success, `401`, `nologin`, `429` and offline states.

## Rules for tests

- No real credentials, account IDs or email addresses anywhere in `tests/`.
- Tests must pass on a machine with no AI logins at all.
- Never point tests at your real `~/.config/g3rm0n` or `~/.cache/g3rm0n`.
