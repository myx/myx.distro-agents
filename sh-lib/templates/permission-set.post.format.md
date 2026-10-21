---
maintainers: magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner
---
# permission-set post — the post of a permission set request

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text of the one ask `--magic-permission-set-request` posts to the human-owner for the extras of a task's or a session's permission set, of the one ask a member makes for what its own task needs (`RequestPermission` with `entries`), and of the one prompt a session's own permission questions to the human-owner become when a further refused call is asked while one is still open. The tooling fills its slots and sends it as the team bot, through the member send. It is not an event-track post.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
  - post
- Lines
  - asked
  - asked-any
  - purpose
  - held
  - held-any
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
- Marks
  - cancelled
- Told
  - allowed
  - denied
- Confirmations
  - granted
  - denied
  - edit
  - not-applied
  - sent-up
- Contract

# Summary

One ask for everything a task or a session needs beyond what its participants hold: what is asked, grouped by place, each place once with its tools and what the access to it is for where the asker said so; what the whole access is for, once, where the asker said so; what is already held; then what it is about: the task in words, the session, the participants with their hosts, who asks and where; and how to answer.

## Goals

- The person sees what is asked at a glance: one line a place, the place by the name it was asked by or by its location root, its tools beside it, and under it what the access will be used for.
- The person sees exactly what an allow grants: every tool and every place asked, each once, a tool asked with no place among them.
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

**🔑 Asked for**
{{asked}}

[[**💡 What it is for**
{{reason}}

]][[**✅ Already held, passed on by the holder**
{{held}}

]][[**🗂 Task**
{{task}}

]][[**🧵 Session**
{{session}}

]][[**👥 Participants**
{{participants}}

]][[**🙋 Asked by**
{{asked-by}}

]][[**✅ How to answer**
{{how-to-answer}}]]
```

# Lines

One line of a list in the post, filled once for each item.

## asked

```
- `{{place}}` — {{tools}}
```

## asked-any

```
- {{tools}} — any target
```

## purpose

```
  - {{purpose}}
