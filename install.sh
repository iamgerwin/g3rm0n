#!/usr/bin/env bash
# Install g3rm0n for the current user (no root needed).
#
#   curl -fsSL https://raw.githubusercontent.com/iamgerwin/g3rm0n/main/install.sh | bash
#   ./install.sh                 from a git checkout: links the checkout (live-editable)
#   ./install.sh --version 0.1.1 install a specific release
#   ./install.sh --uninstall     remove g3rm0n (your config is kept)

# Piped into sh/dash/zsh instead of bash? Stop before any bash syntax is parsed.
# This block must stay POSIX.
if [ -z "${BASH_VERSION:-}" ]; then
  if [ -f "$0" ] && command -v bash >/dev/null 2>&1; then exec bash "$0" "$@"; fi
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
Install g3rm0n for the current user (no root needed).

  curl -fsSL https://raw.githubusercontent.com/iamgerwin/g3rm0n/main/install.sh | bash
  ./install.sh                 from a git checkout: links the checkout (live-editable)
  ./install.sh --version 0.1.1 install a specific release
  ./install.sh --uninstall     remove g3rm0n (your config is kept)
USAGE
}

# The shell the user typed the install command in: the parent of this bash process
# (curl ... | bash) or, failing that, their login shell.
user_shell() {
  local s=""
  [[ -r /proc/$PPID/comm ]] && read -r s </proc/$PPID/comm
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
    bash) say "Add to ~/.bashrc:  export PATH=\"$d:\$PATH\"" ;;
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
  say "g3rm0n removed. Config kept in ${XDG_CONFIG_HOME:-$HOME/.config}/g3rm0n"
}

version=""
while (( $# )); do
  case $1 in
    --uninstall) uninstall; exit 0 ;;
    --version) shift; version=${1:-}; [[ -n $version ]] || fail "--version needs a value, e.g. 0.1.0" ;;
    --version=*) version=${1#*=} ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option $1" ;;
  esac
  shift
done

[[ $(uname -s) == Linux ]] || fail "g3rm0n runs on Linux only"
(( BASH_VERSINFO[0] >= 5 )) || fail "bash 5 or newer is required"

# A checkout is only used when this script runs from a file inside one. When it is
# piped (curl ... | bash) there is no file, so the current directory is never linked.
src="" here=""
if [[ -f ${BASH_SOURCE[0]:-} ]]; then
  here=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd) || here=""
fi
if [[ -z $version && -n $here && -f $here/g3rm0n && -f $here/lib/core.sh ]]; then
  src=$here
  say "Linking checkout $src"
else
  command -v curl >/dev/null || fail "curl is required"
  if [[ -z $version ]]; then
    version=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
      | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -n1)
    [[ -n $version ]] || fail "could not find the latest release"
  fi
  version=${version#v}
  say "Downloading g3rm0n v$version"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "https://github.com/$REPO/archive/refs/tags/v$version.tar.gz" | tar -xz -C "$tmp" --strip-components=1
  [[ -f $tmp/g3rm0n ]] || fail "download did not contain g3rm0n"
  rm -rf "$SHARE_DIR"
  mkdir -p "$(dirname "$SHARE_DIR")"
  mv "$tmp" "$SHARE_DIR"
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
  command -v "$dep" >/dev/null || say "Optional: install $dep to enable the AI panels."
done
say "Run: g3rm0n        (or g3rm0n setup to choose what it shows)"
