---
name: bash-style
description: Bash coding style for scripts that get committed to a git repository, distilled from postmodern's ruby-install and chruby. Use it whenever you write or edit a shell script, function library, bootstrap or install script, bin/ wrapper, CI helper or shunit2 test that will live in a repo, even if the user just says "add a script" or "fix this script" and never mentions style. Not for one-off commands typed into a terminal.
---

# Bash style

Scripts in a repository are read many more times than they are written, and
by people who did not write them. This style optimises for that reader: small
functions with a one-line comment, arguments named on the first lines, every
failure returned to the caller, and bash 3 features only so the script runs on
a stock macOS as well as on Linux. If the repository already has shell scripts
in another consistent style, follow those; this skill is the default and
settles what they leave open.

## Layout

- `#!/usr/bin/env bash` on executables. Library files that are only sourced
  get no shebang and are never executable.
- A tool installed onto PATH: a thin entry point in `bin/<name>` that sources
  `share/<name>/<name>.sh` and reads as a list of steps. Functions live in
  `share/<name>/*.sh`, one topic per file (`logging.sh`, `util.sh`,
  `<thing>/functions.sh`).
- An in-repo tool, run only from the repository it lives in: `bin/` alone,
  no `share/`. One executable per action, named after it, and the shared
  functions, logging included, in `bin/functions.sh`, sourced with
  `source "${0%/*}/functions.sh"`.
- Find yourself with parameter expansion, not external commands:
  `"${0%/*}"` in a script, `"${BASH_SOURCE[0]%/*}"` in a library.
- Tabs for indentation, spaces only to align continuation lines. Keep lines
  within 80 columns.

## Functions

```bash
#
# Downloads a URL into a destination path.
#
function download()
{
	local url="$1"
	local dest="$2"

	mkdir -p "${dest%/*}" || return $?
	run curl -f -L -o "$dest" "$url" || return $?
}
```

- The `function` keyword, and the opening brace on its own line.
- A three-line comment block above every function saying what it does, in
  the present tense.
- Load positional arguments into `local` variables first, then a blank line.
- Every command that can fail ends in `|| return $?`. Libraries never call
  `exit` and never rely on `set -e`; the entry point decides what is fatal.
- Placeholders that a later file overrides are one-liners:
  `function pre_install() { return; }`.

## The entry point

```bash
parse_options "$@" || exit $?
init || exit $?

download_ruby || fail "Download of $ruby_url failed!"
extract_ruby  || fail "Unpacking of $ruby_archive failed!"
```

Each step is a function call with `|| fail "<what failed>"`. Align the `||`
of consecutive steps. `fail` prints the message and exits; only entry points
use it.

## Logging

Four functions, defined once in `logging.sh`, all taking one string:
`log` prints `>>> msg` to stdout, `warn` prints `*** msg` and `error` prints
`!!! msg` to stderr, `debug` prints `[DEBUG] msg` to stderr only when
`enable_debug` is `1`. Colour is used only when the stream is a terminal
(`[[ -t 1 ]]`). `run` calls `debug "$*"` then `"$@"`, so every external
command is visible with `--debug`. Messages end with ` ...` while something
is in progress and with `!` when something failed. A message that is not a
log line but a usage error is prefixed with the program name:
`echo "chruby: unknown Ruby: $1" >&2`.

## Options

`usage()` is a `cat <<USAGE` heredoc listing options, then examples.
`parse_options()` is one `while [[ $# -gt 0 ]]; do case "$1" in ... esac;
done`, each option ending in `shift` or `shift 2`, with `--` handing the rest
to an array, `-*)` rejecting unknown options with `<name>: unrecognized
option $1` on stderr and `return 1`, and `*)` collecting positionals into
`argv+=("$1")`. Positionals are validated after the loop with a `case` on
`${#argv[*]}`. `-V|--version` and `-h|--help` print and `exit`.

## Expressions

- `[[ ]]` for tests, `(( ))` for arithmetic, `$(...)` never backticks.
- `"${path##*/}"` not `basename`, `"${path%/*}"` not `dirname`,
  `"${var:-default}"` for defaults and `"${flag:+-q}"` for optional flags.
- Quote every string variable. `"$@"` and `"${array[@]}"`, never `$*` in a
  command line.
- `case` for dispatch on a string, with one-line arms aligned when they are
  short: `md5)	program="$md5sum" ;;`.
- Single-line forms where they read well: `[[ -n "$x" ]] && do_thing`, and
  `if   cond; then a` / `elif cond; then b` / `fi` with aligned keywords.
- Bash 3 only: no associative arrays, no `${var,,}`, no `mapfile`, no `|&`.
  `shopt -s extglob` is fine when a `case` pattern needs it.
- Test for a tool with `command -v tool >/dev/null`, and pick the first of
  several with a chain of `if command -v a; then x="a" / elif ...`.
- Globals a user may set from the environment are `${RUBY_INSTALL_SRC_DIR:-…}`
  read once at the top. In a library that is sourced into an interactive
  shell (chruby), exported and user-facing globals are UPPERCASE and
  temporaries lowercase; in a standalone tool, lowercase throughout.

## Tests and checks

shunit2, one `test/<topic>-tests/<function>_test.sh` per function, each test a
`function test_<what>()` with `assertEquals "message" "$expected" "$actual"`,
ending in `SHUNIT_PARENT=$0 . $SHUNIT2`. A `test/helper.sh` finds shunit2,
points `HOME` at a fixtures directory and sources the library.

shellcheck over every executable and library, as bash since libraries have
no shebang, with the five codes this style triggers on purpose excluded:

```sh
shellcheck -s bash -e SC2034,SC2154,SC1090,SC1091,SC2242 bin/* share/*/*.sh
shellcheck -s bash -e SC2034,SC2154,SC1090,SC1091,SC2242 bin/*
```

The first for a tool installed onto PATH, the second for an in-repo tool.

A complete small tool in this style is in `references/skeleton.sh`; copy its
shape rather than its content.
