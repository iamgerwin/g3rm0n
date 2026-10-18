#!/usr/bin/env bash
# Interaction tests: folding, key bindings and mouse clicks.
#   1. unit checks of the pure pieces (input decoding, keymap, fold state, titles,
#      panel layout and hit-testing), sourced straight from lib/
#   2. the live dashboard in a pseudo-terminal (script(1)), driven by real key
#      presses and SGR mouse sequences
# No network, no real credentials, nothing outside a temp directory is touched.
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=tests/lib/common.sh
source "$root/tests/lib/common.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0 fail=0 skip=0
check() { # description command...
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then pass=$(( pass + 1 )); printf '  ok    %s\n' "$desc"
  else fail=$(( fail + 1 )); printf '  FAIL  %s\n' "$desc"; show_on_fail "${out:-}"; fi
}
is() { [[ $1 == "$2" ]]; }                         # actual expected
unfolded() { ! fold_is "$1"; }
no_hit() { ! panel_at "$@" >/dev/null; }
contains() { grep -qF -- "$2" <<<"$1"; }
lacks()    { ! grep -qF -- "$2" <<<"$1"; }

export HOME=$tmp/home XDG_CONFIG_HOME=$tmp/config XDG_CACHE_HOME=$tmp/cache XDG_STATE_HOME=$tmp/state
export PATH="$root/tests/mock:$PATH" NO_COLOR=1
unset CLAUDE_CONFIG_DIR CODEX_HOME GLM_API_KEY ZAI_API_KEY Z_AI_API_KEY DEEPSEEK_API_KEY OPENROUTER_API_KEY
mkdir -p "$HOME"
state=$XDG_STATE_HOME/g3rm0n/folded

echo "g3rm0n interaction tests"

# ---- 1. unit checks ---------------------------------------------------------------
# shellcheck source=/dev/null
for m in core ui panel fold input keymap dashboard; do source "$root/lib/$m.sh"; done
g3_colors

ev() { in_decode "$1"; printf '%s' "$IN_EVENT"; }
check "decode: left click"            is "$(ev $'\e[<0;12;5M')" "click 12 5"
check "decode: release is ignored"    is "$(ev $'\e[<0;12;5m')" "none"
check "decode: drag is ignored"       is "$(ev $'\e[<32;12;5M')" "none"
check "decode: right click ignored"   is "$(ev $'\e[<2;12;5M')" "none"
check "decode: wheel up"              is "$(ev $'\e[<64;1;1M')" "wheel up"
check "decode: wheel down"            is "$(ev $'\e[<65;1;1M')" "wheel down"
check "decode: plain key"             is "$(ev q)" "key q"
check "decode: enter"                 is "$(ev '')" "key enter"
check "decode: lone escape"           is "$(ev $'\e')" "key esc"
check "decode: arrow (normal mode)"   is "$(ev $'\e[A')" "key up"
check "decode: arrow (app mode)"      is "$(ev $'\eOB')" "key down"
check "decode: other sequence"        is "$(ev $'\e[15~')" "none"
check "decode: malformed mouse"       is "$(ev $'\e[<0;x;5M')" "none"

check "keymap: 1 is the first section"   is "$(keymap_action 1)" "section ${G3_SECTIONS[0]}"
check "keymap: last digit is ai-credits" is "$(keymap_action ${#G3_SECTIONS[@]})" "section ai-credits"
check "keymap: q quits"                  is "$(keymap_action q)" "quit"
check "keymap: unbound key refreshes"    is "$(keymap_action x)" "refresh"
check "keymap: section digit lookup"     is "$(keymap_key_for_section network)" "6"

panel_reset
for id in cpu memory ai-claude ai-codex; do
  panel_register "$id" "$( [[ $id == ai-* ]] && echo ai-tokens || echo "$id")" x "*" "$id" true
done
FOLD=()
fold_toggle cpu
check "fold: toggle folds"            fold_is cpu
fold_toggle cpu
check "fold: toggle again unfolds"    unfolded cpu
fold_set ai-claude 1
fold_group_toggle ai-claude ai-codex
check "fold: mixed group folds all"   is "$(fold_ids)" "ai-claude ai-codex"
fold_group_toggle ai-claude ai-codex
check "fold: folded group unfolds"    is "$(fold_ids)" ""
fold_apply ai-tokens
check "fold: a section name folds its panels" is "$(fold_ids)" "ai-claude ai-codex"
fold_apply none; fold_apply all
check "fold: all"                     is "$(fold_ids)" "ai-claude ai-codex cpu memory"
fold_apply none; fold_apply cpu,memory
check "fold: comma list"              is "$(fold_ids)" "cpu memory"
fold_save; FOLD=(); fold_load
check "fold: state survives save and load" is "$(fold_ids)" "cpu memory"
# shellcheck disable=SC2016  # a literal $(...) is the attack being tested
printf 'cpu $(touch %s/pwned) ../x MEMORY ai-codex\n' "$tmp" >"$state"; fold_load
check "fold: state file is parsed, never run" bash -c "[[ ! -e '$tmp/pwned' ]]"
check "fold: invalid ids in state are dropped" is "$(fold_ids)" "ai-codex cpu"

