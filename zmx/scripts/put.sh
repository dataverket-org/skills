#!/usr/bin/env bash
#
# Copy a local file into a zmx session, byte for byte, and prove it with a
# sha256 on both sides. Exit 0 when the checksums match, 1 on any failure,
# 2 on usage error.
#
# Usage:
#   put.sh <session> <local_file> <remote_path>
#
# Examples:
#   put.sh server1 app.conf /etc/app/app.conf
#   put.sh server1 ./build/app.tar.gz /tmp/app.tar.gz

set -euo pipefail

if [[ $# -ne 3 ]]; then
  sed -n '2,12p' "$0" | sed 's/^# \?//'
  exit 2
fi

SESSION="$1"
LOCAL="$2"
REMOTE="$3"

[[ -f "$LOCAL" ]] || { echo "put: no such file: $LOCAL" >&2; exit 1; }

# zmx write returns before the session has typed all its chunks, and a
# command sent meanwhile lands inside an open quote. Every chunk here is a
# blocking run with its own exit code instead. A Linux PTY takes at most
# 4096 bytes on one input line: above that, half the runs on Ubuntu 24.04
# never saw their marker. So each typed line stays under 3800 bytes, with
# room for the wrapper and the path, which zmx may quote at twice its
# length. macOS took 85 KB lines. zmx 1.0.1.
# Divide first: whole base64 groups of 4 characters, 3 bytes each.
# shellcheck disable=SC2017
CHUNK=$(( (3800 - 120 - 2 * ${#REMOTE}) / 4 * 3 ))
(( CHUNK >= 300 )) || { echo "put: remote path too long: $REMOTE" >&2; exit 1; }

# Each word is passed to run as-is and quoted by zmx; base64 needs no quoting.
zmx run "$SESSION" bash -c ': > "$1"' _ "$REMOTE" >/dev/null

size=$(wc -c < "$LOCAL" | tr -d ' ')
for (( i = 0; i * CHUNK < size; i++ )); do
  b64=$(dd if="$LOCAL" bs="$CHUNK" skip="$i" count=1 2>/dev/null | base64 | tr -d '\n')
  zmx run "$SESSION" bash -c 'printf %s "$1" | base64 -d >> "$2"' _ "$b64" "$REMOTE" >/dev/null \
    || { echo "put: chunk at byte $((i * CHUNK)) failed" >&2; exit 1; }
done

# Output from run carries the echoed command, \r and the marker; only a
# line that starts with 64 hex digits is the checksum.
sha() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi; }
want=$(sha "$LOCAL" | cut -c1-64)
got=$(zmx run "$SESSION" bash -c 'if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi' _ "$REMOTE" \
  | tr -d '\r' | grep -oE '^[0-9a-f]{64}' || true)

if [[ "$want" != "$got" ]]; then
  echo "put: checksum mismatch for $REMOTE: local $want, session ${got:-none}" >&2
  exit 1
fi
