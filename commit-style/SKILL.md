---
name: commit-style
description: Commit message and pull request title style for the user's own git repositories. A subject is a type, an optional scope and a statement of what is true after the commit; a body is prose that gives the reason and what was verified. Use it whenever you write a commit message, amend one, squash commits, name a pull request or draft its description, even if the user only says "commit this" or "open a PR" and never mentions style. Not for a fork of somebody else's project, where the upstream project's own convention applies.
---

# Commit style

A log is read by someone who wants to know what the repository holds and
since when, without opening a diff. Each commit therefore states a fact about
the repository after it, and the body says why that fact was chosen and how it
was checked. The reader may not be a native English speaker: short words,
exact names, full sentences.

## One form

```
type(scope): statement
```

`fix(forgejo-runners): the runner Deployment recreates on its one RWO claim`

Read the log before writing, for the scopes the repository already uses:

```sh
git log --format='%s' -30
```

A fork of an upstream project is not covered. It follows upstream's
`CONTRIBUTING`, its subject form and its sign-off rule.

## The subject

- **Type**: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `revert`,
  `release`. `feat` is a new capability, `chore` is upkeep that changes no
  behaviour, such as a pulled dependency.
- **Scope**: the component the change belongs to, by the name its directory or
  service has: `forgejo`, `zitadel`, `plans`, `extensions`. No scope when the
  repository is one thing or the change spans several.
- **Statement**: what is true once the commit is in, in the present tense, with
  the thing as the subject of the sentence.

| Write | Not |
|---|---|
| `feat(zulip): the icon is the master mark, navy on white with padding` | `feat(zulip): update icon` |
| `docs(plans): step 5's pgbench gate failed` | `docs(plans): add results` |
| `docs(vaults): swamp keys are named swamp-<repo>-<hostname>` | `docs(vaults): document key naming` |

- Lower case after the colon, unless the first word is a name. No full stop
  at the end.
- Exact names and numbers: the version pulled, the file, the method, the
  decision number. `chore(zitadel): @dataverket/zitadel 2026.10.01.3, the
  seven definitions migrated`.
- A version or a name may lead, followed by a colon and what it brings:
  `feat(forgejo): 2026.11.11.1: repo_merge_settings_ensure converges merge
  settings`.
- One line of about 80 characters at most. The limit is soft: a few
  characters over is better than a name cut short or a vague word. A subject
  well past it holds more than one fact.
- One fact per subject, the main one. Further facts go in the body, or in a
  commit of their own when they can be separated. A semicolon joins two
  facts only when both fit within the length.
- No em dashes, no emoji, no issue number alone as the statement.

## The body

Leave it out when the subject says everything. Otherwise:

- Prose, in paragraphs, wrapped at about 80 columns. No bullet lists and no
  headings.
- The reason the change was made, and what else was considered if that
  matters to the next reader.
- What was verified and when, with the date written out: `Run on 2026-11-12:
  only allow_fast_forward_only_merge changed, and the read-back shows merge
  commits alone.`
- References by name: a decision number, a doc path, an upstream issue
  (`forgejo-helm#1638`).
- What the commit leaves open, in one sentence, if anything.

The body does not retell the diff and does not narrate the work ("first I
tried"). Something that failed is stated as a fact: `the pgbench gate failed
at 412 tps against a floor of 500`.

```
feat(health): the two OIDC documents are asserted by their exact issuer

bodyContains matched a substring, which a longer issuer also satisfies, so the
assertion is bodyJson on the issuer field. The documents are public, so the
record shows the issuer it got when they differ.
```

## Trailers and authorship

- The commit is the user's. No `Co-Authored-By` for an AI, no "generated
  with" line, in the message or in a pull request description.
- No `Signed-off-by` unless the repository asks for it.
- `Reviewed-on` is written by the forge on a merge; never add it by hand.

## Making the commit

- Commit only when asked. On the default branch, make a branch first unless
  the repository commits to it directly.
- Stage by path. Read `git status` and `git diff --staged` before writing the
  message, and leave unrelated changes out of the commit.
- Signing stays on. Never pass `--no-gpg-sign` or `--no-verify`. When signing
  needs a hardware key and fails, stop and give the user the exact command
  to run, with the message in a file or a heredoc.
- A revert names what is undone and the state returned to: `revert: the second
  Incus host, back to the tree at 17f259f`.

## Pull requests

- The title is a subject line in the same form. A pull request with one
  commit takes that commit's subject.
- The description is the body: reason, what was verified, what is left open.
  Prose, the same rules as above.
