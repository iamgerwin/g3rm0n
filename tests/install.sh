#!/usr/bin/env bash
# Install tests: what reaches a user's machine, and that it works there.
#   - only run-time files are installed, with only this OS's backend
#   - the installed copy runs on its own (no checkout needed) through its PATH link
#   - reinstalling replaces an older, fuller install completely
#   - release tarballs (git archive, as GitHub builds them) carry no dev files
#   - the installer runs under bash 3.2, the bash macOS ships
# No network, no real credentials, nothing outside a temp directory is touched.
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

case $(uname -s) in Darwin) plat=darwin other=linux ;; *) plat=linux other=darwin ;; esac
h=$tmp/home
share=$h/.local/share/g3rm0n
mkdir -p "$h"
# a clean environment, but with this machine's bash 5 and shells reachable
ipath=/usr/bin:/bin
for c in bash zsh fish jq curl; do command -v "$c" >/dev/null 2>&1 && ipath+=":$(dirname "$(command -v "$c")")"; done
clean=(env -i "HOME=$h" "PATH=$ipath" "TERM=dumb" "LANG=en_US.UTF-8")

echo "g3rm0n install tests ($plat)"

# ---- only the run-time files ---------------------------------------------------------
"${clean[@]}" bash "$root/install.sh" --from "$root" >"$tmp/log" 2>&1
check "install --from succeeds" test -x "$share/g3rm0n"
expected=$( { printf '%s\n' g3rm0n LICENSE "lib/platform/$plat.sh" completions/g3rm0n.bash completions/g3rm0n.fish completions/_g3rm0n
              (cd "$root" && ls lib/*.sh); } | sort)
actual=$(cd "$share" && find . -type f | sed 's|^\./||' | sort)
check "installs exactly the run-time files" test "$actual" = "$expected"
check "only this OS's backend ($plat)"       test ! -e "$share/lib/platform/$other.sh"
for d in tests rules scripts .github .githooks .claude; do
  check "no $d/ installed" test ! -e "$share/$d"
done
check "no dev docs installed" bash -c "! ls '$share'/{AGENTS,CLAUDE,CONTRIBUTING,ARCHITECTURE}.md 2>/dev/null"

# ---- the installed copy works on its own -------------------------------------------------
out=$("${clean[@]}" "$h/.local/bin/g3rm0n" --once --no-ai 2>&1)
check "installed copy runs through its PATH link" contains "$out" "◉ CPU"
check "installed copy is the installed version" bash -c "'$h/.local/bin/g3rm0n' version | grep -qx \"g3rm0n \$(sed -n 's/^G3_VERSION=\"\\(.*\\)\"$/\\1/p' '$root/lib/core.sh')\""
out=$("${clean[@]}" "$h/.local/bin/g3rm0n" setup --show 2>&1)
check "installed setup runs"        contains "$out" "Detected on this machine"
out=$("${clean[@]}" G3_PLATFORM=$other "$h/.local/bin/g3rm0n" --once 2>&1)
check "a missing backend is explained" contains "$out" "has no $other support"
check "completions are linked"      test -L "$h/.local/share/bash-completion/completions/g3rm0n"

# ---- reinstall replaces an older, fuller install --------------------------------------------
mkdir -p "$share/tests" "$share/rules"; touch "$share/tests/smoke.sh" "$share/README.md"
"${clean[@]}" bash "$root/install.sh" --from "$root" >/dev/null 2>&1
check "reinstall removes files from older installs" bash -c "[[ ! -e '$share/tests' && ! -e '$share/README.md' ]]"

# ---- release tarballs ---------------------------------------------------------------------
if git -C "$root" rev-parse HEAD >/dev/null 2>&1; then
  list=$(git -C "$root" archive --format=tar HEAD | tar -tf -)
  for p in g3rm0n install.sh LICENSE README.md CHANGELOG.md lib/core.sh "lib/platform/linux.sh" "lib/platform/darwin.sh" completions/_g3rm0n; do
    check "tarball has $p" grep -qx -- "$p" <<<"$list"
  done
  for p in tests/ rules/ scripts/ .github/ .githooks/ .claude/ AGENTS.md CLAUDE.md CONTRIBUTING.md ARCHITECTURE.md; do
    check "tarball leaves out $p" bash -c "! grep -q '^${p//./\\.}' <<<\"\$1\"" _ "$list"
  done
  mkdir -p "$tmp/tarball"
  git -C "$root" archive --format=tar HEAD | tar -xf - -C "$tmp/tarball"
  rm -rf "$share"
  "${clean[@]}" bash "$tmp/tarball/install.sh" --from "$tmp/tarball" >/dev/null 2>&1
  out=$("${clean[@]}" "$h/.local/bin/g3rm0n" --once --no-ai 2>&1)
  check "installs and runs from a release tarball" contains "$out" "◉ CPU"
else
  skipped "release tarball checks: not a git checkout"
fi

# ---- bash 3.2, as on a stock Mac -------------------------------------------------------------
old=${G3_TEST_BASH32:-}
[[ -z $old && -x /bin/bash ]] && /bin/bash -c '(( BASH_VERSINFO[0] < 4 ))' 2>/dev/null && old=/bin/bash
if [[ -n $old ]]; then
  rm -rf "$share"
  out=$("${clean[@]}" "$old" "$root/install.sh" --from "$root" 2>&1)
  check "installer runs under bash 3.2"      test -x "$share/g3rm0n"
  check "installer under bash 3.2 is clean"  lacks "$out" "syntax error"
  out=$("${clean[@]}" "$old" -s -- --help < "$root/install.sh" 2>&1)
  check "piped installer under bash 3.2"     contains "$out" "--uninstall"
  out=$("${clean[@]}" "$old" "$share/g3rm0n" version 2>&1)
  check "g3rm0n started by bash 3.2 hands over to bash 5" bash -c "grep -qx 'g3rm0n [0-9.]*' <<<\"\$1\"" _ "$out"
else
  skipped "bash 3.2 checks: no bash 3.2 here (set G3_TEST_BASH32 to one)"
fi

# ---- uninstall --------------------------------------------------------------------------------
"${clean[@]}" bash "$root/install.sh" --uninstall >/dev/null 2>&1
check "uninstall removes the program and its files" bash -c "[[ ! -e '$h/.local/bin/g3rm0n' && ! -e '$share' ]]"

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
(( fail == 0 ))
