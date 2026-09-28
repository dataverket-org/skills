---
name: zmx
description: Use whenever the user names a zmx session to work in, asks to run commands on a server, host or container they have a session open to, or wants a command to outlive the current shell — dev servers, file/test watchers, database servers, anything started once and observed over time. Trigger even when "zmx" isn't named — "run this on server1", "do it in the dev session", "start the dev server", "keep this running and tell me when it's ready", or "run npm run dev and check the logs" all qualify. Do NOT use for one-shot commands that finish in seconds and only you consume.
---

# zmx

Named terminals that persist. A session is a PTY behind a Unix socket;
the operator attaches to it from any window, the agent types into it and
reads it without attaching. Upstream: https://github.com/neurosnap/zmx.
Written against 0.8.1; `run` changed in 0.7.0 (bash, blocking, quoting).
`README.md` here is the operator's side.

## Which mode

| Situation | Mode |
|---|---|
| The user names a session, or the work is on a host or container they opened a session to | 1. Portal |
| A process must keep running: server, watcher, database | 2. Service |
| A command only the agent consumes, that ends on its own | Neither: own Bash, background if long |

Rule: if the user might want to look at it or touch it, or it must outlive
the conversation, it goes in a zmx session.

## Always-active gotchas

### `zmx run` blocks until the command exits. `-d` for anything long-lived

Plain `run` streams the output back and returns the command's exit code.
A server never exits, so the agent hangs. `run <name> -d ...` returns at
once; `zmx wait` and `scripts/wait.sh` track it afterwards.

### Pass the command as words, never as one quoted string

`run` types its arguments as-is. One argument with spaces is re-quoted,
so `zmx run s 'npm run dev'` runs the literal `'npm run dev'`: not found.

```bash
zmx run "$S" -d npm run dev                          # words
printf 'npm run build && npm test\n' | zmx run "$S"  # ; | && > : via stdin
zmx run "$S" -d bash -c 'sleep 2; echo ready'        # or a bash -c wrapper
```

### Never `zmx attach` from agent context

`attach` blocks the shell on a PTY. Inside a session `ZMX_SESSION` is set
and `attach` moves that terminal to the named session, taking the user's
window with it. `run`, `history`, `tail`, `wait`, `send` never switch.

### One session, one command at a time

Commands into a session queue in one shell. Never send two in parallel.

### Interactive prompts are the operator's

`run` gives the command `/dev/null` on stdin, so pagers exit. Anything
that reads the TTY (`sudo`, `ssh` passphrases, `read < /dev/tty`, an
editor) waits for a human. See "Hand a prompt to the operator". Recovery:

```bash
zmx send "$S" "$(printf '\x03')"   # Ctrl+C, raw bytes, no marker
```

### Never kill across prefixes

Other agents and the operator share the host. Kill only sessions under
this project's prefix, and never a portal session the operator opened.

### Version upgrades kill existing sessions

An IPC change orphans running sessions. No `brew upgrade zmx` mid-task.

## 1. Portal: work in a session the operator opened

The operator attached `server1`, logged in, and named it. Every command
for that host goes through it; the agent's own Bash stays for local work.

```bash
S=server1
zmx list --short | grep -qx "$S" || { echo "no session $S; ask the operator to open it"; exit 1; }
zmx run "$S" echo "shell=$SHELL host=$(hostname)"   # once: where am I
zmx run "$S" df -h                                  # output and exit code come back
zmx run "$S" cat /etc/os-release
cat local.conf | zmx write "$S" /etc/app/app.conf   # file in, base64 under the hood
zmx run "$S" systemctl restart web && zmx run "$S" systemctl is-active web
```

Exit codes need `$?` in the session's shell: bash and zsh work; fish does
not (0.8.1 has no fish flag).

### Hand a prompt to the operator

```bash
zmx run "$S" -d sudo systemctl restart web    # will ask for a password
# tell the user: "attach to server1 (zmx attach server1) and answer the prompt"
zmx wait "$S"                                  # returns the exit code when they have
```

Tested: a detached command reading the TTY, answered from an attached
client, released `wait` with the command's exit code.

## 2. Service: a process that keeps running

```bash
PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" || basename "$PWD")
S="${PROJECT}-server"

if ! zmx list --short 2>/dev/null | grep -qx "$S"; then
  zmx run "$S" -d npm run dev
  zmx set "$S" project="$PROJECT" role=server
fi
scripts/wait.sh "$S" 'listening on' --timeout 60
```

Names follow `${PROJECT}-<role>`. Labels mark ownership when names are
ambiguous on a shared host; `zmx list | grep project="$PROJECT"` finds
ours. `run` cannot label at creation, so set right after.
`ZMX_SESSION_PREFIX="${PROJECT}-"` scopes every command and a bare
`zmx wait` to the prefix; optional.

Several processes: one session per role, the loop below.

```bash
for name_cmd in "server:npm run dev" "tests:npm run test:watch"; do
  name="${name_cmd%%:*}"; cmd="${name_cmd#*:}"; S="${PROJECT}-${name}"
  zmx list --short 2>/dev/null | grep -qx "$S" && continue
  printf '%s\n' "$cmd" | zmx run "$S" -d
  zmx set "$S" project="$PROJECT" role="$name"
done
```

### Reading a running process

```bash
scripts/output.sh "$S" | tail -20             # program output only
scripts/scan.sh "$S" 'error|fail|traceback'   # exit 0 match, 1 none, 2 usage
scripts/wait.sh "$S" 'ready' --timeout 60     # exit 0 match, 1 timeout with tail on stderr
zmx history "$S"                              # raw: wrapped at PTY width, prompts, echoes
zmx tail "$S"                                 # follows, blocks: for humans
```

Raw history carries the typed command with its `ZMX_TASK_COMPLETED`
marker, so a bare `grep` matches the command you sent. `output.sh` joins
wrapped lines, drops echoes and markers, strips ANSI; the other two read
through it. Logs that must be kept: `printf 'cmd 2>&1 | tee -a log\n' | zmx run "$S" -d`.

### Detached commands that finish

```bash
zmx run "${PROJECT}-tests" -d npm test
zmx wait "${PROJECT}-tests"                   # the task's exit code
zmx wait "${PROJECT}-build" "${PROJECT}-lint"
zmx list | grep "name=${PROJECT}-tests"       # exit_code= and ended= once done
```

`wait` on a server blocks forever; use `scripts/wait.sh`.

### Lifecycle

```bash
zmx list                                      # name, pid, clients, cwd, labels, exit_code
zmx kill "$S"; zmx kill "$S" --force
zmx list --short 2>/dev/null | grep "^${PROJECT}-" | while read -r s; do zmx kill "$s"; done
```

A session keeps the environment it was created with; `SSH_AUTH_SOCK`
inside goes stale after a re-login. Recreate rather than debug.

## When to consult what

| Task | Look here |
|---|---|
| Program output without echoes or ANSI | `scripts/output.sh` |
| Scan scrollback for a regex | `scripts/scan.sh` |
| Wait for a process to log "ready" | `scripts/wait.sh` |
| Full CLI surface and flags | `zmx help` (no `--help`) |
| Operator's side: attach, prompts, troubleshooting | `README.md` |
| Source, changelog, the author's portal write-up | https://github.com/neurosnap/zmx, https://bower.sh/zmx-ai-portal |
