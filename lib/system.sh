#!/usr/bin/env bash
# system.sh — system sampling and the system panels, the same on every platform.
#
# Raw numbers come from the platform backend (lib/platform/<os>.sh), which fills the
# globals of the platform contract (see ARCHITECTURE.md). This module turns them into
# rates, the health score and the six panels. Rates are deltas between two samples
# divided by the real elapsed time, so a slow frame never inflates them.

# The platform contract: every backend defines all of these (see ARCHITECTURE.md).
SYS_CONTRACT=(plat_static plat_cpu plat_load plat_mem plat_net_bytes plat_disk_bytes plat_temp
  plat_uptime plat_root_pct plat_disks plat_battery plat_gpu plat_top plat_link plat_vpn plat_sensors
  plat_mtime plat_keychain_has plat_keychain_read plat_cleanup)

sys_contract_missing() { # -> contract functions the loaded backend doesn't define
  local f
  for f in "${SYS_CONTRACT[@]}"; do declare -F "$f" >/dev/null || printf '%s\n' "$f"; done
}

# ---- static facts (read once) -----------------------------------------------

sys_static() {
  local missing; missing=$(sys_contract_missing)
  [[ -z $missing ]] || die "the $G3_PLATFORM backend is incomplete, missing: ${missing//$'\n'/ }"
  S_HOST=${HOSTNAME:-$(uname -n)}
  S_HOST=${S_HOST%%.*}                                  # "mac-mini.local" -> "mac-mini"
  (( ${#S_HOST} > 24 )) && S_HOST="${S_HOST:0:23}…"     # keep room for the OS and kernel
  S_KERNEL=$(uname -r)
  plat_static
  S_RXH=() S_TXH=()
  S_T=${EPOCHREALTIME/./}
  plat_net_bytes;  S_PRX=$NET_RX S_PTX=$NET_TX
  plat_disk_bytes; S_PDR=$DIO_R S_PDW=$DIO_W
}

# ---- one sample -------------------------------------------------------------

sys_sample() {
  local now dus
  now=${EPOCHREALTIME/./}
  dus=$(( now - S_T )); (( dus < 1 )) && dus=1
  S_T=$now

  plat_cpu
  plat_load

  plat_mem
  S_MEM_U=$(( S_MEM_T - S_MEM_A )) S_SWAP_U=$(( S_SWAP_T - S_SWAP_F ))
  (( S_SWAP_U < 0 )) && S_SWAP_U=0
  S_MEM_P=0;  (( S_MEM_T > 0 )) && S_MEM_P=$(( S_MEM_U * 100 / S_MEM_T ))
  S_SWAP_P=0; (( S_SWAP_T > 0 )) && S_SWAP_P=$(( S_SWAP_U * 100 / S_SWAP_T ))

  # network + disk throughput
  plat_net_bytes
  S_RX=$(( (NET_RX - S_PRX) * 1000000 / dus )); S_TX=$(( (NET_TX - S_PTX) * 1000000 / dus ))
  (( S_RX < 0 )) && S_RX=0; (( S_TX < 0 )) && S_TX=0
  S_PRX=$NET_RX S_PTX=$NET_TX
  S_RXH+=("$S_RX") S_TXH+=("$S_TX")
  (( ${#S_RXH[@]} > 16 )) && S_RXH=("${S_RXH[@]:1}") S_TXH=("${S_TXH[@]:1}")

  plat_disk_bytes
  S_DR=$(( (DIO_R - S_PDR) * 1000000 / dus )); S_DW=$(( (DIO_W - S_PDW) * 1000000 / dus ))
  (( S_DR < 0 )) && S_DR=0; (( S_DW < 0 )) && S_DW=0
  S_PDR=$DIO_R S_PDW=$DIO_W

  sys_temp_pick < <(plat_temp)
  plat_uptime
  plat_root_pct
}

# sensor lines ("kind<TAB>°C<TAB>name") on stdin -> S_TEMP (whole °C) and S_TEMP_SRC:
# the hottest CPU sensor when the machine names one ("CPU", as iStat Menus shows it),
# else the hottest sensor of any kind; both empty when nothing is readable
sys_temp_pick() {
  local kind v name cpu=-1 any=-1
  while IFS=$'\t' read -r kind v name; do
    v=${v%.*}
    [[ $v =~ ^[0-9]+$ ]] || continue
    (( v > any )) && any=$v
    [[ $kind == cpu ]] && (( v > cpu )) && cpu=$v
  done
  if (( cpu >= 0 )); then S_TEMP=$cpu S_TEMP_SRC=CPU
  elif (( any >= 0 )); then S_TEMP=$any S_TEMP_SRC="hottest sensor"
  else S_TEMP="" S_TEMP_SRC=""; fi
}

sys_sensors_report() { # `g3rm0n sensors`: every readable sensor, and which one Temp shows
  local kind v name n=0
  local -a lines=()
  local -a notes=()
  mapfile -t lines < <(plat_sensors | grep -v '^note' | sort -t $'\t' -k1,1 -k2,2nr)
  mapfile -t notes < <(plat_sensors | sed -n 's/^note\t-\t//p')
  printf '%s\n' "${c_bold}Temperature sensors g3rm0n can read${c_off} ${c_dim}(${G3_PLATFORM})${c_off}"
  for kind in "${lines[@]}"; do
    IFS=$'\t' read -r kind v name <<<"$kind"
    printf '  %-6s %6s°C  %s\n' "${kind/cpu/CPU}" "$v" "$name"
    n=$(( n + 1 ))
  done
  local note
  if (( n == 0 )); then
    printf '  %s\n' "${c_dim}none readable on this machine: the Power panel shows \"no sensors exposed\"${c_off}"
    for note in "${notes[@]}"; do printf '  %s\n' "${c_dim}${note}${c_off}"; done
    return 0
  fi
  for note in "${notes[@]}"; do printf '  %s\n' "${c_dim}${note}${c_off}"; done
  sys_temp_pick < <(printf '%s\n' "${lines[@]}")
  printf '\n  %s\n' "Temp shows ${c_bold}${S_TEMP}°C${c_off} ${c_dim}(${S_TEMP_SRC}: the hottest $( [[ $S_TEMP_SRC == CPU ]] && echo "CPU sensor" || echo "sensor, as none is named CPU"))${c_off}"
}

# ---- health ------------------------------------------------------------------

sys_health() { # -> H_SCORE H_LABEL H_DOT
  local s=100
  (( S_CPU > 75 ))      && s=$(( s - (S_CPU - 75) / 2 ))
  (( S_MEM_P > 80 ))    && s=$(( s - (S_MEM_P - 80) ))
  (( S_SWAP_P > 60 ))   && s=$(( s - (S_SWAP_P - 60) / 4 ))
  [[ -n $S_TEMP ]] && (( S_TEMP > 80 )) && s=$(( s - (S_TEMP - 80) ))
  (( ${S_ROOT_P:-0} > 90 )) && s=$(( s - (S_ROOT_P - 90) * 2 ))
  (( s < 0 )) && s=0
  H_SCORE=$s
  if   (( s >= 90 )); then H_LABEL="Healthy";  H_DOT="${c_green}●${c_off}"
  elif (( s >= 70 )); then H_LABEL="Busy";     H_DOT="${c_yellow}●${c_off}"
  elif (( s >= 50 )); then H_LABEL="Strained"; H_DOT="${c_yellow}◐${c_off}"
  else                     H_LABEL="Critical"; H_DOT="${c_red}○${c_off}"; fi
}

# ---- panels ------------------------------------------------------------------
# Renderers for panel.sh: each fills PANEL_BODY (rows, no title) and sets PANEL_SUM,
# the one-line summary shown in the title while the panel is folded.

declare -gA SYS_ICON=([cpu]="◉" [memory]="◫" [disk]="▤" [power]="◪" [processes]="≡" [network]="⇅")
declare -gA SYS_TITLE=([cpu]="CPU" [memory]="Memory" [disk]="Disk" [power]="Power" [processes]="Processes" [network]="Network")

sys_panel_cpu() {
  PANEL_BODY=()
  PANEL_BODY+=("$(ui_label Usage)$(ui_bar "$S_CPU") $(ui_pct "$S_CPU")")
  PANEL_BODY+=("$(ui_label Cores)${S_CORES}")
  PANEL_BODY+=("$(ui_label Load)$S_L1 · $S_L5 · $S_L15 ${c_dim}· $S_THREADS threads${c_off}")
  PANEL_BODY+=("$(ui_label Model)${c_dim}${S_MODEL:0:38}${c_off}")
  PANEL_SUM="$(ui_tone "$S_CPU")${S_CPU}%${c_off} · load $S_L1"
}

sys_panel_memory() {
  PANEL_BODY=()
  PANEL_BODY+=("$(ui_label Used)$(ui_bar "$S_MEM_P") $(ui_pct "$S_MEM_P") ${c_dim}$(g3_bytes "$S_MEM_U")/$(g3_bytes "$S_MEM_T")${c_off}")
  if (( S_SWAP_T > 0 )); then
    PANEL_BODY+=("$(ui_label Swap)$(ui_bar "$S_SWAP_P") $(ui_pct "$S_SWAP_P") ${c_dim}$(g3_bytes "$S_SWAP_U")/$(g3_bytes "$S_SWAP_T")${c_off}")
  else
    PANEL_BODY+=("$(ui_label Swap)${c_dim}not configured${c_off}")
  fi
  PANEL_BODY+=("$(ui_label Free)$(g3_bytes "$S_MEM_A") ${c_dim}available${c_off}")
  PANEL_BODY+=("$(ui_label Cache)$(g3_bytes "$S_CACHE") ${c_dim}buffers & page cache${c_off}")
  PANEL_SUM="$(ui_tone "$S_MEM_P")${S_MEM_P}%${c_off} · $(g3_bytes "$S_MEM_U")/$(g3_bytes "$S_MEM_T")"
}

sys_panel_disk() {
  PANEL_BODY=()
  local mnt fs size used pct label
  declare -A seen=()
  while IFS=$'\t' read -r mnt fs size used pct; do
    [[ -n ${seen[$mnt]:-} ]] && continue
    seen[$mnt]=1
    label=$mnt; [[ $mnt == "$HOME" ]] && label="~"
    PANEL_BODY+=("$(ui_label "${label:0:6}")$(ui_bar "$pct" 10) $(ui_pct "$pct") ${c_dim}$(g3_bytes "$used")/$(g3_bytes "$size") $fs${c_off}")
  done < <(plat_disks)
  PANEL_BODY+=("$(ui_label I/O)${c_dim}read${c_off} $(g3_bytes "$S_DR")/s ${c_dim}· write${c_off} $(g3_bytes "$S_DW")/s")
  PANEL_SUM="${S_ROOT_LABEL:-/} $(ui_tone "${S_ROOT_P:-0}")${S_ROOT_P:-?}%${c_off} · io $(g3_bytes $(( S_DR + S_DW )))/s"
}

sys_panel_power() {
  PANEL_BODY=()
  local bat=""
  plat_battery
  [[ -n $BAT_CAP ]] && bat="$(ui_bar "$BAT_CAP" 10) $(ui_pct "$BAT_CAP") ${c_dim}· ${BAT_STATUS}${c_off}"
  if [[ -n $bat ]]; then PANEL_BODY+=("$(ui_label Batt)$bat")
  elif [[ $BAT_AC == 1 ]]; then PANEL_BODY+=("$(ui_label Batt)${c_dim}none · on AC power${c_off}")
  else PANEL_BODY+=("$(ui_label Batt)${c_dim}none${c_off}"); fi

  plat_gpu
  if [[ -n $GPU_UTIL ]]; then
    local extra=""
    [[ -n $GPU_MEM_T ]] && extra+=" · $(g3_bytes "$GPU_MEM_U")/$(g3_bytes "$GPU_MEM_T")"
    [[ -n $GPU_TEMP ]] && extra+=" · ${GPU_TEMP}°C"
    PANEL_BODY+=("$(ui_label GPU)$(ui_bar "$GPU_UTIL" 10) $(ui_pct "$GPU_UTIL")${extra:+ ${c_dim}${extra# }${c_off}}")
  fi

  if [[ -n $S_TEMP ]]; then
    local tone=$c_green
    (( S_TEMP >= 70 )) && tone=$c_yellow; (( S_TEMP >= 85 )) && tone=$c_red
    PANEL_BODY+=("$(ui_label Temp)${tone}${S_TEMP}°C${c_off} ${c_dim}${S_TEMP_SRC}${c_off}")
  else
    PANEL_BODY+=("$(ui_label Temp)${c_dim}no sensors exposed${c_off}")
  fi
  PANEL_BODY+=("$(ui_label Uptime)$(g3_duration "$S_UP")")
  PANEL_SUM=""
  if [[ -n $BAT_CAP ]]; then PANEL_SUM="batt ${BAT_CAP}%"; elif [[ $BAT_AC == 1 ]]; then PANEL_SUM="AC"; fi
  [[ -n $S_TEMP ]] && PANEL_SUM+="${PANEL_SUM:+ · }${S_TEMP}°C"
  [[ -n $PANEL_SUM ]] || PANEL_SUM="up $(g3_duration "$S_UP")"
}

sys_panel_processes() {
  PANEL_BODY=()
  PANEL_BODY+=("$(ui_label Tasks)${S_TASKS#*/} ${c_dim}total · ${S_TASKS%/*} running${c_off}")
  local pcpu rss comm rank=0
  PANEL_SUM="${S_TASKS#*/} tasks"
  while read -r pcpu rss comm; do
    comm=${comm##*/}                 # macOS reports full paths
    [[ $comm == ps ]] && continue   # ps always sees itself as busy
    rank=$(( rank + 1 ))
    (( rank == 1 )) && PANEL_SUM+=" · ${comm:0:10} ${pcpu%.*}%"
    PANEL_BODY+=("${c_dim}$rank${c_off}      $(ui_pad "${comm:0:16}" 17)$(ui_bar "${pcpu%.*}" 5) $(printf '%5s%%' "$pcpu") $(printf '%7s' "$(g3_bytes $(( rss * 1024 )))")")
    (( rank >= 3 )) && break
  done < <(plat_top)
}

sys_panel_network() {
  PANEL_BODY=()
  PANEL_BODY+=("$(ui_label Down)${c_cyan}$(ui_pad "$(ui_spark "${S_RXH[@]}")" 16)${c_off} $(g3_bytes "$S_RX")/s")
  PANEL_BODY+=("$(ui_label Up)${c_cyan}$(ui_pad "$(ui_spark "${S_TXH[@]}")" 16)${c_off} $(g3_bytes "$S_TX")/s")
  PANEL_SUM="↓ $(g3_bytes "$S_RX")/s · ↑ $(g3_bytes "$S_TX")/s"
  plat_link
  PANEL_BODY+=("$(ui_label Link)${LINK_DEV:-offline}${LINK_ADDR:+ ${c_dim}·${c_off} $LINK_ADDR}")
  plat_vpn
  [[ -n $VPN_DEV ]] && PANEL_BODY+=("$(ui_label VPN)$VPN_DEV${VPN_ADDR:+ ${c_dim}·${c_off} $VPN_ADDR}")
  return 0
}
