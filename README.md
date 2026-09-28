# dataverket-skills

Skills for coding agents: Claude Code, GitHub Copilot, OpenCode. One folder per
skill, `SKILL.md` plus `scripts/`, `references/`, `evals/`.

| Skill | What it does |
|---|---|
| [playwright](playwright/) | Browser automation in a persistent container. Screenshots, computed styles, DOM and network checks. |

## Install

Symlink the folder, not the file. Agents discover `~/.claude/skills/<name>/SKILL.md`.

```sh
ln -s "$PWD/playwright" ~/.claude/skills/playwright
```

## Conventions

- `SKILL.md` under 150 lines. Longer material in `references/`, pointed to from the body.
- Scripts: no host dependencies beyond podman or docker. Versions pinned in the script.
- Comments: facts, decisions, references. No reasoning prose.
- `evals/evals.json`: test prompts for the skill-creator loop.
- Verify before commit: `shellcheck scripts/*.sh`, `node --check scripts/*.js`, one real run.
