#!/usr/bin/env bash
#
# Scan a zmx session's scrollback for a regex pattern.
# Exit 0 on match (prints matching lines), 1 on no match,
# 2 on usage error.
#
# Usage:
#   scan.sh <session> <pattern> [--context N]
#
# Defaults: --context 0 (just matching lines).
#
# Examples:
#   scan.sh myapp-build 'error|fail|traceback'
#   scan.sh myapp-build 'level=error' --context 3
#   if scan.sh myapp-build 'level=error'; then echo "saw errors"; fi

set -euo pipefail

if [[ $# -lt 2 ]]; then
  sed -n '2,15p' "$0" | sed 's/^# \?//'
  exit 2
fi

SESSION="$1"
PATTERN="$2"
shift 2

CONTEXT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context) CONTEXT="$2"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *)         echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Program output only: see output.sh for the echo and marker filtering.
# grep exit status: 0 = match, 1 = no match, 2+ = error. Forward all three
# so callers can distinguish "no errors" from "the scan itself broke".
"$(dirname "$0")/output.sh" "$SESSION" | grep -iE -C "$CONTEXT" -- "$PATTERN"
