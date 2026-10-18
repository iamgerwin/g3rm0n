#!/usr/bin/env bash
# ui.sh — panel primitives: titles, bars, sparklines, padding, two-column grid

shopt -s extglob

G3_W=46     # panel width
G3_GAP=2    # gutter between the two columns
G3_SPARK=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
G3_FILL='████████████████████████████████'
G3_TRACK='░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░'
G3_LINE='────────────────────────────────────────────────────────────'

ui_len() { # visible width (ANSI color codes stripped)
  local s=${1//$'\e'\[*([0-9;])m/}
  printf '%d' "${#s}"
}

ui_pad() { # text width -> text right-padded to width
  local n; n=$(ui_len "$1")
  if (( n >= $2 )); then printf '%s' "$1"; else printf '%s%*s' "$1" $(( $2 - n )) ''; fi
}

ui_label() { ui_pad "$1" 7; }   # left column of every panel row

# ui_title <icon> <name> [marker] [summary] [key] -> one title row, G3_W columns wide:
#   "◉ CPU ────────────────"                       plain (one-shot output)
#   "▾ ◉ CPU ──────────── 1"                        live: fold marker and shortcut key
#   "▸ ◉ CPU · 24% · load 1.12 ──────────── 1"      folded: summary in the title
# A summary that doesn't fit drops its last " · " parts; it is never cut mid-part.
ui_title() {
  local head="${3:+$3 }$c_bold$1 $2$c_off" tail="${5:+ $c_dim${5:-}$c_off}" sum=${4:-} t used fill
  # visible widths, measured in-process (no subshells: this runs for every panel, every frame)
  t=${head//$'\e'\[*([0-9;])m/}; used=${#t}
  t=${tail//$'\e'\[*([0-9;])m/}; used=$(( used + ${#t} + 1 ))
  # a summary that doesn't fit loses its last " · " parts, most important part first;
  # it is never cut mid-part, so colors stay intact ("612 tasks · WindowServer 12%" -> "612 tasks")
  while [[ -n $sum ]]; do
    t=${sum//$'\e'\[*([0-9;])m/}
    (( used + ${#t} + 5 <= G3_W )) && break
    if [[ $sum == *" · "* ]]; then sum=${sum% · *}; else sum=""; fi
  done
  if [[ -n $sum ]]; then
    # braces matter: macOS reads the first byte of a UTF-8 character after $name as part of the name
    head+=" ${c_dim}·${c_off} $sum"; used=$(( used + ${#t} + 3 ))
  fi
  fill=$(( G3_W - used ))
  (( fill < 0 )) && fill=0
  printf '%s %s%s%s%s' "$head" "$c_dim" "${G3_LINE:0:fill}" "$c_off" "$tail"
}

# ui_term_size -> UI_COLS UI_ROWS. Asks the terminal itself (stty on /dev/tty, the same
# on GNU and BSD). `tput cols` inside $(...) is not used: macOS's tput only looks at
# stdout, which is a pipe there, so it always answers 80x24.
ui_term_size() {
  local r="" c=""
  read -r r c < <(stty size 2>/dev/null </dev/tty)   # silence first: no tty is normal in scripts
  if [[ $r =~ ^[1-9][0-9]*$ && $c =~ ^[1-9][0-9]*$ ]]; then UI_ROWS=$r UI_COLS=$c; return 0; fi
  # no terminal (piped from a script, CI): $COLUMNS/$LINES, then terminfo, then 100x24
  UI_COLS=${COLUMNS:-} UI_ROWS=${LINES:-}
  [[ $UI_COLS =~ ^[1-9][0-9]*$ ]] || UI_COLS=$(tput cols 2>/dev/null)
  [[ $UI_ROWS =~ ^[1-9][0-9]*$ ]] || UI_ROWS=$(tput lines 2>/dev/null)
  [[ $UI_COLS =~ ^[1-9][0-9]*$ ]] || UI_COLS=100
  [[ $UI_ROWS =~ ^[1-9][0-9]*$ ]] || UI_ROWS=24
  return 0
}

ui_tone() { # pct -> color for that load level
  if (( $1 < 60 )); then printf '%s' "$c_green"
  elif (( $1 < 85 )); then printf '%s' "$c_yellow"
  else printf '%s' "$c_red"; fi
}

ui_bar() { # pct [width]
  local p=${1%.*} w=${2:-16} on
  [[ $p =~ ^-?[0-9]+$ ]] || p=0
  (( p < 0 )) && p=0; (( p > 100 )) && p=100
  on=$(( (p * w + 50) / 100 ))
  (( p > 0 && on == 0 )) && on=1
  printf '%s%s%s%s%s' "$(ui_tone "$p")" "${G3_FILL:0:on}" "$c_dim" "${G3_TRACK:0:w-on}" "$c_off"
}

ui_pct() { printf '%4s%%' "${1%.*}"; }

ui_spark() { # values... -> sparkline scaled to the largest value
  local v max=1 out=""
  for v in "$@"; do (( v > max )) && max=$v; done
  for v in "$@"; do out+=${G3_SPARK[v * 7 / max]}; done
  printf '%s' "$out"
}

# ui_grid cols item... : item = "group:ARRAY". Each ARRAY is one panel (one row per
# element, title first). Consecutive panels of the same group share a row when the
# terminal is wide enough; groups never mix. Lines are appended to the global OUT
# array, and each title's position is appended to UI_HITS (for mouse clicks).
ui_grid() {
  local cols=$1 two=0 i=0 n r h a1 a2 g
  shift
  local -a items=("$@")
  n=${#items[@]}
  (( cols >= G3_W * 2 + G3_GAP )) && two=1
  while (( i < n )); do
    g=${items[i]%%:*} a1=${items[i]#*:} a2=""
    if (( two && i + 1 < n )) && [[ ${items[i+1]%%:*} == "$g" ]]; then
      a2=${items[i+1]#*:}; i=$(( i + 2 ))
    else
      i=$(( i + 1 ))
    fi
    local -n _left=$a1
    h=${#_left[@]}
    # where each panel's title row lands: "out-row first-col last-col array"
    UI_HITS+=("${#OUT[@]} 0 $(( G3_W - 1 )) $a1")
    [[ -n $a2 ]] && UI_HITS+=("${#OUT[@]} $(( G3_W + G3_GAP )) $(( G3_W * 2 + G3_GAP - 1 )) $a2")
    if [[ -n $a2 ]]; then
      local -n _right=$a2
      (( ${#_right[@]} > h )) && h=${#_right[@]}
      for (( r = 0; r < h; r++ )); do
        OUT+=("$(ui_pad "${_left[r]:-}" $(( G3_W + G3_GAP )))${_right[r]:-}")
      done
    else
      OUT+=("${_left[@]}")
    fi
    OUT+=("")
  done
}
