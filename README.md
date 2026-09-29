# dataverket-skills

Skills for coding agents. One folder per skill: `SKILL.md` plus `scripts/`,
`references/`, `evals/`.

| Skill | What it does |
|---|---|
| [bash-style](bash-style/) | Bash style for scripts committed to a repo, after postmodern's ruby-install and chruby: tabs, `function` blocks, `|| return $?`, bash 3, shunit2. |
| [playwright](playwright/) | Browser automation in a persistent container. Screenshots, computed styles, DOM and network checks. |
| [zmx](zmx/) | Long-lived processes in detached sessions: dev servers, watchers, databases. Start, wait for ready, scan output, kill by project. |

## Install

This repo is the canonical copy. Agents read symlinks to it from their own
skill folders: `~/.claude/skills` (Claude Code) and `~/.agents/skills` (other
agents; Claude Code only scans it for `/import`). The scripts are in `bin/`,
the Taskfile is the index. Needs [Task](https://taskfile.dev).

```sh
task list     # skills and symlink status per folder
task update   # git pull, add missing symlinks, remove stale ones
task link     # same without the pull
task check    # shellcheck bin/
```

Real folders and symlinks to other places in those folders are left alone.

## Conventions

- `SKILL.md` under 150 lines. Longer material in `references/`, pointed to from the body.
- Scripts: no host dependencies beyond podman or docker. Versions pinned in the script.
- Comments: facts, decisions, references. No reasoning prose.
- `evals/evals.json`: test prompts for the skill-creator loop.
- Verify before commit: `shellcheck scripts/*.sh`, `node --check scripts/*.js`, one real run.
