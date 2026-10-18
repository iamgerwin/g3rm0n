#!/usr/bin/env bash
# platform/darwin.sh — the macOS backend: sysctl, vm_stat, iostat, netstat, ioreg, pmset.
#
# Implements the platform contract documented in ARCHITECTURE.md ("Platforms"), with
# the stock tools every Mac has and no root. Per-core load is something macOS only
# gives to root (powermetrics), so the Cores row shows the core layout instead.
#
# Temperatures come from the IOKit HID temperature sensors, the same unprivileged
# source iStat Menus and similar tools use on Apple silicon, read through JavaScript
# for Automation (osascript), which every Mac has. Intel Macs keep their sensors in
# the SMC, which needs more than a script, so they show "no sensors exposed".
#
# Two readings take time: CPU usage needs a measured window (macOS has no cumulative
# tick counter like /proc/stat; a 1-second `iostat`), and starting osascript takes a
# moment. Both run as background probes between frames, and each sample reads the
# last finished result, so they never block a frame (except the very first one).

plat_static() { # -> S_OS S_MODEL S_THREADS S_GPU, plus the backend's own constants
  S_OS="macOS $(sw_vers -productVersion 2>/dev/null)"
  S_MODEL=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
  S_THREADS=$(sysctl -n hw.logicalcpu 2>/dev/null || echo "?")
  DW_PAGE=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
  DW_MEM=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  local p e
  p=$(sysctl -n hw.perflevel0.logicalcpu 2>/dev/null) e=$(sysctl -n hw.perflevel1.logicalcpu 2>/dev/null)
  if [[ $p =~ ^[0-9]+$ && $e =~ ^[0-9]+$ ]]; then DW_CORES="$p performance · $e efficiency"
  else DW_CORES="$(sysctl -n hw.physicalcpu 2>/dev/null || echo "?") cores"; fi
  S_GPU=""
  dw_gpu_util >/dev/null && S_GPU=apple
  DW_RUN="$G3_CACHE_DIR/run.$$" S_CPU=0
  mkdir -p "$G3_CACHE_DIR" 2>/dev/null
  dw_probe cpu dw_iostat
  dw_probe temp dw_sensors
}

# ---- background probes -------------------------------------------------------

declare -gA DW_PID=()

dw_probe() { # name command... -> run it in the background, unless the last run is still going
  local f=$DW_RUN.$1
  [[ -n ${DW_PID[$1]:-} ]] && kill -0 "${DW_PID[$1]}" 2>/dev/null && return 0
  { "${@:2}" >"$f.tmp" 2>/dev/null && mv -f "$f.tmp" "$f"; } &
  DW_PID[$1]=$!
}

dw_probe_out() { # name -> path of its last finished result (the very first one is waited for)
  local f=$DW_RUN.$1
  [[ ! -e $f && -n ${DW_PID[$1]:-} ]] && wait "${DW_PID[$1]}" 2>/dev/null
  printf '%s' "$f"
}

dw_iostat() { have iostat && iostat -C -c 2 -w 1; }   # one 1-second CPU measurement

dw_cpu_parse() { # iostat output on stdin -> us+sy of the last line, found by the header
  awk 'NR == 2 { for (i = 1; i <= NF; i++) { if ($i == "us") u = i; if ($i == "sy") s = i } }
       NR > 2 { last = $0 }
       END { if (u && s) { split(last, f); printf "%d", f[u] + f[s] } }'
}

plat_cpu() { # -> S_CPU (0-100) and S_CORES (the core layout; per-core load needs root)
  local f v
  f=$(dw_probe_out cpu)
  if [[ -r $f ]]; then
    v=$(dw_cpu_parse <"$f")
    [[ $v =~ ^[0-9]+$ ]] && S_CPU=$(( v > 100 ? 100 : v ))
  fi
  dw_probe cpu dw_iostat
  S_CORES="${c_dim}${DW_CORES}${c_off}"
}

