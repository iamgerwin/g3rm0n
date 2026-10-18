#!/usr/bin/env bash
# Cross-shell tests: start g3rm0n, g3rm0n setup, the installer and the completions
# from every shell installed on this machine (bash, zsh, fish, dash/sh, ksh, mksh,
# tcsh, busybox sh). Shells that aren't installed are skipped, not failed.
# Like smoke.sh: temporary HOME, mock curl, no network, no real credentials.
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
  else fail=$(( fail + 1 )); printf '  FAIL  %s\n' "$desc"; fi
}
skipped() { skip=$(( skip + 1 )); printf '  skip  %s\n' "$1"; }
contains() { grep -qF -- "$2" <<<"$1"; }
lacks()    { ! grep -qF -- "$2" <<<"$1"; }
has_shell() { command -v "$1" >/dev/null 2>&1; }

# isolated environment; g3rm0n is reached through PATH like a real install
export HOME=$tmp/home XDG_CONFIG_HOME=$tmp/config XDG_CACHE_HOME=$tmp/cache COLUMNS=100
mkdir -p "$HOME" "$tmp/bin"
ln -s "$root/g3rm0n" "$tmp/bin/g3rm0n"
export PATH="$root/tests/mock:$tmp/bin:$PATH"
unset CLAUDE_CONFIG_DIR CODEX_HOME GLM_API_KEY ZAI_API_KEY Z_AI_API_KEY DEEPSEEK_API_KEY OPENROUTER_API_KEY NO_COLOR
# zsh: let a developer's ~/.zshenv point zsh at its modules when it isn't installed
# system-wide; on a normal install ZDOTDIR is simply a folder with no rc files
export ZDOTDIR=${G3_TEST_ZDOTDIR:-$tmp/zdot}
mkdir -p "$ZDOTDIR"

# pty <shell> <keys...>: run "g3rm0n setup" in a pseudo-terminal started from <shell>
# (script(1) runs its command with $SHELL), typing each key with a short pause
pty() {
  local sh=$1; shift
  { sleep 0.4; local k; for k in "$@"; do printf '%b' "$k"; sleep 0.15; done; sleep 0.4; } \
    | pty_run "$sh" "g3rm0n setup" 2>&1
}

cfg=$XDG_CONFIG_HOME/g3rm0n/config
shells=(bash zsh fish dash sh ksh mksh tcsh)

echo "g3rm0n cross-shell tests"

# ---- the dashboard and setup, launched from each shell --------------------------
for sh in "${shells[@]}"; do
  if ! has_shell "$sh"; then skipped "$sh: not installed"; continue; fi
  # "; true" keeps the shell as the parent process (no exec of the last command)
  out=$("$sh" -c 'g3rm0n --once --no-ai; true' 2>&1)
  check "$sh: dashboard runs" contains "$out" "◉ CPU"
  check "$sh: piped output is plain" lacks "$out" $'\e['
  out=$("$sh" -c 'g3rm0n setup --show; true' 2>&1)
  check "$sh: setup --show runs" contains "$out" "Detected on this machine"
  check "$sh: g3rm0n version" bash -c "'$sh' -c 'g3rm0n version; true' | grep -qx 'g3rm0n [0-9.]*'"
done

# ---- started by a POSIX shell directly: "sh g3rm0n" hands over to bash ------------
for sh in sh dash ksh mksh zsh; do
  has_shell "$sh" || continue
  check "$sh g3rm0n: hands over to bash" bash -c "'$sh' '$root/g3rm0n' version | grep -qx 'g3rm0n [0-9.]*'"
done
if has_shell busybox; then
  check "busybox sh g3rm0n: hands over to bash" bash -c "busybox sh '$root/g3rm0n' version | grep -qx 'g3rm0n [0-9.]*'"
fi
check "install.sh piped to sh: refused with a hint" \
  bash -c "! sh <'$root/install.sh' 2>'$tmp/err' && grep -q 'with bash' '$tmp/err'"
check "sh install.sh --help: hands over to bash" bash -c "sh '$root/install.sh' --help | grep -q -- '--uninstall'"
check "install.sh --help works when piped" bash -c "bash -s -- --help <'$root/install.sh' | grep -q -- '--uninstall'"

# ---- API keys: exported keys are found, unexported ones are not, hints match ---------
if has_shell bash; then
  out=$(bash -c 'export GLM_API_KEY=test; g3rm0n setup --show' 2>&1)
  check "bash: exported key found" contains "$out" "found · \$GLM_API_KEY"
  out=$(bash -c 'GLM_API_KEY=test; g3rm0n setup --show; true' 2>&1)
  check "bash: unexported key not found" contains "$out" 'not found · export GLM_API_KEY=…'
  out=$(bash -c 'export GLM_API_KEY=test; g3rm0n --once -s ai-tokens; true' 2>&1)
  check "bash: Z.ai panel from exported key" contains "$out" "AI Tokens · Z.ai"