w() { local s; s=$(ui_title "$@"); ui_len "$s"; }
check "title: plain is 46 wide"            is "$(w '◉' CPU)" 46
check "title: live marker + key is 46"     is "$(w '◉' CPU ▾ '' 1)" 46
check "title: folded summary is 46"        is "$(w '◉' CPU ▸ '24% · load 1.12' 1)" 46
check "title: long summary is dropped"     lacks "$(ui_title '✦' 'AI Tokens · OpenRouter' ▸ 'far too long a summary to fit here' 7)" "far too"
check "title: plain title unchanged"       is "$(ui_title '◉' CPU)" "◉ CPU ────────────────────────────────────────"

# layout and hit-testing with four fake panels: two system, two AI
fake() { PANEL_BODY=("row a" "row b" "row c"); PANEL_SUM="sum"; }
panel_reset
panel_register cpu cpu system "◉" CPU fake
panel_register memory memory system "◫" Memory fake
panel_register ai-claude ai-tokens tokens "✦" "AI Tokens · Claude" fake
panel_register ai-codex ai-tokens tokens "✦" "AI Tokens · Codex" fake
FOLD=(); panel_render_all
OUT=(); panel_compose 1 100
check "grid: two columns at 100"   is "$(panel_at 3 1)" "cpu"
check "grid: right title is hit"   is "$(panel_at 50 1)" "memory"
check "grid: body rows aren't titles" no_hit 3 2
check "grid: the gap isn't a title"   no_hit 47 1
check "grid: second group row"     is "$(panel_at 60 6)" "ai-codex"
fold_set cpu 1; OUT=(); panel_compose 1 100
check "grid: folded panel shows its summary" contains "${OUT[0]}" "▸ ◉ CPU · sum"
check "grid: unfolded shows marker and key"  contains "${OUT[0]}" "▾ ◫ Memory"
OUT=(); panel_compose 1 60
check "grid: folded panel is one line"  is "${OUT[1]}" ""
check "grid: one column below 94 cols"  is "$(panel_at 3 3)" "memory"
check "grid: next panel follows the fold" is "${OUT[2]}" "$(ui_title "◫" Memory ▾ "" 2)"
fold_set cpu 0; OUT=(); panel_compose 0 100
check "grid: one-shot output has no markers" lacks "${OUT[*]}" "▾"

# dispatch: only "quit" ends the dashboard; a click that hits no title does nothing
fold_set cpu 0; OUT=(); panel_compose 1 100
survives() { # IN_EVENT -> true when the event leaves the dashboard running
  DASH_QUIT=0 IN_EVENT=$1
  dash_event || return 1
  (( DASH_QUIT == 0 ))
}
quits() { DASH_QUIT=0 IN_EVENT=$1; dash_event; (( DASH_QUIT == 1 )); }
check "dispatch: q quits"                         quits "key q"
for e in "click 3 2" "click 3 5" "click 47 1" "click 99 1" "click 3 999" "click 0 0" "wheel up" "wheel down" "none" "key x" "key enter"; do
  check "dispatch: '$e' keeps the dashboard running" survives "$e"
done
FOLD=(); survives "click 3 1"
check "dispatch: a click on a title folds it"     fold_is cpu
fold_set cpu 0

# ---- 2. the live dashboard in a pseudo-terminal ---------------------------------------
if ! command -v script >/dev/null 2>&1; then
  skip=$(( skip + 1 )); printf '  skip  live dashboard: script(1) not installed\n'
