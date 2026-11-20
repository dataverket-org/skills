# macOS's /bin/bash is 3.2, and env finds it when Homebrew's bin is not first
# in PATH. This block itself runs in bash 3.2.
if (( BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] < 502 )); then
	cat >&2 <<EOF
${0##*/}: needs bash 5.2 or newer, but runs in $BASH $BASH_VERSION.
Install a newer bash (on macOS: brew install bash) and put its directory
before /bin in PATH, so that "#!/usr/bin/env bash" finds it.
EOF
	exit 1
fi
