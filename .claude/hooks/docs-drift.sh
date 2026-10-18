#!/usr/bin/env bash
# Stop hook for coding agents: before an agent hands back, run the docs drift check
# on everything changed since main. On drift, exit 2 so the agent sees the findings
# and aligns the docs before it stops. Uses the same check as the pre-commit hook and CI.
input=$(cat)
# second pass after a block: let the agent stop and report instead of looping
[[ $input == *'"stop_hook_active":true'* || $input == *'"stop_hook_active": true'* ]] && exit 0
root=${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)} || exit 0
cd "$root" || exit 0
base=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || echo HEAD)
if ! out=$(tests/docs.sh --since "$base" 2>&1); then
  printf '%s\n\nDocs have drifted from the code. Align them (rules/08-documentation.md), rerun tests/docs.sh, then finish.\n' "$out" >&2
  exit 2
fi
exit 0