fi
if has_shell zsh; then
  out=$(zsh -c 'export GLM_API_KEY=test; g3rm0n setup --show; true' 2>&1)
  check "zsh: exported key found" contains "$out" "found · \$GLM_API_KEY"
  out=$(zsh -c 'GLM_API_KEY=test; g3rm0n setup --show; true' 2>&1)
  check "zsh: unexported key not found" contains "$out" 'not found · export GLM_API_KEY=…'
  out=$(zsh -c 'export GLM_API_KEY=test; g3rm0n --once -s ai-tokens; true' 2>&1)
  check "zsh: Z.ai panel from exported key" contains "$out" "AI Tokens · Z.ai"
else
  skipped "zsh: API key tests"
fi
if has_shell fish; then
  out=$(fish -c 'set -gx GLM_API_KEY test; g3rm0n setup --show' 2>&1)
  check "fish: exported key found (set -gx)" contains "$out" "found · \$GLM_API_KEY"
  out=$(fish -c 'set -g GLM_API_KEY test; g3rm0n setup --show' 2>&1)
  check "fish: unexported key not found, hint uses set -gx" contains "$out" 'not found · set -gx GLM_API_KEY …'
  out=$(fish -c 'set -gx GLM_API_KEY test; g3rm0n --once -s ai-tokens' 2>&1)
  check "fish: Z.ai panel from exported key" contains "$out" "AI Tokens · Z.ai"
  out=$(fish -c 'set -gx DEEPSEEK_API_KEY test; set -gx OPENROUTER_API_KEY test; g3rm0n --once -s ai-credits' 2>&1)
  check "fish: credit panels from exported keys" contains "$out" "AI Credits · OpenRouter"
else
  skipped "fish: API key tests"
fi
if has_shell tcsh; then
  out=$(tcsh -c 'setenv GLM_API_KEY test; g3rm0n setup --show; true' 2>&1)
  check "tcsh: setenv key found" contains "$out" "found · \$GLM_API_KEY"
  out=$(tcsh -c 'g3rm0n setup --show; true' 2>&1)
  check "tcsh: hint uses setenv" contains "$out" 'not found · setenv GLM_API_KEY …'
else
  skipped "tcsh: API key tests"
fi

# ---- interactive setup in a real terminal, started from each shell ----------------
if ! has_shell script; then
  skipped "interactive setup: script(1) not installed"
else
  for sh in bash zsh fish; do
    if ! has_shell "$sh"; then skipped "$sh: interactive setup"; continue; fi
    rm -f "$cfg"
    # sections: a = none, space = cpu, down (both cursor-key modes) twice, space = disk,
    # enter; no AI section chosen, so no provider step; interval 7, enter
    out=$(pty "$sh" a ' ' '\e[B' '\eOB' ' ' '\r' '7\r')
    check "$sh: interactive setup saves" contains "$out" "Saved"
    check "$sh: arrows and space pick sections" grep -qx 'sections = cpu disk' "$cfg"
    check "$sh: interval answer saved" grep -qx 'interval = 7' "$cfg"
    rm -f "$cfg"
    # keep every section, then look at the provider step's hint for a missing key
    out=$(pty "$sh" '\r' '\r' '\r')
    case $sh in fish) hint='set -gx GLM_API_KEY …' ;; *) hint='export GLM_API_KEY=…' ;; esac
    check "$sh: provider step hint in $sh syntax" contains "$out" "$hint"
    check "$sh: defaults kept on enter" grep -q '^sections = cpu memory disk power processes network ai-tokens ai-credits$' "$cfg"
    rm -f "$cfg"
    out=$(pty "$sh" q)
    check "$sh: q cancels without writing" bash -c "[[ ! -e '$cfg' ]] && grep -q Cancelled <<<\"\$1\"" _ "$out"
  done
fi

# ---- completions -----------------------------------------------------------------
bash_complete() { # words... -> candidates the bash completion offers for the last word
  bash -c 'source "$1"; shift; COMP_WORDS=("$@"); COMP_CWORD=$(( $# - 1 )); COMPREPLY=()
           _g3rm0n; printf "%s\n" "${COMPREPLY[@]}"' _ "$root/completions/g3rm0n.bash" "$@"
}
check "bash completion: subcommands" bash -c "grep -qx setup <<<\"\$1\"" _ "$(bash_complete g3rm0n se)"
check "bash completion: setup options" bash -c "grep -qx -- --defaults <<<\"\$1\"" _ "$(bash_complete g3rm0n setup --)"
check "bash completion: keeps earlier list items" bash -c "grep -qx cpu,memory <<<\"\$1\"" _ "$(bash_complete g3rm0n -s cpu,me)"

