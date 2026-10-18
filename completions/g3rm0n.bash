# bash completions for g3rm0n
_g3rm0n() {
  local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
  local sections="cpu memory disk power processes network ai-tokens ai-credits"
  if [[ ${COMP_WORDS[1]:-} == setup ]]; then
    mapfile -t COMPREPLY < <(compgen -W "--defaults --show --reset --help" -- "$cur")
    return
  fi
  case $prev in
    -s|--sections) mapfile -t COMPREPLY < <(compgen -W "$sections" -- "${cur##*,}"); return ;;
    -i|--interval) return ;;
  esac
  if (( COMP_CWORD == 1 )); then
    mapfile -t COMPREPLY < <(compgen -W "setup version help --once --interval --sections --no-ai --no-color" -- "$cur")
  else
    mapfile -t COMPREPLY < <(compgen -W "--once --interval --sections --no-ai --no-color" -- "$cur")
  fi
}
complete -F _g3rm0n g3rm0n