else
  live() { # "args" key... : run the live dashboard at 100x50 and type the keys
    local args=$1; shift
    { sleep 1.2; local k; for k in "$@"; do printf '%b' "$k"; sleep 0.5; done; sleep 0.3; } \
      | pty_run bash "stty cols 100 rows 50; '$root/g3rm0n' --no-ai -i 30 $args" 2>&1
  }
  rm -f "$state"
  # row 3 is the first panel title (header + blank line); column 5 is inside it
  out=$(live "" 2 '\e[<0;5;3M\e[<0;5;3m' q)
  check "live: digit folds its section"      contains "$out" "▸ ◫ Memory"
  check "live: clicking a title folds it"     contains "$out" "▸ ◉ CPU"
  check "live: fold state is remembered"      is "$(cat "$state")" "cpu memory"
  check "live: mouse reporting turned on"     contains "$out" $'\e[?1000h\e[?1006h'
  check "live: mouse reporting turned off"    contains "$out" $'\e[?1006l\e[?1000l'
  check "live: screen restored on quit"       contains "$out" $'\e[?1049l'
  out=$(live "" q)
  check "live: folds restored on next start"  contains "$out" "▸ ◉ CPU"
  out=$(live "" + q)
  check "live: + unfolds everything"          is "$(cat "$state")" ""
  out=$(live "" - q)
  check "live: - folds everything"            is "$(cat "$state")" "cpu disk memory network power processes"
  out=$(live "--fold none" q)
  check "live: --fold none starts unfolded"   is "$(cat "$state")" ""
  out=$(live "--no-mouse" q)
  check "live: --no-mouse leaves the mouse alone" lacks "$out" $'\e[?1000h'
  mkdir -p "$XDG_CONFIG_HOME/g3rm0n"; printf 'mouse = off\n' >"$XDG_CONFIG_HOME/g3rm0n/config"
  out=$(live "" q)
  check "live: mouse = off in config"         lacks "$out" $'\e[?1000h'
  rm -f "$XDG_CONFIG_HOME/g3rm0n/config"
  # clicks beside the titles (a body row, the gap, empty space, past the panels),
  # right clicks and the wheel are ignored; the dashboard keeps going until "2" and "q"
  rm -f "$state"
  out=$(live "" '\e[<0;10;6M\e[<0;10;6m' '\e[<0;47;3M' '\e[<0;60;45M' '\e[<0;200;200M' \
                '\e[<2;5;3M' '\e[<64;5;8M' '\e[<65;5;8M' 2 q)
  check "live: clicks off the titles don't quit"  contains "$out" "▸ ◫ Memory"
  check "live: ... nor fold anything"             is "$(cat "$state")" "memory"
  out=$(live "" '\x03')
  check "live: Ctrl-C restores the terminal"  contains "$out" $'\e[?1000l\e[?1049l'
fi

# ---- updating g3rm0n while it runs -------------------------------------------------------
check "update while running: g3rm0n ends with main and exit on one line" test "$(tail -n 1 "$root/g3rm0n")" = 'main "$@"; exit'
# bash reads a script as it runs it; an update or git pull that rewrites g3rm0n in place
# must not make the running copy parse the new file when it exits
if command -v script >/dev/null 2>&1; then
  mkdir -p "$tmp/live"; cp -R "$root/g3rm0n" "$root/lib" "$tmp/live/"
  out=$( { sleep 1.2
           # rewrite the running file in place (same inode), longer than before
           { printf '#!/usr/bin/env bash\n'; for _ in $(seq 1 40); do printf '# padding %s\n' "$(printf 'x%.0s' $(seq 1 60))"; done
             tail -n +2 "$root/g3rm0n"; } >"$tmp/live/g3rm0n.new"
           cat "$tmp/live/g3rm0n.new" >"$tmp/live/g3rm0n"
           sleep 0.5; printf q; sleep 0.5; } \
         | pty_run bash "stty cols 100 rows 50; '$tmp/live/g3rm0n' --no-ai -i 30; echo EXIT=\$?" 2>&1)
  check "update while running: exits cleanly"     contains "$out" "EXIT=0"
  check "update while running: no parse errors"   bash -c "! grep -qiE 'syntax error|command not found|unexpected' <<<\"\$1\"" _ "$out"
fi

# ---- one-shot output with --fold -------------------------------------------------------
out=$("$root/g3rm0n" --once --no-ai --fold all 2>&1)
# folded titles can sit in either column, depending on the width the runner reports
check "once: --fold all leaves one line per panel" bash -c "(( \$(grep -o '▸ ' <<<\"\$1\" | wc -l) == 6 )) && ! grep -q 'Usage' <<<\"\$1\"" _ "$out"
out=$("$root/g3rm0n" --once --no-ai -f memory 2>&1)
check "once: -f folds one section"          bash -c "grep -q '▸ ◫ Memory · ' <<<\"\$1\" && grep -q '^Usage' <<<\"\$1\"" _ "$out"
out=$("$root/g3rm0n" --once --no-ai 2>&1)
check "once: saved folds don't leak into scripts" lacks "$out" "▸"

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
(( fail == 0 ))
