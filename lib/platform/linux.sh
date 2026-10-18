#!/usr/bin/env bash
# platform/linux.sh — the Linux backend: reads /proc and /sys directly.
#
# Implements the platform contract documented in ARCHITECTURE.md ("Platforms").
# Every function is read-only and fills the globals named in its comment.

plat_static() { # -> S_OS S_MODEL S_THREADS S_GPU
  S_OS=$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-Linux}")
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
  LX_PT=() LX_PI=()
  lx_cpu_read LX_PT LX_PI
}

lx_cpu_read() { # total_arr idle_arr — index 0 is all CPUs, then one per core
  local -n _tot=$1 _idl=$2
  local name user nice sys idle iow irq soft steal _rest
  _tot=() _idl=()
  while read -r name user nice sys idle iow irq soft steal _rest; do
    [[ $name == cpu* ]] || break
    _tot+=( $(( user + nice + sys + idle + iow + irq + soft + ${steal:-0} )) )
    _idl+=( $(( idle + iow )) )
  done </proc/stat
}

plat_cpu() { # -> S_CPU (0-100) and S_CORES (one activity glyph per core, at most 40)
  local -a tot=() idl=()
  local dt di n step k p strip=""
  lx_cpu_read tot idl
  dt=$(( tot[0] - LX_PT[0] )); di=$(( idl[0] - LX_PI[0] ))
  S_CPU=0; (( dt > 0 )) && S_CPU=$(( (dt - di) * 100 / dt ))
  n=$(( ${#tot[@]} - 1 )); step=1
  (( n > 40 )) && step=$(( (n + 39) / 40 ))   # keep the strip inside the panel
  for (( k = 1; k <= n; k += step )); do
    dt=$(( tot[k] - LX_PT[k] )); di=$(( idl[k] - LX_PI[k] ))
    p=0; (( dt > 0 )) && p=$(( (dt - di) * 100 / dt ))
    (( p > 100 )) && p=100; (( p < 0 )) && p=0
    strip+=${G3_SPARK[p * 7 / 100]}
  done
  S_CORES="${c_cyan}${strip}${c_off}"
  LX_PT=("${tot[@]}") LX_PI=("${idl[@]}")
}

plat_load() { # -> S_L1 S_L5 S_L15 S_TASKS ("running/total")
  read -r S_L1 S_L5 S_L15 S_TASKS _ </proc/loadavg
}

plat_mem() { # -> S_MEM_T S_MEM_A S_CACHE S_SWAP_T S_SWAP_F (bytes)
  local key val _u mt=0 ma=0 st=0 sf=0 bu=0 ca=0 sr=0
  while read -r key val _u; do
    case $key in
      MemTotal:) mt=$val ;; MemAvailable:) ma=$val ;; Buffers:) bu=$val ;;
      Cached:) ca=$val ;; SReclaimable:) sr=$val ;; SwapTotal:) st=$val ;; SwapFree:) sf=$val ;;
    esac
  done </proc/meminfo
  S_MEM_T=$(( mt * 1024 )) S_MEM_A=$(( ma * 1024 )) S_CACHE=$(( (bu + ca + sr) * 1024 ))
  S_SWAP_T=$(( st * 1024 )) S_SWAP_F=$(( sf * 1024 ))
}

