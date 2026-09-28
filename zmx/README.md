# zmx for operators

This is the human side of the `zmx` skill. `SKILL.md` tells the agent what
to do; this page tells you what is going on and what is yours to do.

## The idea

A zmx session is a terminal that keeps running on its own and has a name.
Anyone who knows the name can look into it or type into it, from any
window, and it keeps running when the window closes. That is the whole
tool: no tabs, no panes, just named terminals that persist.

The agent uses that in three ways. The first is the one that matters most.

## 1. The portal: the agent works in your terminals

You open a terminal and attach to a session, then get it into the place
where the work is:

```sh
zmx attach server1      # a new named terminal
ssh server1             # now that terminal is logged in
```

Do the same for `server2`. Then start the agent in its own session:

```sh
zmx attach agent
claude
```

Tell the agent: "use zmx sessions server1 and server2 for the server work".
From then on it types into your terminals instead of logging in itself:

```sh
zmx run server1 df -h
zmx run server2 systemctl restart web
```

Each command runs in the shell that is already logged in. The output goes
back to the agent, with the exit code, as if it had run the command
locally. You can watch it happen in the `server1` window, scroll back, or
type in between.

**What this buys you**

- The agent never holds the SSH keys or credentials. You logged in; it
  types.
- You see everything it does, where it does it.
- The same instructions work whether the session is a local shell, a
  container, or a remote host. You choose what the session points at.

**When it needs you.** A password prompt, a YubiKey touch, a confirmation
that reads from the terminal: the agent cannot answer those. It will start
the command, then say "attach to server2 and answer the prompt". You do:

```sh
zmx attach server2      # answer, then close the window or press ctrl+\
```

The agent is waiting on the command and continues when it finishes.

## 2. Services: something that should keep running

"Start the dev server and tell me when it is ready." The agent starts it in
a session of its own, detached, and watches the output:

```sh
zmx run org-server -d task preview
```

The server lives in `org-server`, not in the agent's session, so it
survives a closed window or a new conversation tomorrow. If it misbehaves:

```sh
zmx attach org-server   # live log, your keyboard
```

Sessions are named `<project>-<role>`. The agent only ever kills sessions
under its own project prefix, so its cleanup cannot touch yours.

## 3. Neither: ordinary work

Tests, builds, scripts that finish in a minute: the agent runs those in its
own session with its own background mechanism. Nothing to attach to.

**The rule.** If you might want to look at it or touch it, it goes in a
zmx session. If it must outlive the conversation, it goes in a zmx session.
Otherwise it is just a command.

## Things to know

- **Attach, detach, close.** `zmx attach <name>` opens a session in your
  window. `ctrl+\` or closing the window detaches; the session keeps
  running. `zmx kill <name>` ends it.
- **See what exists.** `zmx list` shows every session with its directory
  and labels. `zmx history <name>` prints its scrollback.
- **Several people, one session.** Two windows can attach to the same
  session. Whoever typed last leads; the other sees it live.
- **Inside a session, `zmx attach other` moves your terminal** to the other
  session instead of opening a second window. That is a feature for you and
  a trap for scripts; the agent never attaches.
- **Upgrading zmx kills every session.** Do not `brew upgrade zmx` while
  something you care about is running.
- **The agent's commands echo into scrollback** with a completion marker
  like `ZMX_TASK_COMPLETED:1a2b:0`. That is how it gets the exit code. Harmless.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| The agent says a command was not found, but it exists | It passed the command as one quoted string; zmx types the quotes | The skill says to pass words. Point it at the gotcha. |
| The agent hangs after starting a server | It forgot `-d`; a plain `run` waits for the command to finish | `zmx send <name> "$(printf '\x03')"` sends ctrl+c, then restart with `-d` |
| A session shows a stuck prompt | Something inside wants a TTY: an editor, a pager, `sudo` | Attach and answer, or ctrl+c as above |
| `git push` in an old session fails on the key | The session kept the `SSH_AUTH_SOCK` from when it was created | Kill and recreate the session |
| A session vanished | zmx was upgraded | Start it again |

Upstream: https://github.com/neurosnap/zmx. The author's own write-up of
the portal pattern: https://bower.sh/zmx-ai-portal.
