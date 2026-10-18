#!/usr/bin/env bash
# ai.sh — AI usage panels.
#
# Two kinds of provider, each with its own normalized row and panel:
#   tokens   subscription windows that reset (Claude, Codex, Z.ai)
#            row: plan \t pct1 \t window1 \t reset1_epoch \t pct2 \t window2 \t reset2_epoch
#            (window = seconds, or a literal label such as "Tools")
#   credits  prepaid balance that runs down (DeepSeek, OpenRouter)
#            row: currency \t left \t total \t spent_day \t spent_week \t spent_month \t label \t detail
#            ("-" = not reported by that API)
#
# Credentials are referenced, never copied: a provider's credential is either
# "file:<path>" (the login its own CLI keeps) or "env:<VARIABLE>" (an API key already
# exported in your shell). g3rm0n reads it at request time, sends it only to that
# provider's own endpoint, and caches nothing but the usage numbers.
#
# Adding a provider: entries in AI_NAME/AI_KIND (+ AI_ENV or ai_default_file), then
# ai_fetch_<id> (sets AI_CODE and AI_ROW) and ai_hint_<id>.

AI_TTL=60            # default seconds between API calls per provider; frames redraw from the cache
AI_BACKOFF_MAX=3600  # longest wait after repeated rate limits (a Retry-After may ask for more)
# Providers whose usage endpoint is strict get a longer default. Claude's limits move
# slowly (5-hour and weekly windows), and its endpoint rate-limits frequent callers.
declare -gA AI_REFRESH=([claude]=300)
AI_DIR="$G3_CACHE_DIR/ai"

declare -gA AI_NAME=([claude]="Claude" [codex]="Codex" [zai]="Z.ai" [deepseek]="DeepSeek" [openrouter]="OpenRouter")
declare -gA AI_KIND=([claude]=tokens [codex]=tokens [zai]=tokens [deepseek]=credits [openrouter]=credits)
declare -gA AI_ENV=([zai]="GLM_API_KEY ZAI_API_KEY Z_AI_API_KEY" [deepseek]="DEEPSEEK_API_KEY" [openrouter]="OPENROUTER_API_KEY")
# where a CLI keeps its login in the OS credential store instead of a file (macOS)
declare -gA AI_KEYCHAIN=([claude]="Claude Code-credentials")
declare -gA AI_PID=()

ai_default_file() {
  case $1 in
    claude) printf '%s' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json" ;;
    codex)  printf '%s' "${CODEX_HOME:-$HOME/.codex}/auth.json" ;;
  esac
}

ai_detect() { # id -> "file:<path>" / "keychain:<service>" / "env:<VAR>" found here, or nothing
  local v f
  f=$(ai_default_file "$1")
  if [[ -n $f ]]; then
    if [[ -r $f ]]; then printf 'file:%s' "$f"
    elif [[ -n ${AI_KEYCHAIN[$1]:-} ]] && plat_keychain_has "${AI_KEYCHAIN[$1]}"; then
      printf 'keychain:%s' "${AI_KEYCHAIN[$1]}"
    fi
    return 0
  fi
  for v in ${AI_ENV[$1]}; do
    [[ -n ${!v:-} ]] && { printf 'env:%s' "$v"; return 0; }
  done
  return 0
}

ai_ref() { # id -> configured reference, falling back to detection
  local r=${CFG[$1.credentials]:-}
  if [[ -n $r ]]; then printf '%s' "$r"; else ai_detect "$1"; fi
}

ai_ref_ready() { # reference -> true when it can be used right now
  case $1 in
    file:*) [[ -r $(g3_expand "${1#file:}") ]] ;;
    keychain:*) plat_keychain_has "${1#keychain:}" ;;
    env:*)  local v=${1#env:}; [[ $v =~ ^[A-Za-z_][A-Za-z0-9_]*$ && -n ${!v:-} ]] ;;
    *) return 1 ;;
  esac
}

ai_providers() { # -> ids to show, in display order (subscriptions first)
  [[ ${G3_NO_AI:-0} == 1 ]] && return 0
  have curl && have jq || return 0
  local id want=${CFG[providers]:-auto}
  for id in "${G3_PROVIDERS[@]}"; do
    [[ $want == auto ]] || g3_has "$want" "$id" || continue
    g3_section_on "ai-${AI_KIND[$id]}" || continue
    ai_ref_ready "$(ai_ref "$id")" && printf '%s\n' "$id"
  done
  return 0
}

