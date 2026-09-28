#!/usr/bin/env bash
# Playwright in a persistent container.
#   run.sh [--clean] <workspace>      script on stdin
#   result: <workspace>/.tmp/playwright/result.json
# IMAGE and PW_VERSION move together: the image carries the browser builds that
# playwright-core@PW_VERSION expects. Bump both, then run with --clean.
set -euo pipefail

IMAGE="mcr.microsoft.com/playwright:v1.63.0-noble"
PW_VERSION="1.63.0"
IDLE_TIMEOUT=600                                       # s without a run; container exits
SCRIPT_TIMEOUT_MS="${PW_SCRIPT_TIMEOUT_MS:-120000}"    # per script, enforced by runner.js
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# CONTAINER_BIN in the env wins, then podman, then docker.
RT=""
for c in "${CONTAINER_BIN:-}" podman docker; do
  [ -n "$c" ] && command -v "$c" >/dev/null 2>&1 && { RT=$c; break; }
done
[ -n "$RT" ] || { echo "run.sh: podman or docker required" >&2; exit 1; }

CLEAN=false
[ "${1:-}" = "--clean" ] && { CLEAN=true; shift; }
WORKSPACE="${1:?usage: run.sh [--clean] <workspace>}"
mkdir -p "$WORKSPACE"
WORKSPACE="$(cd "$WORKSPACE" && pwd)"
WORKDIR="$WORKSPACE/.tmp/playwright"
mkdir -p "$WORKDIR"

# Name = basename + hash of the full path. Basename alone collided: every
# session scratchpad is named scratchpad/, and the first one owned the container.
# cksum, not sha1sum: POSIX, present on macOS.
HASH="$(printf '%s' "$WORKDIR" | cksum | cut -d' ' -f1)"
NAME="pw-$(basename "$WORKSPACE")-$HASH"

# SELinux relabel only when enforcing/permissive.
SELABEL=""
if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" != "Disabled" ]; then SELABEL=",Z"; fi

# --network=host: localhost dev servers on Linux. On macOS the host network is
# the podman machine VM; the Mac is host.containers.internal. Untested on macOS.
NET="--network=host"

running() { [ "$($RT inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = "true" ]; }
mount_of() { $RT inspect -f '{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' "$1" 2>/dev/null; }

# Script from stdin. A TTY means an interactive call with nothing piped.
if [ -t 0 ]; then : > "$WORKDIR/script.js"; else cat > "$WORKDIR/script.js"; fi

if $CLEAN; then
  $RT rm -f "$NAME" >/dev/null 2>&1 || true
  echo "removed container $NAME" >&2
  [ -s "$WORKDIR/script.js" ] || exit 0
fi

# Empty script used to run and exit 0. Under an agent's shell stdin is never a
# TTY, so a bare call silently did nothing.
[ -s "$WORKDIR/script.js" ] || { echo "run.sh: no script on stdin" >&2; exit 2; }

if ! $RT image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "pulling $IMAGE (first time, ~2 GB)" >&2
  $RT pull -q "$IMAGE" >/dev/null
fi

cmp -s "$SCRIPT_DIR/runner.js" "$WORKDIR/runner.js" 2>/dev/null || cp "$SCRIPT_DIR/runner.js" "$WORKDIR/runner.js"

# Recreate when the container is bound elsewhere, or when its mount went stale
# (workspace deleted and recreated: the bind still points at the old inode).
if running "$NAME"; then
  if [ "$(mount_of "$NAME")" != "$WORKDIR" ] || ! $RT exec "$NAME" test -f /workspace/script.js 2>/dev/null; then
    $RT rm -f "$NAME" >/dev/null 2>&1 || true
  fi
fi

if ! running "$NAME"; then
  $RT rm -f "$NAME" >/dev/null 2>&1 || true
  # shellcheck disable=SC2016  # idle loop runs inside the container
  $RT run -d --name "$NAME" $NET \
    -v "$WORKDIR:/workspace${SELABEL}" \
    "$IMAGE" \
    sh -c 'touch /tmp/.last_run; while sleep 30; do [ $(( $(date +%s) - $(stat -c %Y /tmp/.last_run) )) -gt '"$IDLE_TIMEOUT"' ] && exit 0; done' \
    >/dev/null
  echo "started container $NAME" >&2
  $RT exec -e npm_config_update_notifier=false "$NAME" sh -c \
    'cd /workspace && [ -d node_modules/playwright-core ] || npm install --no-audit --no-fund --loglevel=error playwright-core@'"$PW_VERSION" >&2
fi

$RT exec -e "PW_SCRIPT_TIMEOUT_MS=$SCRIPT_TIMEOUT_MS" "$NAME" sh -c 'cd /workspace && node runner.js'
