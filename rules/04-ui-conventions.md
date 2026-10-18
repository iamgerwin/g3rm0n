# 4. UI conventions

Consistency is the product. A new panel must look like it was always there.

## Panel anatomy

```
◉ CPU ────────────────────────────────────────    ← title: icon, name, rule to 46 columns
Usage  ████████░░░░░░░░   53%                     ← label (7 columns) + value
Cores  ▄▄
Load   0.61 · 0.71 · 0.61 · 2 threads
```

- **Width:** every panel is `G3_W` = 46 columns, and two panels sit side by side with
  a 2-column gap. Below 94 columns, panels stack in one column.
- **Title:** composed by `panel.sh` from the icon and name you register; renderers
  never draw their own title. The icon is a single-width glyph. In the live dashboard
  the title also carries the fold marker (`▾` open, `▸` folded) and the section's
  shortcut digit at the right end.
- **Rows:** start every row with `ui_label <Label>`, which pads the label to 7
  columns. Labels are one capitalized word of 6 characters or fewer.
- **Height:** 3–5 rows per panel. Panels that share a row are padded to equal height automatically.
- **One fact per row.** Put secondary detail after a dim `·`.

## Header

The top line is a list of components (`lib/header.sh`), rendered in the order given by
`header` in the config. A new component is one `hdr_<id>` function that sets `HDR_TEXT`
from already-sampled data, plus its `HDR_FN` entry. Components never add their own
separators, never run a process per frame (use `printf '%(…)T'` for time), and say in
`HDR_DROP` whether they may give way in a narrow window.

## Folding

Every panel folds to its title line. A folded title shows the panel's summary
(`PANEL_SUM`) after a `·`:

```
▸ ◫ Memory · 44% · 13.9G/31.2G ───────────── 2
```

- The summary is the one or two numbers someone would unfold the panel to see: a
  usage percent, a balance, a state such as `rate limited`.
- Order its parts by importance, separated by ` · `, and keep the whole to about 25
  columns. When it doesn't fit, its last parts are dropped (`612 tasks · WindowServer 12%`
  becomes `612 tasks`); a part is never cut, so colors never break. Plan for the
  longest realistic value on every platform: Macs run hundreds of processes with
  long names.
- The layout depends only on the terminal size from `ui_term_size`, the same on
  every platform. Never measure the terminal with `tput` inside `$(...)`: macOS's
  `tput` can't see the terminal from there and answers 80×24.
- Color only the main number (`ui_tone` for percentages, `c_yellow` for states that
  need attention). The rest stays plain.
- One-shot output stays exactly as it was before folding: no markers and no digits
  unless `--fold` asked for folds.

## Bars and numbers

| Use | Call | Width |
|-----|------|-------|
| Main gauge in a system panel | `ui_bar pct` | 16 |
| Compact gauge (disk, battery, GPU, AI windows) | `ui_bar pct 10` | 10 |
| Per-process gauge | `ui_bar pct 5` | 5 |
| Percent next to a bar | `ui_pct pct` | 4 + `%` |
| Bytes | `g3_bytes n` | `1.5K` `3.0G` |
| Durations | `g3_duration secs` | `3d 4h` `2h 05m` `7m` |
| Money | `ai_money cur amount` | `$8.20` `¥12.34` |

Bars are green below 60%, yellow below 85%, red above. Don't invent other color scales.

## Color

- `c_bold` is for the one number that matters most in a row.
- `c_dim` is for secondary text: units, notes, explanations.
- `c_yellow` and `c_red` mark states that need attention: stale, rate limited, expired, hot.
- `c_cyan` is for sparklines and core strips.
- Every color is optional. Output must stay readable with `--no-color`, with `NO_COLOR`
  set, and when piped.

## Groups

The grid pairs panels only within a group: `system`, `tokens` (AI Tokens, ✦) and
`credits` (AI Credits, ◆). Subscription panels show windows that reset. Credit panels
show money that runs down. Never mix the two shapes.

## Wording

- AI panel titles read `AI Tokens · <Provider>` or `AI Credits · <Provider>`.
- States use one word followed by a hint: `expired · run claude to sign in again`,
  `rejected · check DEEPSEEK_API_KEY`, `rate limited · retrying in 30m`.
- Numbers that aren't fresh keep their place and say so: `12m ago · retry 4m` at the end
  of the last row (tokens) or as a `Status` last row (credits). An estimated value is
  marked `~`.
- When an API doesn't report a value, say `not reported by this API`. Never show `0`.
