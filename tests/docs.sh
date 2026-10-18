#!/usr/bin/env bash
# Documentation drift check: fails when the docs no longer match the code.
#
#   tests/docs.sh                  consistency checks only
#   tests/docs.sh --staged         ... plus: staged code changes need a CHANGELOG entry
#   tests/docs.sh --since <ref>    ... plus: code changed since <ref> needs a CHANGELOG entry
#
# Run by the pre-commit hook (.githooks/pre-commit), the coding-agent stop hook
# (.claude/hooks/docs-drift.sh) and CI. Deterministic: no network, no clock, no
# randomness. What it enforces is described in rules/08-documentation.md.
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root" || exit 2

mode="" ref=""
case ${1:-} in
  "") ;;
  --staged) mode=staged ;;
  --since) mode=since; ref=${2:?--since needs a git ref}; [[ $ref == -* ]] && { echo "docs: bad ref $ref" >&2; exit 2; } ;;
  -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
  *) echo "docs: unknown option $1" >&2; exit 2 ;;
esac

pass=0 fail=0
ok()  { pass=$(( pass + 1 )); }
bad() { fail=$(( fail + 1 )); printf '  DRIFT  %s\n' "$*"; }
check() { # description command... : silent when it holds, loud when it drifts
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then ok; else bad "$desc"; fi
}
in_file() { grep -qF -- "$2" "$1"; }

# the facts, read from the code itself
export HOME=${HOME:-/nonexistent}
# shellcheck source=/dev/null
source lib/core.sh
# shellcheck source=/dev/null
source lib/ai.sh
# shellcheck source=/dev/null
source lib/keymap.sh
help=$(NO_COLOR=1 ./g3rm0n help 2>&1)
setup_help=$(NO_COLOR=1 ./g3rm0n setup --help 2>&1)
mapfile -t opts < <(grep -o -- '--[a-z][a-z-]*' <<<"$help" | grep -vx -- '--help' | sort -u)
mapfile -t setup_opts < <(grep -o -- '--[a-z][a-z-]*' <<<"$setup_help" | grep -vx -- '--help' | sort -u)
comps=(completions/g3rm0n.bash completions/g3rm0n.fish completions/_g3rm0n)

echo "g3rm0n docs drift check (v$G3_VERSION)"

# ---- version and changelog -----------------------------------------------------
v=$G3_VERSION
check "G3_VERSION '$v' is not MAJOR.MINOR.PATCH" bash -c "[[ '$v' =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]"
check "g3rm0n version does not print $v" bash -c "[[ \$(./g3rm0n version) == 'g3rm0n $v' ]]"
check "CHANGELOG.md has no '## [Unreleased]' section" in_file CHANGELOG.md '## [Unreleased]'
latest=$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$' CHANGELOG.md | sed 's/^## \[\([^]]*\)\].*/\1/')
check "latest CHANGELOG release is '${latest:-none}', but G3_VERSION is $v (run scripts/bump-version.sh)" \
  test "$latest" = "$v"
check "CHANGELOG [Unreleased] link must compare v$v...HEAD" \
  in_file CHANGELOG.md "[Unreleased]: https://github.com/iamgerwin/g3rm0n/compare/v$v...HEAD"
while read -r hv; do
  check "CHANGELOG version $hv has no link reference at the bottom" grep -q "^\[$hv\]: https://github.com/iamgerwin/g3rm0n/" CHANGELOG.md
done < <(sed -n 's/^## \[\([0-9][0-9.]*\)\].*/\1/p' CHANGELOG.md)
check "CHANGELOG headings must be '## [X.Y.Z] - YYYY-MM-DD'" \
  bash -c "! grep -E '^## \[' CHANGELOG.md | grep -vE '^## \[(Unreleased|[0-9]+\.[0-9]+\.[0-9]+)\]( - [0-9]{4}-[0-9]{2}-[0-9]{2})?$'"
check "CHANGELOG uses a category outside Added/Changed/Deprecated/Removed/Fixed/Security" \
  bash -c "! grep -E '^### ' CHANGELOG.md | grep -vE '^### (Added|Changed|Deprecated|Removed|Fixed|Security)$'"
for f in README.md install.sh; do
  while read -r ex; do
    check "$f shows '--version $ex' but the current version is $v" test "$ex" = "$v"
  done < <(grep -oE -- '--version [0-9]+\.[0-9]+\.[0-9]+' "$f" | awk '{print $2}')
done

# ---- sections, options, providers: code vs README vs completions ---------------
for s in "${G3_SECTIONS[@]}"; do
  check "section '$s' missing from README.md" in_file README.md "\`$s\`"
  check "section '$s' missing from g3rm0n help" grep -qw -- "$s" <<<"$help"
  for c in "${comps[@]}"; do check "section '$s' missing from $c" in_file "$c" "$s"; done
done
for o in "${opts[@]}"; do
  check "option $o (g3rm0n help) missing from README.md" in_file README.md "$o"
  check "option $o missing from completions/g3rm0n.bash" in_file completions/g3rm0n.bash "$o"
  check "option $o missing from completions/g3rm0n.fish" in_file completions/g3rm0n.fish "-l ${o#--}"
  check "option $o missing from completions/_g3rm0n" in_file completions/_g3rm0n "$o"
done
for o in "${setup_opts[@]}"; do
  check "setup option $o missing from README.md" in_file README.md "setup $o"
  for c in "${comps[@]}"; do check "setup option $o missing from $c" in_file "$c" "${o#--}"; done
