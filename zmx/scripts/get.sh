#!/usr/bin/env bash
#
# Copy a file out of a zmx session into a local file, byte for byte, and
# prove it with a sha256 on both sides. Exit 0 when the checksums match,
# 1 on any failure, 2 on usage error.
#
# Usage:
#   get.sh <session> <remote_path> <local_file>
#
# Examples:
#   get.sh server1 /etc/app/app.conf ./app.conf
#   get.sh server1 /var/log/app.log /tmp/app.log

set -euo pipefail

if [[ $# -ne 3 ]]; then
  sed -n '2,12p' "$0" | sed 's/^# \?//'
  exit 2
fi

SESSION="$1"
REMOTE="$2"
LOCAL="$3"

# Output from run comes through the PTY: \r\n line ends, sometimes the
# echoed command first, the ZMX_TASK_COMPLETED marker last. Markers on their
# own lines bracket the payload, so none of that can leak into the file.
# Base64 survives the PTY where raw bytes would not. zmx 1.0.1.
TAG="ZMXGET$$"
out=$(zmx run "$SESSION" bash -c \
  'set -e; sum=$( { command -v sha256sum >/dev/null && sha256sum "$1"; } || shasum -a 256 "$1"); echo "$2-SUM ${sum%% *}"; echo "$2-BEGIN"; base64 < "$1"; echo "$2-END"' \
  _ "$REMOTE" "$TAG" | tr -d '\r') \
  || { echo "get: reading $REMOTE in $SESSION failed" >&2; exit 1; }

want=$(sed -n "s/^$TAG-SUM \([0-9a-f]\{64\}\)\$/\1/p" <<< "$out")
sed -n "/^$TAG-BEGIN\$/,/^$TAG-END\$/p" <<< "$out" | sed '1d;$d' | base64 -d > "$LOCAL"

sha() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi; }
got=$(sha "$LOCAL" | cut -c1-64)

if [[ -z "$want" || "$want" != "$got" ]]; then
  echo "get: checksum mismatch for $REMOTE: session ${want:-none}, local $got" >&2
  exit 1
fi
