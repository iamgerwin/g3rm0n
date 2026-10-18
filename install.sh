#!/usr/bin/env bash
# Install g3rm0n for the current user, on Linux or macOS (no root needed).
#
#   curl -fsSL https://raw.githubusercontent.com/iamgerwin/g3rm0n/main/install.sh | bash
#   ./install.sh                 from a git checkout: links the checkout (live-editable)
#   ./install.sh --version 0.1.7 install a specific release
#   ./install.sh --from DIR      install from an unpacked release or checkout, offline
#   ./install.sh --uninstall     remove g3rm0n (your config is kept)
#
# Only the files g3rm0n needs at run time are installed (see runtime_files), with
# just the backend for this operating system. This script itself must keep working
# with bash 3.2, the version macOS ships, because `curl ... | bash` runs it there.

# Piped into sh/dash/zsh instead of bash? Stop before any bash syntax is parsed.
# On macOS and some distributions sh *is* bash in POSIX mode; treat that as sh too.
# This block must stay POSIX.
if [ -z "${BASH_VERSION:-}" ] || case ":${SHELLOPTS:-}:" in *:posix:*) true ;; *) false ;; esac; then
  # re-run with bash only when $0 is this script (piped, $0 is the shell itself)
  if [ -f "$0" ] && grep -q '^# Install g3rm0n' "$0" 2>/dev/null && command -v bash >/dev/null 2>&1; then
    exec bash "$0" "$@"
  fi
  echo "install: run this installer with bash, e.g. curl -fsSL <url> | bash" >&2
  exit 1
fi
set -euo pipefail

REPO="iamgerwin/g3rm0n"
SHARE_DIR="${G3RM0N_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/g3rm0n}"
BIN_DIR="${G3RM0N_BIN_DIR:-$HOME/.local/bin}"
FISH_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fish"
BASH_COMP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
ZSH_COMP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"
MARK="# managed by g3rm0n install.sh"

say()  { printf '  %s\n' "$*"; }
fail() { printf 'install: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Install g3rm0n for the current user, on Linux or macOS (no root needed).

  curl -fsSL https://raw.githubusercontent.com/iamgerwin/g3rm0n/main/install.sh | bash
  ./install.sh                 from a git checkout: links the checkout (live-editable)
  ./install.sh --version 0.1.7 install a specific release
  ./install.sh --from DIR      install from an unpacked release or checkout, offline
  ./install.sh --uninstall     remove g3rm0n (your config is kept)
USAGE
}

platform() { # -> linux / darwin, or fail
  case $(uname -s) in
    Linux) printf linux ;;
    Darwin) printf darwin ;;
    *) fail "g3rm0n runs on Linux and macOS (this system is $(uname -s))" ;;
  esac
}

find_bash5() { # -> path of a bash 5 or newer, the way g3rm0n itself looks for one
  local b
  for b in "$(command -v bash 2>/dev/null)" /opt/homebrew/bin/bash /usr/local/bin/bash /usr/bin/bash /bin/bash; do
    # shellcheck disable=SC2016  # the candidate bash expands it, not this shell
    [[ -x $b ]] && "$b" -c '[ "${BASH_VERSION%%.*}" -ge 5 ]' 2>/dev/null && { printf '%s' "$b"; return 0; }
  done
  return 1
}

# The run-time file set, relative to a source tree. Tests, docs, rules, CI and
# maintainer scripts are never installed, and only this OS's backend is.
runtime_files() { # platform
  local f
  printf '%s\n' g3rm0n LICENSE "lib/platform/$1.sh" \
    completions/g3rm0n.bash completions/g3rm0n.fish completions/_g3rm0n
  for f in "$SRC_TREE"/lib/*.sh; do printf 'lib/%s\n' "${f##*/}"; done
}

