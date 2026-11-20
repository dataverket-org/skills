---
name: zmx
description: Work in named zmx terminal sessions that persist. Use whenever the user names a zmx session to work in, asks to run commands on a server, host or container they have a session open to, or wants a command to outlive the current shell, such as a dev server, a file or test watcher, a database server, or anything started once and observed over time. Use it even when "zmx" is not named; "run this on server1", "do it in the dev session", "start the dev server", "keep this running and tell me when it's ready" and "run npm run dev and check the logs" all qualify. Not for one-shot commands that finish in seconds and only you consume.
---

# zmx

A session is a named PTY behind a Unix socket. The operator attaches to it
from any window; the agent types into it and reads it without attaching.
Upstream: https://github.com/neurosnap/zmx. Written against 0.8.1; `run`
changed in 0.7.0 (bash, blocking, quoting). `README.md` here is the
operator's side.

## Which mode

| Situation | Mode |
|---|---|
| The user names a session, or the work is on a host or container they opened a session to | 1. Portal |
| A process must keep running: server, watcher, database | 2. Service |
| A command only the agent consumes, that ends on its own | Neither: own Bash, background if long |

If the user might want to look at it or touch it, or it must outlive the
conversation, put it in a zmx session.

## Rules that always apply

- **Use `-d` for anything long-lived.** Plain `run` streams the output and
  returns the command's exit code, so it blocks until the command exits and
  a server hangs the agent. `run <name> -d ...` returns at once; track it
  with `zmx wait` or `scripts/wait.sh`.
- **Pass the command as words, not one quoted string.** `run` types its
  arguments as-is and re-quotes one that has spaces, so
  `zmx run s 'npm run dev'` runs the literal `'npm run dev'`: not found.

  ```bash
  zmx run "$S" -d npm run dev                          # words
  printf 'npm run build && npm test\n' | zmx run "$S"  # ; | && > : via stdin
  zmx run "$S" -d bash -c 'sleep 2; echo ready'        # or a bash -c wrapper
  ```
- **Do not `zmx attach`.** It blocks the shell on a PTY. Inside a session
  `ZMX_SESSION` is set and `attach` moves that terminal to the named session,
  taking the user's window with it. `run`, `history`, `tail`, `wait` and
  `send` never switch.
- **Send one command at a time to a session.** Commands queue in one shell;
  never send two in parallel.
- **Leave interactive prompts to the operator.** `run` gives the command
  `/dev/null` on stdin, so pagers exit, but anything that reads the TTY
  (`sudo`, an `ssh` passphrase, `read < /dev/tty`, an editor) waits for a
  human. See "Hand a prompt to the operator". To recover, send Ctrl+C as raw
  bytes, which carry no marker: `zmx send "$S" "$(printf '\x03')"`.
- **Kill only your own sessions.** Other agents and the operator share the
  host. Kill only sessions under this project's prefix, and never a portal
  session the operator opened.
- **Do not upgrade zmx mid-task.** An IPC change orphans running sessions,
  so no `brew upgrade zmx`.

## 1. Portal: work in a session the operator opened

The operator attached `server1`, logged in and named it. Send every command
for that host through it; keep the agent's own Bash for local work.

```bash
S=server1
zmx list --short | grep -qx "$S" || { echo "no session $S; ask the operator to open it"; exit 1; }
zmx run "$S" echo "shell=$SHELL host=$(hostname)"   # once: where am I
zmx run "$S" df -h                                  # output and exit code come back
zmx run "$S" cat /etc/os-release
cat local.conf | zmx write "$S" /etc/app/app.conf   # file in, base64 under the hood
zmx run "$S" systemctl restart web && zmx run "$S" systemctl is-active web
```

Exit codes need `$?` in the session's shell: bash and zsh work, fish does
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

- Name a session `${PROJECT}-<role>`.
- Label it right after creating it, since `run` cannot label at creation.
  Labels mark ownership when names are ambiguous on a shared host;
  `zmx list | grep project="$PROJECT"` finds ours.
- Optionally set `ZMX_SESSION_PREFIX="${PROJECT}-"`, which scopes every
  command and a bare `zmx wait` to the prefix.

For several processes, use one session per role:

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

Read through `output.sh`, not raw history. Raw history carries the typed
command with its `ZMX_TASK_COMPLETED` marker, so a bare `grep` matches the
command you sent. `output.sh` joins wrapped lines, drops echoes and markers
and strips ANSI; the other two scripts read through it. To keep a log:
`printf 'cmd 2>&1 | tee -a log\n' | zmx run "$S" -d`.

### Detached commands that finish

```bash
zmx run "${PROJECT}-tests" -d npm test
zmx wait "${PROJECT}-tests"                   # the task's exit code
zmx wait "${PROJECT}-build" "${PROJECT}-lint"
zmx list | grep "name=${PROJECT}-tests"       # exit_code= and ended= once done
```

`wait` on a server blocks forever; use `scripts/wait.sh` there.

### Lifecycle

```bash
zmx list                                      # name, pid, clients, cwd, labels, exit_code
zmx kill "$S"; zmx kill "$S" --force
zmx list --short 2>/dev/null | grep "^${PROJECT}-" | while read -r s; do zmx kill "$s"; done
```

A session keeps the environment it was created with, so `SSH_AUTH_SOCK`
inside goes stale after a re-login. Recreate the session; do not debug it.

## Where to look

| Task | Look here |
|---|---|
| Program output without echoes or ANSI | `scripts/output.sh` |
| Scan scrollback for a regex | `scripts/scan.sh` |
| Wait for a process to log "ready" | `scripts/wait.sh` |
| Full CLI surface and flags | `zmx help` (no `--help`) |
| Operator's side: attach, prompts, troubleshooting | `README.md` |
| Source, changelog, the author's portal write-up | https://github.com/neurosnap/zmx, https://bower.sh/zmx-ai-portal |
