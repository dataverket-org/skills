---
name: zmx
description: Use whenever a command needs to outlive the current shell — dev servers, file/test watchers, database servers, anything you'd start once and observe over time. Trigger even when "zmx" isn't named — "start the dev server", "run the watcher in the background", "keep this running and tell me when it's ready", or "run npm run dev and check the logs" all qualify. Do NOT use for one-shot commands that finish in seconds.
---

# zmx

Session-persistence wrapper around long-lived terminal processes. Each
session is a named, detached PTY backed by a per-session Unix socket;
the agent sends commands and reads scrollback non-interactively.

Upstream: https://github.com/neurosnap/zmx. Written against 0.8.1.
`run` changed in 0.7.0 (bash, blocking, quoting); older notes do not apply.

## Always-active gotchas

### `zmx run` blocks until the command exits. `-d` for anything long-lived

Plain `run` returns the command's exit code when it finishes. A dev
server never finishes, so the agent hangs. `run <name> -d ...` returns
at once; `zmx wait` and `scripts/wait.sh` track it afterwards.

### Pass the command as words, never as one quoted string

`run` types its arguments into a bash session as-is. One argument with
spaces is re-quoted, so `zmx run s 'npm run dev'` runs the literal
`'npm run dev'`: command not found.

```bash
zmx run "$SESSION" -d npm run dev                   # words
printf 'npm run build && npm test\n' | zmx run "$SESSION"   # ; | && > : via stdin
zmx run "$SESSION" -d bash -c 'sleep 2; echo ready' # or a bash -c wrapper
```

Redirects and pipes as words are typed literally; use stdin or `bash -c`.

### Never `zmx attach` from agent context

`attach` blocks the calling shell on a PTY. Inside a session
`ZMX_SESSION` is set and `attach` switches that terminal instead of
opening a client, taking the user's terminal with it. `run`, `history`,
`tail`, `wait` never switch. Reserve `attach` for the human.

### Interactive programs

`run` gives the command `/dev/null` on stdin, so pagers and prompts
exit instead of blocking. A program that opens the TTY itself (`vim`,
`less` on a tty check) still hangs the session. Recover with:

```bash
zmx send "$SESSION" "$(printf '\x03')"   # Ctrl+C, raw bytes, no marker
zmx history "$SESSION" | tail -100
```

### One project = one prefix; never kill across prefixes

Multiple agents share the host. Derive the session name from the
project (git root or `$PWD`) and kill only sessions under that prefix.

### Version upgrades kill existing sessions

An IPC change in the new daemon orphans running sessions. No
`brew upgrade zmx` while a long task is mid-flight.

### `send` vs `run`

`send` writes raw bytes: no completion marker, no exit code, no `\r`
appended. For control characters and prompts. `run` for commands.

## Session naming

```bash
PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" || basename "$PWD")
```

Names follow `${PROJECT}-<role>`: `myapp-server`, `myapp-tests`.
`ZMX_SESSION_PREFIX="${PROJECT}-"` makes every command prefix-scoped
and `zmx wait` with no name wait for the whole prefix; `list` still
prints full names. Optional; the explicit prefix works everywhere.

## Starting processes (idempotent)

```bash
SESSION="${PROJECT}-server"

if ! zmx list --short 2>/dev/null | grep -q "^${SESSION}$"; then
  zmx run "$SESSION" -d npm run dev
  zmx set "$SESSION" project="$PROJECT" role=server
fi
```

Labels (`set`, `get`, `clear`, shown by `zmx list`) mark ownership when
names alone are ambiguous on a shared host; `zmx list | grep
project="$PROJECT"` finds ours. `run` cannot label at creation, so set
them right after; `attach --labels` can, but attach is not for agents.

For multiple processes:

```bash
for name_cmd in "server:npm run dev" "tests:npm run test:watch"; do
  name="${name_cmd%%:*}"; cmd="${name_cmd#*:}"
  SESSION="${PROJECT}-${name}"
  if ! zmx list --short 2>/dev/null | grep -q "^${SESSION}$"; then
    printf '%s\n' "$cmd" | zmx run "$SESSION" -d
    zmx set "$SESSION" project="$PROJECT" role="$name"
  fi
done
```

## Sending one-off commands

```bash
zmx run "${PROJECT}-main" cat README.md            # blocks, returns exit code
printf 'ls -lah\n' | zmx run "${PROJECT}-main"     # via stdin
zmx write "${PROJECT}-main" /tmp/data.json < file  # file through the session, works over SSH
```

## Reading output

```bash
zmx history "${PROJECT}-server"               # scrollback, wrapped at PTY width
zmx history "${PROJECT}-server" | tail -50
zmx tail "${PROJECT}-server"                  # follow live (blocks)
```

`tail` blocks like `tail -f`: for human observation, never in automation.

```bash
scripts/output.sh "${PROJECT}-server" | tail -20   # program output only
```

Raw history is rendered at the PTY width and carries the typed command
with the `ZMX_TASK_COMPLETED` marker appended, so a bare `grep` matches
the command you sent. `output.sh` joins wrapped lines, drops echoes and
markers, strips ANSI. `scan.sh` and `wait.sh` read through it.

## Scanning scrollback for a pattern

```bash
scripts/scan.sh "${PROJECT}-build" 'error|fail|traceback'
scripts/scan.sh "${PROJECT}-build" 'level=error' --context 3
```

Exit 0 = match (lines on stdout). Exit 1 = no match. Exit 2 = usage.

## Waiting for a process to become ready

```bash
scripts/wait.sh "${PROJECT}-server" 'listening on'
scripts/wait.sh "${PROJECT}-server" 'ready' --timeout 60
```

Exit 0 = matched. Exit 1 = timeout, last 20 lines on stderr.
Prefer a tool's own status API (kubectl, db clients) over a scrollback
match when one exists.

## Waiting for completion

For detached commands that finish on their own:

```bash
zmx run "${PROJECT}-tests" -d npm test
zmx wait "${PROJECT}-tests"                              # exit code of the task
zmx wait "${PROJECT}-build" "${PROJECT}-lint"            # several
zmx list | grep "^.*name=${PROJECT}-tests"               # exit_code= and ended= once done
```

Servers and watchers never finish: `wait` on those blocks forever, use
`scripts/wait.sh`.

## Lifecycle

```bash
zmx list                                                 # name, pid, clients, cwd, labels, exit_code
zmx list --short                                         # names only
zmx kill "${PROJECT}-server"
zmx kill "${PROJECT}-server" --force

zmx list --short 2>/dev/null | grep "^${PROJECT}-" | while read -r s; do
  zmx kill "$s"
done
```

A session keeps the environment it was created with. `SSH_AUTH_SOCK`
inside one goes stale after a re-login; recreate the session rather
than debugging the agent.

## When to use zmx

| Scenario                              | zmx? |
|---|---|
| Dev server (`npm run dev`, `rails s`) | Yes |
| File watcher                          | Yes |
| Test watcher                          | Yes |
| Database server                       | Yes |
| One-shot build                        | No  |
| Quick command (<10s)                  | No  |
| Need stdout directly in conversation  | No  |

Rule of thumb: anything you would `&` and `disown`, or open a separate
terminal tab for, goes in zmx.

## When to consult what

| Task                                | Look here |
|---|---|
| Program output without echoes or ANSI | `scripts/output.sh` |
| Scan a session's scrollback for a regex | `scripts/scan.sh` |
| Wait for a process to log "ready"   | `scripts/wait.sh` |
| Full CLI surface and flags          | `zmx help` (no `--help`) |
| Source, releases, changelog         | https://github.com/neurosnap/zmx |