ai_secret() { # id jq-path -> secret from the provider's referenced credential
  local ref; ref=$(ai_ref "$1")
  case $ref in
    file:*) jq -r "$2 // empty" "$(g3_expand "${ref#file:}")" 2>/dev/null ;;
    keychain:*) plat_keychain_read "${ref#keychain:}" | jq -r "$2 // empty" 2>/dev/null ;;
    env:*)  local v=${ref#env:}; printf '%s' "${!v:-}" ;;
  esac
}

# ---- transport ---------------------------------------------------------------

ai_get() { # url header-lines -> AI_BODY AI_CODE AI_RETRY_AFTER
  # request headers travel on stdin so tokens never appear in the process list;
  # response headers come first (-D -) so a 429's Retry-After can be honoured
  local out hdr re=$'(^|\n)[Rr][Ee][Tt][Rr][Yy]-[Aa][Ff][Tt][Ee][Rr]:[[:space:]]*([0-9]+)'
  out=$(curl -s -m 6 -D - -w '\n%{http_code}' -H @- "$1" <<<"$2")
  AI_CODE=${out##*$'\n'} out=${out%$'\n'*}
  [[ $AI_CODE =~ ^[0-9]+$ ]] || AI_CODE=000
  hdr=${out%%$'\r\n\r\n'*}
  if [[ $hdr != "$out" ]]; then AI_BODY=${out#*$'\r\n\r\n'}; else AI_BODY=$out hdr=""; fi
  AI_RETRY_AFTER=""
  [[ $hdr =~ $re ]] && AI_RETRY_AFTER=${BASH_REMATCH[2]}
  return 0
}

# ISO 8601 ("2026-10-18T17:00:00.123+00:00", "...Z") -> epoch seconds, in jq so it
# behaves the same with GNU and BSD date. null or unparsable -> 0.
# shellcheck disable=SC2016  # jq program: $m is a jq variable
AI_JQ_EPOCH='def epoch: if type != "string" then 0 else
  (capture("^(?<d>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(\\.[0-9]+)?(?<z>Z|[+-][0-9]{2}:?[0-9]{2})?$")
   // null) as $m | if $m == null then 0 else
  (($m.d + "Z") | fromdateiso8601) - (if ($m.z // "Z") == "Z" then 0 else
    (($m.z[1:3] | tonumber) * 3600 + ($m.z[-2:] | tonumber) * 60) * (if $m.z[0:1] == "-" then -1 else 1 end) end)
  end end;'

# ---- subscription providers --------------------------------------------------

ai_fetch_claude() {
  local tok plan p1 r1 p2 r2
  tok=$(ai_secret claude '.claudeAiOauth.accessToken')
  [[ -n $tok ]] || { AI_CODE=nologin; return; }
  ai_get https://api.anthropic.com/api/oauth/usage \
    "Authorization: Bearer $tok"$'\n'"anthropic-beta: oauth-2025-04-20"
  [[ $AI_CODE == 200 ]] || return
  plan=$(ai_secret claude '.claudeAiOauth.rateLimitTier // .claudeAiOauth.subscriptionType')
  plan=${plan#default_}; plan=${plan#claude_}; plan=${plan//_/ }
  IFS=$'\t' read -r p1 r1 p2 r2 < <(jq -r "$AI_JQ_EPOCH"' [(.five_hour.utilization // 0), (.five_hour.resets_at | epoch),
      (.seven_day.utilization // 0), (.seven_day.resets_at | epoch)] | @tsv' <<<"$AI_BODY" 2>/dev/null)
  [[ -n $p1 ]] || { AI_CODE=bad; return; }
  printf -v AI_ROW '%s\t%s\t%s\t%s\t%s\t%s\t%s' "${plan:-?}" "$p1" 18000 "$r1" "$p2" 604800 "$r2"
}
ai_hint_claude() { printf 'run claude to sign in again'; }

ai_fetch_codex() {
  local tok acc
  tok=$(ai_secret codex '.tokens.access_token')
  acc=$(ai_secret codex '.tokens.account_id')
  [[ -n $tok ]] || { AI_CODE=nologin; return; }
  ai_get https://chatgpt.com/backend-api/wham/usage \
    "Authorization: Bearer $tok"$'\n'"User-Agent: codex-cli${acc:+$'\n'ChatGPT-Account-Id: $acc}"
  [[ $AI_CODE == 200 ]] || return
  AI_ROW=$(jq -r '.rate_limit as $r | [(.plan_type // "?"),
      ($r.primary_window.used_percent // 0), ($r.primary_window.limit_window_seconds // 18000),
      ($r.primary_window.reset_at // 0),
      ($r.secondary_window.used_percent // 0), ($r.secondary_window.limit_window_seconds // 604800),
      ($r.secondary_window.reset_at // 0)] | @tsv' <<<"$AI_BODY" 2>/dev/null)
  [[ -n $AI_ROW ]] || AI_CODE=bad
}
ai_hint_codex() { printf 'run codex login'; }

# Z.ai answers errors with HTTP 200 and the real code in the body. Limit units:
# 3 = 5h tokens, 6 = weekly tokens, 5 = monthly tool calls (shown when no weekly cap).
ai_fetch_zai() {
  local key; key=$(ai_secret zai)
  [[ -n $key ]] || { AI_CODE=nologin; return; }
  ai_get https://api.z.ai/api/monitor/usage/quota/limit "Authorization: Bearer $key"
  [[ $AI_CODE == 200 ]] || return
  AI_CODE=$(jq -r '.code // 200' <<<"$AI_BODY" 2>/dev/null)
  [[ $AI_CODE == 200 ]] || return
  AI_ROW=$(jq -r '.data as $d | def lim($u): ($d.limits // [] | map(select(.unit == $u)) | first);
      lim(3) as $h | (lim(6) // lim(5)) as $w |
      [($d.level // "?"),
       ($h.percentage // 0), 18000, (($h.nextResetTime // 0) / 1000 | floor),
       ($w.percentage // 0), (if $w.unit == 6 then 604800 else "Tools" end),
       (($w.nextResetTime // 0) / 1000 | floor)] | @tsv' <<<"$AI_BODY" 2>/dev/null)
  [[ -n $AI_ROW ]] || AI_CODE=bad
}
ai_hint_zai() { printf 'check %s' "$(ai_ref zai | sed 's/^env://')"; }

# ---- credit providers --------------------------------------------------------

# DeepSeek reports a balance only (no spend history): topped-up vs granted split.
ai_fetch_deepseek() {
  local key; key=$(ai_secret deepseek)
  [[ -n $key ]] || { AI_CODE=nologin; return; }
  ai_get https://api.deepseek.com/user/balance "Authorization: Bearer $key"$'\n'"Accept: application/json"
  [[ $AI_CODE == 200 ]] || return
  AI_ROW=$(jq -r '(.balance_infos // [] | (map(select(.currency == "USD")) + .) | first) as $b
      | select($b != null)
      | ({"USD": "$", "CNY": "¥"}[$b.currency] // "") as $s
      | [$b.currency, $b.total_balance, "-", "-", "-", "-", "Split",
         ("topped up \($s)\($b.topped_up_balance) · granted \($s)\($b.granted_balance)"
          + (if .is_available == false then " · paused" else "" end))] | @tsv' <<<"$AI_BODY" 2>/dev/null)
  [[ -n $AI_ROW ]] || AI_CODE=bad
}
ai_hint_deepseek() { printf 'check %s' "$(ai_ref deepseek | sed 's/^env://')"; }

# OpenRouter: account credits from /credits, spend windows and key cap from /key.
ai_fetch_openrouter() {
  local key key_body credits='{}'
  key=$(ai_secret openrouter)
  [[ -n $key ]] || { AI_CODE=nologin; return; }
  ai_get https://openrouter.ai/api/v1/key "Authorization: Bearer $key"
  [[ $AI_CODE == 200 ]] || return
  key_body=$AI_BODY
  ai_get https://openrouter.ai/api/v1/credits "Authorization: Bearer $key"
  [[ $AI_CODE == 200 ]] && credits=$AI_BODY   # optional: falls back to the key's own limit
  AI_CODE=200
  AI_ROW=$(jq -rn --argjson k "$key_body" --argjson c "$credits" '
      ($k.data // {}) as $d | ($c.data // {}) as $a
      | (if $a.total_credits != null then [($a.total_credits - ($a.total_usage // 0)), $a.total_credits]
         elif $d.limit_remaining != null then [$d.limit_remaining, $d.limit]
         else ["-", "-"] end) as $bal
      | ["USD", $bal[0], $bal[1],
         ($d.usage_daily // "-"), ($d.usage_weekly // "-"), ($d.usage_monthly // "-"), "Key",
         ((if $d.limit == null then "no spend cap" else "cap $\($d.limit)" end)
          + (if $d.is_free_tier then " · free tier" else "" end))] | @tsv' 2>/dev/null)
  [[ -n $AI_ROW ]] || AI_CODE=bad
}
ai_hint_openrouter() { printf 'check %s' "$(ai_ref openrouter | sed 's/^env://')"; }

# ---- cache + background refresh ----------------------------------------------

ai_ttl() { # id -> seconds between calls: config <id>.refresh, else AI_REFRESH, else AI_TTL (60 at least)
  local v=${CFG[$1.refresh]:-}
  [[ $v =~ ^[0-9]+$ ]] || v=${AI_REFRESH[$1]:-$AI_TTL}   # unset or not a number: the default
  (( v < 60 )) && v=60
  printf '%d' "$v"
}

# AI_DIR/<id>.status holds "code next-attempt-epoch consecutive-429s". It is shared by
# every running g3rm0n, so they all wait for the same next attempt.
ai_stale() { # id -> true when the provider may be called again
  local f=$AI_DIR/$1.status t code="" next="" ttl
  [[ -e $f ]] || return 0
  read -r code next _ <"$f" 2>/dev/null
  if [[ $next =~ ^[0-9]+$ ]] && (( next > 0 )); then (( EPOCHSECONDS >= next )); return; fi
  # a status file from before 0.1.6 holds only the code
  ttl=$(ai_ttl "$1"); [[ $code == 429 ]] && ttl=$(( ttl * 5 ))
  t=$(plat_mtime "$f"); t=${t:-0}
  (( EPOCHSECONDS - t >= ttl ))
}

ai_backoff() { # id consecutive-429s retry-after -> seconds to wait after a rate limit
  local ttl base wait n=$2
  ttl=$(ai_ttl "$1"); base=$(( ttl > 300 ? ttl : 300 ))
  wait=$base
  while (( n > 1 && wait < AI_BACKOFF_MAX )); do wait=$(( wait * 2 )); n=$(( n - 1 )); done
  (( wait > AI_BACKOFF_MAX )) && wait=$AI_BACKOFF_MAX
  # the server's own Retry-After wins when it asks for longer (capped at 6 hours)
  if [[ $3 =~ ^[0-9]+$ ]] && (( $3 > wait )); then wait=$(( $3 < 21600 ? $3 : 21600 )); fi
  printf '%d' "$wait"
}

ai_refresh() { # id -> AI_DIR/<id>.row (only on success) and AI_DIR/<id>.status
  local id=$1 AI_CODE="" AI_BODY="" AI_ROW="" AI_RETRY_AFTER="" lock t
  local pcode="" pnext="" pfails="" fails=0 next
  mkdir -p "$AI_DIR" && chmod 700 "$AI_DIR"
  # one refresh per provider at a time, across every running g3rm0n
  lock=$AI_DIR/$id.lock
  if ! mkdir "$lock" 2>/dev/null; then
    t=$(plat_mtime "$lock"); (( EPOCHSECONDS - ${t:-0} < 60 )) && return 0
    rm -rf "$lock"; mkdir "$lock" 2>/dev/null || return 0   # a lock left by a killed run
  fi
  if ! ai_stale "$id"; then rmdir "$lock" 2>/dev/null; return 0; fi   # someone just did it
  "ai_fetch_$id"
  [[ -r $AI_DIR/$id.status ]] && read -r pcode pnext pfails <"$AI_DIR/$id.status"
  if [[ $AI_CODE == 429 ]]; then
    [[ $pcode == 429 && $pfails =~ ^[0-9]+$ ]] && fails=$pfails
    fails=$(( fails + 1 ))
    next=$(( EPOCHSECONDS + $(ai_backoff "$id" "$fails" "$AI_RETRY_AFTER") ))
  else
    next=$(( EPOCHSECONDS + $(ai_ttl "$id") ))
  fi
  [[ $AI_CODE == 200 && -n $AI_ROW ]] && printf '%s\n' "$AI_ROW" >"$AI_DIR/$id.row"
  printf '%s %s %s\n' "$AI_CODE" "$next" "$fails" >"$AI_DIR/$id.status.$$" && mv -f "$AI_DIR/$id.status.$$" "$AI_DIR/$id.status"
  rmdir "$lock" 2>/dev/null
  return 0
}

ai_tick() { # id [sync] -> start a refresh when due; never blocks a live frame
  ai_stale "$1" || return 0
  if [[ ${2:-} == sync ]]; then ai_refresh "$1"; return; fi
  local pid=${AI_PID[$1]:-}
  [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null && return 0
  ai_refresh "$1" &
  AI_PID[$1]=$!
}

# ---- panels --------------------------------------------------------------------

ai_win_label() { # seconds -> "5h" / "Week" / "30d"; a non-number is already a label
  local s=$1
  [[ $s =~ ^[0-9]+$ ]] || { printf '%s' "$s"; return; }
  if (( s == 604800 )); then printf 'Week'
  elif (( s % 86400 == 0 )); then printf '%dd' $(( s / 86400 ))
  else printf '%dh' $(( s / 3600 )); fi
}

ai_money() { # currency amount -> "$8.20" / "¥12.34" / "12.34 EUR"; "-" passes through
  [[ -z $2 || $2 == - ]] && { printf -- '-'; return; }
  local n; printf -v n '%.2f' "$2" 2>/dev/null || n=$2
  case $1 in USD) printf '$%s' "$n" ;; CNY) printf '¥%s' "$n" ;; *) printf '%s %s' "$n" "$1" ;; esac
}

ai_window_row() { # pct window reset_epoch
  local note="window idle" pct=$1
  if (( $3 > 0 && $3 <= EPOCHSECONDS )); then
    # the cached window has reset since it was read: a new one starts empty (an
    # estimate, marked "~", until the next successful refresh)
    pct="~0" note="new window · reset $(g3_ago $(( EPOCHSECONDS - $3 ))) ago"
  elif (( $3 > 0 )); then
    note="resets in $(g3_duration $(( $3 - EPOCHSECONDS )))"
  fi
  printf '%s%s %s %s' "$(ui_label "$(ai_win_label "$2")")" "$(ui_bar "${pct#\~}" 10)" "$(ui_pct "$pct")" "${c_dim}· ${note}${c_off}"
}

ai_title() { # id -> "AI Tokens · Claude" / "AI Credits · OpenRouter"
  if [[ ${AI_KIND[$1]} == credits ]]; then printf 'AI Credits · %s' "${AI_NAME[$1]}"
  else printf 'AI Tokens · %s' "${AI_NAME[$1]}"; fi
}
ai_icon() { if [[ ${AI_KIND[$1]} == credits ]]; then printf '◆'; else printf '✦'; fi; }

# ai_panel id -> PANEL_BODY + PANEL_SUM in the standard layout for its kind.
# Cached numbers always stay on screen. When they aren't fresh, the panel says how
# old they are and when the next attempt is ("12m ago · retry 4m"), instead of
# hiding them behind an error; a Status row appears only when there is nothing to
# show yet, or when the user has to act (login expired or missing).
ai_panel() {
  local id=$1 kind=${AI_KIND[$1]} code="" next="" what="Login" bad="expired" note="" age wait
  [[ $kind == credits ]] && { what="Key"; bad="rejected"; }
  PANEL_BODY=() PANEL_SUM=""
  [[ -r $AI_DIR/$id.status ]] && read -r code next _ <"$AI_DIR/$id.status"
  [[ $next =~ ^[0-9]+$ ]] || next=0
  wait=$(( next > EPOCHSECONDS ? next - EPOCHSECONDS : 0 ))
  case $code in
    401|403) PANEL_BODY+=("$(ui_label "$what")${c_yellow}${bad}${c_off} ${c_dim}· $("ai_hint_$id")${c_off}")
             PANEL_SUM="${c_yellow}${what,,} ${bad}${c_off}" ;;
    nologin) PANEL_BODY+=("$(ui_label "$what")${c_dim}missing · $("ai_hint_$id")${c_off}")
             PANEL_SUM="${what,,} missing" ;;
  esac
  if [[ ! -r $AI_DIR/$id.row ]]; then
    case $code in
      000) PANEL_BODY+=("$(ui_label Status)${c_dim}offline · retrying${c_off}"); PANEL_SUM="offline" ;;
      429) PANEL_BODY+=("$(ui_label Status)${c_yellow}rate limited${c_off} ${c_dim}· retrying in $(g3_ago "$wait")${c_off}")
           PANEL_SUM="${c_yellow}rate limited${c_off}" ;;
      401|403|nologin) ;;
      *) PANEL_BODY+=("${c_dim}fetching usage…${c_off}"); PANEL_SUM="fetching…" ;;
    esac
    return
  fi
  age=$(plat_mtime "$AI_DIR/$id.row"); age=$(( EPOCHSECONDS - ${age:-$EPOCHSECONDS} ))
  if [[ $code != 200 ]] || (( age > 2 * $(ai_ttl "$id") )); then
    note="${c_dim}· $(g3_ago "$age") ago${c_off}"
    case $code in
      429) note+=" ${c_dim}·${c_off} ${c_yellow}retry $(g3_ago "$wait")${c_off}" ;;
      000) note+=" ${c_dim}· offline${c_off}" ;;
    esac
  fi
  "ai_body_$kind" "$id"
}

ai_body_tokens() { # appends to PANEL_BODY: both windows, then headroom in the short one
  local plan p1 w1 r1 p2 w2 r2 left est=""
  IFS=$'\t' read -r plan p1 w1 r1 p2 w2 r2 <"$AI_DIR/$1.row"
  PANEL_BODY+=("$(ai_window_row "$p1" "$w1" "$r1")")
  PANEL_BODY+=("$(ai_window_row "$p2" "$w2" "$r2")")
  # a window that has reset since the last read starts over (estimate until refreshed)
  (( r1 > 0 && r1 <= EPOCHSECONDS )) && { p1=0; est="~"; }
  (( r2 > 0 && r2 <= EPOCHSECONDS )) && p2=0
  left=$(( 100 - ${p1%.*} )); (( left < 0 )) && left=0
  PANEL_BODY+=("$(ui_label Left)${c_bold}${est}${left}%${c_off} of $(ai_win_label "$w1") window ${note:-${c_dim}· ${plan} plan${c_off}}")
  local l2; l2=$(ai_win_label "$w2"); [[ $l2 == Week ]] && l2=wk
  [[ -n $PANEL_SUM ]] || PANEL_SUM="$(ai_win_label "$w1") $(ui_tone "${p1%.*}")${est}${p1%.*}%${c_off} · ${l2,,} ${p2%.*}%"
}

ai_body_credits() { # appends to PANEL_BODY: balance, spend, provider detail
  local cur left total day week month label detail pct
  IFS=$'\t' read -r cur left total day week month label detail <"$AI_DIR/$1.row"
  if [[ $total != - && $left != - ]] && awk -v t="$total" 'BEGIN { exit !(t > 0) }'; then
    pct=$(awk -v l="$left" -v t="$total" 'BEGIN { p = (t - l) * 100 / t; if (p < 0) p = 0; printf "%d", p }')
    PANEL_BODY+=("$(ui_label Spent)$(ui_bar "$pct" 10) $(ui_pct "$pct") ${c_dim}·${c_off} ${c_bold}$(ai_money "$cur" "$left")${c_off}${c_dim} left of $(ai_money "$cur" "$total")${c_off}")
  else
    PANEL_BODY+=("$(ui_label Left)${c_bold}$(ai_money "$cur" "$left")${c_off} ${c_dim}· prepaid balance${c_off}")
  fi
  if [[ $day == - && $week == - && $month == - ]]; then
    PANEL_BODY+=("$(ui_label Usage)${c_dim}not reported by this API${c_off}")
  else
    PANEL_BODY+=("$(ui_label Usage)$(ai_money "$cur" "$day") ${c_dim}day ·${c_off} $(ai_money "$cur" "$week") ${c_dim}wk ·${c_off} $(ai_money "$cur" "$month") ${c_dim}mo${c_off}")
  fi
  # numbers that aren't fresh say so in the last row ("Status 12m ago · retry 4m"),
  # which keeps every row inside the panel width
  if [[ -n $note ]]; then PANEL_BODY+=("$(ui_label Status)${note/#${c_dim}· /${c_dim}}")
  else PANEL_BODY+=("$(ui_label "$label")${c_dim}${detail}${c_off}"); fi
  [[ -n $PANEL_SUM ]] || PANEL_SUM="$(ai_money "$cur" "$left") left"
}
