#!/usr/bin/env bash
# Platform tests: every backend in lib/platform/ against the same contract.
#   1. contract: each backend defines every function in SYS_CONTRACT, and g3rm0n
#      refuses to start with an incomplete one
#   2. macOS backend on recorded macOS output (tests/mock/darwin), on any machine
#   3. the native backend of the machine running the tests, with the same checks on
#      Linux and macOS, so every implementation is held to the same features
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
matches()  { grep -qE -- "$2" <<<"$1"; }

export HOME=$tmp/home XDG_CONFIG_HOME=$tmp/config XDG_CACHE_HOME=$tmp/cache XDG_STATE_HOME=$tmp/state
export NO_COLOR=1 COLUMNS=100
mkdir -p "$HOME"
case $(uname -s) in Darwin) native=darwin ;; *) native=linux ;; esac

echo "g3rm0n platform tests (native: $native)"

# ---- 1. the contract -------------------------------------------------------------
for b in "$root"/lib/platform/*.sh; do
  name=${b##*/}; name=${name%.sh}
  missing=$(bash -c 'G3_PLATFORM=$1; for m in core ui; do source "$2/lib/$m.sh"; done
                     source "$3"; source "$2/lib/system.sh"; sys_contract_missing' _ "$name" "$root" "$b")
  check "contract: $name backend defines every plat_ function" test -z "$missing"
done
mkdir -p "$tmp/broken"
cp -R "$root/g3rm0n" "$root/lib" "$tmp/broken/"
sed -i.bak '/^plat_gpu()/,/^}/d' "$tmp/broken/lib/platform/$native.sh"
out=$("$tmp/broken/g3rm0n" --once --no-ai 2>&1)
check "contract: an incomplete backend is refused by name" contains "$out" "missing: plat_gpu"

# ---- portable code: what breaks on one platform only, caught on every platform -------
code=("$root/g3rm0n" "$root/install.sh" "$root"/lib/*.sh "$root"/lib/platform/*.sh "$root/completions/g3rm0n.bash")
shared=("$root/g3rm0n" "$root/install.sh" "$root"/lib/*.sh "$root/completions/g3rm0n.bash")
# macOS's libc counts UTF-8 lead bytes as identifier characters: "$c_dim·" breaks there
out=$(LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~[:space:]]' "${code[@]}")
check "portable: no \$name directly followed by a non-ASCII character" test -z "$out"
# GNU-only or BSD-only flags belong in a backend, never in shared code
# (comments, and the /proc/$PPID/comm probe that falls back to ps, are fine)
# shellcheck disable=SC2016  # a literal $PPID in the pattern
out=$(grep -nE '(date -d|date -j|stat -c|stat -f|readlink -f|sed -i|df -B|--output=|--sort=|nproc|/proc/|/sys/)' "${shared[@]}" \
      | grep -vE '^\S+:[0-9]+:\s*#|/proc/\$PPID/comm' )
check "portable: no OS-specific commands in shared code" test -z "$out"

# ---- 2. the macOS backend on recorded macOS output ---------------------------------
out=$(PATH="$root/tests/mock/darwin:$PATH" G3_PLATFORM=darwin "$root/g3rm0n" --once --no-ai 2>&1)
check "darwin: OS name"                  contains "$out" "macOS 15.1"
check "darwin: CPU usage from iostat"    matches  "$out" "Usage .* 23%"
check "darwin: core layout"              contains "$out" "8 performance · 4 efficiency"
check "darwin: load and threads"         contains "$out" "2.15 · 1.98 · 1.87 · 12 threads"
check "darwin: CPU model"                contains "$out" "Apple M2 Pro"
check "darwin: memory like Activity Monitor" matches "$out" "Used .* 51% 8.2G/16.0G"
check "darwin: swap"                     matches  "$out" "Swap .* 50% 1.0G/2.0G"
check "darwin: file cache"               contains "$out" "4.1G buffers & page cache"
check "darwin: system volume"            matches  "$out" "^/ .* 4% 9.7G/460.4G apfs"
check "darwin: data volume shown as ~"   matches  "$out" "^~ .* 35% 152.5G/460.4G apfs"
check "darwin: disk throughput"          matches  "$out" "read [1-9][0-9.]*[KM]/s"
check "darwin: battery"                  contains "$out" "81% · discharging"
check "darwin: Apple GPU"                matches  "$out" "GPU .* 18%"
check "darwin: no root-only sensors"     contains "$out" "no sensors exposed"
check "darwin: uptime"                   contains "$out" "Uptime 3d 4h"
check "darwin: tasks"                    contains "$out" "8 total · 2 running"
check "darwin: busiest process"          matches  "$out" "1 +firefox"
check "darwin: names with spaces"        contains "$out" "Google Chrome He"
check "darwin: ps never lists itself"    bash -c "! grep -qE '^[0-9] +ps ' <<<\"\$1\"" _ "$out"
check "darwin: network rate"             matches  "$out" "Down .*[1-9][0-9.]*[KM]/s"
check "darwin: link"                     contains "$out" "en0 · 192.168.1.24"
check "darwin: VPN, not macOS's own tunnels" contains "$out" "VPN    utun4 · 100.101.1.7"
out=$(PATH="$root/tests/mock/darwin:$PATH" G3_PLATFORM=darwin "$root/g3rm0n" --once --no-ai --fold all 2>&1)
check "darwin: folded summaries"         contains "$out" "▸ ◫ Memory · 51% · 8.2G/16.0G"
check "darwin: CPU measurement cleaned up" bash -c "! ls '$XDG_CACHE_HOME'/g3rm0n/cpu.* 2>/dev/null"

# ---- 2b. macOS Keychain logins (Claude Code keeps its login there on a Mac) -------------
k=$tmp/kc; mkdir -p "$k/home"
kc() { PATH="$root/tests/mock/darwin:$root/tests/mock:$PATH" G3_PLATFORM=darwin HOME=$k/home \
       XDG_CACHE_HOME=$k/cache XDG_CONFIG_HOME=$k/config "$@"; }
out=$(kc "$root/g3rm0n" --once -s ai-tokens 2>&1)
check "darwin keychain: Claude found in the Keychain"   contains "$out" "AI Tokens · Claude"
check "darwin keychain: usage read with that login"     contains "$out" "max 5x plan"
out=$(kc "$root/g3rm0n" setup --show 2>&1)
check "darwin keychain: setup says where it was found"  contains "$out" "found · macOS Keychain"
kc "$root/g3rm0n" setup --defaults >/dev/null 2>&1
check "darwin keychain: config references, never stores" bash -c "grep -qx 'claude.credentials = keychain:Claude Code-credentials' '$k/config/g3rm0n/config' && ! grep -q accessToken '$k/config/g3rm0n/config' && ! grep -rq test '$k/cache/g3rm0n/ai'"
rm -rf "$k/cache" "$k/config"
out=$(G3_MOCK_KEYCHAIN=empty kc "$root/g3rm0n" --once -s ai-tokens 2>&1)
check "darwin keychain: no panel without a login"       lacks "$out" "AI Tokens · Claude"
mkdir -p "$k/home/.claude"; printf '%s' '{"claudeAiOauth":{"accessToken":"test","subscriptionType":"pro"}}' >"$k/home/.claude/.credentials.json"
out=$(kc "$root/g3rm0n" setup --show 2>&1)
check "darwin keychain: a login file still comes first" contains "$out" "found · ~/.claude/.credentials.json"

# ---- 2c. parity: both backends, the same layout and the same features -----------------
for b in darwin native; do
  if [[ $b == darwin ]]; then
    out=$(PATH="$root/tests/mock/darwin:$PATH" G3_PLATFORM=darwin COLUMNS=100 "$root/g3rm0n" --once --no-ai 2>&1)
  else
    out=$(COLUMNS=100 "$root/g3rm0n" --once --no-ai 2>&1); b=$native
  fi
  check "parity ($b): two columns at 100 columns" bash -c "grep -q '◉ CPU.*◫ Memory' <<<\"\$1\"" _ "$out"
  check "parity ($b): all six system panels"      bash -c "for p in '◉ CPU' '◫ Memory' '▤ Disk' '◪ Power' '≡ Processes' '⇅ Network'; do grep -qF \"\$p\" <<<\"\$1\" || exit 1; done" _ "$out"
  if [[ $b == darwin ]]; then
    out=$(PATH="$root/tests/mock/darwin:$PATH" G3_PLATFORM=darwin "$root/g3rm0n" --once --no-ai --fold all 2>&1)
  else
    out=$("$root/g3rm0n" --once --no-ai --fold all 2>&1)
  fi
  check "parity ($b): every folded title has a summary" bash -c "(( \$(grep -oE '▸ [^ ]+ [A-Za-z]+ · ' <<<\"\$1\" | wc -l) == 6 ))" _ "$out"
  label=$(grep -oE '▸ ▤ Disk · [^ ]+' <<<"$out"); label=${label##* }
  check "parity ($b): the Disk summary names a volume it shows" test -n "$label"
done

# ---- 2d. numbers don't depend on the locale ----------------------------------------------
loc=$(locale -a 2>/dev/null | grep -iE '^(de_DE|fr_FR|nl_NL|pt_BR)\.(utf-?8)$' | head -n1)
if [[ -n $loc ]]; then
  lc() { LC_ALL=$loc PATH="$root/tests/mock:$PATH" HOME=$k/home XDG_CACHE_HOME=$tmp/lc OPENROUTER_API_KEY=test "$@"; }
  out=$(lc "$root/g3rm0n" --once -s ai-credits,network 2>&1)
  check "locale $loc: money uses . and two decimals"  contains "$out" "\$8.20 left of \$25.00"
  check "locale $loc: spend rows too"                 contains "$out" "\$3.10 wk"
  check "locale $loc: rates still measured"           bash -c "grep -qE 'Down .*[0-9][BKMG]?/s' <<<\"\$1\"" _ "$out"
  check "locale $loc: no shell errors"                bash -c "! grep -qiE 'invalid number|syntax error|bad substitution' <<<\"\$1\"" _ "$out"
  out=$(LC_ALL=$loc PATH="$root/tests/mock/darwin:$PATH" G3_PLATFORM=darwin "$root/g3rm0n" --once --no-ai 2>&1)
  check "locale $loc: macOS backend parses its tools"  bash -c "grep -q 'Used .* 51% 8.2G/16.0G' <<<\"\$1\" && ! grep -qi 'invalid' <<<\"\$1\"" _ "$out"
else
  printf '  skip  locale checks: no comma-decimal locale installed\n'
fi

# ---- 3. the native backend, same checks everywhere -----------------------------------
out=$("$root/g3rm0n" --once --no-ai 2>&1)
check "$native: header names the OS"     matches  "$out" "^g3rm0n .*· (macOS|[A-Za-z])"
check "$native: CPU usage is a percent"  matches  "$out" "^Usage .* +([0-9]|[1-9][0-9]|100)%"
check "$native: cores row"               matches  "$out" "^Cores +[^ ]"
check "$native: load average"            matches  "$out" "^Load +[0-9.]+ · [0-9.]+ · [0-9.]+ · [0-9]+ threads"
check "$native: memory total"            matches  "$out" "Used +.*%.*/[1-9][0-9.]*[MGT]"
check "$native: root volume"             matches  "$out" "^/ +.*%"
check "$native: disk throughput row"     matches  "$out" "^I/O +read .*/s · write .*/s"
check "$native: battery row"             matches  "$out" "Batt +"
check "$native: uptime"                  matches  "$out" "Uptime [0-9]+(d|h|m)"
check "$native: tasks"                   matches  "$out" "Tasks +[1-9][0-9]* total · [0-9]+ running"
check "$native: three busiest processes" bash -c "(( \$(grep -cE '^[123] +[^ ]' <<<\"\$1\") == 3 ))" _ "$out"
check "$native: network rows"            matches  "$out" "Down .*/s"
check "$native: link row"                matches  "$out" "Link +[^ ]"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