plat_net_bytes() { # -> NET_RX NET_TX: bytes over every interface except loopback
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

plat_disk_bytes() { # -> DIO_R DIO_W: bytes over physical disks (partitions/loop/dm skipped)
  local maj min dev rd rdm sr rms wr wrm sw _rest
  DIO_R=0 DIO_W=0
  while read -r maj min dev rd rdm sr rms wr wrm sw _rest; do
    [[ -e /sys/block/$dev/device ]] || continue
    DIO_R=$(( DIO_R + sr * 512 )); DIO_W=$(( DIO_W + sw * 512 ))
  done </proc/diskstats
}

plat_temp() { # -> hottest sensor in °C, empty when the machine exposes none
  local f t hot=-1
  for f in /sys/class/thermal/thermal_zone*/temp /sys/class/hwmon/hwmon*/temp*_input; do
    [[ -r $f ]] || continue
    read -r t <"$f" 2>/dev/null || continue
    [[ $t =~ ^[0-9]+$ ]] || continue
    (( t / 1000 > hot && t < 150000 )) && hot=$(( t / 1000 ))
  done
  (( hot >= 0 )) && printf '%d' "$hot"
}

plat_uptime() { local up _idle; read -r up _idle </proc/uptime; S_UP=${up%.*}; }

plat_root_pct() { # -> S_ROOT_P and S_ROOT_LABEL: the volume the health score watches
  S_ROOT_P=$(df --output=pcent / 2>/dev/null | tail -n1 | tr -dc '0-9') S_ROOT_LABEL=/
}

plat_disks() { # -> lines "mount<TAB>fstype<TAB>size<TAB>used<TAB>pct" for / and $HOME
  df -B1 --output=target,fstype,size,used,pcent / "$HOME" 2>/dev/null | tail -n +2 \
    | while read -r mnt fs size used pct; do printf '%s\t%s\t%s\t%s\t%s\n' "$mnt" "$fs" "$size" "$used" "${pct%\%}"; done
}

plat_battery() { # -> BAT_CAP BAT_STATUS (empty without a battery) BAT_AC (1 on mains)
  local d type
  BAT_CAP="" BAT_STATUS="" BAT_AC=""
  for d in /sys/class/power_supply/*; do
    [[ -r $d/type ]] || continue
    read -r type <"$d/type"
    if [[ $type == Battery && -r $d/capacity && -z $BAT_CAP ]]; then
      read -r BAT_CAP <"$d/capacity"; read -r BAT_STATUS <"$d/status" 2>/dev/null
      BAT_STATUS=${BAT_STATUS,,}
    elif [[ $type == Mains && -r $d/online ]]; then
      read -r BAT_AC <"$d/online"
    fi
  done
}

plat_gpu() { # -> GPU_UTIL [GPU_MEM_U GPU_MEM_T bytes] [GPU_TEMP], empty when unknown
  local gu="" gm="" gt="" gc="" f
  GPU_UTIL="" GPU_MEM_U="" GPU_MEM_T="" GPU_TEMP=""
  if [[ $S_GPU == nvidia ]]; then
    IFS=', ' read -r gu gm gt gc < <(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu \
      --format=csv,noheader,nounits 2>/dev/null | head -n1)
    [[ $gu =~ ^[0-9]+$ ]] || return 0
    GPU_UTIL=$gu GPU_MEM_U=$(( gm * 1048576 )) GPU_MEM_T=$(( gt * 1048576 )) GPU_TEMP=$gc
  elif [[ $S_GPU == amd ]]; then
    for f in /sys/class/drm/card[0-9]/device/gpu_busy_percent; do read -r gu <"$f" 2>/dev/null && break; done
    [[ $gu =~ ^[0-9]+$ ]] && GPU_UTIL=$gu
  fi
  return 0
}

plat_top() { # -> up to 5 lines "pcpu rss_kb name", busiest first
  ps -eo pcpu=,rss=,comm= --sort=-pcpu 2>/dev/null | head -n 5
}

plat_link() { # -> LINK_DEV LINK_ADDR of the default route, empty when offline
  local w prev=""
  LINK_DEV="" LINK_ADDR=""
  have ip || return 0
  for w in $(ip -o -4 route get 1.1.1.1 2>/dev/null); do
    [[ $prev == dev ]] && LINK_DEV=$w
    [[ $prev == src ]] && LINK_ADDR=$w
    prev=$w
  done
}

plat_vpn() { # -> VPN_DEV VPN_ADDR of the first VPN-style interface, empty when none
  local v
  VPN_DEV="" VPN_ADDR=""
  for v in /sys/class/net/wg* /sys/class/net/tun* /sys/class/net/tailscale* /sys/class/net/ppp*; do
    [[ -e $v ]] || continue
    VPN_DEV=${v##*/}
    VPN_ADDR=$(ip -o -4 addr show dev "$VPN_DEV" 2>/dev/null | { read -r _ _ _ a _; printf '%s' "${a%/*}"; })
    return 0
  done
}

plat_mtime() { stat -c %Y "$1" 2>/dev/null; }   # file -> modification time (epoch)

# The OS credential store. Linux CLIs (Claude Code included) keep logins in files,
# so there is nothing to look up here.
plat_keychain_has()  { return 1; }   # service -> true when an item exists
plat_keychain_read() { return 1; }   # service -> the item's secret on stdout

plat_cleanup() { :; }
