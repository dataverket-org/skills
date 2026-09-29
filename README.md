# dataverket-skills

Skills for coding agents. One folder per skill: `SKILL.md`, and `scripts/`,
`references/`, `evals/` where the skill needs them.

| Skill | What it does |
|---|---|
| [bash-style](bash-style/) | Bash style for scripts committed to a repo, after postmodern's ruby-install and chruby: tabs, `function` blocks, `|| return $?`, bash 3, shunit2. |
| [playwright](playwright/) | Browser automation in a persistent container. Screenshots, computed styles, DOM and network checks. |
| [zmx](zmx/) | Long-lived processes in detached sessions: dev servers, watchers, databases. Start, wait for ready, scan output, kill by project. |

## Install

This repo is the canonical copy of each skill. Agents read symlinks to it
from their own skill folders.

| Folder | Read by |
|---|---|
| `~/.claude/skills` | Claude Code |
| `~/.agents/skills` | Other agents. Claude Code does not load skills from it. |

```sh
git clone ssh://git@git.dataverket.org/dataverket/skills.git
cd skills
task link     # first run: symlink every skill into both folders
```

Afterwards:

```sh
task          # help: the list of tasks
task list     # skills and symlink status per folder
task update   # git pull, then link
task link     # add missing symlinks, remove stale ones
```

`task link` leaves real folders and symlinks to other places alone. Needs
[Task](https://taskfile.dev).

## Conventions

- `SKILL.md` under 150 lines. Longer material in `references/`, pointed to from the body.
- Skill scripts: no host dependencies beyond podman or docker. Versions pinned in the script.
- `bin/` follows [bash-style](bash-style/), in-repo layout. Verify with its
  shellcheck command for `bin/` alone, from the repo root.
- `Taskfile.yml` lists commands. A task that needs conditionals, loops or
  computed variables becomes a script in `bin/`.
- Comments: facts, decisions, references. No reasoning prose.
- `evals/evals.json`: test prompts for the skill-creator loop.
- Verify a skill before commit: `shellcheck scripts/*.sh`, `node --check scripts/*.js`, one real run.
