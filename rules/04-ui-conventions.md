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
- **Title:** `ui_title <icon> <name>`. The icon is a single-width glyph.
- **Rows:** start every row with `ui_label <Label>`, which pads the label to 7
  columns. Labels are one capitalized word of 6 characters or fewer.
- **Height:** 3–5 rows per panel. Panels that share a row are padded to equal height automatically.
- **One fact per row.** Put secondary detail after a dim `·`.

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
  `rejected · check DEEPSEEK_API_KEY`, `rate limited · retrying in 5m`.
- When an API doesn't report a value, say `not reported by this API`. Never show `0`.