latest_version() { # -> the newest release's version, e.g. 0.1.4
  local url v=""
  # the releases/latest page redirects to .../releases/tag/vX.Y.Z; unlike the API it
  # has no per-IP rate limit, which shared networks and CI machines run into
  url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" 2>/dev/null) || url=""
  [[ $url == */releases/tag/* ]] && v=${url##*/tag/}
  if [[ -z $v ]]; then
    v=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
      | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)
  fi
  v=${v#v}
  [[ $v =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && printf '%s' "$v"
}

install_runtime() { # source-tree platform -> SHARE_DIR holds exactly the run-time files
  local tree=$1 plat=$2 stage f
  SRC_TREE=$tree
  [[ -f $tree/g3rm0n && -f $tree/lib/platform/$plat.sh ]] || fail "$tree is not a g3rm0n release for $plat"
  mkdir -p "$(dirname "$SHARE_DIR")"
  stage=$(mktemp -d "$(dirname "$SHARE_DIR")/.g3rm0n.XXXXXX")
  while IFS= read -r f; do
    [[ -f $tree/$f ]] || { rm -rf "$stage"; fail "release is missing $f"; }
    mkdir -p "$stage/$(dirname "$f")"
    cp -p "$tree/$f" "$stage/$f"
  done < <(runtime_files "$plat")
  chmod +x "$stage/g3rm0n"
  rm -rf "$SHARE_DIR"
  mv "$stage" "$SHARE_DIR"
}

# The shell the user typed the install command in: the parent of this bash process
# (curl ... | bash) or, failing that, their login shell.
user_shell() {
  local s=""
  if [[ -r /proc/$PPID/comm ]]; then read -r s </proc/$PPID/comm
  else s=$(ps -o comm= -p "$PPID" 2>/dev/null); s=${s##*/}; fi   # macOS: no /proc
  s=${s#-}
  case $s in
    bash|zsh|fish|ksh|mksh|ksh93|dash|sh|tcsh|csh|nu|xonsh|elvish) printf '%s' "$s" ;;
    *) printf '%s' "${SHELL##*/}" ;;
  esac
}

path_hint() { # how to put BIN_DIR on PATH in the user's shell
  local d=${BIN_DIR/#$HOME/\$HOME}
  case $(user_shell) in
    fish) say "fish picks it up in new shells (conf.d/g3rm0n.fish was added)." ;;
    zsh)  say "Add to ~/.zshrc:   export PATH=\"$d:\$PATH\"" ;;
    bash) if [[ $(uname -s) == Darwin ]]; then say "Add to ~/.bash_profile:  export PATH=\"$d:\$PATH\""
          else say "Add to ~/.bashrc:  export PATH=\"$d:\$PATH\""; fi ;;
    tcsh|csh) say "Add to ~/.${SHELL##*/}rc:  set path = ( ${BIN_DIR/#$HOME/\~} \$path )" ;;
    nu)   say "Add to your nushell config:  \$env.PATH = (\$env.PATH | prepend '$BIN_DIR')" ;;
    *)    say "Add to your shell profile:  export PATH=\"$d:\$PATH\"" ;;
  esac
  say "Then open a new shell."
}

uninstall() {
  rm -f "$BIN_DIR/g3rm0n" "$BASH_COMP_DIR/g3rm0n" "$ZSH_COMP_DIR/_g3rm0n"
  local f
  for f in "$FISH_DIR/completions/g3rm0n.fish" "$FISH_DIR/conf.d/g3rm0n.fish"; do
    if [[ -L $f ]]; then rm -f "$f"
    elif [[ -f $f ]] && grep -q "$MARK" "$f"; then rm -f "$f"; fi
  done
  if [[ -d $SHARE_DIR && ! -L $SHARE_DIR ]]; then rm -rf "$SHARE_DIR"; fi
  say "g3rm0n removed. Config kept in ${XDG_CONFIG_HOME:-$HOME/.config}/g3rm0n, folds in ${XDG_STATE_HOME:-$HOME/.local/state}/g3rm0n"
}

