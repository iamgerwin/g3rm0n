# Architecture

g3rm0n is a small bash program organized like an interactive UI application: a
**model** that samples the machine, **views** that turn samples into panels, and a
**controller** that turns input into actions. Each module owns one concern and
talks to the others through a few documented globals and function contracts.

`tests/docs.sh` fails if a module under `lib/` is missing from this file.

## Modules

```
g3rm0n ──► lib/core.sh ──► lib/ui.sh ──► lib/panel.sh ──► lib/fold.sh ──► lib/input.sh ──► lib/keymap.sh
           (load order)    lib/system.sh ──► lib/ai.sh ──► lib/dashboard.sh ──► lib/setup.sh
```

| Module | Role | Owns |
|--------|------|------|
| `g3rm0n` | Entry point | Shell guard, argument parsing, dispatch to dashboard or setup |
| `lib/core.sh` | Foundation | Version, paths (config, cache, state), sections, colors, config parsing, formatting helpers |
| `lib/ui.sh` | View primitives | Titles, bars, sparklines, padding, the two-column grid and its hit map (`UI_HITS`) |
| `lib/panel.sh` | Panel registry and composition | `panel_register`, `panel_render_all` (sample step), `panel_compose` (render step), `panel_at` (hit-testing) |
| `lib/fold.sh` | Fold state (model) | `FOLD` map, toggles and groups, `--fold` lists, persistence in `$G3_STATE_DIR/folded` |
| `lib/input.sh` | Input adapter | Raw terminal bytes in, normalized events out (`key`, `click`, `wheel`, `none`); mouse on/off |
| `lib/keymap.sh` | Key bindings (data) | `KEYMAP` (key → action) and `KEYMAP_HELP` (what help and the README show) |
| `lib/system.sh` | System model and renderers | `/proc` and `/sys` sampling, health score, the six system panel renderers |
| `lib/ai.sh` | AI model and renderers | Provider fetchers, cache and background refresh, the AI panel renderer |
| `lib/dashboard.sh` | Controller | Panel registration, the live loop, event → action dispatch (`dash_do`), terminal restore |
| `lib/setup.sh` | Setup flow | `g3rm0n setup`: the checklist UI and writing the config |

## Patterns

**Registry (panels).** Every panel is registered once with an id, section, grid group,
icon, title and renderer (`panel_register` in `dash_register`). Nothing else keeps a
list of panels: composition, folding, hit-testing, `--fold` and the section shortcuts
all read the registry. Adding a panel means registering it; no other code changes.

**Renderer contract (strategy).** A renderer fills `PANEL_BODY` with rows (no title)
and may set `PANEL_SUM` to a one-line summary for the folded title. System panels
(`sys_panel_<section>`) and AI panels (`ai_panel <id>`, one shape per kind) are
interchangeable to the composer.

**Sample / render split.** `dash_sample` reads the machine and runs every renderer once
per interval. `dash_render` builds the frame from those results and the fold state.
Folding, clicking and resizing only re-render, so rates and sparklines are never
skewed by input, and redraws are fast.

**Adapter (input).** `in_read` does the I/O and `in_decode` is a pure function from a
byte sequence to an event. Terminal quirks (SGR mouse, application cursor keys,
releases, drags) are handled there and nowhere else, and `in_decode` is unit-tested
with plain strings.

**Command table (keys).** `KEYMAP` maps keys to named actions (`quit`, `refresh`,
`section <name>`, `fold-all`, `unfold-all`, `panel <id>`). `dash_do` is the single
dispatcher. A new shortcut is one table entry plus a `KEYMAP_HELP` line; the docs
check makes sure the README lists it. Unbound keys refresh, as they always have.

**State as data.** Fold state is a map of panel ids, saved as one line of ids and
parsed with a whitelist (never sourced). The config is parsed the same way. Neither
holds anything but layout and preferences.

## The live loop

```
dash_run
 ├─ sys_static, dash_register, fold_load, mouse on, alternate screen
 └─ loop
     ├─ if due:  dash_sample  ─► sys_sample, sys_health, ai_tick, panel_render_all
     ├─ dash_render  ─► header, panel_compose (fold markers, summaries, UI_HITS), footer
     └─ wait for the next sample, in ≤250 ms slices (a resize can't interrupt read):
          in_read ─► IN_EVENT ─► dash_event ─► keymap_action / panel_at ─► dash_do
```

Exit paths (`q`, Ctrl-C, `TERM`, any error) all run `dash_restore`, which turns mouse
reporting off and leaves the alternate screen, so the terminal is always given back
clean.

## One-shot mode

`--once` (automatic when piped) registers the same panels, fetches AI usage in
parallel, samples once and renders with `live = 0`: no markers, no shortcut digits,
and no saved folds unless `--fold` is given. The output is the same as before folding
existed.

## Extending

| To add | Touch |
|--------|-------|
| A system panel | a renderer in `lib/system.sh`, its icon/title in `SYS_ICON`/`SYS_TITLE`, the section in `G3_SECTIONS` (`lib/core.sh`), the docs |
| An AI provider | `lib/ai.sh` only ([rules/05](rules/05-adding-a-provider.md)); it registers itself through `dash_register` |
| A key binding | `KEYMAP` and `KEYMAP_HELP` in `lib/keymap.sh`, an action in `dash_do` if it's new, the README keys table |
| A mouse gesture | `in_decode` (new event), `dash_event` (event → action) |
