#!/usr/bin/env bash
# Draw the README's sample screens with g3rm0n's own renderers and fixed sample data,
# so the README always shows exactly what the code draws.
#
#   scripts/readme-sample.sh full       the live dashboard, every panel open
#   scripts/readme-sample.sh folded     the same with some panels folded
#   scripts/readme-sample.sh --update   rewrite both blocks in README.md
#
# README.md marks each block with <!-- sample:full --> / <!-- sample:folded --> and
# <!-- /sample -->. tests/docs.sh fails when a block differs from this output, and
# scripts/bump-version.sh runs --update. Sample data only: never real machine data.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

draw() { # full|folded -> the screen on stdout
  local tmp utf8=C.UTF-8; tmp=$(mktemp -d)
  [[ $(uname -s) == Darwin ]] && utf8=en_US.UTF-8   # macOS has no C.UTF-8
  # shellcheck disable=SC2016  # expanded by the inner bash
  NO_COLOR=1 LC_ALL=$utf8 TZ=UTC HOME=$tmp XDG_CACHE_HOME=$tmp/cache XDG_STATE_HOME=$tmp/state \
    bash -c '
    set -euo pipefail
    root=$1 mode=$2
    for m in core ui panel fold input keymap header system ai dashboard; do source "$root/lib/$m.sh"; done
    g3_colors; g3_config_load

    # a sample workstation (fixed values; the platform functions are stand-ins)
    S_HOST=workstation S_OS="Ubuntu 24.04.1 LTS" S_KERNEL=6.8.0-45-generic
    H_DOT="●" H_SCORE=96 H_LABEL=Healthy
    S_CPU=24 S_CORES="▂▁▃▁▅▂▁▁▂▇▁▂▁▁▃▁" S_L1=1.12 S_L5=0.98 S_L15=0.87 S_THREADS=16
    S_MODEL="AMD Ryzen 7 7840U w/ Radeon 780M"
    S_MEM_T=33500744704 S_MEM_U=14925011763 S_MEM_A=18575732941 S_MEM_P=44 S_CACHE=10307921510
    S_SWAP_T=8589934592 S_SWAP_U=0 S_SWAP_P=0
    S_DR=1258291 S_DW=348160 S_ROOT_P=68 S_ROOT_LABEL=/
    S_TEMP=54 S_TEMP_SRC=CPU S_UP=281520 S_TASKS=2/412
    S_RX=2516582 S_TX=98304
    S_RXH=(1 1 2 5 9 3 1 1 1 2 1 1 1 1 1 1) S_TXH=(1 1 1 2 3 1 1 1 1 1 1 1 1 1 1 1)
    plat_disks()   { printf "/\text4\t501759434342\t335468209766\t68\n"; }
    plat_battery() { BAT_CAP=81 BAT_STATUS=discharging BAT_AC=""; }
    plat_gpu()     { GPU_UTIL=18 GPU_MEM_U="" GPU_MEM_T="" GPU_TEMP=""; }
    plat_top()     { printf "18.2 1992294 firefox\n7.5 831898 code\n3.1 246579 node\n"; }
    plat_link()    { LINK_DEV=wlp1s0 LINK_ADDR=192.168.1.24; }
    plat_vpn()     { VPN_DEV=tailscale0 VPN_ADDR=100.101.1.7; }
    plat_mtime()   { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }

    # sample AI usage, written to a throwaway cache (resets a little ahead, so the
    # rounded "resets in" text is the same however long drawing takes)
    mkdir -p "$AI_DIR"
    t=$(( EPOCHSECONDS + 30 ))
    printf "max 5x\t42\t18000\t%d\t17\t604800\t%d\n" $(( t + 8040 )) $(( t + 274200 )) >"$AI_DIR/claude.row"
    printf "plus\t12\t18000\t%d\t3\t604800\t%d\n" $(( t + 13860 )) $(( t + 496800 )) >"$AI_DIR/codex.row"
    printf "lite\t64\t18000\t%d\t10\tTools\t%d\n" $(( t + 3480 )) $(( t + 860400 )) >"$AI_DIR/zai.row"
    printf "CNY\t110.00\t-\t-\t-\t-\tSplit\ttopped up ¥100.00 · granted ¥10.00\n" >"$AI_DIR/deepseek.row"
    printf "USD\t8.2\t25\t0.42\t3.1\t12.5\tKey\tno spend cap\n" >"$AI_DIR/openrouter.row"
    for id in claude codex zai deepseek openrouter; do printf "200 %d 0\n" $(( t + 600 )) >"$AI_DIR/$id.status"; done

    AI_IDS=(claude codex zai deepseek openrouter)
    dash_register
    panel_render_all
    FOLD=()
    [[ $mode == folded ]] && fold_apply memory,power,processes,network,ai-credits
    COLS_NOW=96 UI_ROWS=200
    OUT=()
    hdr_render 96 "" 1791462840          # 2026-10-08 12:34 UTC
    OUT+=("$HDR_LINE" "")
    panel_compose 1 96
    [[ $mode == folded ]] && { while [[ ${#OUT[@]} -gt 0 && -z ${OUT[-1]} ]]; do unset "OUT[-1]"; done; }
    [[ $mode == full ]] && OUT+=("$(dash_footer 2)")
    printf "%s\n" "${OUT[@]}" | sed "s/[[:space:]]*$//"
  ' _ "$root" "$1"
  rm -rf "$tmp"
}

update() { # rewrite the sample blocks in README.md
  local mode block
  for mode in full folded; do
    block=$(draw "$mode")
    awk -v mode="$mode" -v block="$block" '
      $0 == "<!-- sample:" mode " -->" { print; print "```"; print block; print "```"; skip = 1; next }
      skip && $0 == "<!-- /sample -->" { skip = 0 }
      !skip { print }' "$root/README.md" >"$root/README.md.tmp"
    mv "$root/README.md.tmp" "$root/README.md"
  done
}

case ${1:-} in
  full|folded) draw "$1" ;;
  --update) update ;;
  *) sed -n '2,10p' "$0"; exit 2 ;;
esac
