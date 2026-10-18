#!/usr/bin/env bash
# AI refresh policy tests: how often providers are called, what happens after a rate
# limit, and what the panels show meanwhile. Uses the mock curl (tests/mock/curl) and
# its request log to count real API calls. No network, no real credentials.
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=tests/lib/common.sh
source "$root/tests/lib/common.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0 fail=0
check() { # description command...
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then pass=$(( pass + 1 )); printf '  ok    %s\n' "$desc"
  else fail=$(( fail + 1 )); printf '  FAIL  %s\n' "$desc"; show_on_fail "${out:-}"; fi
}
is() { [[ $1 == "$2" ]]; }
contains() { grep -qF -- "$2" <<<"$1"; }
lacks()    { ! grep -qF -- "$2" <<<"$1"; }
near() { (( $1 >= $2 - 5 && $1 <= $2 + 5 )); }    # epoch within a few seconds
not_due() { ! ai_stale "$1"; }
fits() { local r; for r in "$@"; do (( $(ui_len "$r") <= 46 )) || return 1; done; }   # rows... -> all inside a panel

export HOME=$tmp/home XDG_CONFIG_HOME=$tmp/config XDG_CACHE_HOME=$tmp/cache XDG_STATE_HOME=$tmp/state
export PATH="$root/tests/mock:$PATH" NO_COLOR=1 COLUMNS=100 G3_MOCK_LOG=$tmp/requests
unset CLAUDE_CONFIG_DIR CODEX_HOME GLM_API_KEY ZAI_API_KEY Z_AI_API_KEY DEEPSEEK_API_KEY OPENROUTER_API_KEY
mkdir -p "$HOME/.claude"
login() { printf '{"claudeAiOauth":{"accessToken":"%s","subscriptionType":"pro"}}' "$1" >"$HOME/.claude/.credentials.json"; }
calls() { grep -c "${1:-}" "$G3_MOCK_LOG" 2>/dev/null || echo 0; }
login test

echo "g3rm0n AI refresh tests"

# shellcheck source=/dev/null
for m in core ui panel "platform/$(case $(uname -s) in Darwin) echo darwin ;; *) echo linux ;; esac)" ai; do source "$root/lib/$m.sh"; done
g3_colors; g3_config_load
st=$AI_DIR/claude.status

# ---- how often ------------------------------------------------------------------------
check "interval: Claude waits 5 minutes by default" is "$(ai_ttl claude)" 300
check "interval: others every minute"            is "$(ai_ttl codex)" 60
CFG[claude.refresh]=900; check "interval: <provider>.refresh in the config" is "$(ai_ttl claude)" 900
CFG[claude.refresh]=10;  check "interval: never below one minute"         is "$(ai_ttl claude)" 60
CFG[claude.refresh]=abc; check "interval: a bad value falls back"         is "$(ai_ttl claude)" 300
unset 'CFG[claude.refresh]'

# ---- backoff after a rate limit ----------------------------------------------------------
check "backoff: first 429 waits 5m"               is "$(ai_backoff claude 1 '')" 300
check "backoff: doubles each time"                is "$(ai_backoff claude 2 '')" 600
check "backoff: ... again"                        is "$(ai_backoff claude 3 '')" 1200
check "backoff: capped at an hour"                is "$(ai_backoff claude 9 '')" 3600
check "backoff: a longer Retry-After wins"        is "$(ai_backoff claude 1 1800)" 1800
check "backoff: a shorter Retry-After doesn't"    is "$(ai_backoff claude 3 60)" 1200
check "backoff: Retry-After capped at 6 hours"    is "$(ai_backoff claude 1 999999)" 21600

# ---- the transport reads Retry-After -------------------------------------------------------
ai_get https://api.anthropic.com/api/oauth/usage $'Authorization: Bearer ratelimited'
check "transport: 429 seen"                       is "$AI_CODE" 429
check "transport: Retry-After read"               is "$AI_RETRY_AFTER" 1800
check "transport: body without headers"           is "${AI_BODY:0:1}" "{"
ai_get https://api.anthropic.com/api/oauth/usage $'Authorization: Bearer test'
check "transport: 200 body is plain JSON"         bash -c "jq -e .five_hour <<<\"\$1\"" _ "$AI_BODY"
check "transport: no Retry-After on success"      is "$AI_RETRY_AFTER" ""
: >"$G3_MOCK_LOG"

# ---- one call per interval, shared by every g3rm0n ------------------------------------------
ai_refresh claude
read -r code next fails <"$st"
check "refresh: success recorded"                 is "$code" 200
check "refresh: next attempt in 5 minutes"        near "$next" $(( EPOCHSECONDS + 300 ))
check "refresh: not due again yet"                not_due claude
ai_tick claude sync; ai_tick claude sync
check "refresh: repeated ticks make no new call"  is "$(calls)" 1
printf '200 1 0\n' >"$st"                       # due (any past epoch)
for _ in 1 2 3 4 5 6; do ai_refresh claude & done; wait
check "refresh: six processes at once make one call" is "$(calls)" 2
mkdir "$AI_DIR/claude.lock"; printf '200 1 0\n' >"$st"
ai_refresh claude
check "refresh: a fresh lock held elsewhere is respected" is "$(calls)" 2
touch -t 202001010000 "$AI_DIR/claude.lock"
ai_refresh claude
check "refresh: a lock left by a killed run is taken over" is "$(calls)" 3
check "refresh: the lock is released"             test ! -e "$AI_DIR/claude.lock"

