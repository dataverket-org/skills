---
name: bash-style
description: Bash coding style for scripts that get committed to a git repository, distilled from postmodern's ruby-install and chruby. Use it whenever you write or edit a shell script, function library, bootstrap or install script, bin/ wrapper, CI helper or shunit2 test that will live in a repo, even if the user just says "add a script" or "fix this script" and never mentions style. Not for one-off commands typed into a terminal.
---

# Bash style

A committed script is read far more often than it is written, by people who
did not write it. Write for that reader: small functions, named arguments,
every failure returned to the caller, and bash 3 only, so a stock macOS runs
it too. Where the repository already has a consistent shell style, follow
it; this skill settles what that style leaves open.

## Layout

- Start an executable with `#!/usr/bin/env bash`. Give a library that is only
  sourced no shebang and no execute bit.
- **Tool installed onto PATH**: make `bin/<name>` a thin entry point that
  sources `share/<name>/<name>.sh` and reads as a list of steps. Put the
  functions in `share/<name>/*.sh`, one topic per file (`logging.sh`,
  `util.sh`, `<thing>/functions.sh`).
- **In-repo tool**, run only from its repository: one executable per action
  in `bin/`, named after the action, with the shared functions and logging in
  `bin/functions.sh`. Start each script with
  `source "${0%/*}/functions.sh" || exit $?`.
- When `bin/functions.sh` passes 150 lines, move it to `share/<name>/`, laid
  out as for a tool on PATH, `<name>` being the repository's name. Scripts
  then start with `source "${0%/*}/../share/<name>/<name>.sh" || exit $?`.
  The bound is from ruby-install, where a topic file is 44 to 142 lines.
- Find your own path with parameter expansion, not an external command:
  `"${0%/*}"` in a script, `"${BASH_SOURCE[0]%/*}"` in a library.
- Indent with tabs; use spaces only to align continuation lines. Keep lines
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

- Use the `function` keyword and put the opening brace on its own line.
- Put a three-line comment block above every function that says what it
  does, in the present tense.
- Load the positional arguments into `local` variables first, then leave a
  blank line.
- End every command that can fail with `|| return $?`. A library never relies
  on `set -e` and never calls `exit`, `fail` excepted: the entry point decides
  what is fatal.
- Write a placeholder that a later file overrides as a one-liner:
  `function pre_install() { return; }`.

## Comments

State a fact the code cannot: the choice made, a constraint, a reference.
`# GNU and BSD sed differ on -i; write to a temp file.` or
`# Bound from ruby-install, where a topic file is 44 to 142 lines.`

Do not write reasoning, weigh alternatives or tell how the code came to be.
Do not restate the code: no `# Loop over files` above a `for` loop, no
`# Return on error` beside `|| return $?`. Leave a line that reads clearly
without a comment.

## The entry point

```bash
parse_options "$@" || exit $?
init || exit $?

download_ruby || fail "Download of $ruby_url failed!"
extract_ruby  || fail "Unpacking of $ruby_archive failed!"
```

Make each step a function call with `|| fail "<what failed>"`, and align the
`||` of consecutive steps. Call `fail` only from an entry point.

## Logging

Define these once, in `logging.sh`, or in `bin/functions.sh` for an in-repo
tool within the bound:

| Function | Does |
|---|---|
| `log` | prints `>>> msg` to stdout |
| `warn` | prints `*** msg` to stderr |
| `error` | prints `!!! msg` to stderr |
| `debug` | prints `[DEBUG] msg` to stderr, only when `enable_debug` is `1` |
| `run` | calls `debug "$*"`, then `"$@"`, so `--debug` shows every external command |
| `fail` | calls `error` and exits; the one library function that exits |

- Use colour only when the stream is a terminal (`[[ -t 1 ]]`). End a message
  with ` ...` while something is in progress and with `!` when it failed.
- Prefix a usage error, which is not a log line, with the program name:
  `echo "chruby: unknown Ruby: $1" >&2`.

## Options

- Write `usage()` as a `cat <<USAGE` heredoc: options, then examples.
- Write `parse_options()` as one `while [[ $# -gt 0 ]]; do case "$1" in ...
  esac; done`, each option ending in `shift` or `shift 2`.
- `--` hands the rest to an array. `-*)` rejects an unknown option with
  `<name>: unrecognized option $1` on stderr and `return 1`. `*)` collects
  positionals with `argv+=("$1")`.
- Validate the positionals after the loop with a `case` on `${#argv[*]}`.
- `-V|--version` and `-h|--help` print and `exit`. A script that takes no
  options leaves out `usage`, `parse_options`, `debug` and `run`.

## Expressions

- Use `[[ ]]` for tests, `(( ))` for arithmetic and `$(...)`, never backticks.
- Use `"${path##*/}"` not `basename`, `"${path%/*}"` not `dirname`,
  `"${var:-default}"` for defaults and `"${flag:+-q}"` for optional flags.
- Quote every string variable. Use `"$@"` and `"${array[@]}"`, never `$*` in
  a command line.
- Dispatch on a string with `case`, with short arms on one line, aligned:
  `md5)	program="$md5sum" ;;`.
- Use single-line forms where they read well: `[[ -n "$x" ]] && do_thing`,
  and `if   cond; then a` / `elif cond; then b` / `fi` with aligned keywords.
- Stay within bash 3: no associative arrays, no `${var,,}`, no `mapfile`, no
  `|&`. `shopt -s extglob` is fine when a `case` pattern needs it.
- Test for a tool with `command -v tool >/dev/null`, and pick the first of
  several with a chain of `if command -v a; then x="a" / elif ...`.
- Read a global the user may set from the environment once, at the top:
  `${RUBY_INSTALL_SRC_DIR:-…}`. In a library sourced into an interactive
  shell (chruby), exported and user-facing globals are UPPERCASE and
  temporaries lowercase; in a standalone tool, lowercase throughout.

## Tests and checks

Test with shunit2: one `test/<topic>-tests/<function>_test.sh` per function,
each test a `function test_<what>()` with
`assertEquals "message" "$expected" "$actual"`, the file ending in
`SHUNIT_PARENT=$0 . $SHUNIT2`. A `test/helper.sh` finds shunit2, points `HOME`
at a fixtures directory and sources the library.

Run shellcheck from the repository root over `bin/` and `share/` only, as
bash since libraries have no shebang, with the five codes this style triggers
on purpose excluded:

```sh
shellcheck -s bash -e SC2034,SC2154,SC1090,SC1091,SC2242 bin/*
shellcheck -s bash -e SC2034,SC2154,SC1090,SC1091,SC2242 \
	bin/* share/<name>/*.sh    # with a share/<name>/
```

`references/skeleton.sh` is a complete small tool in this style; copy its
shape, not its content.
