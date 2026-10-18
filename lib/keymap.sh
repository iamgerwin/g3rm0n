#!/usr/bin/env bash
# keymap.sh — key bindings for the live dashboard, as data.
#
# Each binding maps a key to an action (a command name plus an optional argument).
# The dashboard dispatches actions by name (dash_do), so adding a shortcut is one
# line here, and README's "Keys" table is checked against KEYMAP_HELP by tests/docs.sh.
#
# Actions:  quit · refresh · section <name> · fold-all · unfold-all · panel <id>

declare -gA KEYMAP=(
  [q]=quit [Q]=quit
  [r]=refresh [' ']=refresh
  [-]=fold-all [_]=fold-all
  [+]=unfold-all [=]=unfold-all
)
# section shortcuts follow the section order: 1 = first section, 2 = second, ...
keymap_init() {
  local i
  for (( i = 0; i < ${#G3_SECTIONS[@]} && i < 9; i++ )); do
    KEYMAP[$(( i + 1 ))]="section ${G3_SECTIONS[i]}"
  done
}

keymap_key_for_section() { # section -> its digit
  local i
  for (( i = 0; i < ${#G3_SECTIONS[@]}; i++ )); do
    [[ ${G3_SECTIONS[i]} == "$1" ]] && { printf '%d' $(( i + 1 )); return; }
  done
}

keymap_action() { # key -> action ("refresh" for unbound keys, as before folding existed)
  printf '%s' "${KEYMAP[$1]:-refresh}"
}

# key label | what it does — rendered by `g3rm0n help` and mirrored in the README
KEYMAP_HELP=(
  "1-${#G3_SECTIONS[@]}|fold or unfold a section (the digit is shown on each panel title)"
  "click|fold or unfold one panel (click its title)"
  "- / +|fold everything / unfold everything"
  "r, space|refresh now"
  "q|quit"
)

keymap_init
