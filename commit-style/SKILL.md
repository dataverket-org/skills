---
name: commit-style
description: Commit message and pull request style for the user's own git repositories - a `type(scope): statement` subject of about 80 characters saying what is true after the commit, and a prose body giving intent and outcome with verified references. Use it whenever you write or amend a commit message, squash commits, title a pull request or write its description, or reference or close a Forgejo issue, even if the user only says "commit this" or "open a PR" and never mentions style. Not for a fork of someone else's project; follow upstream's convention there.
---

# Commit style

The log is read without the diff, often by a non-native English reader. The
subject states a fact about the repository; the body says why and what came
of it. Use short words, exact names and full sentences.

In a fork of an upstream project, follow upstream's `CONTRIBUTING`, subject
form and sign-off rule, not this skill.

## Subject

```
type(scope): statement
```

- **Type**: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `revert`
  or `release`. `feat` adds a capability; `chore` changes no behaviour.
- **Scope**: the component, named as its directory or service is. Take it from
  `git log --format='%s' -30`. Omit it when the change spans several.
- **Statement**: what is true after the commit, present tense, the thing as
  the grammatical subject. An imperative says what you did; the reader wants
  what the repository now holds.

| Write | Not |
|---|---|
| `feat(zulip): the icon is the master mark, navy on white with padding` | `feat(zulip): update icon` |
| `fix(forgejo-runners): the runner Deployment recreates on its one RWO claim` | `fix(forgejo-runners): fix rollout` |
| `docs(plans): step 5's pgbench gate failed` | `docs(plans): add results` |
| `chore(zitadel): @dataverket/zitadel 2026.10.01.3, seven definitions migrated` | `chore(zitadel): bump extension` |

- Keep it to one line of about 80 characters. The limit is soft: go a few
  over before you cut a name short.
- State one fact, the main one. Put the rest in the body or in another
  commit. A subject far past the limit holds two facts.
- Start in lower case unless the first word is a name. No full stop.
- Give exact names and numbers: the version, the method, the decision.
- No em dashes, no emoji.

## Body

Omit it when the subject says everything. Otherwise write what the diff
cannot show:

- **Intent**: what the change is for and the problem it answers.
- **Outcome**: what is different for someone using or running the thing, what
  was verified and on which date, what is left open.

Do not repeat logic that is in the code, such as which function calls which
or what a condition tests; the diff says it exactly. Do not narrate the work.
State a failure as an outcome: `the pgbench gate failed at 412 tps against a
floor of 500`.

Write prose in paragraphs, wrapped at about 80 columns. No bullets, no
headings.

```
feat(health): the two OIDC documents are asserted by their exact issuer

A longer issuer that only starts with ours passed the old check, so a
misconfigured instance read as healthy. The check now fails on anything but
the exact issuer, and the record shows the issuer it got. Run on 2026-11-09
against both instances: both pass, and a test instance with a suffix fails.
```

## References

Add one where the reader would otherwise have to search:

| Target | Form |
|---|---|
| Decision or doc in the repository | `decision 023`, `docs/storage.md` |
| Issue or pull request, same repository | `#27` |
| Issue or pull request, same forge | `dataverket/fabrikk#12` |
| Another forge, release notes, versioned docs | the full link |

Verify each reference before writing it: open the issue, fetch the link,
check that the decision exists and says what you claim. Leave out what you
cannot check. A wrong reference costs the reader more than a missing one.

## Closing an issue on Forgejo

A bare `#27` only links. A keyword before it acts on the issue:

| Effect | Keywords |
|---|---|
| Close | `close`, `closes`, `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves`, `resolved` |
| Reopen | `reopen`, `reopens`, `reopened` |

Write `Closes #27` as the last line, one line per issue, and only when the
change finishes the issue. With a pull request, put it in the description so
the issue closes at merge. Without a pull request, put it in the last commit
of the branch.

## Trailers

- The commit is the user's: no `Co-Authored-By` for an AI and no "generated
  with" line, in a message or a pull request.
- No `Signed-off-by` unless the repository asks for it.
- Never write `Reviewed-on`; the forge adds it at merge.

## Making the commit

- Commit only when asked, and on a branch. An agent does not commit to the
  default branch and does not merge into it.
- Stage by path. Read `git status` and `git diff --staged` first, and leave
  unrelated changes out.
- As an agent, commit unsigned: `git commit --no-gpg-sign`. The signature
  belongs on the merge. Everything that reaches the default branch is signed
  by a person or by the forge, and that signature attests the whole branch,
  so a signature on an unreviewed commit would say too much.
- Leave the signing configuration alone, and do not skip hooks with
  `--no-verify`.
- A revert names what is undone and the state returned to: `revert: the second
  Incus host, back to the tree at 17f259f`.

## Pull requests

The title is a subject line; with one commit, use that commit's subject. The
description follows the body rules: intent, outcome, what is left open.
