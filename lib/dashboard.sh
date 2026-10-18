#!/usr/bin/env bash
# dashboard.sh — composes the panels into frames: live (alternate screen) or one-shot

dash_frame() { # cols -> OUT (all lines of one frame)
  local cols=$1 s id hw
  local -a items=()
  OUT=()
  sys_sample
  sys_health

  for s in cpu memory disk power processes network; do
    g3_section_on "$s" || continue
    "sys_panel_$s"
    items+=("system:P_$s")
  done
  for id in "${AI_IDS[@]}"; do
    ai_tick "$id" "$DASH_SYNC"
    ai_panel "$id" "P_ai_$id"
    items+=("${AI_KIND[$id]}:P_ai_$id")
  done

  hw="$S_HOST · $S_OS · $S_KERNEL"
  local room=$(( cols - 30 ))
  (( room < 0 )) && room=0
  OUT+=("${c_bold}${c_magenta}g3rm0n${c_off}  $H_DOT ${c_bold}$H_SCORE${c_off} $H_LABEL  ${c_dim}${hw:0:room}${c_off}")
  OUT+=("")
  ui_grid "$cols" "${items[@]}"
}

dash_restore() { printf '\e[?1049l\e[?25h\e[0m'; }

dash_run() { # once interval
  local once=$1 interval=$2 cols rows key frame
  local -a OUT=() AI_IDS=()
  local P_cpu=() P_memory=() P_disk=() P_power=() P_processes=() P_network=()
  local P_ai_claude=() P_ai_codex=() P_ai_zai=() P_ai_deepseek=() P_ai_openrouter=()
  mapfile -t AI_IDS < <(ai_providers)

  sys_static

  if (( once )); then
    # one-shot: fetch AI usage up front (in parallel) and wait for a real sample window
    DASH_SYNC=""
    local id
    for id in "${AI_IDS[@]}"; do ai_stale "$id" && ai_refresh "$id" & done
    sleep 1
    wait
    cols=$(tput cols 2>/dev/null || echo "${COLUMNS:-100}")
    dash_frame "$cols"
    printf '%s\n' "${OUT[@]}"
    return
  fi

  DASH_SYNC=""
  trap 'dash_restore; exit 0' INT TERM
  trap dash_restore EXIT
  printf '\e[?1049h\e[2J\e[?25l'
  sleep 0.5   # give the first frame a meaningful sample window

  local last_cols=0
  while :; do
    cols=$(tput cols 2>/dev/null || echo 100)
    rows=$(tput lines 2>/dev/null || echo 24)
    (( cols != last_cols )) && printf '\e[2J'
    last_cols=$cols
    dash_frame "$cols"
    OUT+=("${c_dim}g3rm0n v$G3_VERSION · every ${interval}s · q quit · any key refreshes · g3rm0n setup to customize${c_off}")
    # never print more lines than fit, or each frame scrolls the screen
    (( ${#OUT[@]} > rows - 1 )) && OUT=("${OUT[@]:0:rows-1}")
    printf -v frame '%s\e[K\n' "${OUT[@]}"
    printf '\e[H%s\e[J' "$frame"
    key=""
    if read -rsn1 -t "$interval" key </dev/tty 2>/dev/null; then
      [[ $key == [qQ] ]] && break
    fi
  done
  dash_restore
  trap - INT TERM EXIT
}
