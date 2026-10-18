# 5. Adding an AI provider

A provider takes a few small edits in `lib/ai.sh` and one line in `lib/core.sh`.

## 1. Decide the kind

| Kind | Use when | Panel |
|------|----------|-------|
| `tokens` | The plan has usage windows that reset (5-hour, weekly, monthly) | AI Tokens ✦ |
| `credits` | You buy credit up front and it runs down | AI Credits ◆ |

## 2. Register it

- `lib/core.sh`: append the id to `G3_PROVIDERS` and update the matching `G3_SECTION_NOTE`.
- `lib/ai.sh`: add the id to `AI_NAME` (display name) and `AI_KIND`.
- Say where the credential lives:
  - a login file another CLI keeps → add a case to `ai_default_file`;
  - an API key in the environment → add `AI_ENV[<id>]="PRIMARY_VAR ALT_VAR"`.

## 3. Write `ai_fetch_<id>`

It must:

1. Read the secret with `ai_secret <id> [jq-path]`. If it's empty, set `AI_CODE=nologin` and return.
2. Call `ai_get <url> "<header lines>"` exactly once per endpoint you need. Read-only
   endpoints only (see [Security & privacy](03-security-privacy.md)).
3. Leave `AI_CODE` at the HTTP status. If the API reports errors inside a 200 body,
   copy the real code into `AI_CODE`.
4. On success, set `AI_ROW` to one tab-separated line in the shape for its kind:

```
tokens:   plan  pct1  window1  reset1_epoch  pct2  window2  reset2_epoch
credits:  currency  left  total  spent_day  spent_week  spent_month  label  detail
```

`window` is in seconds (`18000` = 5h, `604800` = Week) or a short literal label.
Use `-` for any value the API doesn't report. Use `0` as a reset epoch only when no
window has started.

## 4. Write `ai_hint_<id>`

Print a few words telling the user how to fix a missing or rejected credential,
such as `run codex login` or `check DEEPSEEK_API_KEY`.

## 5. Wire up the panel arrays

Declare `P_ai_<id>=()` alongside the others in `dash_run` (`lib/dashboard.sh`).

## 6. Test it

- Add a canned response to `tests/mock/curl`, with placeholders for every identifier.
- Extend `tests/smoke.sh` to render the panel from the mock.
- Check the panel at 100 columns (paired) and 60 columns (stacked).
- Check the `401`, `nologin`, `429` and offline states.
- Update the README's provider table and `CHANGELOG.md`; `tests/docs.sh` fails until
  the provider and its credential variables are in the README.
