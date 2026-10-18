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

ui_title() { # icon text -> "◉ CPU ──────────" spanning the panel width
  local fill=$(( G3_W - ${#1} - ${#2} - 2 ))
  (( fill < 0 )) && fill=0
  printf '%s%s %s%s %s%s%s' "$c_bold" "$1" "$2" "$c_off" "$c_dim" "${G3_LINE:0:fill}" "$c_off"
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
# element). Consecutive panels of the same group share a row when the terminal is
# wide enough; groups never mix. Lines are appended to the global OUT array.
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