```

## held

```
- `{{place}}` — {{tools}} ({{holder}})
```

## held-any

```
- {{tools}} — any target ({{holder}})
```

## task

```
[[{{task-title}}
]][[{{task-names}}
]][[{{task-text}}]]
```

## session

```
[[{{session-description}} · ]]`{{session-id}}`[[ · {{session-thread}}]]
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
- click ❌ to deny, or 🔓 to allow the set: an allow gives these to every participant listed
- or reply `allow-set`, `deny`, or `edit:` followed by the change
- the word first; a comment after a comma, or on the next lines
```

# Reactions

The emoji the tooling places under the post, as Slack names.

## set

```
x
unlock
```

# Marks

What the tooling puts on the post once the request is discarded. A reaction is a Slack name.

## cancelled

```
no_entry_sign
```

# Told

The one line the tooling posts in the session's thread once the set is answered, for all its participants.

## allowed

```
🔓 Permission set `{{set-id}}` is allowed by {{by}}: {{count}} permission(s), {{scope-words}}, are granted to {{participants}}. A call refused before can be made again.
```

## denied

```
❌ Permission set `{{set-id}}` is denied by {{by}}: nothing is granted to {{participants}}.
```

# Confirmations

The one reply the tooling posts in the thread an answer was read in: what was read, and what was done with it.

## granted

```
✅ Read: `{{verdict}}` by {{by}}. Granted: {{count}} permission(s) to {{participants}}, {{scope-words}}.
```

## denied

```
❌ Read: `{{verdict}}` by {{by}}. Nothing is granted to {{participants}}.
```

## edit

```
✏️ Read: `{{verdict}}` by {{by}}. Nothing is granted: the request goes back to {{member}} to change.[[ {{text}}]]
```

## not-applied

```
⚠️ Read: `{{verdict}}` by {{by}}, and it could not be applied: nothing is granted, and the request stays open. {{reason}}
```

## sent-up

```
⚠️ Read: `{{verdict}}` by {{by}}, and it is not applied: {{reason}}. Nothing is granted yet. The request now goes to {{holder}}, and stays open.
```

# Contract

- rule: The post is the one fenced block under `## post`, sent as the team bot through the member send, addressed to the human-owner.
- rule: Required: `{{scope-words}}` and `{{asked}}`. A slot outside `[[ … ]]` is required: with one empty, nothing is posted. `{{how-to-answer}}` is filled from `# Answers` on every post that takes an answer, and a post that takes one is never sent without it. Text in `[[ … ]]` is kept only when every slot in it has a value, and a group may span lines, so a heading is left out together with its empty list. No field is ever shown as a placeholder.
- rule: `{{asked}}` is one `## asked` line for each place asked, in the order first asked: `{{place}}` once, then `{{tools}}`, every tool asked for it, separated by commas, in one fixed order: Read, Grep, Glob, Edit, Write, NotebookEdit, Execute, WebFetch, WebSearch, cred, then any other in the order asked. No place and no line is written twice. Every entry an allow would grant stands in it: what is not shown is not asked.
- rule: An entry asked with no target, a tool alone, has no place: its tools stand on one `## asked-any` line, which says that the grant is for any target, in the same order.
- rule: `{{place}}` is the place the entry was asked by, `<name>:<glob>`, where the asker named one (`@<name>[:<glob>]`), a registered place or a built-in one (`.skillset-shared`, `.skillset-.local`): the name as asked, whatever other place its files lie in. An entry asked by a path is shown by its location root, `<place>:<relative path>`, where the target lies in a registered place; a target that lies in none is shown as given. No absolute path is shown beside a place or anywhere else in the post for a target that has one. One resolver gives the location root, for every permission post (`LocalTools.Places.include`). There is no separate list of places.
- rule: `{{purpose}}` is what the asker said the access to that place will be used for, one `## purpose` line right under its place. It is optional: a place with none has no such line. One place has one purpose.
- rule: `{{reason}}` is what the asker said the whole access is for, in its own words, on one line, cut at 480 bytes and redacted: the `reason` of a `RequestPermission` with `entries`. It stands once, under its own heading, and is optional: a request that gave none has no such group.
- rule: `{{held}}` is one `## held` line for each place and holder of an entry a participant already holds, grouped as `{{asked}}` is, with `{{holder}}`, the member that holds it and passes it on; an entry held with no target stands on a `## held-any` line.
- rule: `{{task}}` says what the request is about in words: `{{task-title}}`, the title of the item the request's item tracks, else that item's own heading; `{{task-names}}`, the names of the tracked item and of the dispatch, each in code style; and `{{task-text}}`, a longer text, shown only where no purpose was given for any place and none for the whole access: the description the spawner gave for the dispatch, else the tracked item's first paragraph, else the first paragraph of the dispatch's own brief. A text is cut at a sentence end, to at most 4 sentences and at most 480 bytes. One reader gives the title and the text, for this post and for the event-track start post alike (`AgentsTools.TaskText.include`).
- rule: `{{session}}` is the coworking session the request is for, its words first: `{{session-description}}`, what the spawn that started it said it is for, else the name or comment that session was given; then `{{session-id}}`, its first 8 characters; and `{{session-thread}}`, its session thread, a link where the workspace's address is configured, else its `<channel>:<ts>` in code style.
- rule: `{{participants}}` is one `## participant` line for each participant an allow would reach: `{{member}}`, `{{host}}`, the host its spawn runs on, and `{{description}}`, what that participant was brought in for, as its own spawn said.
- rule: `{{asked-by}}` is the member that made the request, with the host and the workspace it was made on, as the other permission posts show them.
- rule: `{{scope-words}}` is the block under `# Scope words` named for the request's scope. `{{how-to-answer}}` is the block under `# Answers` named `set`, which says once that an allow gives the extras to every participant listed.
- rule: The emoji placed under the post are the block under `# Reactions` named `set`, one Slack name each, in that order: `x` denies, `unlock` allows the set. They are placed by the identity that posted, and a reaction by that identity is never an answer: only a click by the one the post is addressed to is. `edit` has no emoji, since it carries the change in words. A thumbs up, an `ok` or any other emoji grants nothing.
- rule: A name placed here must be one the verdict reader takes for a permission set (`AgentsEscalationVerdict.awk`): `x` to deny, `unlock` to allow the set, deny first where both are held.
- rule: A post that no longer takes an answer is this same text without its `{{how-to-answer}}` group: the post of a request its asker discarded. The tooling fills it again from the request's own record, edits the post to it, takes its own answer emoji off it, and puts on it the reaction under `# Marks` named `cancelled`.
- rule: Every value comes from records on disk: the item, the spawn records, the session store, the request itself. Nothing is looked up over the network for this post. Every value is redacted, and a description, a comment or a purpose is cut as a message is: at 120 bytes, at its first line, with an ellipsis.
- rule: The request's record keeps every entry exactly as asked, with its exact target, the place each was asked by, each purpose with its place, what the whole access is for, and each entry a participant already held with its holder. Only the post is grouped and shown by place. An allow-set grants the entries asked, never one already held.
- rule: A member's own request is one such post too: a `RequestPermission` with `entries` (`--intern-op-permission-set-ask`, `AgentsTools.InternOpPermission.include`). Its one participant is the asking member. It starts from a refused call, which its entries must cover, or nothing is posted and the call comes back as a correction. It is for the task where its `task_ref` names a board item, and for the session where it names none. It is posted, answered, granted, confirmed and withdrawn as every permission set is.
- rule: Once the set is allowed or denied, its participants are told in the session's thread, in one line for all of them, posted by the team bot: the block under `# Told` named `allowed` or `denied`. `{{set-id}}` is the first 8 characters of the request's id, `{{by}}` who answered, as a name, `{{count}}` how many permissions the set holds, `{{participants}}` the participants, separated by commas. It is posted once for a request, and only where the session has a thread.
- rule: Once an answer is read, the tooling says so with one reply in the thread it was read in, as the team bot: the block under `# Confirmations` named `granted` for an allow-set that is applied, `denied` for a deny, `edit` for an edit, with `{{member}}`, who asked, and the change in words where the answer carried one, `not-applied` for an answer that could not be applied, with `{{reason}}`, and `sent-up` for an allow from someone who does not hold every permission of the set, with `{{reason}}` and `{{holder}}`, who the request goes to now. It is posted once for an answer, never again on a later read.
- rule: A session's own permission questions are one such post too. While a `RequestPermission` of a session to the human-owner is open and nothing from him stands in its thread, a further refused call of that session makes no new post: it is added to the open one (`--intern-op-escalation-permission-add`, `AgentsTools.MemberEscalation.include`). That prompt is then a permission set of scope `session` whose one participant is the asking member, with one entry for each call asked, each taken from its refusal record and never from the asker's words, and with `{{purpose}}` the reason the asker gave for the first call of a place. Its post is edited in place to this text, filled from its record, and the emoji under it become those of `# Reactions`. One answer covers every call listed: an allow-set grants each of them to that member, for this session, and a deny grants none.
- rule: A call is shown in the post before any answer can grant it: the post is edited first, and the call is written to the record only after the thread was read once more and held nothing. Once he has answered, or written anything in the thread, the prompt takes no further call, and the next refused call of that session is a prompt of its own. A call whose target a set would read as a pattern is never added: it is asked on its own.
- rule: Every text outside the slots is posted exactly as written here.
