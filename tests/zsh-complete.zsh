#!/usr/bin/env zsh
# Print the completions zsh offers for a command line, one per line.
#   zsh tests/zsh-complete.zsh 'g3rm0n --s'
# Starts a throwaway interactive zsh in a pseudo-terminal (zpty) with a temporary
# ZDOTDIR and no global rc files, loads completions/_g3rm0n, presses TAB and prints
# every candidate. Set G3C_DEBUG=1 to see the raw terminal output on stderr.
zmodload zsh/zpty || exit 2
local root=${0:A:h:h} line=$1 out zdot
zdot=$(mktemp -d) || exit 2
trap 'zpty -d g3c 2>/dev/null; rm -rf -- $zdot' EXIT

# the child inherits this shell's module and function paths, plus our completion
{
  print -r -- "module_path=(${(j: :)${(@q)module_path}})"
  print -r -- "fpath=(${(q)root}/completions ${(j: :)${(@q)fpath}})"
  print -r -- 'PS1="" PROMPT="" RPROMPT=""; unsetopt zle_bracketed_paste 2>/dev/null'
  print -r -- 'autoload -Uz compinit && compinit -u -D'
  print -r -- 'compadd() { local -a __h; builtin compadd -O __h "$@"; (( $#__h )) && print -rl -- "<<"${^__h} >/dev/tty; builtin compadd "$@" }'
  print -r -- 'g3c-done() { print -r -- "<<END>>" >/dev/tty; zle send-break }; zle -N g3c-done'
  print -r -- 'bindkey "^I" complete-word; bindkey "^X" g3c-done'
  print -r -- 'print -r -- "<<READY>>"'
} >$zdot/.zshrc

zpty g3c "ZDOTDIR=${(q)zdot} TERM=dumb zsh -d -i"
local -a seen
# wait until the child has loaded compinit, then type the line, TAB and ^X
while zpty -r g3c out; do
  [[ -n $G3C_DEBUG ]] && print -r -- "init:${(q+)out}" >&2
  [[ $out == *'<<READY>>'* ]] && break
done
zpty -w -n g3c "$line"$'\t\x18'
while zpty -r g3c out; do
  out=${out//$'\r'/}
  [[ -n $G3C_DEBUG ]] && print -r -- "raw:${(q+)out}" >&2
  [[ $out == *'<<END>>'* ]] && break
  # the first candidate can share a line with the echoed input
  [[ $out == *'<<'* ]] && seen+=(${${out##*<<}%$'\n'})
done
print -rl -- ${(u)seen}