version="" from=""
while (( $# )); do
  case $1 in
    --uninstall) uninstall; exit 0 ;;
    --version) shift; version=${1:-}; [[ -n $version ]] || fail "--version needs a value, e.g. 0.1.0" ;;
    --version=*) version=${1#*=} ;;
    --from) shift; from=${1:-}; [[ -d $from ]] || fail "--from needs a folder, e.g. --from ./g3rm0n-0.1.2" ;;
    --from=*) from=${1#*=} ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option $1" ;;
  esac
  shift
done

plat=$(platform) || exit 1
bash5_v=""
if bash5=$(find_bash5); then
  # shellcheck disable=SC2016  # expanded by that bash
  bash5_v=$("$bash5" -c 'printf %s "${BASH_VERSION%%(*}"')
else
  if [[ $plat == darwin ]]; then
    fail "g3rm0n needs bash 5 or newer; macOS ships 3.2. Install it with Homebrew (https://brew.sh): brew install bash"
  fi
  fail "bash 5 or newer is required"
fi

# A checkout is only used when this script runs from a file inside one. When it is
# piped (curl ... | bash) there is no file, so the current directory is never linked.
src="" here=""
if [[ -f ${BASH_SOURCE[0]:-} ]]; then
  here=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd) || here=""
fi
if [[ -n $from ]]; then
  say "Installing from $from"
  install_runtime "$(cd "$from" && pwd)" "$plat"
  src=$SHARE_DIR
elif [[ -z $version && -n $here && -f $here/g3rm0n && -f $here/lib/core.sh ]]; then
  src=$here
  say "Linking checkout $src"
else
  command -v curl >/dev/null || fail "curl is required"
  if [[ -z $version ]]; then
    version=$(latest_version) || version=""   # report it below, not via set -e
    [[ -n $version ]] || fail "could not find the latest release; pick one with --version (see https://github.com/$REPO/releases)"
  fi
  version=${version#v}
  say "Downloading g3rm0n v$version"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "https://github.com/$REPO/archive/refs/tags/v$version.tar.gz" | tar -xz -C "$tmp" --strip-components=1
  [[ -f $tmp/g3rm0n ]] || fail "download did not contain g3rm0n"
  install_runtime "$tmp" "$plat"
  rm -rf "$tmp"
  trap - EXIT
  src=$SHARE_DIR
fi

chmod +x "$src/g3rm0n"
mkdir -p "$BIN_DIR" "$BASH_COMP_DIR"
ln -sfn "$src/g3rm0n" "$BIN_DIR/g3rm0n"
ln -sfn "$src/completions/g3rm0n.bash" "$BASH_COMP_DIR/g3rm0n"
say "Installed $BIN_DIR/g3rm0n"

if [[ -f $src/completions/_g3rm0n ]] && { command -v zsh >/dev/null 2>&1 || [[ -e $HOME/.zshrc ]]; }; then
  mkdir -p "$ZSH_COMP_DIR"
  ln -sfn "$src/completions/_g3rm0n" "$ZSH_COMP_DIR/_g3rm0n"
  say "Added zsh completions to $ZSH_COMP_DIR"
  if [[ $(user_shell) == zsh ]]; then
    say "  enable them in ~/.zshrc, before compinit:  fpath+=(${ZSH_COMP_DIR/#$HOME/\~})"
  fi
fi

if command -v fish >/dev/null 2>&1 || [[ -d $FISH_DIR ]]; then
  mkdir -p "$FISH_DIR/conf.d" "$FISH_DIR/completions"
  ln -sfn "$src/completions/g3rm0n.fish" "$FISH_DIR/completions/g3rm0n.fish"
  # fish does not read ~/.profile, so ~/.local/bin is often missing from its PATH
  cat >"$FISH_DIR/conf.d/g3rm0n.fish" <<FISH
$MARK
if test -d "$BIN_DIR"; and not contains -- "$BIN_DIR" \$PATH
    set -gx PATH "$BIN_DIR" \$PATH
end
FISH
  say "Added fish completions and PATH entry"
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) path_hint ;;
esac
for dep in curl jq; do
  if ! command -v "$dep" >/dev/null; then
    if [[ $plat == darwin ]]; then say "Optional: brew install $dep, to enable the AI panels."
    else say "Optional: install $dep to enable the AI panels."; fi
  fi
done
if [[ $plat == darwin ]]; then say "Using bash ${bash5_v:-5} from $bash5"; fi
say "Run: g3rm0n        (or g3rm0n setup to choose what it shows)"
