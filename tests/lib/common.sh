#!/usr/bin/env bash
# common.sh — portable helpers shared by every test suite, so the same tests run
# unchanged on Linux (GNU tools) and macOS (BSD tools). Sourced, never run.

# file_mode <path> -> permission bits, e.g. 600
file_mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

# with_timeout <seconds> <cmd...> -> runs cmd, killing it after the limit when a
# timeout tool exists (GNU timeout / Homebrew gtimeout); otherwise just runs it
with_timeout() {
  local s=$1; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"
  else "$@"; fi
}

# pty_run <shell> <command> : runs <command> with <shell> -c inside a pseudo-terminal,
# with stdin forwarded to it, and prints everything the terminal showed.
# util-linux script (Linux) and BSD script (macOS) take different arguments.
pty_run() {
  local sh=$1 cmd=$2 shp
  shp=$(command -v "$sh") || return 127
  if script --version >/dev/null 2>&1; then
    SHELL=$shp script -qfec "$cmd" /dev/null
  else
    SHELL=$shp script -q /dev/null "$shp" -c "$cmd"
  fi
}

# iso_utc <epoch> -> 2026-10-18T17:00:00 (UTC), with GNU or BSD date
iso_utc() { date -u -d "@$1" +%FT%T 2>/dev/null || date -u -r "$1" +%FT%T; }
