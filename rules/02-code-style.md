# 2. Code style

## Language and runtime

- Bash **5.0+** only (`EPOCHREALTIME`, `EPOCHSECONDS`, namerefs, `${var,,}`).
- g3rm0n is a bash program, but people start it from any shell (bash, zsh, fish, dash,
  ksh, tcsh, …). Never assume the user's shell is bash: anything shown to the user
  that they would type (exporting a key, editing `PATH`) goes through
  `g3_export_hint` or the installer's `path_hint`, which phrase it for their shell.
- The guard at the top of `g3rm0n` and `install.sh` must stay POSIX `sh` (and
  zsh-safe: no unquoted word splitting), so `sh g3rm0n`, `zsh g3rm0n`, macOS's bash
  3.2 and `curl … | sh` hand over to bash 5 or fail politely, never with syntax errors.
- Linux and macOS. Everything OS-specific lives in `lib/platform/<os>.sh` behind the
  platform contract ([architecture](../ARCHITECTURE.md#platforms)). Shared code must
  not use GNU-only or BSD-only flags (`date -d`, `stat -c`, `sed -i`, `readlink -f`,
  `df --output`, `ps --sort`, …); put the call in a backend, or use a form both have.
- On Linux, read `/proc` and `/sys` directly instead of spawning tools when practical.
- `install.sh` must keep working with **bash 3.2** (macOS's own bash): no `mapfile`,
  associative arrays, `${var,,}` or empty arrays under `set -u`. `tests/install.sh`
  runs it with bash 3.2.
- Use the OS's stock tools only. GNU flags are fine inside `lib/platform/linux.sh`,
  BSD flags inside `lib/platform/darwin.sh`. Anything that isn't part of a stock
  install must be optional and checked with `have <cmd>` before use.

## Layout

```
g3rm0n              entry point: argument parsing and dispatch only
lib/core.sh         version, paths, colors, config parsing, formatting helpers
lib/ui.sh           panel primitives: titles, bars, sparklines, padding, grid
lib/panel.sh        panel registry, sample/render composition, hit-testing
lib/fold.sh         fold state and its persistence
lib/input.sh        terminal input adapter: keys and mouse -> events
lib/keymap.sh       key bindings as data
lib/platform/linux.sh   Linux backend (the platform contract)
lib/platform/darwin.sh  macOS backend (the platform contract)
lib/system.sh       rates, health score and system panel renderers (all platforms)
lib/ai.sh           AI providers, cache and AI panel renderer
lib/dashboard.sh    controller: panel registration, live loop, action dispatch
lib/setup.sh        g3rm0n setup
completions/        bash, zsh (_g3rm0n) and fish completions
tests/              test suites; tests/lib/ shared portable helpers; tests/mock/ fake
                    curl and recorded macOS command output (tests/mock/darwin/)
scripts/            maintainer tools (bump-version.sh); never installed
.githooks/          git hooks (enable with: git config core.hooksPath .githooks)
.claude/            coding-agent project settings and hooks
rules/              these rules
```

[ARCHITECTURE.md](../ARCHITECTURE.md) explains how the modules work together and
which pattern each follows. Put new code in the module that owns its concern. Don't create a new module for a
single function.

## Naming

| Prefix | Owner | Example |
|--------|-------|---------|
| `g3_` | core helpers | `g3_bytes`, `g3_config_load` |
| `ui_` | UI primitives | `ui_bar`, `ui_grid` |
| `sys_` | system sampling and panels | `sys_sample`, `sys_panel_cpu` |
| `ai_` | AI providers and panels | `ai_fetch_claude`, `ai_panel` |
| `panel_` | panel registry and composition | `panel_register`, `panel_at` |
| `fold_` | fold state | `fold_toggle`, `fold_save` |
| `in_` | input adapter | `in_read`, `in_decode` |
| `keymap_` | key bindings | `keymap_action` |
| `dash_` | dashboard controller | `dash_sample`, `dash_do` |
| `setup_` | setup command | `setup_write` |
| `G3_*` | global constants | `G3_VERSION`, `G3_W` |
| `S_*` | sampled system state | `S_CPU`, `S_MEM_P` |
| `PANEL_*` | panel registry and the renderer contract | `PANEL_BODY`, `PANEL_SUM`, `PANEL_IDS` |
| `PB_*`, `PV_*` | per-panel body rows / composed view (made by `panel.sh`, never by hand) | `PB_cpu`, `PV_ai_zai` |
| `KEYMAP*`, `FOLD`, `IN_EVENT` | key bindings, fold state, the current input event | |
| `c_*` | color codes (empty when color is off) | `c_dim`, `c_off` |

Locals are lowercase and always declared with `local`. Functions start with a
one-line comment that states inputs and outputs, e.g. `# pct [width] -> colored bar`.

## Rules

- `shellcheck` must report nothing. Disable a check inline only with a reason, e.g.
  `# shellcheck disable=SC2088  # matching a literal "~/" prefix on purpose`.
- Quote every expansion unless word splitting is the point, and say so when it is.
- Never `eval`. Never `source` user-controlled files: the config is parsed, not sourced.
- Prefer bash builtins over subshells inside the frame loop; every fork costs time at
  each refresh.
- Keep functions short and single-purpose. A sampler samples, a renderer formats, the
  controller decides. Renderers never read input or fold state; the composer never
  samples.
- Keep I/O at the edges: decoding, layout and fold logic are pure functions over their
  inputs, so `tests/ui.sh` can check them with plain strings.
- Behavior that is really data (key bindings, sections, providers) lives in a table,
  not in `if` chains.
- Comments explain **why**, not what. Match the density of the surrounding code.
- Write user-facing text in plain, short sentences with no jargon.
- Format with 2-space indents and no tabs, and keep lines under ~110 columns.
