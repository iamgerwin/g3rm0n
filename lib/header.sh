#!/usr/bin/env bash
# header.sh — the dashboard's top line, built from small components.
#
#   g3rm0n  ● 100 Healthy  ger-01 · Ubuntu 26.04.1 LTS · Oct 08 | 12:34PM PST
#   └logo┘  └──health───┘  └host┘   └──────os───────┘   └date┘   └──time───┘
#
# Each component is one function that sets HDR_TEXT (with colors) from data the
# samplers already hold. The header is whatever list of component ids it is given,
# in that order: today `header` in the config or HDR_DEFAULT, later any arranging UI.
# Adding a component is one function plus one HDR_FN entry; nothing else changes.
#
# Separators come from the pair of neighbours, not from the components: two spaces
# after the lead items (logo, health), " | " between date and time, " · " otherwise.
# When the line is wider than the terminal, components are dropped in HDR_DROP order
# (least important first); logo, health and time are never dropped.

HDR_DEFAULT=$G3_HEADER
HDR_DROP=(kernel os host date)
declare -gA HDR_FN=(
  [logo]=hdr_logo [health]=hdr_health [host]=hdr_host [os]=hdr_os
  [kernel]=hdr_kernel [date]=hdr_date [time]=hdr_time
)
declare -gA HDR_JOIN=([date time]=" | " [time date]=" | ")
declare -gA HDR_LEAD=([logo]=1 [health]=1)

# ---- components (each sets HDR_TEXT; $1 is the time to show, as an epoch) ------
hdr_logo()   { HDR_TEXT="${c_bold}${c_magenta}g3rm0n${c_off}"; }
hdr_health() { HDR_TEXT="$H_DOT ${c_bold}${H_SCORE}${c_off} $H_LABEL"; }
hdr_host()   { HDR_TEXT="${c_dim}${S_HOST}${c_off}"; }
hdr_os()     { HDR_TEXT="${c_dim}${S_OS}${c_off}"; }
hdr_kernel() { HDR_TEXT="${c_dim}${S_KERNEL}${c_off}"; }
# bash's own strftime: no `date` process per frame, the same on GNU and BSD systems
hdr_date()   { printf -v HDR_TEXT '%s%(%b %d)T%s' "$c_dim" "$1" "$c_off"; }
hdr_time()   { printf -v HDR_TEXT '%s%(%I:%M%p %Z)T%s' "$c_dim" "$1" "$c_off"; }

hdr_ids() { # spec -> the valid component ids in it, one per line (unknown ones skipped)
  local id
  for id in ${1//,/ }; do [[ -n ${HDR_FN[$id]:-} ]] && printf '%s\n' "$id"; done
  return 0
}

hdr_join() { # id... -> HDR_LINE: the components joined with their separators
  local id prev="" sep
  HDR_LINE=""
  for id in "$@"; do
    "${HDR_FN[$id]}" "$HDR_NOW"
    if [[ -z $prev ]]; then sep=""
    elif [[ -n ${HDR_LEAD[$prev]:-} ]]; then sep="  "
    else sep=${HDR_JOIN["$prev $id"]:-" ${c_dim}·${c_off} "}; fi
    HDR_LINE+="$sep$HDR_TEXT"
    prev=$id
  done
}

# hdr_render cols [spec] [epoch] -> HDR_LINE: the header for a terminal that wide
hdr_render() {
  local cols=$1 spec=${2:-$HDR_DEFAULT} drop t i
  HDR_NOW=${3:-$EPOCHSECONDS}
  local -a ids=()
  mapfile -t ids < <(hdr_ids "$spec")
  (( ${#ids[@]} )) || mapfile -t ids < <(hdr_ids "$HDR_DEFAULT")
  hdr_join "${ids[@]}"
  for drop in "${HDR_DROP[@]}"; do
    t=${HDR_LINE//$'\e'\[*([0-9;])m/}
    (( ${#t} <= cols )) && return 0
    for i in "${!ids[@]}"; do [[ ${ids[i]} == "$drop" ]] && unset 'ids[i]'; done
    ids=("${ids[@]}")
    hdr_join "${ids[@]}"
  done
  return 0
}
