#!/usr/bin/env bash
# setup.sh — `g3rm0n setup`: choose sections and AI providers, write the config.
# Setup never reads, prints or stores a key. For each provider it only records
# WHERE the credential already lives on this machine (file:<path> or env:<VAR>).

setup_usage() {
  cat <<EOF
${c_bold}g3rm0n setup${c_off} — choose what the dashboard shows

  g3rm0n setup              interactive: sections, AI providers, refresh interval
  g3rm0n setup --defaults   write a config with every section and every detected provider
  g3rm0n setup --show       print the current config and what was detected
  g3rm0n setup --reset      delete the config (back to built-in defaults)

Config file: $G3_CONFIG_FILE
EOF
}

# ui_checklist title result-array item... ; item = "id|label|note|1 or 0"
ui_checklist() {
  local title=$1
  local -n _sel=$2
  shift 2
  local -a ids=() labels=() notes=() on=()
  local it a b c d i n cur=0 key rest drawn=0 all
  for it in "$@"; do
    IFS='|' read -r a b c d <<<"$it"
    ids+=("$a") labels+=("$b") notes+=("$c") on+=("${d:-0}")
  done
  n=${#ids[@]}
  printf '\e[?25l'
  while :; do
    (( drawn )) && printf '\e[%dA' $(( n + 2 ))
    printf '%s\e[K\n' "${c_bold}${title}${c_off}"
    for (( i = 0; i < n; i++ )); do
      local box="[ ]" ptr=" "
      (( on[i] )) && box="[${c_green}x${c_off}]"
      (( i == cur )) && ptr="${c_cyan}›${c_off}"
      printf '  %s %s %s %s\e[K\n' "$ptr" "$box" "$(ui_pad "${labels[i]}" 18)" "${c_dim}${notes[i]}${c_off}"
    done
    printf '  %s\e[K\n' "${c_dim}↑/↓ move · space toggle · a all/none · enter save · q cancel${c_off}"
    drawn=1
    IFS= read -rsn1 key </dev/tty || { printf '\e[?25h'; return 1; }
    case $key in
      $'\e') IFS= read -rsn2 -t 0.05 rest </dev/tty
             # normal (\e[A) and application (\eOA) cursor-key modes
             case $rest in '[A'|OA) cur=$(( (cur - 1 + n) % n )) ;; '[B'|OB) cur=$(( (cur + 1) % n )) ;; esac ;;
      k) cur=$(( (cur - 1 + n) % n )) ;;
      j) cur=$(( (cur + 1) % n )) ;;
      ' ') on[cur]=$(( ! on[cur] )) ;;
      a) all=0
         for (( i = 0; i < n; i++ )); do (( on[i] )) || all=1; done
         for (( i = 0; i < n; i++ )); do on[i]=$all; done ;;
      '') break ;;
      q|Q) printf '\e[?25h'; return 1 ;;
    esac
  done
  printf '\e[?25h'
  _sel=()
  for (( i = 0; i < n; i++ )); do (( on[i] )) && _sel+=("${ids[i]}"); done
  return 0
}

setup_provider_note() { # id -> where its credential was found, or how to provide one
  local ref; ref=$(ai_detect "$1")
  case $ref in
    file:*) printf 'found · %s' "$(g3_tilde "${ref#file:}")" ;;
    keychain:*) printf 'found · macOS Keychain' ;;
    env:*)  printf 'found · %s%s' '$' "${ref#env:}" ;;
    *) if [[ -n ${AI_ENV[$1]:-} ]]; then printf 'not found · %s' "$(g3_export_hint "${AI_ENV[$1]%% *}")"
       else printf 'not found · sign in to %s' "${AI_NAME[$1]}"; fi ;;
  esac
}

