#!/usr/bin/env bash
# Install g3rm0n for the current user (no root needed).
#
#   curl -fsSL https://raw.githubusercontent.com/iamgerwin/g3rm0n/main/install.sh | bash
#   ./install.sh                 from a git checkout: links the checkout (live-editable)
#   ./install.sh --version 0.1.0 install a specific release
#   ./install.sh --uninstall     remove g3rm0n (your config is kept)
set -euo pipefail

REPO="iamgerwin/g3rm0n"
SHARE_DIR="${G3RM0N_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/g3rm0n}"
BIN_DIR="${G3RM0N_BIN_DIR:-$HOME/.local/bin}"
FISH_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fish"
BASH_COMP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
MARK="# managed by g3rm0n install.sh"

say()  { printf '  %s\n' "$*"; }
fail() { printf 'install: %s\n' "$*" >&2; exit 1; }

uninstall() {
  rm -f "$BIN_DIR/g3rm0n" "$BASH_COMP_DIR/g3rm0n"
  local f
  for f in "$FISH_DIR/completions/g3rm0n.fish" "$FISH_DIR/conf.d/g3rm0n.fish"; do
    [[ -L $f ]] && rm -f "$f"
    [[ -f $f ]] && grep -q "$MARK" "$f" && rm -f "$f"
  done
  [[ -d $SHARE_DIR && ! -L $SHARE_DIR ]] && rm -rf "$SHARE_DIR"
  say "g3rm0n removed. Config kept in ${XDG_CONFIG_HOME:-$HOME/.config}/g3rm0n"
}

version=""
while (( $# )); do
  case $1 in
    --uninstall) uninstall; exit 0 ;;
    --version) shift; version=${1:-} ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) fail "unknown option $1" ;;
  esac
  shift
done

[[ $(uname -s) == Linux ]] || fail "g3rm0n runs on Linux only"
(( BASH_VERSINFO[0] >= 5 )) || fail "bash 5 or newer is required"

src=""
here=""
if cd_out=$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd); then here=$cd_out; fi
if [[ -z $version && -f $here/g3rm0n && -f $here/lib/core.sh ]]; then
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

if command -v fish >/dev/null 2>&1 || [[ -d $FISH_DIR ]]; then
  mkdir -p "$FISH_DIR/conf.d" "$FISH_DIR/completions"
  ln -sfn "$src/completions/g3rm0n.fish" "$FISH_DIR/completions/g3rm0n.fish"
  # fish does not read ~/.profile, so ~/.local/bin is often missing from its PATH
  cat >"$FISH_DIR/conf.d/g3rm0n.fish" <<EOF
$MARK
if test -d "$BIN_DIR"; and not contains -- "$BIN_DIR" \$PATH
    set -gx PATH "$BIN_DIR" \$PATH
end
EOF
  say "Added fish completions and PATH entry"
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) say "Add $BIN_DIR to your PATH, then open a new shell." ;;
esac
for dep in curl jq; do
  command -v "$dep" >/dev/null || say "Optional: install $dep to enable the AI panels."
done
say "Run: g3rm0n        (or g3rm0n setup to choose what it shows)"
