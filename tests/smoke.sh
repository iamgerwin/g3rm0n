#!/usr/bin/env bash
# Smoke tests: run g3rm0n end to end against temporary folders and a mock curl.
# No network, no real credentials, nothing outside a temp directory is touched.
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
contains() { grep -qF -- "$2" <<<"$1"; }
lacks()    { ! grep -qF -- "$2" <<<"$1"; }

# isolated environment: fake HOME with fake logins, mock curl first on PATH
export HOME=$tmp/home XDG_CONFIG_HOME=$tmp/config XDG_CACHE_HOME=$tmp/cache
export PATH="$root/tests/mock:$PATH" COLUMNS=100
unset CLAUDE_CONFIG_DIR CODEX_HOME GLM_API_KEY ZAI_API_KEY Z_AI_API_KEY DEEPSEEK_API_KEY OPENROUTER_API_KEY NO_COLOR
mkdir -p "$HOME/.claude" "$HOME/.codex"
printf '%s' '{"claudeAiOauth":{"accessToken":"test","subscriptionType":"pro","rateLimitTier":"default_claude_pro"}}' >"$HOME/.claude/.credentials.json"
printf '%s' '{"tokens":{"access_token":"test","account_id":"00000000-0000-0000-0000-000000000000"}}' >"$HOME/.codex/auth.json"
export GLM_API_KEY=test DEEPSEEK_API_KEY=test OPENROUTER_API_KEY=test

g3="$root/g3rm0n"
echo "g3rm0n smoke tests"

check "version" bash -c "'$g3' version | grep -qx 'g3rm0n [0-9]*\.[0-9]*\.[0-9]*'"
check "help" bash -c "'$g3' help | grep -q 'g3rm0n setup'"
check "unknown option fails" bash -c "! '$g3' --nope"
check "bad interval fails" bash -c "! '$g3' -i 0"

out=$("$g3" --once 2>&1)
check "snapshot has system panels" contains "$out" "◉ CPU"
check "snapshot has memory" contains "$out" "◫ Memory"
check "piped output has no escape codes" lacks "$out" $'\e['
check "Claude panel" contains "$out" "AI Tokens · Claude"
check "Claude 5h window" contains "$out" "42%"
check "Claude plan" contains "$out" "pro plan"
check "Claude reset time parsed" bash -c "grep -qE 'resets in (1h 59m|2h 00m)' <<<\"\$1\"" _ "$out"
check "Codex panel" contains "$out" "AI Tokens · Codex"
check "Z.ai tools fallback" contains "$out" "Tools"
check "DeepSeek balance" contains "$out" "¥110.00"
check "DeepSeek reports no spend" contains "$out" "not reported by this API"
check "OpenRouter credits" contains "$out" "\$8.20 left of \$25.00"
check "OpenRouter spend" contains "$out" "\$0.42 day"

check "cache holds no tokens" bash -c "! grep -rq 'test' '$XDG_CACHE_HOME/g3rm0n/ai'/*.row"
check "cache dir is private" test "$(file_mode "$XDG_CACHE_HOME/g3rm0n/ai")" = 700

out=$("$g3" --once --no-ai 2>&1)
check "--no-ai hides AI panels" lacks "$out" "AI Tokens"

out=$("$g3" --once -s cpu,network --no-ai 2>&1)
check "--sections limits panels" bash -c "grep -q '⇅ Network' <<<\"\$1\" && ! grep -q 'Memory' <<<\"\$1\"" _ "$out"

rm -rf "$XDG_CACHE_HOME"
out=$(GLM_API_KEY=bad "$g3" --once -s ai-tokens 2>&1)
check "rejected key shows expired" contains "$out" "expired"

"$g3" setup --defaults >/dev/null 2>&1
cfg=$XDG_CONFIG_HOME/g3rm0n/config
check "setup --defaults writes config" test -f "$cfg"
check "config is mode 600" test "$(file_mode "$cfg")" = 600
check "config references, never stores" bash -c "grep -q 'zai.credentials = env:GLM_API_KEY' '$cfg' && ! grep -q '= test' '$cfg'"
check "config lists detected providers" bash -c "grep -q '^providers = claude codex zai deepseek openrouter' '$cfg'"

printf 'sections = cpu\ninterval = 3\n' >"$cfg"
out=$("$g3" --once 2>&1)
check "dashboard honours config sections" bash -c "grep -q 'CPU' <<<\"\$1\" && ! grep -q 'Memory' <<<\"\$1\"" _ "$out"
check "setup --reset removes config" bash -c "'$g3' setup --reset && [[ ! -e '$cfg' ]]"
check "setup is refused without a terminal" bash -c "! '$g3' setup </dev/null"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