done
for id in "${G3_PROVIDERS[@]}"; do
  check "provider ${AI_NAME[$id]} missing from the README providers table" grep -q "^| .* | ${AI_NAME[$id]} |" README.md
  for var in ${AI_ENV[$id]:-}; do check "credential variable $var missing from README.md" in_file README.md "$var"; done
done

for k in "${KEYMAP_HELP[@]}"; do
  check "key '${k%%|*}' (KEYMAP_HELP) missing from the README keys table" grep -qF -- "| \`${k%%|*}\`" README.md
done
g3_config_load
for key in "${!CFG[@]}"; do
  check "config key '$key' missing from the README configuration table" grep -qF -- "| \`$key\`" README.md
done

# ---- the README's sample screens are what the code draws -------------------------------
for screen in full folded; do   # (not "mode": that's this script's own option)
  shown=$(awk -v m="<!-- sample:$screen -->" '$0 == m { on = 1; next } on && /^<!-- \/sample -->/ { exit } on && !/^```/' README.md)
  check "README sample '$screen' differs from scripts/readme-sample.sh $screen (run scripts/readme-sample.sh --update)" \
    test "$shown" = "$(scripts/readme-sample.sh "$screen")"
done

# ---- architecture: every module is documented ---------------------------------------
for m in lib/*.sh lib/platform/*.sh; do
  check "$m missing from ARCHITECTURE.md" in_file ARCHITECTURE.md "$m"
  check "$m missing from the layout in rules/02-code-style.md" in_file rules/02-code-style.md "$m"
done

# ---- rules, tests, CI, agent instructions ---------------------------------------
for r in rules/[0-9]*.md; do
  check "rules/README.md does not link ${r#rules/}" in_file rules/README.md "(${r#rules/})"
done
for t in tests/*.sh; do
  check "CI does not run $t" in_file .github/workflows/ci.yml "$t"
  check "rules/06-testing.md does not mention $t" in_file rules/06-testing.md "$t"
done
check "AGENTS.md must point to rules/" in_file AGENTS.md "rules/"
check "AGENTS.md must point to ARCHITECTURE.md" in_file AGENTS.md "ARCHITECTURE.md"
check "AGENTS.md must point to learnings/dump.md" in_file AGENTS.md "learnings/dump.md"
check "CLAUDE.md must import learnings/dump.md" in_file CLAUDE.md "@learnings/dump.md"
check "rules/08-documentation.md must list learnings/dump.md" in_file rules/08-documentation.md "learnings/dump.md"
# every learnings entry: "## YYYY-MM-DD · area · title" and its four fields
check "learnings/dump.md has entries" bash -c "grep -qE '^## [0-9]{4}-[0-9]{2}-[0-9]{2} · ' learnings/dump.md"
while IFS= read -r h; do
  body=$(awk -v h="$h" '$0 == h { on = 1; next } /^## / { on = 0 } on' learnings/dump.md)
  for f in "What happened" "Cause" "Lesson" "Enforced by"; do
    check "learnings entry '${h#\#\# }' has no **$f:**" grep -qF -- "- **$f:**" <<<"$body"
  done
done < <(grep -E '^## [0-9]{4}-[0-9]{2}-[0-9]{2} · ' learnings/dump.md)
# (the format example sits in a fenced block at the top, so fences are skipped)
learnings_headings_ok() {
  ! awk '/^```/ { f = !f; next } !f && /^## /' learnings/dump.md \
    | grep -vE '^## [0-9]{4}-[0-9]{2}-[0-9]{2} · [^·]+ · .+$'
}
check "learnings headings must be '## YYYY-MM-DD · area · title'" learnings_headings_ok
check "CLAUDE.md must import AGENTS.md" in_file CLAUDE.md "@AGENTS.md"
check "AGENTS.md must name the docs check" in_file AGENTS.md "tests/docs.sh"
check ".githooks/pre-commit must run the docs check" in_file .githooks/pre-commit "tests/docs.sh"
for b in lib/platform/*.sh; do
  b=${b##*/}; b=${b%.sh}
  check "platform '$b' missing from the README platforms table" grep -qE "^\| [^|]+ \| [\`]${b}[\`] \|" README.md
done
# shellcheck disable=SC2016  # expanded by the inner bash
check "the platform contract in ARCHITECTURE.md must list every plat_ function" \
  bash -c 'source lib/system.sh 2>/dev/null; for f in "${SYS_CONTRACT[@]}"; do grep -qF "\`$f\`" ARCHITECTURE.md || exit 1; done' 

# ---- what changed: code changes need a changelog entry -----------------------------
if [[ -n $mode ]]; then
  if [[ $mode == staged ]]; then
    changed=$(git diff --cached --name-only)
  else
    changed=$( { git diff --name-only "$ref" 2>/dev/null; git ls-files -o --exclude-standard; } | sort -u)
  fi
  code=$(grep -E '^(g3rm0n|install\.sh|lib/|completions/)' <<<"$changed")
  if [[ -n $code ]]; then
    check "code changed ($(tr '\n' ' ' <<<"$code" | sed 's/ $//')) but CHANGELOG.md was not updated" \
      grep -qx CHANGELOG.md <<<"$changed"
  fi
  if grep -qE '^lib/(core|ai)\.sh$|^g3rm0n$' <<<"$code" && ! grep -qx README.md <<<"$changed"; then
    printf '  note   lib/core.sh, lib/ai.sh or g3rm0n changed without README.md: check that the README still matches\n'
  fi
fi

if (( fail )); then
  printf '\n%d drift finding(s). Fix the docs (see rules/08-documentation.md), then rerun tests/docs.sh.\n' "$fail"
  exit 1
fi
printf '  ok    %d checks, docs match the code\n' "$pass"
