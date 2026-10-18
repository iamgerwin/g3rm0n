#!/usr/bin/env bash
# Bump the version everywhere it appears and cut the CHANGELOG release section.
#
#   scripts/bump-version.sh patch|minor|major    next version by Semantic Versioning
#   scripts/bump-version.sh 1.4.2                an explicit version
#   scripts/bump-version.sh patch --date 2026-01-31
#
# Updates G3_VERSION in lib/core.sh, turns the CHANGELOG "Unreleased" notes into a
# dated "## [X.Y.Z]" section, rewrites the compare links, and refreshes the
# "--version X.Y.Z" examples in README.md and install.sh. Then runs tests/docs.sh.
# It never commits, tags or pushes: see rules/07-git-and-releases.md.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
url=https://github.com/iamgerwin/g3rm0n

die() { printf 'bump-version: %s\n' "$*" >&2; exit 1; }

part=${1:-}; shift || true
date=$(date +%F)
while (( $# )); do
  case $1 in
    --date) date=${2:?--date needs YYYY-MM-DD}; shift ;;
    *) die "unknown option $1" ;;
  esac
  shift
done
[[ $date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "date must be YYYY-MM-DD, got $date"

old=$(sed -n 's/^G3_VERSION="\([0-9.]*\)"$/\1/p' lib/core.sh)
[[ $old =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || die "cannot read G3_VERSION from lib/core.sh"
ma=${BASH_REMATCH[1]} mi=${BASH_REMATCH[2]} pa=${BASH_REMATCH[3]}
case $part in
  patch) new="$ma.$mi.$(( pa + 1 ))" ;;
  minor) new="$ma.$(( mi + 1 )).0" ;;
  major) new="$(( ma + 1 )).0.0" ;;
  [0-9]*.[0-9]*.[0-9]*) new=$part ;;
  *) die "usage: scripts/bump-version.sh patch|minor|major|X.Y.Z [--date YYYY-MM-DD]" ;;
esac
[[ $new =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "not a version: $new"
[[ $(printf '%s\n%s\n' "$old" "$new" | sort -V | tail -n1) == "$new" && $new != "$old" ]] \
  || die "$new is not newer than $old"
grep -q "^## \[$new\]" CHANGELOG.md && die "CHANGELOG.md already has $new"

# the Unreleased section must say what is being released
notes=$(awk '/^## \[Unreleased\]/{on=1; next} /^## \[/{on=0} on' CHANGELOG.md | grep -c '^- ' || true)
(( notes > 0 )) || die "CHANGELOG.md has nothing under [Unreleased] to release"

sed -i "s/^G3_VERSION=\"$old\"$/G3_VERSION=\"$new\"/" lib/core.sh
sed -i "s/^## \[Unreleased\]$/## [Unreleased]\n\n## [$new] - $date/" CHANGELOG.md
sed -i "s|^\[Unreleased\]: .*|[Unreleased]: $url/compare/v$new...HEAD\n[$new]: $url/compare/v$old...v$new|" CHANGELOG.md
sed -i -E "s/--version [0-9]+\.[0-9]+\.[0-9]+/--version $new/g" README.md install.sh

printf 'Bumped %s -> %s (%s)\n' "$old" "$new" "$date"
tests/docs.sh
