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
- Respect rate limits: at most one call per provider per `AI_TTL`, and back off
  after an HTTP 429.
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
- Use the mock in `tests/mock/curl` for provider tests. Tests must never need real keys.

## Reporting a vulnerability

Report security issues privately to iamgerwin@live.com, not in a public issue.
