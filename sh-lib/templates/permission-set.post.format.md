---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# permission-set post — the post of a permission set request

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text of the one ask `--magic-permission-set-request` posts to the human-owner for the extras of a task's or a session's permission set. The tooling fills its slots and sends it as the team bot, through the member send. It is not an event-track post.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
  - post
- Lines
  - asked
  - purpose
  - held
  - task
  - session
  - participant
  - asked-by
- Scope words
  - task
  - session
- Answers
  - set
- Reactions
  - set
- Contract

# Summary

One ask for everything a task or a session needs beyond what its participants hold: what is asked, grouped by place, each place once with its tools and what the access is for where the asker said so; what is already held; then what it is about: the task in words, the session, the participants with their hosts, who asks and where; and how to answer.

## Goals

- The person sees what is asked at a glance: one line a place, the place by its location root, its tools beside it, and under it what the access will be used for.
- The person can tell what it is about without knowing an id: the task in words, the session, who takes part and where each runs, who asks.
- No path and no line is written twice.
- Changing the wording, an icon or a heading is an edit to this file, not to the operation that fills it.

## Scope

- Does: fix the text and the slots of the post, the line of each place, participant and context item, and the line that says how to answer.
- Doesn't: decide what an answer means. The verdict reader does (`AgentsEscalationVerdict.awk`).
- Doesn't: write a grant. The escalation operation does, from the request's own record, which keeps every entry exactly as asked (`AgentsTools.InternOpPermission.include`).

# Skeleton

## post

```
# 🔐 Permission set

May the participants have these, {{scope-words}}?

**➕ Asked for**
{{asked}}

[[**✅ Already held, passed on by the holder**
{{held}}

]][[**🗂 Task**
{{task}}

]][[**🧵 Session**
{{session}}

]][[**👥 Participants**
{{participants}}

]][[**🙋 Asked by**
{{asked-by}}

]]{{how-to-answer}}
```

# Lines

One line of a list in the post, filled once for each item.

## asked

```
- `{{place}}` — {{tools}}
```

## purpose

```
  - {{purpose}}
```

## held

```
- `{{place}}` — {{tools}} ({{holder}})
```

## task

```
[[{{task-title}}
]][[{{task-names}}
]][[{{task-text}}]]
```

## session

```
`{{session-id}}`[[ · {{session-thread}}]][[ — {{session-description}}]]
```

## participant

```
- {{member}}[[ · host {{host}}]][[ — {{description}}]]
```

## asked-by

```
{{member}}[[ · {{host}}]][[ / {{workspace}}]]
```

# Scope words

How far an allow reaches, in plain words, by the request's scope.

## task

```
for this task only
```

## session

```
for this session only
```

# Answers

The lines that say how to answer.

## set

```
Click ❌ to deny, or 🔓 to allow the set. An allow gives these to every participant listed.
Or reply with the first word: allow-set, deny, or edit followed by the change.
```

# Reactions

The emoji the tooling places under the post, as Slack names.

## set

```
x
unlock
```

# Contract

- rule: The post is the one fenced block under `## post`, sent as the team bot through the member send, addressed to the human-owner.
- rule: Required: `{{scope-words}}`, `{{asked}}` and `{{how-to-answer}}`. A slot outside `[[ … ]]` is required: with one empty, nothing is posted. Text in `[[ … ]]` is kept only when every slot in it has a value, and a group may span lines, so a heading is left out together with its empty list. No field is ever shown as a placeholder.
- rule: `{{asked}}` is one `## asked` line for each place asked, in the order first asked: `{{place}}` once, then `{{tools}}`, every tool asked for it, separated by commas, in one fixed order: Read, Grep, Glob, Edit, Write, NotebookEdit, Execute, WebFetch, WebSearch, cred, then any other in the order asked. No place and no line is written twice.
- rule: `{{place}}` is shown by its location root, `<place>:<relative path>`, where the target lies in a registered place, and then no absolute path is shown beside it or anywhere in the post; a target that lies in none is shown as given. One resolver gives it, for every permission post (`AgentsTools.Places.include`). There is no separate list of places.
- rule: `{{purpose}}` is what the asker said the access to that place will be used for, one `## purpose` line right under its place. It is optional: a place with none has no such line. One place has one purpose.
- rule: `{{held}}` is one `## held` line for each place and holder of an entry a participant already holds, grouped as `{{asked}}` is, with `{{holder}}`, the member that holds it and passes it on.
- rule: `{{task}}` says what the request is about in words: `{{task-title}}`, the title of the item the request's item tracks, else that item's own heading; `{{task-names}}`, the names of the tracked item and of the dispatch, each in code style; and `{{task-text}}`, a longer text, shown only where no purpose was given for any place: the description the spawner gave for the dispatch, else the tracked item's first paragraph, else the first paragraph of the dispatch's own brief. A text is cut at a sentence end, to at most 4 sentences and at most 480 bytes. One reader gives the title and the text, for this post and for the event-track start post alike (`AgentsTools.TaskText.include`).
- rule: `{{session}}` is the coworking session the request is for: `{{session-id}}`, its first 8 characters; `{{session-thread}}`, its session thread, a link where the workspace's address is configured, else its `<channel>:<ts>` in code style; and `{{session-description}}`, what the spawn that started it said it is for, else the name or comment that session was given.
- rule: `{{participants}}` is one `## participant` line for each participant an allow would reach: `{{member}}`, `{{host}}`, the host its spawn runs on, and `{{description}}`, what that participant was brought in for, as its own spawn said.
- rule: `{{asked-by}}` is the member that made the request, with the host and the workspace it was made on, as the other permission posts show them.
- rule: `{{scope-words}}` is the block under `# Scope words` named for the request's scope. `{{how-to-answer}}` is the block under `# Answers` named `set`, which says once that an allow gives the extras to every participant listed.
- rule: The emoji placed under the post are the block under `# Reactions` named `set`, one Slack name each, in that order: `x` denies, `unlock` allows the set. They are placed by the identity that posted, and a reaction by that identity is never an answer: only a click by the one the post is addressed to is. `edit` has no emoji, since it carries the change in words. A thumbs up, an `ok` or any other emoji grants nothing.
- rule: A name placed here must be one the verdict reader takes for a permission set (`AgentsEscalationVerdict.awk`): `x` to deny, `unlock` to allow the set, deny first where both are held.
- rule: Every value comes from records on disk: the item, the spawn records, the session store, the request itself. Nothing is looked up over the network for this post. Every value is redacted, and a description, a comment or a purpose is cut as a message is: at 120 bytes, at its first line, with an ellipsis.
- rule: The request's record keeps every entry exactly as asked, with its exact target, and each purpose with its place. Only the post is grouped and shown by place. An allow-set grants what the record holds.
- rule: Every text outside the slots is posted exactly as written here.
