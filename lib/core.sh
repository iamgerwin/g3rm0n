#!/usr/bin/env bash
# core.sh — version, paths, colors, config and small shared helpers

G3_VERSION="0.1.7"
G3_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/g3rm0n"
G3_CONFIG_FILE="$G3_CONFIG_DIR/config"
G3_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/g3rm0n"
G3_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/g3rm0n"

G3_SECTIONS=(cpu memory disk power processes network ai-tokens ai-credits)
G3_HEADER="logo health host os date time"   # header components, in order (lib/header.sh)
G3_PROVIDERS=(claude codex zai deepseek openrouter)

declare -gA G3_SECTION_LABEL=(
  [cpu]="CPU" [memory]="Memory" [disk]="Disk" [power]="Power & thermals"
  [processes]="Processes" [network]="Network"
  [ai-tokens]="AI Tokens" [ai-credits]="AI Credits"
)
declare -gA G3_SECTION_NOTE=(
  [cpu]="usage, per-core activity, load"
  [memory]="RAM, swap, cache"
  [disk]="space on / and \$HOME, read/write rates"
  [power]="battery, GPU, temperature, uptime"
  [processes]="busiest processes"
  [network]="throughput, interface, VPN"
  [ai-tokens]="subscription limits: Claude, Codex, Z.ai"
  [ai-credits]="prepaid API balance: DeepSeek, OpenRouter"
)

g3_colors() {
  if [[ -t 1 && -z ${NO_COLOR:-} && ${G3_NO_COLOR:-0} != 1 ]]; then
    c_off=$'\e[0m' c_bold=$'\e[1m' c_dim=$'\e[2m'
    c_red=$'\e[31m' c_green=$'\e[32m' c_yellow=$'\e[33m'
    c_blue=$'\e[34m' c_magenta=$'\e[35m' c_cyan=$'\e[36m'
  else
    c_off='' c_bold='' c_dim='' c_red='' c_green='' c_yellow='' c_blue='' c_magenta='' c_cyan=''
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }
die()  { printf '%sg3rm0n: %s%s\n' "$c_red" "$*" "$c_off" >&2; exit 1; }

# 1536 -> 1.5K, 3221225472 -> 3.0G
g3_bytes() {
  local n=${1:-0} units=BKMGTP i=0 tenths
  (( n < 0 )) && n=0
  while (( n >= 1024 * 1024 && i < 4 )); do n=$(( n / 1024 )); i=$(( i + 1 )); done
  if (( n < 1024 )) && (( i == 0 )); then printf '%dB' "$n"; return; fi
  tenths=$(( n * 10 / 1024 ))
  printf '%d.%d%s' $(( tenths / 10 )) $(( tenths % 10 )) "${units:i+1:1}"
}

# seconds -> "3d 4h" / "2h 05m" / "7m"
g3_duration() {
  local s=${1:-0}
  (( s < 0 )) && s=0
  if   (( s >= 86400 )); then printf '%dd %dh' $(( s / 86400 )) $(( s % 86400 / 3600 ))
  elif (( s >= 3600 ));  then printf '%dh %02dm' $(( s / 3600 )) $(( s % 3600 / 60 ))
  else printf '%dm' $(( s / 60 )); fi
}

g3_tilde() { # "$HOME/x" -> "~/x" (display only)
  # shellcheck disable=SC2088  # a literal "~" is the point
  if [[ $1 == "$HOME"/* ]]; then printf '~/%s' "${1#"$HOME"/}"; else printf '%s' "$1"; fi
}

# The shell g3rm0n was started from (its parent process), else the login shell.
# Used only to phrase hints in that shell's own syntax.
g3_user_shell() {
  local s=""
  if [[ -r /proc/$PPID/comm ]]; then read -r s </proc/$PPID/comm
  else s=$(ps -o comm= -p "$PPID" 2>/dev/null); s=${s##*/}; fi   # macOS: no /proc
  s=${s#-}
  case $s in
    bash|zsh|fish|ksh|mksh|ksh93|dash|sh|tcsh|csh|nu|xonsh|elvish) printf '%s' "$s" ;;
    *) s=${SHELL##*/}; printf '%s' "${s:-sh}" ;;
  esac
}

g3_export_hint() { # VAR -> how to export it in the user's shell
  case ${G3_USER_SHELL:=$(g3_user_shell)} in
    fish)     printf 'set -gx %s …' "$1" ;;
    tcsh|csh) printf 'setenv %s …' "$1" ;;
    nu)       printf '%senv.%s = …' '$' "$1" ;;
    xonsh)    printf '$%s = …' "$1" ;;
    elvish)   printf 'set-env %s …' "$1" ;;
    *)        printf 'export %s=…' "$1" ;;
  esac
}

# seconds -> "<1m" / "12m" / "3h" / "2d": short ages that fit beside other text
g3_ago() {
  local s=${1:-0}
  (( s < 0 )) && s=0
  if   (( s < 60 ));    then printf '<1m'
  elif (( s < 3600 ));  then printf '%dm' $(( s / 60 ))
  elif (( s < 86400 )); then printf '%dh' $(( s / 3600 ))
  else printf '%dd' $(( s / 86400 )); fi
}

g3_expand() { # "~/x" -> "$HOME/x"
  # shellcheck disable=SC2088  # matching a literal "~/" prefix on purpose
  if [[ $1 == "~/"* ]]; then printf '%s' "$HOME/${1#\~/}"; else printf '%s' "$1"; fi
}

# ---- config -----------------------------------------------------------------
# Plain "key = value" lines. Parsed, never sourced, so the file can't run code.

declare -gA CFG=()

g3_config_load() {
  CFG=([sections]="${G3_SECTIONS[*]}" [interval]=2 [providers]=auto [mouse]=on [header]="$G3_HEADER")
  [[ -r $G3_CONFIG_FILE ]] || return 0
  local line re='^[[:space:]]*([a-z][a-z0-9_.-]*)[[:space:]]*=[[:space:]]*(.*)$'
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    [[ $line =~ $re ]] || continue
    local v=${BASH_REMATCH[2]}
    v=${v%"${v##*[![:space:]]}"}
    CFG[${BASH_REMATCH[1]}]=$v
  done <"$G3_CONFIG_FILE"
}

g3_has() { # list word -> true when word is in the space/comma separated list
  local list=" ${1//,/ } "
  [[ $list == *" $2 "* ]]
}

g3_section_on() { g3_has "${CFG[sections]}" "$1"; }
