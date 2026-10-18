#!/usr/bin/env bash
# system.sh — samples the kernel's counters (/proc, /sys) and builds the system panels.
# Everything is read-only. Rates are deltas between two samples divided by the real
# elapsed time, so a slow frame never inflates them.

# ---- static facts (read once) -----------------------------------------------

sys_static() {
  S_HOST=${HOSTNAME:-$(uname -n)}
  S_OS=$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-Linux}")
  S_KERNEL=$(uname -r)
  S_MODEL=""
  local k v
  while IFS=: read -r k v; do
    [[ $k == "model name"* ]] && { S_MODEL=${v# }; break; }
  done </proc/cpuinfo
  S_MODEL=${S_MODEL//(R)/}; S_MODEL=${S_MODEL//(TM)/}; S_MODEL=${S_MODEL% CPU @*}
  S_THREADS=$(nproc 2>/dev/null || echo "?")
  S_GPU=""
  if have nvidia-smi && nvidia-smi -L >/dev/null 2>&1; then S_GPU=nvidia
  elif compgen -G "/sys/class/drm/card[0-9]/device/gpu_busy_percent" >/dev/null; then S_GPU=amd; fi
  S_PT=() S_PI=() S_RXH=() S_TXH=()
  S_T=${EPOCHREALTIME/./}
  sys_cpu_read S_PT S_PI
  sys_net_read;  S_PRX=$NET_RX S_PTX=$NET_TX
  sys_dio_read;  S_PDR=$DIO_R S_PDW=$DIO_W
}

# ---- raw counters -----------------------------------------------------------

sys_cpu_read() { # total_arr idle_arr — index 0 is all CPUs, then one per core
  local -n _tot=$1 _idl=$2
  local name user nice sys idle iow irq soft steal _rest
  _tot=() _idl=()
  while read -r name user nice sys idle iow irq soft steal _rest; do
    [[ $name == cpu* ]] || break
    _tot+=( $(( user + nice + sys + idle + iow + irq + soft + ${steal:-0} )) )
    _idl+=( $(( idle + iow )) )
  done </proc/stat
}

sys_net_read() { # -> NET_RX NET_TX: bytes over every interface except loopback
  local line ifc
  local -a f
  NET_RX=0 NET_TX=0
  while IFS= read -r line; do
    [[ $line == *:* ]] || continue
    ifc=${line%%:*}; ifc=${ifc//[[:space:]]/}
    [[ $ifc == lo ]] && continue
    read -ra f <<<"${line#*:}"
    NET_RX=$(( NET_RX + f[0] )); NET_TX=$(( NET_TX + f[8] ))
  done </proc/net/dev
}

sys_dio_read() { # -> DIO_R DIO_W: bytes over physical disks (partitions/loop/dm skipped)
  local maj min dev rd rdm sr rms wr wrm sw _rest
  DIO_R=0 DIO_W=0
  while read -r maj min dev rd rdm sr rms wr wrm sw _rest; do
    [[ -e /sys/block/$dev/device ]] || continue
    DIO_R=$(( DIO_R + sr * 512 )); DIO_W=$(( DIO_W + sw * 512 ))
  done </proc/diskstats
}

sys_temp() { # -> hottest sensor in °C, empty when the machine exposes none
  local f t hot=-1
  for f in /sys/class/thermal/thermal_zone*/temp /sys/class/hwmon/hwmon*/temp*_input; do
    [[ -r $f ]] || continue
    read -r t <"$f" 2>/dev/null || continue
    [[ $t =~ ^[0-9]+$ ]] || continue
    (( t / 1000 > hot && t < 150000 )) && hot=$(( t / 1000 ))
  done
  (( hot >= 0 )) && printf '%d' "$hot"
}

# ---- one sample -------------------------------------------------------------

sys_sample() {
  local now dus k n step dt di p strip=""
  now=${EPOCHREALTIME/./}
  dus=$(( now - S_T )); (( dus < 1 )) && dus=1
  S_T=$now

  # cpu
  local -a tot=() idl=()
  sys_cpu_read tot idl
  dt=$(( tot[0] - S_PT[0] )); di=$(( idl[0] - S_PI[0] ))
  S_CPU=0; (( dt > 0 )) && S_CPU=$(( (dt - di) * 100 / dt ))
  n=$(( ${#tot[@]} - 1 )); step=1
  (( n > 40 )) && step=$(( (n + 39) / 40 ))   # keep the strip inside the panel
  for (( k = 1; k <= n; k += step )); do
    dt=$(( tot[k] - S_PT[k] )); di=$(( idl[k] - S_PI[k] ))
    p=0; (( dt > 0 )) && p=$(( (dt - di) * 100 / dt ))
    (( p > 100 )) && p=100; (( p < 0 )) && p=0
    strip+=${G3_SPARK[p * 7 / 100]}
  done
  S_STRIP=$strip
  S_PT=("${tot[@]}") S_PI=("${idl[@]}")
  read -r S_L1 S_L5 S_L15 S_TASKS _ </proc/loadavg

  # memory (kB in /proc/meminfo)
  local key val _u mt=0 ma=0 st=0 sf=0 bu=0 ca=0 sr=0
  while read -r key val _u; do
    case $key in
      MemTotal:) mt=$val ;; MemAvailable:) ma=$val ;; Buffers:) bu=$val ;;
      Cached:) ca=$val ;; SReclaimable:) sr=$val ;; SwapTotal:) st=$val ;; SwapFree:) sf=$val ;;
    esac
  done </proc/meminfo
  S_MEM_T=$(( mt * 1024 )) S_MEM_U=$(( (mt - ma) * 1024 )) S_MEM_A=$(( ma * 1024 ))
  S_CACHE=$(( (bu + ca + sr) * 1024 ))
  S_SWAP_T=$(( st * 1024 )) S_SWAP_U=$(( (st - sf) * 1024 ))
  S_MEM_P=0;  (( mt > 0 )) && S_MEM_P=$(( (mt - ma) * 100 / mt ))
  S_SWAP_P=0; (( st > 0 )) && S_SWAP_P=$(( (st - sf) * 100 / st ))

  # network + disk throughput
  sys_net_read
  S_RX=$(( (NET_RX - S_PRX) * 1000000 / dus )); S_TX=$(( (NET_TX - S_PTX) * 1000000 / dus ))
  (( S_RX < 0 )) && S_RX=0; (( S_TX < 0 )) && S_TX=0
  S_PRX=$NET_RX S_PTX=$NET_TX
  S_RXH+=("$S_RX") S_TXH+=("$S_TX")
  (( ${#S_RXH[@]} > 16 )) && S_RXH=("${S_RXH[@]:1}") S_TXH=("${S_TXH[@]:1}")

  sys_dio_read
  S_DR=$(( (DIO_R - S_PDR) * 1000000 / dus )); S_DW=$(( (DIO_W - S_PDW) * 1000000 / dus ))
  (( S_DR < 0 )) && S_DR=0; (( S_DW < 0 )) && S_DW=0
  S_PDR=$DIO_R S_PDW=$DIO_W

  S_TEMP=$(sys_temp)
  local up _idle
  read -r up _idle </proc/uptime
  S_UP=${up%.*}
  S_ROOT_P=$(df --output=pcent / 2>/dev/null | tail -n1 | tr -dc '0-9')
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

sys_panel_cpu() {
  P_cpu=("$(ui_title "◉" "CPU")")
  P_cpu+=("$(ui_label Usage)$(ui_bar "$S_CPU") $(ui_pct "$S_CPU")")
  P_cpu+=("$(ui_label Cores)${c_cyan}${S_STRIP}${c_off}")
  P_cpu+=("$(ui_label Load)$S_L1 · $S_L5 · $S_L15 ${c_dim}· $S_THREADS threads${c_off}")
  P_cpu+=("$(ui_label Model)${c_dim}${S_MODEL:0:38}${c_off}")
}

sys_panel_memory() {
  P_memory=("$(ui_title "◫" "Memory")")
  P_memory+=("$(ui_label Used)$(ui_bar "$S_MEM_P") $(ui_pct "$S_MEM_P") ${c_dim}$(g3_bytes "$S_MEM_U")/$(g3_bytes "$S_MEM_T")${c_off}")
  if (( S_SWAP_T > 0 )); then
    P_memory+=("$(ui_label Swap)$(ui_bar "$S_SWAP_P") $(ui_pct "$S_SWAP_P") ${c_dim}$(g3_bytes "$S_SWAP_U")/$(g3_bytes "$S_SWAP_T")${c_off}")
  else
    P_memory+=("$(ui_label Swap)${c_dim}not configured${c_off}")
  fi
  P_memory+=("$(ui_label Free)$(g3_bytes "$S_MEM_A") ${c_dim}available${c_off}")
  P_memory+=("$(ui_label Cache)$(g3_bytes "$S_CACHE") ${c_dim}buffers & page cache${c_off}")
}

sys_panel_disk() {
  P_disk=("$(ui_title "▤" "Disk")")
  local mnt fs size used pct label
  declare -A seen=()
  while read -r mnt fs size used pct; do
    [[ -n ${seen[$mnt]:-} ]] && continue
    seen[$mnt]=1
    label=$mnt; [[ $mnt == "$HOME" ]] && label="~"
    pct=${pct%\%}
    P_disk+=("$(ui_label "${label:0:6}")$(ui_bar "$pct" 10) $(ui_pct "$pct") ${c_dim}$(g3_bytes "$used")/$(g3_bytes "$size") $fs${c_off}")
  done < <(df -B1 --output=target,fstype,size,used,pcent / "$HOME" 2>/dev/null | tail -n +2)
  P_disk+=("$(ui_label I/O)${c_dim}read${c_off} $(g3_bytes "$S_DR")/s ${c_dim}· write${c_off} $(g3_bytes "$S_DW")/s")
}

sys_panel_power() {
  P_power=("$(ui_title "◪" "Power")")
  local d type cap status bat="" ac=""
  for d in /sys/class/power_supply/*; do
    [[ -r $d/type ]] || continue
    read -r type <"$d/type"
    if [[ $type == Battery && -r $d/capacity && -z $bat ]]; then
      read -r cap <"$d/capacity"; read -r status <"$d/status" 2>/dev/null
      bat="$(ui_bar "$cap" 10) $(ui_pct "$cap") ${c_dim}· ${status,,}${c_off}"
    elif [[ $type == Mains && -r $d/online ]]; then
      read -r ac <"$d/online"
    fi
  done
  if [[ -n $bat ]]; then P_power+=("$(ui_label Batt)$bat")
  elif [[ $ac == 1 ]]; then P_power+=("$(ui_label Batt)${c_dim}none · on AC power${c_off}")
  else P_power+=("$(ui_label Batt)${c_dim}none${c_off}"); fi

  local gu gm gt gc
  if [[ $S_GPU == nvidia ]]; then
    IFS=', ' read -r gu gm gt gc < <(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu \
      --format=csv,noheader,nounits 2>/dev/null | head -n1)
    [[ $gu =~ ^[0-9]+$ ]] && P_power+=("$(ui_label GPU)$(ui_bar "$gu" 10) $(ui_pct "$gu") ${c_dim}· $(g3_bytes $(( gm * 1048576 )))/$(g3_bytes $(( gt * 1048576 ))) · ${gc}°C${c_off}")
  elif [[ $S_GPU == amd ]]; then
    local f
    for f in /sys/class/drm/card[0-9]/device/gpu_busy_percent; do read -r gu <"$f" 2>/dev/null && break; done
    [[ $gu =~ ^[0-9]+$ ]] && P_power+=("$(ui_label GPU)$(ui_bar "$gu" 10) $(ui_pct "$gu")")
  fi

  if [[ -n $S_TEMP ]]; then
    local tone=$c_green
    (( S_TEMP >= 70 )) && tone=$c_yellow; (( S_TEMP >= 85 )) && tone=$c_red
    P_power+=("$(ui_label Temp)${tone}${S_TEMP}°C${c_off} ${c_dim}hottest sensor${c_off}")
  else
    P_power+=("$(ui_label Temp)${c_dim}no sensors exposed${c_off}")
  fi
  P_power+=("$(ui_label Uptime)$(g3_duration "$S_UP")")
}

sys_panel_processes() {
  P_processes=("$(ui_title "≡" "Processes")")
  P_processes+=("$(ui_label Tasks)${S_TASKS#*/} ${c_dim}total · ${S_TASKS%/*} running${c_off}")
  local pcpu rss comm rank=0
  while read -r pcpu rss comm; do
    [[ $comm == ps ]] && continue   # ps always sees itself as busy
    rank=$(( rank + 1 ))
    P_processes+=("${c_dim}$rank${c_off}      $(ui_pad "${comm:0:16}" 17)$(ui_bar "${pcpu%.*}" 5) $(printf '%5s%%' "$pcpu") $(printf '%7s' "$(g3_bytes $(( rss * 1024 )))")")
    (( rank >= 3 )) && break
  done < <(ps -eo pcpu=,rss=,comm= --sort=-pcpu 2>/dev/null | head -n 5)
}

sys_panel_network() {
  P_network=("$(ui_title "⇅" "Network")")
  P_network+=("$(ui_label Down)${c_cyan}$(ui_pad "$(ui_spark "${S_RXH[@]}")" 16)${c_off} $(g3_bytes "$S_RX")/s")
  P_network+=("$(ui_label Up)${c_cyan}$(ui_pad "$(ui_spark "${S_TXH[@]}")" 16)${c_off} $(g3_bytes "$S_TX")/s")
  local w dev="" src="" prev=""
  if have ip; then
    for w in $(ip -o -4 route get 1.1.1.1 2>/dev/null); do
      [[ $prev == dev ]] && dev=$w
      [[ $prev == src ]] && src=$w
      prev=$w
    done
  fi
  P_network+=("$(ui_label Link)${dev:-offline}${src:+ ${c_dim}·${c_off} $src}")
  local v name addr
  for v in /sys/class/net/wg* /sys/class/net/tun* /sys/class/net/tailscale* /sys/class/net/ppp*; do
    [[ -e $v ]] || continue
    name=${v##*/}
    addr=$(ip -o -4 addr show dev "$name" 2>/dev/null | { read -r _ _ _ a _; printf '%s' "${a%/*}"; })
    P_network+=("$(ui_label VPN)$name${addr:+ ${c_dim}·${c_off} $addr}")
    break
  done
}
