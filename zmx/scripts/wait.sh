#!/usr/bin/env bash
#
# Wait for a regex pattern to appear in a zmx session's scrollback.
# Exit 0 on match, 1 on timeout (with last N lines of history on
# stderr to aid diagnosis).
#
# Usage:
#   wait.sh <session> <pattern> [--timeout SECONDS] [--tail N]
#
# Defaults: --timeout 30, --tail 20.
#
# Examples:
#   wait.sh myapp-server 'listening on'
#   wait.sh myapp-server 'ready'                 --timeout 60
#   wait.sh myapp-db     'accepting connections' --timeout 300 --tail 50

set -euo pipefail

if [[ $# -lt 2 ]]; then
  sed -n '2,15p' "$0" | sed 's/^# \?//'
  exit 2
fi

SESSION="$1"
PATTERN="$2"
shift 2

TIMEOUT=30
TAIL_N=20

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --tail)    TAIL_N="$2"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *)         echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Program output only: see output.sh for the echo and marker filtering.
output() { "$(dirname "$0")/output.sh" "$SESSION"; }

deadline=$(( $(date +%s) + TIMEOUT ))

while [[ $(date +%s) -lt $deadline ]]; do
  if output | grep -iEq -- "$PATTERN"; then
    exit 0
  fi
  sleep 1
done

echo "wait: timeout after ${TIMEOUT}s waiting for /${PATTERN}/ in ${SESSION}" >&2
echo "--- last ${TAIL_N} lines of scrollback ---" >&2
output | tail -n "$TAIL_N" >&2
exit 1
