#!/usr/bin/env bash
# panel.sh — panel registry and composition.
#
# Every panel on screen is registered once with an id, the section it belongs to, the
# grid group it pairs within, an icon, a title and a renderer:
#
#   panel_register <id> <section> <group> <icon> <title> <renderer> [arg]
#
# A renderer fills the global array PANEL_BODY with the panel's rows (no title) and
# may set PANEL_SUM to a short one-line summary that is shown in the title while the
# panel is folded. It is called as: <renderer> [arg]
#
# panel_render_all runs every renderer and keeps the results (the "sample" step).
# panel_compose builds the visible frame from those results and the fold state (the
# "render" step), so folding, unfolding and resizing never re-sample the machine.

declare -ga PANEL_IDS=()
declare -gA PANEL_SECTION=() PANEL_GROUP=() PANEL_ICON=() PANEL_TITLE=()
declare -gA PANEL_FN=() PANEL_ARG=() PANEL_SUMMARY=() PANEL_OF_VIEW=()
declare -ga PANEL_BODY=() UI_HITS=()
PANEL_SUM=""

panel_register() {
  local id=$1
  [[ -n ${PANEL_FN[$id]:-} ]] || PANEL_IDS+=("$id")
  PANEL_SECTION[$id]=$2 PANEL_GROUP[$id]=$3 PANEL_ICON[$id]=$4 PANEL_TITLE[$id]=$5
  PANEL_FN[$id]=$6 PANEL_ARG[$id]=${7:-}
}

panel_reset() {
  PANEL_IDS=() PANEL_SECTION=() PANEL_GROUP=() PANEL_ICON=() PANEL_TITLE=()
  PANEL_FN=() PANEL_ARG=() PANEL_SUMMARY=() PANEL_OF_VIEW=()
}

panel_var() { local v=${1//[^a-zA-Z0-9]/_}; printf '%s' "$v"; }   # id -> array-safe name

panel_in_section() { # section -> ids of its registered panels
  local id
  for id in "${PANEL_IDS[@]}"; do [[ ${PANEL_SECTION[$id]} == "$1" ]] && printf '%s\n' "$id"; done
}

panel_render_all() { # run every renderer; body rows land in PB_<id>
  local id v
  for id in "${PANEL_IDS[@]}"; do
    PANEL_BODY=() PANEL_SUM=""
    "${PANEL_FN[$id]}" ${PANEL_ARG[$id]:+"${PANEL_ARG[$id]}"}
    v=${id//[^a-zA-Z0-9]/_}
    declare -ga "PB_$v=()"
    local -n _body="PB_$v"
    _body=("${PANEL_BODY[@]}")
    unset -n _body
    PANEL_SUMMARY[$id]=$PANEL_SUM
  done
}

# panel_compose <live 0|1> <cols> -> appends the grid to OUT; UI_HITS maps title rows to panels
panel_compose() {
  local live=$1 cols=$2 id v marker key title
  local -a items=()
  UI_HITS=() PANEL_OF_VIEW=()
  for id in "${PANEL_IDS[@]}"; do
    v=${id//[^a-zA-Z0-9]/_}
    declare -ga "PV_$v=()"
    # shellcheck disable=SC2178  # namerefs, re-pointed at this panel's arrays each pass
    local -n _view="PV_$v" _body="PB_$v"
    marker="" key=""
    if (( live )); then
      key=$(keymap_key_for_section "${PANEL_SECTION[$id]}")
      if fold_is "$id"; then marker="▸"; else marker="▾"; fi
    elif fold_is "$id"; then
      marker="▸"
    fi
    if fold_is "$id"; then
      title=$(ui_title "${PANEL_ICON[$id]}" "${PANEL_TITLE[$id]}" "$marker" "${PANEL_SUMMARY[$id]}" "$key")
      _view=("$title")
    else
      title=$(ui_title "${PANEL_ICON[$id]}" "${PANEL_TITLE[$id]}" "$marker" "" "$key")
      _view=("$title" "${_body[@]}")
    fi
    unset -n _view _body
    PANEL_OF_VIEW[PV_$v]=$id
    items+=("${PANEL_GROUP[$id]}:PV_$v")
  done
  ui_grid "$cols" "${items[@]}"
}

panel_at() { # col row (1-based screen) -> id of the panel whose title is there
  local hit r c0 c1 view
  for hit in "${UI_HITS[@]}"; do
    read -r r c0 c1 view <<<"$hit"
    if (( $2 == r + 1 && $1 > c0 && $1 <= c1 + 1 )); then
      printf '%s' "${PANEL_OF_VIEW[$view]}"
      return 0
    fi
  done
  return 1
}
