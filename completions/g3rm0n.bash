# bash completions for g3rm0n
_g3rm0n() {
  local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
  local sections="cpu memory disk power processes network ai-tokens ai-credits"
  if [[ ${COMP_WORDS[1]:-} == setup ]]; then
    (( COMP_CWORD == 2 )) && mapfile -t COMPREPLY < <(compgen -W "--defaults --show --reset --help" -- "$cur")
    return
  fi
  case $prev in
    -s|--sections|-f|--fold)
      # comma-separated list: complete the last item and keep the ones before it
      local done="" last=$cur words=$sections
      [[ $prev == -f || $prev == --fold ]] && words+=" all none"
      [[ $cur == *,* ]] && done=${cur%,*}, last=${cur##*,}
      mapfile -t COMPREPLY < <(compgen -P "$done" -W "$words" -- "$last")
      compopt -o nospace 2>/dev/null
      return ;;
    -i|--interval) return ;;
  esac
  if (( COMP_CWORD == 1 )); then
    mapfile -t COMPREPLY < <(compgen -W "setup version help --once --interval --sections --fold --no-mouse --no-ai --no-color" -- "$cur")
  else
    mapfile -t COMPREPLY < <(compgen -W "--once --interval --sections --fold --no-mouse --no-ai --no-color" -- "$cur")
  fi
}
complete -F _g3rm0n g3rm0n
