#!/usr/bin/env bash
# input.sh — terminal input adapter: raw bytes in, normalized events out.
#
# Mouse support uses the xterm SGR mouse protocol (DECSET 1000 + 1006), the standard
# that terminals on Linux, macOS and Windows (Windows Terminal, WSL, iTerm2,
# Terminal.app, GNOME Terminal, Konsole, kitty, Alacritty, WezTerm, tmux with
# `mouse on`) all speak. No library is involved.
#
# Events (IN_EVENT), one per call:
#   key <char>        a printable key ("key enter", "key esc", "key up" ... for specials)
#   click <col> <row> left button pressed at 1-based screen coordinates
#   wheel up|down     scroll wheel
#   none              timeout, or input that means nothing to g3rm0n

IN_TTY=${G3_TTY:-/dev/tty}

in_mouse_on()  { printf '\e[?1000h\e[?1006h'; }   # report presses, in SGR encoding
in_mouse_off() { printf '\e[?1006l\e[?1000l'; }

# in_decode <raw> -> IN_EVENT. Pure: no I/O, so it can be tested with plain strings.
in_decode() {
  local raw=$1 b x y
  IN_EVENT=none
  case $raw in
    "") IN_EVENT="key enter" ;;
    $'\e') IN_EVENT="key esc" ;;
    $'\e[<'*[Mm])
      local re=$'^\e\\[<([0-9]+);([0-9]+);([0-9]+)([Mm])$'
      [[ $raw =~ $re ]] || return 0
      b=${BASH_REMATCH[1]} x=${BASH_REMATCH[2]} y=${BASH_REMATCH[3]}
      [[ ${BASH_REMATCH[4]} == M ]] || return 0          # ignore releases
      (( b & 32 )) && return 0                           # ignore drags
      if (( b & 64 )); then
        (( b & 1 )) && IN_EVENT="wheel down" || IN_EVENT="wheel up"
      elif (( (b & 3) == 0 )); then
        IN_EVENT="click $x $y"
      fi ;;
    $'\e['A|$'\eO'A) IN_EVENT="key up" ;;
    $'\e['B|$'\eO'B) IN_EVENT="key down" ;;
    $'\e'*) ;;                                           # other escape sequences
    ?) IN_EVENT="key $raw" ;;
  esac
}

# in_read <timeout> -> IN_EVENT. Reads one key or one complete escape sequence.
in_read() {
  local c="" rest="" ch i
  IN_EVENT=none
  IFS= read -rsn1 -t "$1" c <"$IN_TTY" 2>/dev/null || { [[ -n $c ]] || return 0; }
  if [[ $c == $'\e' ]]; then
    # the rest of a sequence arrives together; stop at its final byte
    for (( i = 0; i < 32; i++ )); do
      IFS= read -rsn1 -t 0.02 ch <"$IN_TTY" 2>/dev/null || break
      rest+=$ch
      (( i > 0 )) && [[ $ch == [A-Za-z~] ]] && break
      [[ $i == 0 && $ch != [\[O] ]] && break
    done
  fi
  in_decode "$c$rest"
}
