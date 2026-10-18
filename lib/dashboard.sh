#!/usr/bin/env bash
# dashboard.sh — the controller: registers panels, runs the live loop, dispatches input.
#
#   sample   read the machine and the AI cache, run every panel renderer   (each interval)
#   render   compose header + panels (with fold state) + footer, draw      (after any event)
#   input    one normalized event from input.sh -> one action from keymap.sh -> dash_do
#
# Folding, clicks and resizes only re-render; they never re-sample, so rates and
# sparklines stay correct however fast you press keys.

DASH_SYNC=""

dash_register() { # build the panel registry from the config and the detected providers
  local s id
  panel_reset
  for s in cpu memory disk power processes network; do
    g3_section_on "$s" || continue
    panel_register "$s" "$s" system "${SYS_ICON[$s]}" "${SYS_TITLE[$s]}" "sys_panel_$s"
  done
  for id in "${AI_IDS[@]}"; do
    panel_register "ai-$id" "ai-${AI_KIND[$id]}" "${AI_KIND[$id]}" "$(ai_icon "$id")" "$(ai_title "$id")" ai_panel "$id"
  done
}

dash_sample() {
  local id
  sys_sample
  sys_health
  for id in "${AI_IDS[@]}"; do ai_tick "$id" "$DASH_SYNC"; done
  panel_render_all
}

dash_render() { # live cols -> OUT
  local live=$1 cols=$2 hw room
  OUT=()
  hw="$S_HOST · $S_OS · $S_KERNEL"
  room=$(( cols - 30 )); (( room < 0 )) && room=0
  OUT+=("${c_bold}${c_magenta}g3rm0n${c_off}  $H_DOT ${c_bold}$H_SCORE${c_off} $H_LABEL  ${c_dim}${hw:0:room}${c_off}")
  OUT+=("")
  panel_compose "$live" "$cols"
}

dash_footer() { # interval -> the live footer, shortened to fit
  local n=${#G3_SECTIONS[@]}
  local long="g3rm0n v$G3_VERSION · every ${1}s · 1-$n or click a title to fold · -/+ all · r refresh · q quit"
  local short="1-$n/click fold · -/+ all · q quit"
  if (( ${#long} <= COLS_NOW )); then printf '%s' "${c_dim}${long}${c_off}"
  else printf '%s' "${c_dim}${short}${c_off}"; fi
}

dash_draw() { # interval -> paints one frame on the alternate screen
  local rows frame
  rows=$(tput lines 2>/dev/null || echo 24)
  OUT+=("$(dash_footer "$1")")
  # never print more lines than fit, or each frame scrolls the screen
  (( ${#OUT[@]} > rows - 1 )) && OUT=("${OUT[@]:0:rows-1}")
  printf -v frame '%s\e[K\n' "${OUT[@]}"
  printf '\e[H%s\e[J' "$frame"
}

# dash_do <action> [arg] -> runs one action; returns 1 to quit. Sets DASH_RESAMPLE.
dash_do() {
  local -a ids=()
  case $1 in
    quit) return 1 ;;
    refresh) DASH_RESAMPLE=1 ;;
    section) mapfile -t ids < <(panel_in_section "$2")
             (( ${#ids[@]} )) && fold_group_toggle "${ids[@]}" && fold_save ;;
    panel) [[ -n $2 ]] && fold_toggle "$2" && fold_save ;;
    fold-all) fold_group 1 "${PANEL_IDS[@]}"; fold_save ;;
    unfold-all) fold_group 0 "${PANEL_IDS[@]}"; fold_save ;;
  esac
  return 0
}

dash_event() { # IN_EVENT -> action, then dash_do; returns 1 to quit
  local kind a b id
  read -r kind a b <<<"$IN_EVENT"
  case $kind in
    key)   local action; action=$(keymap_action "$a")
           # shellcheck disable=SC2086  # "section cpu" -> two words on purpose
           dash_do $action ;;
    click) id=$(panel_at "$a" "$b") && dash_do panel "$id" ;;
    *)     return 0 ;;
  esac
}

dash_restore() { (( ${G3_MOUSE:-0} )) && in_mouse_off; printf '\e[?1049l\e[?25h\e[0m'; plat_cleanup; }

dash_run() { # once interval [fold-list]
  local once=$1 interval=$2 fold_list=${3:-} cols key
  local -a OUT=() AI_IDS=()
  mapfile -t AI_IDS < <(ai_providers)
  sys_static
  dash_register

  if (( once )); then
    # one-shot: fetch AI usage up front (in parallel) and wait for a real sample window
    local id
    for id in "${AI_IDS[@]}"; do ai_stale "$id" && ai_refresh "$id" & done
    sleep 1
    wait
    FOLD=()
    [[ -n $fold_list ]] && fold_apply "$fold_list"
    cols=$(tput cols 2>/dev/null || echo "${COLUMNS:-100}")
    dash_sample
    dash_render 0 "$cols"
    printf '%s\n' "${OUT[@]}"
    plat_cleanup
    return
  fi

  fold_load
  [[ -n $fold_list ]] && { FOLD=(); fold_apply "$fold_list"; fold_save; }
  G3_MOUSE=1
  [[ ${CFG[mouse]:-on} == off || ${G3_NO_MOUSE:-0} == 1 ]] && G3_MOUSE=0

  local resized=0
  trap 'dash_restore; exit 0' INT TERM
  trap dash_restore EXIT
  trap 'resized=1' WINCH
  printf '\e[?1049h\e[2J\e[?25l'
  (( G3_MOUSE )) && in_mouse_on
  sleep 0.5   # give the first frame a meaningful sample window

  local next now wait last_cols=0 DASH_RESAMPLE=1
  while :; do
    if (( DASH_RESAMPLE )); then
      dash_sample
      DASH_RESAMPLE=0
      next=$(( ${EPOCHREALTIME/./} + interval * 1000000 ))
    fi
    COLS_NOW=$(tput cols 2>/dev/null || echo 100)
    (( COLS_NOW != last_cols )) && printf '\e[2J'
    last_cols=$COLS_NOW
    dash_render 1 "$COLS_NOW"
    dash_draw "$interval"

    # wait for input until the next sample is due, in short slices so a resize
    # (which can't interrupt read) is redrawn promptly
    while :; do
      now=${EPOCHREALTIME/./}
      (( now >= next )) && { DASH_RESAMPLE=1; break; }
      wait=$(( next - now )); (( wait > 250000 )) && wait=250000
      printf -v key '%d.%06d' $(( wait / 1000000 )) $(( wait % 1000000 ))
      in_read "$key"
      if (( resized )); then resized=0; break; fi
      [[ $IN_EVENT == none ]] && continue
      dash_event || { dash_restore; trap - INT TERM EXIT WINCH; return 0; }
      break
    done
  done
}
