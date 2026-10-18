# 3. Security & privacy

g3rm0n sits next to credentials for paid services. These rules are not optional.

## Credentials are referenced, never stored

- A provider's credential is a **reference**: `file:<path>` (a login file another CLI
  already keeps) or `env:<VARIABLE>` (an API key the user already exported).
- `g3rm0n setup` records only that reference. It must never read a key's value
  for display, copy it, print it, or write it to the config, cache or any log.
- Detection may test whether a variable is non-empty or a file is readable. It must
  not print or compare the value.
- Read the secret only at request time, inside the provider's fetch function, and
  keep it in a local variable.

## Network calls

- Send a credential **only** to that provider's own API host. Never send it to a
  third party, a proxy you added, an analytics endpoint or a "helper" service.
- Pass auth headers to curl on **stdin** (`ai_get` does this with `-H @-`), never as
  command-line arguments, which any local user can read in `ps`.
- Make read-only `GET` requests to usage and balance endpoints only. Never call
  endpoints that change an account, spend money or refresh/rotate a token.
- Respect rate limits. A provider is called at most once per `ai_ttl` (60 s, or longer
  for strict endpoints in `AI_REFRESH`: Claude 300 s), by one g3rm0n at a time (the
  `<id>.lock` in the cache). After an HTTP 429, wait for `Retry-After` or back off
  exponentially (`ai_backoff`, up to an hour); the next attempt is shared through
  `<id>.status`, so every running copy waits together.
- Prefer the last good reading to an error: keep cached numbers on screen and say how
  old they are, rather than replacing them with a failure state.
- Network calls run in the background in live mode and never block a frame.
- `--no-ai` must guarantee zero network traffic.

## Storage

- The cache (`~/.cache/g3rm0n/ai`, mode 700) holds normalized usage rows and HTTP
  status codes only, never response bodies, tokens or account identifiers.
- The config file is written with mode 600 through a temp file and an atomic rename.
- No telemetry, crash reporting or update checks run from the dashboard.

## Tests and fixtures

- Fixtures are synthetic. Never paste a real API response that contains an account
  ID, email address or token; replace those fields with obvious placeholders.
- The only file the dashboard writes outside the cache is `$G3_STATE_DIR/folded`
  (panel ids). Keep it that way: no usage numbers, no account data, no credentials.
- Credentials may also live in the OS credential store (`keychain:<service>` on
  macOS). Detection reads the item's attributes only; the secret is read through
  `plat_keychain_read` at request time and handled exactly like a file or variable.
- Platform backends run unprivileged, stock tools only, and never ask for `sudo`.
  Background measurements (macOS CPU) write numbers only, to the cache, and are
  removed on exit by `plat_cleanup`.
- Use the mock in `tests/mock/curl` for provider tests. Tests must never need real keys.

## Reporting a vulnerability

Report security issues privately to iamgerwin@live.com, not in a public issue.
