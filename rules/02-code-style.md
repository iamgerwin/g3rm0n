# 2. Code style

## Language and runtime

- Bash **5.0+** only (`EPOCHREALTIME`, `EPOCHSECONDS`, namerefs, `${var,,}`).
- g3rm0n is a bash program, but people start it from any shell (bash, zsh, fish, dash,
  ksh, tcsh, …). Never assume the user's shell is bash: anything shown to the user
  that they would type (exporting a key, editing `PATH`) goes through
  `g3_export_hint` or the installer's `path_hint`, which phrase it for their shell.
- The POSIX guard at the top of `g3rm0n` and `install.sh` must stay POSIX `sh`, so
  `sh g3rm0n` and `curl … | sh` fail politely instead of with syntax errors.
- Linux only: read `/proc` and `/sys` directly instead of spawning tools when practical.
- GNU coreutils are fine (`df --output`, `stat -c`, `date -d`). Anything else must be
  optional and checked with `have <cmd>` before use.

## Layout

```
g3rm0n              entry point: argument parsing and dispatch only
lib/core.sh         version, paths, colors, config parsing, formatting helpers
lib/ui.sh           panel primitives: titles, bars, sparklines, padding, grid
lib/panel.sh        panel registry, sample/render composition, hit-testing
lib/fold.sh         fold state and its persistence
lib/input.sh        terminal input adapter: keys and mouse -> events
lib/keymap.sh       key bindings as data
lib/system.sh       system samplers and system panel renderers
lib/ai.sh           AI providers, cache and AI panel renderer
lib/dashboard.sh    controller: panel registration, live loop, action dispatch
lib/setup.sh        g3rm0n setup
completions/        bash, zsh (_g3rm0n) and fish completions
tests/              smoke tests, cross-shell tests, docs drift check and mocks
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