setup_write() { # sections-string providers-string interval
  local id ref tmp
  mkdir -p "$G3_CONFIG_DIR"
  tmp=$(mktemp "$G3_CONFIG_DIR/.config.XXXXXX")
  {
    printf '# g3rm0n configuration — written by g3rm0n setup on %s\n' "$(date '+%Y-%m-%d %H:%M')"
    printf '# Safe to edit by hand. Credentials are referenced, never stored:\n'
    printf '#   <provider>.credentials = file:<path>   (a login file another CLI keeps)\n'
    printf '#   <provider>.credentials = env:<NAME>    (an API key exported in your shell)\n'
    printf '#   <provider>.credentials = keychain:<service>   (a login in the macOS Keychain)\n\n'
    printf 'sections = %s\n' "$1"
    printf 'interval = %s\n' "$3"
    printf 'providers = %s\n' "${2:-none}"
    for id in $2; do
      ref=$(ai_detect "$id")
      if [[ -z $ref ]]; then
        if [[ -n ${AI_ENV[$id]:-} ]]; then ref="env:${AI_ENV[$id]%% *}"; else ref="file:$(ai_default_file "$id")"; fi
      fi
      [[ $ref == file:* ]] && ref="file:$(g3_tilde "${ref#file:}")"
      printf '%s.credentials = %s\n' "$id" "$ref"
    done
    # keep settings setup doesn't manage (e.g. mouse = off), exactly as written
    if [[ -r $G3_CONFIG_FILE ]]; then
      grep -E '^[[:space:]]*[a-z][a-z0-9_.-]*[[:space:]]*=' "$G3_CONFIG_FILE" \
        | grep -vE '^[[:space:]]*(sections|interval|providers|[a-z0-9_-]+\.credentials)[[:space:]]*='
    fi
  } >"$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$G3_CONFIG_FILE"
}

setup_show() {
  printf '%s\n' "${c_bold}Config${c_off}  $G3_CONFIG_FILE"
  if [[ -r $G3_CONFIG_FILE ]]; then
    grep -v '^[[:space:]]*#' "$G3_CONFIG_FILE" | sed '/^$/d; s/^/  /'
  else
    printf '  %s\n' "${c_dim}none yet — built-in defaults: every section, every detected provider${c_off}"
  fi
  printf '\n%s\n' "${c_bold}Detected on this machine${c_off}"
  local id
  for id in "${G3_PROVIDERS[@]}"; do
    printf '  %s %s\n' "$(ui_pad "${AI_NAME[$id]}" 12)" "${c_dim}$(setup_provider_note "$id")${c_off}"
  done
  printf '\n  %s\n' "${c_dim}API keys must be exported in the shell that starts g3rm0n: $(g3_export_hint NAME)${c_off}"
  have curl && have jq || printf '\n  %s\n' "${c_yellow}AI panels need curl and jq${c_off}"
}

setup_run() {
  g3_config_load
  case ${1:-} in
    -h|--help|help) setup_usage; return ;;
    --show) setup_show; return ;;
    --reset)
      if [[ -e $G3_CONFIG_FILE ]]; then rm -f -- "$G3_CONFIG_FILE"; printf 'Removed %s\n' "$G3_CONFIG_FILE"
      else printf 'No config to remove.\n'; fi
      return ;;
    --defaults)
      local id found=()
      for id in "${G3_PROVIDERS[@]}"; do [[ -n $(ai_detect "$id") ]] && found+=("$id"); done
      setup_write "${G3_SECTIONS[*]}" "${found[*]}" 2
      printf 'Wrote %s\n' "$G3_CONFIG_FILE"
      setup_show
      return ;;
    "") ;;
    *) setup_usage; return 1 ;;
  esac

  [[ -t 0 && -t 1 ]] || die "setup is interactive; use 'g3rm0n setup --defaults' in scripts"

  printf '\n%s\n%s\n\n' "${c_bold}${c_magenta}g3rm0n setup${c_off}" \
    "${c_dim}Choose what your dashboard shows. Nothing is sent anywhere while you do.${c_off}"

  local s id
  local -a items=() sections=() providers=()
  for s in "${G3_SECTIONS[@]}"; do
    items+=("$s|${G3_SECTION_LABEL[$s]}|${G3_SECTION_NOTE[$s]}|$(g3_section_on "$s" && echo 1 || echo 0)")
  done
  ui_checklist "Sections" sections "${items[@]}" || { printf '\nCancelled — nothing changed.\n'; return 1; }

  if g3_has "${sections[*]}" ai-tokens || g3_has "${sections[*]}" ai-credits; then
    printf '\n%s\n' "${c_dim}AI providers: g3rm0n only references credentials that already exist here.${c_off}"
    items=()
    local want=${CFG[providers]:-auto} default
    for id in "${G3_PROVIDERS[@]}"; do
      g3_has "${sections[*]}" "ai-${AI_KIND[$id]}" || continue
      default=0
      if [[ $want == auto ]]; then [[ -n $(ai_detect "$id") ]] && default=1
      else g3_has "$want" "$id" && default=1; fi
      items+=("$id|${AI_NAME[$id]}|$(setup_provider_note "$id")|$default")
    done
    if (( ${#items[@]} )); then
      ui_checklist "AI providers" providers "${items[@]}" || { printf '\nCancelled — nothing changed.\n'; return 1; }
    fi
  fi

  local interval=${CFG[interval]:-2} answer
  printf '\n%s ' "Refresh every how many seconds? [${interval}]"
  IFS= read -r answer </dev/tty
  [[ $answer =~ ^[1-9][0-9]*$ ]] && interval=$answer

  setup_write "${sections[*]}" "${providers[*]}" "$interval"
  printf '\n%s Saved %s\n' "${c_green}✓${c_off}" "$G3_CONFIG_FILE"
  printf '  %s\n' "${c_dim}Run g3rm0n to open the dashboard. Keys were not read or stored.${c_off}"
}