plat_load() { # -> S_L1 S_L5 S_L15 S_TASKS ("running/total")
  local _b
  read -r _b S_L1 S_L5 S_L15 _ < <(sysctl -n vm.loadavg 2>/dev/null)   # "{ 1.83 1.92 1.95 }"
  S_TASKS=$(ps -A -o state= 2>/dev/null | awk '{ n++ } /^R/ { r++ } END { printf "%d/%d", r, n }')
}

plat_mem() { # -> S_MEM_T S_MEM_A S_CACHE S_SWAP_T S_SWAP_F (bytes)
  # "used" follows Activity Monitor: app memory + wired + compressed
  local used cache
  read -r used cache < <(vm_stat 2>/dev/null | awk -v pg="$DW_PAGE" '
    { gsub(/\./, "", $NF) }
    /^Anonymous pages/ { anon = $NF } /^Pages purgeable/ { purg = $NF }
    /^Pages wired down/ { wired = $NF } /^Pages occupied by compressor/ { comp = $NF }
    /^Pages active/ { act = $NF } /^File-backed pages/ { file = $NF }
    END { app = anon ? anon - purg : act; printf "%.0f %.0f\n", (app + wired + comp) * pg, (file + purg) * pg }')
  S_MEM_T=$DW_MEM S_MEM_A=$(( DW_MEM - ${used:-0} )) S_CACHE=${cache:-0}
  (( S_MEM_A < 0 )) && S_MEM_A=0
  # "total = 2048.00M  used = 1123.50M  free = 924.50M  (encrypted)"
  read -r S_SWAP_T S_SWAP_F < <(sysctl -n vm.swapusage 2>/dev/null | awk '
    function b(v) { u = substr(v, length(v)); v += 0; return v * (u == "G" ? 1073741824 : u == "M" ? 1048576 : u == "K" ? 1024 : 1) }
    { printf "%.0f %.0f\n", b($3), b($9) }')
  S_SWAP_T=${S_SWAP_T:-0} S_SWAP_F=${S_SWAP_F:-0}
}

plat_net_bytes() { # -> NET_RX NET_TX: bytes over every interface except loopback
  read -r NET_RX NET_TX < <(netstat -ibn 2>/dev/null | awk '
    $3 ~ /^<Link#/ && $1 !~ /^lo/ { rx += $(NF-4); tx += $(NF-1) } END { printf "%.0f %.0f\n", rx, tx }')
  NET_RX=${NET_RX:-0} NET_TX=${NET_TX:-0}
}

plat_disk_bytes() { # -> DIO_R DIO_W: bytes read and written by every block storage driver
  read -r DIO_R DIO_W < <(ioreg -c IOBlockStorageDriver -r -w 0 2>/dev/null | awk '
    { while (match($0, /"Bytes \((Read|Write)\)"=[0-9]+/)) {
        s = substr($0, RSTART, RLENGTH); n = s; sub(/.*=/, "", n)
        if (s ~ /Read/) r += n; else w += n
        $0 = substr($0, RSTART + RLENGTH) } }
    END { printf "%.0f %.0f\n", r, w }')
  DIO_R=${DIO_R:-0} DIO_W=${DIO_W:-0}
}

# IOKit HID temperature sensors (usage page 0xff00, usage 5). JXA's ObjC bridge binds
# the IOHIDEventSystemClient functions; prints "name<TAB>°C" for each sensor.
# shellcheck disable=SC2016  # a JavaScript program: "$" is JXA's ObjC bridge
DW_SENSORS_JS='ObjC.import("Foundation"); ObjC.import("IOKit");
function run() {
  ObjC.bindFunction("IOHIDEventSystemClientCreate", ["id", ["void *"]]);
  ObjC.bindFunction("IOHIDEventSystemClientSetMatching", ["void", ["id", "id"]]);
  ObjC.bindFunction("IOHIDEventSystemClientCopyServices", ["id", ["id"]]);
  ObjC.bindFunction("IOHIDServiceClientCopyProperty", ["id", ["id", "id"]]);
  ObjC.bindFunction("IOHIDServiceClientCopyEvent", ["id", ["id", "long long", "int", "long long"]]);
  ObjC.bindFunction("IOHIDEventGetFloatValue", ["double", ["id", "int"]]);
  var client = $.IOHIDEventSystemClientCreate(null);
  if (!client || client.isNil()) return "#IOKit sensor client unavailable";
  $.IOHIDEventSystemClientSetMatching(client,
    $.NSDictionary.dictionaryWithObjectsForKeys($([65280, 5]), $(["PrimaryUsagePage", "PrimaryUsage"])));
  var list = $.IOHIDEventSystemClientCopyServices(client);
  if (!list || list.isNil()) return "#IOKit: no temperature sensor services";
  var out = [];
  for (var i = 0; i < list.count; i++) {
    var svc = list.objectAtIndex(i);
    var ev = $.IOHIDServiceClientCopyEvent(svc, 15, 0, 0);          /* 15: temperature */
    if (!ev || ev.isNil()) continue;
    var t = $.IOHIDEventGetFloatValue(ev, 15 << 16);
    var name = $.IOHIDServiceClientCopyProperty(svc, $("Product"));
    name = (name && !name.isNil()) ? ObjC.unwrap(name) : "sensor " + i;
    if (t > 0 && t < 130) out.push(name + "\t" + t.toFixed(1));
  }
  out.push("#IOKit: " + list.count + " sensor services, " + out.length + " readings");
  return out.join("\n");
}'

dw_sensors() { # -> "kind<TAB>°C<TAB>name" per sensor; kind is cpu for the CPU dies and clusters
  have osascript || return 0
  # "PMU tcal" is a fixed calibration value, not a temperature
  # a "#" line says what the script saw; it becomes a note for `g3rm0n sensors`
  osascript -l JavaScript <<<"$DW_SENSORS_JS" 2>&1 | awk -F'\t' '
    /^#/ { sub(/^#/, ""); printf "note\t-\t%s\n", $0; next }
    /execution error/ { printf "note\t-\tosascript: %s\n", $0; next }
    NF >= 2 && $1 !~ /tcal/ && $2 + 0 > 0 && $2 + 0 < 130 {
      kind = ($1 ~ /tdie|[pPeE]ACC|CPU|[Cc]ore/) ? "cpu" : "other"
      printf "%s\t%s\t%s\n", kind, $2, $1 }'
}

plat_sensors() { dw_sensors; }   # every readable sensor, now (for `g3rm0n sensors`)

plat_temp() { # -> sensor lines for this frame, from the last background reading
  local f; f=$(dw_probe_out temp)
  [[ -r $f ]] && cat "$f"
  dw_probe temp dw_sensors
  return 0
}

plat_uptime() { # -> S_UP seconds since boot ("{ sec = 1697040000, usec = 0 } ...")
  local boot; boot=$(sysctl -n kern.boottime 2>/dev/null)
  boot=${boot#*sec = }; boot=${boot%%,*}
  [[ $boot =~ ^[0-9]+$ ]] && S_UP=$(( EPOCHSECONDS - boot )) || S_UP=0
}

dw_df() { # paths... -> "mount<TAB>size<TAB>used<TAB>pct" (bytes), mount points may contain spaces
  df -kP "$@" 2>/dev/null | awk 'NR > 1 { m = $6; for (i = 7; i <= NF; i++) m = m " " $i
    sub(/%/, "", $5); printf "%s\t%.0f\t%.0f\t%s\n", m, $2 * 1024, $3 * 1024, $5 }'
}

plat_root_pct() { # -> S_ROOT_P S_ROOT_LABEL: the data volume, where your files live
  # (/ is a sealed, read-only system snapshot whose usage barely changes)
  local _m _s _u pct
  IFS=$'\t' read -r _m _s _u pct < <(dw_df "$HOME")
  S_ROOT_P=$pct S_ROOT_LABEL="~"
}

plat_disks() { # -> lines "label<TAB>fstype<TAB>size<TAB>used<TAB>pct" for / and your data volume
  local mnt size used pct fs home_mnt
  home_mnt=$(dw_df "$HOME" | cut -f1)
  while IFS=$'\t' read -r mnt size used pct; do
    fs=$(mount 2>/dev/null | awk -v m="$mnt" '{ i = index($0, " on " m " ("); if (i) { t = substr($0, i + length(m) + 6); sub(/[,)].*/, "", t); print t; exit } }')
    [[ $mnt == "$home_mnt" && $mnt != / ]] && mnt=$HOME
    printf '%s\t%s\t%s\t%s\t%s\n' "$mnt" "${fs:-apfs}" "$size" "$used" "$pct"
  done < <(dw_df / "$HOME")
}

plat_battery() { # -> BAT_CAP BAT_STATUS (empty without a battery) BAT_AC (1 on mains)
  # "Now drawing from 'AC Power'" / " -InternalBattery-0 (id=…)	81%; discharging; 3:10 remaining"
  local out re='([0-9]+)%; ([a-zA-Z ]+);'
  BAT_CAP="" BAT_STATUS="" BAT_AC=""
  out=$(pmset -g batt 2>/dev/null)
  [[ $out == *"'AC Power'"* ]] && BAT_AC=1
  if [[ $out =~ $re ]]; then BAT_CAP=${BASH_REMATCH[1]} BAT_STATUS=${BASH_REMATCH[2],,}; fi
  return 0
}

dw_gpu_util() { # -> Apple GPU utilization in percent (fails when the GPU doesn't report it)
  local v
  v=$(ioreg -r -d 1 -w 0 -c IOAccelerator 2>/dev/null | grep -o '"Device Utilization %"=[0-9]*' | head -n1)
  v=${v##*=}
  [[ $v =~ ^[0-9]+$ ]] && printf '%s' "$v"
}

plat_gpu() { # -> GPU_UTIL (unified memory and temperature aren't reported per GPU)
  GPU_UTIL="" GPU_MEM_U="" GPU_MEM_T="" GPU_TEMP=""
  [[ $S_GPU == apple ]] && GPU_UTIL=$(dw_gpu_util)
  return 0
}

plat_top() { # -> up to 5 lines "pcpu rss_kb name", busiest first (-c: name, not full path)
  ps -A -r -c -o pcpu=,rss=,comm= 2>/dev/null | head -n 5
}

plat_link() { # -> LINK_DEV LINK_ADDR of the default route, empty when offline
  LINK_DEV=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2; exit }')
  LINK_ADDR=""
  [[ -n $LINK_DEV ]] && LINK_ADDR=$(ipconfig getifaddr "$LINK_DEV" 2>/dev/null)
  return 0
}

plat_vpn() { # -> VPN_DEV VPN_ADDR: the first tunnel interface with an IPv4 address
  # macOS keeps several utun interfaces for its own services; only an IPv4 one is a VPN
  read -r VPN_DEV VPN_ADDR < <(ifconfig 2>/dev/null | awk '
    /^[a-z]/ { dev = $1; sub(/:$/, "", dev) }
    /^[[:space:]]+inet / && dev ~ /^(utun|ppp|ipsec|wg|tun)/ { print dev, $2; exit }')
  return 0
}

plat_mtime() { stat -f %m "$1" 2>/dev/null; }   # file -> modification time (epoch)

# The macOS Keychain, where Claude Code keeps its login. Checking that an item exists
# reads its attributes only (no secret, no prompt). Reading the secret happens only
# when its provider is called; macOS may ask once to allow it ("Always Allow").
plat_keychain_has()  { have security && security find-generic-password -s "$1" >/dev/null 2>&1; }
plat_keychain_read() { have security && security find-generic-password -s "$1" -w 2>/dev/null; }

plat_cleanup() { # stop the background probes and remove their files
  local p
  for p in "${DW_PID[@]}"; do kill "$p" 2>/dev/null; done
  [[ -n ${DW_RUN:-} ]] && rm -f "$DW_RUN".* 2>/dev/null
  return 0
}
