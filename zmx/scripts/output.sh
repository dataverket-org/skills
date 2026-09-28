#!/usr/bin/env bash
#
# Print a zmx session's program output: scrollback without ANSI, without
# the echoed command lines and without ZMX_TASK_COMPLETED markers.
# Exit 0 always (empty output is not an error), 2 on usage error.
#
# Usage:
#   output.sh <session>
#
# Examples:
#   output.sh myapp-server | tail -20
#   output.sh myapp-build | grep -c warning

set -euo pipefail

if [[ $# -ne 1 ]]; then
  sed -n '2,12p' "$0" | sed 's/^# \?//'
  exit 2
fi

# History is rendered at the PTY width, so a long echoed command wraps and
# its marker lands on the next line. Lines of exactly the widest length are
# treated as continued and joined, then any line carrying the marker is
# dropped: that removes both the echoed command and the marker itself.
# A real output line that is exactly screen-wide merges with its successor;
# grep still finds patterns, only --context around it shifts. zmx 0.8.1.
zmx history "$1" --vt 2>/dev/null \
  | sed -E $'s/\x1b\\[[0-9;?]*[A-Za-z]//g; s/\x1b\\][^\x07]*\x07//g; s/\r//g' \
  | awk '
      { line[NR] = $0; if (length($0) > w) w = length($0) }
      END {
        buf = ""
        for (i = 1; i <= NR; i++) {
          buf = buf line[i]
          if (length(line[i]) == w && i < NR) continue
          if (buf !~ /ZMX_TASK_COMPLETED/ && buf ~ /[^[:space:]]/) print buf
          buf = ""
        }
      }'