# ---- rate limited: keep the numbers, wait longer, say when ------------------------------------
login ratelimited; printf '200 1 0\n' >"$st"
ai_refresh claude
read -r code next fails <"$st"
check "429: recorded"                             is "$code" 429
check "429: Retry-After 30m honoured"             near "$next" $(( EPOCHSECONDS + 1800 ))
check "429: counted"                              is "$fails" 1
check "429: last good numbers kept"               test -s "$AI_DIR/claude.row"
ai_panel claude; out=$(printf '%s\n' "${PANEL_BODY[@]}")
check "429 panel: numbers stay on screen"         contains "$out" "42%"
check "429 panel: no alarming Status row"         lacks "$out" "Status"
check "429 panel: says when it retries"           contains "$out" "retry 30m"
check "429 panel: says how old the numbers are"   bash -c "grep -qE '(<1m|[0-9]+m) ago' <<<\"\$1\"" _ "$out"
check "429 panel: every row fits the panel"       fits "${PANEL_BODY[@]}"
login ratelimited-noheader
for n in 2 3; do printf '429 1 %d\n' $(( n - 1 )) >"$st"; ai_refresh claude; done
read -r code next fails <"$st"
check "429 again: backoff grows (5m, 10m, 20m)"   near "$next" $(( EPOCHSECONDS + 1200 ))
check "429 again: counted"                        is "$fails" 3
login test; printf '429 1 3\n' >"$st"; ai_refresh claude
read -r code next fails <"$st"
check "success after 429s: back to normal"        bash -c "[[ '$code $fails' == '200 0' ]]"
rm -f "$AI_DIR/claude.row"; login ratelimited; printf '200 1 0\n' >"$st"; ai_refresh claude
ai_panel claude; out=$(printf '%s\n' "${PANEL_BODY[@]}")
check "429 with nothing cached: says so, and when" contains "$out" "rate limited · retrying in 30m"
login test

# ---- older status files (before 0.1.6) -------------------------------------------------------
printf '429\n' >"$st"
check "legacy status: a fresh 429 isn't retried"  not_due claude
touch -t 202001010000 "$st"
check "legacy status: an old one is"              ai_stale claude

# ---- a window that reset while waiting -------------------------------------------------------
printf 'pro\t13\t18000\t%d\t11\t604800\t%d\n' $(( EPOCHSECONDS - 600 )) $(( EPOCHSECONDS + 86400 )) >"$AI_DIR/claude.row"
printf '429 %d 1\n' $(( EPOCHSECONDS + 900 )) >"$st"
ai_panel claude; out=$(printf '%s\n' "${PANEL_BODY[@]}")
check "reset: the new window is estimated empty"  contains "$out" "~0%"
check "reset: and marked as new"                  contains "$out" "new window · reset 10m ago"
check "reset: headroom estimated full"            contains "$out" "~100% of 5h window"
check "reset: the weekly window keeps its value"  contains "$out" "11%"
check "reset: folded summary is marked too"       contains "$PANEL_SUM" "~0%"

# ---- fresh numbers look exactly as before ------------------------------------------------------
ai_refresh_now() { printf '200 1 0\n' >"$st"; ai_refresh claude; }
ai_refresh_now; ai_panel claude; out=$(printf '%s\n' "${PANEL_BODY[@]}")
check "fresh: plan shown, no age"                 bash -c "grep -q 'pro plan' <<<\"\$1\" && ! grep -q ' ago' <<<\"\$1\"" _ "$out"

# ---- credit panels say it in their last row ----------------------------------------------------
export OPENROUTER_API_KEY=test
ai_refresh openrouter; printf '000 %d 0\n' $(( EPOCHSECONDS + 60 )) >"$AI_DIR/openrouter.status"
ai_panel openrouter; out=$(printf '%s\n' "${PANEL_BODY[@]}")
check "credits offline: numbers kept"             contains "$out" "\$8.20 left of \$25.00"
check "credits offline: last row says so"         bash -c "tail -n1 <<<\"\$1\" | grep -q '^Status .* ago · offline'" _ "$out"
unset OPENROUTER_API_KEY

# ---- end to end: back-to-back runs share one call ------------------------------------------------
rm -rf "$XDG_CACHE_HOME"; : >"$G3_MOCK_LOG"
"$root/g3rm0n" --once -s ai-tokens >/dev/null 2>&1
"$root/g3rm0n" --once -s ai-tokens >/dev/null 2>&1
out=$("$root/g3rm0n" --once -s ai-tokens 2>&1)
check "end to end: three runs, one Claude call"   is "$(calls anthropic)" 1
check "end to end: and the panel"                 contains "$out" "AI Tokens · Claude"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