if has_shell fish; then
  fish_complete() { fish -c "source '$root/completions/g3rm0n.fish'; complete -C '$1'" 2>&1 | cut -f1; }
  check "fish completion: subcommands" bash -c "grep -qx setup <<<\"\$1\"" _ "$(fish_complete 'g3rm0n se')"
  check "fish completion: setup options" bash -c "grep -qx -- --defaults <<<\"\$1\"" _ "$(fish_complete 'g3rm0n setup --')"
  check "fish completion: keeps earlier list items" bash -c "grep -qx cpu,memory <<<\"\$1\"" _ "$(fish_complete 'g3rm0n -s cpu,me')"
else
  skipped "fish completions"
fi

if has_shell zsh && zsh -c 'zmodload zsh/zpty' 2>/dev/null; then
  zsh_complete() { with_timeout 20 zsh "$root/tests/zsh-complete.zsh" "$1" 2>&1; }
  check "zsh completion: syntax" zsh -n "$root/completions/_g3rm0n"
  check "zsh completion: subcommands" bash -c "grep -qx setup <<<\"\$1\"" _ "$(zsh_complete 'g3rm0n se')"
  check "zsh completion: options" bash -c "grep -qx -- --no-ai <<<\"\$1\"" _ "$(zsh_complete 'g3rm0n --no')"
  check "zsh completion: setup options" bash -c "grep -qx -- --defaults <<<\"\$1\"" _ "$(zsh_complete 'g3rm0n setup --')"
  check "zsh completion: comma-separated sections" bash -c "grep -qx memory <<<\"\$1\"" _ "$(zsh_complete 'g3rm0n -s cpu,me')"
else
  skipped "zsh completions"
fi

# ---- installer, then a fresh shell finds g3rm0n ------------------------------------
ihome=$tmp/ihome
mkdir -p "$ihome"
# a minimal PATH without ~/.local/bin, plus wherever the shells under test live
ipath=/usr/local/bin:/usr/bin:/bin
for sh in bash zsh fish; do has_shell "$sh" && ipath+=":$(dirname "$(command -v "$sh")")"; done
iclean=(env -i "HOME=$ihome" "PATH=$ipath" "TERM=dumb" "LANG=C.UTF-8")
inst=$("${iclean[@]}" bash "$root/install.sh" 2>&1)
check "installer: links the binary" test -L "$ihome/.local/bin/g3rm0n"
check "installer: bash completion" test -L "$ihome/.local/share/bash-completion/completions/g3rm0n"
check "installer: PATH hint when ~/.local/bin is missing" contains "$inst" "PATH"
if has_shell fish; then
  check "installer: fish finds g3rm0n in a new shell" \
    bash -c "$(printf '%q ' "${iclean[@]}") fish -c 'g3rm0n version' | grep -qx 'g3rm0n [0-9.]*'"
fi
if has_shell zsh; then
  check "installer: zsh completion linked" test -L "$ihome/.local/share/zsh/site-functions/_g3rm0n"
  out=$("${iclean[@]}" "ZDOTDIR=$ZDOTDIR" zsh -c "bash '$root/install.sh'; true" 2>&1)
  check "installer: zsh users get a ~/.zshrc PATH line" contains "$out" "Add to ~/.zshrc"
fi
if has_shell fish; then
  rm -f "$ihome/.config/fish/conf.d/g3rm0n.fish"   # as if fish had never seen g3rm0n
  out=$("${iclean[@]}" fish -c "bash '$root/install.sh'" 2>&1)
  check "installer: fish users are told conf.d handles PATH" contains "$out" "conf.d/g3rm0n.fish"
fi
(cd "$tmp" && mkdir -p fakecheckout/lib && touch fakecheckout/g3rm0n fakecheckout/lib/core.sh)
# piped from a folder that looks like a checkout; the mock curl answers the release
# lookup with 404, so the install stops right after choosing where to install from
out=$(cd "$tmp/fakecheckout" && env -i "HOME=$ihome" "PATH=$root/tests/mock:/usr/bin:/bin" bash -s <"$root/install.sh" 2>&1)
check "installer: piped install never links the current directory" lacks "$out" "Linking checkout"
"${iclean[@]}" bash "$root/install.sh" --uninstall >/dev/null 2>&1
check "installer: uninstall removes every link" bash -c "[[ ! -e '$ihome/.local/bin/g3rm0n' && ! -e '$ihome/.local/share/zsh/site-functions/_g3rm0n' && ! -e '$ihome/.config/fish/conf.d/g3rm0n.fish' ]]"

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
(( fail == 0 ))
