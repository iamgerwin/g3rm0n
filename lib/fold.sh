#!/usr/bin/env bash
# fold.sh — fold state: which panels are collapsed to their title line.
#
# State is keyed by panel id (see panel.sh). The live dashboard remembers it between
# runs in $G3_STATE_DIR/folded, one line of space-separated panel ids. That file holds
# layout only, never usage numbers or credentials.

declare -gA FOLD=()
G3_FOLD_FILE="$G3_STATE_DIR/folded"

fold_is() { [[ ${FOLD[$1]:-0} == 1 ]]; }

fold_set() { # id 0|1
  if (( $2 )); then FOLD[$1]=1; else unset 'FOLD[$1]'; fi
}

fold_toggle() { if fold_is "$1"; then fold_set "$1" 0; else fold_set "$1" 1; fi; }

fold_group() { # 0|1 id... -> fold or unfold every id
  local on=$1 id; shift
  for id in "$@"; do fold_set "$id" "$on"; done
}

fold_group_toggle() { # id... -> fold all of them, or unfold all if all are folded
  local id all=1
  for id in "$@"; do fold_is "$id" || all=0; done
  fold_group $(( ! all )) "$@"
}

fold_ids() { # -> folded panel ids, sorted, one line
  local -a ids=("${!FOLD[@]}")
  (( ${#ids[@]} )) || return 0
  printf '%s\n' "${ids[@]}" | sort | tr '\n' ' ' | sed 's/ $//'
}

# fold_apply <list>: "all", "none", or section names / panel ids, comma or space separated
fold_apply() {
  local w id
  for w in ${1//,/ }; do
    case $w in
      none) FOLD=() ;;
      all)  for id in "${PANEL_IDS[@]}"; do fold_set "$id" 1; done ;;
      *)    for id in "${PANEL_IDS[@]}"; do
              [[ $id == "$w" || ${PANEL_SECTION[$id]} == "$w" ]] && fold_set "$id" 1
            done ;;
    esac
  done
}

fold_load() {
  FOLD=()
  [[ -r $G3_FOLD_FILE ]] || return 0
  local line id
  IFS= read -r line <"$G3_FOLD_FILE" || [[ -n $line ]] || return 0
  for id in $line; do
    [[ $id =~ ^[a-z][a-z0-9-]*$ ]] && FOLD[$id]=1
  done
}

fold_save() {
  local tmp
  mkdir -p "$G3_STATE_DIR" 2>/dev/null || return 0
  tmp=$(mktemp "$G3_STATE_DIR/.folded.XXXXXX" 2>/dev/null) || return 0
  if fold_ids >"$tmp" && mv -f "$tmp" "$G3_FOLD_FILE"; then return 0; fi
  rm -f "$tmp"
}
