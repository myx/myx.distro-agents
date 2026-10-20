---
maintainers: magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner
---
# request-permission post — the post of a `RequestPermission`

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text of the permission request a member posts with `RequestPermission`. The tool fills its slots and sends it through the member send: as that member's own message, or as the team bot's when it is asked of the human-owner. It is not an event-track post.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
  - post
- Parts
  - question
  - refusal
  - reason
- Answers
  - grant
  - grant, with folder
  - grant, with folder and project
  - grant, with text
  - grant, with choices
  - confirm
  - grant, with contact
- Reactions
  - grant
  - grant, with folder
  - grant, with folder and project
  - grant, with contact
  - confirm
- Authority
  - reason
  - task
  - unclear
  - unthreaded
- Marks
  - revised
  - superseded
  - cancelled
- Returned
  - hint
- Scope words
  - once
  - session
  - task
  - contact
- Reasons
  - not-offered
- Confirmations
  - granted
  - denied
  - not-applied
  - sent-up
- Contract

# Summary

A permission request asks for one refused call: what an allow would grant, said from that call as its record holds it, why the task needs it in the asker's own words, the task, the context where one is given, how to answer, and last the refusal by its id.

## Goals

- The person sees exactly which call was refused, and denies or allows it with one click or one word.
- The person sees from the post exactly what a click grants: its first line is made from the refused call, never from the asker's words.
- Each fact is said once: the tool, the target and the member in the first line, the refusal by its id on the last line, where it interrupts nothing a person reads.
- A grant always takes its own answer. A plain agreement grants nothing.
- Changing the wording, an icon or a hint is an edit to this file, not to the tool that fills it.

## Scope

- Does: fix the text and the slots of the post, the lines that say how to answer, and the emoji placed under the post.
- Doesn't: decide what an answer means. The verdict reader does (`AgentsEscalationVerdict.awk`).
- Doesn't: write a grant. The escalation operation does (`AgentsTools.MemberEscalation.include`).

# Skeleton

## post

```
# 🔐 Permission[[ {{tag}}]][[ {{revised}}]]

{{question}}

**💡 Why this task needs it**
{{reason}}

**🗂 Task**
{{task}}

[[**⚙ Context**
{{context}}

]][[**✅ How to answer**
{{how-to-answer}}

]]{{refusal}}
```

# Parts

A block of the post that has a name. It is filled, and stands where the slot of its name is: in the post above, and in the post of a call under the second name `AskUserQuestion`, which shows it for a permission only because only this template has it. A part that carries the name of a field stands wherever a post shows that field. Every part is filled from the fields as the call gave them.

## question

```
Allow **{{refused-tool}}**[[ on `{{refused-target}}`]][[ for **{{refused-for}}**]]? An allow grants exactly that, and nothing wider.
```

## refusal

```
_Refusal:_ `{{refusal-id}}`
```

## reason

```
[[{{question}}
]]{{reason}}
```

# Answers

The lines under `How to answer`.

## grant

```
- click ❌ to deny, 1️⃣ to allow once, or 🔁 to allow for this session
- or reply `deny`, `allow-once` or `allow-session`
- the word first; a comment after a comma, or on the next lines
```

## grant, with folder

```
- click ❌ to deny, 1️⃣ to allow once, or 🔁 to allow for this session
- or click 📁 to allow **{{refused-tool}}** on `{{folder}}`, for this session
- or reply `deny`, `allow-once` or `allow-session`, or `allow-folder` for 📁
- the word first; a comment after a comma, or on the next lines
```

## grant, with folder and project

```
- click ❌ to deny, 1️⃣ to allow once, or 🔁 to allow for this session
- or click 📁 to allow **{{refused-tool}}** on `{{folder}}`, for this session
- or click 🏗️ to allow **{{refused-tool}}** on the project `{{project}}`, for this session
- or reply `deny`, `allow-once` or `allow-session`, `allow-folder` for 📁, or `allow-project` for 🏗️
- the word first; a comment after a comma, or on the next lines
```

## grant, with text

```
- reply with the text to give in its place
- or reply `allow-once` to let {{refused-for}} give its own, or `deny` to refuse it
- the word first; a comment after a comma, or on the next lines
```

## grant, with choices

```
- reply the word of one of the choices below
- or reply `allow-once` to let {{refused-for}} give its own, or `deny` to refuse it
- the word first; a comment after a comma, or on the next lines
```

## confirm

```
- click 👍 to confirm or ❌ to stop
- or reply `yes` or `no`
- the word first; a comment after a comma, or on the next lines
```

## grant, with contact

For a call refused for a contact (`contact:<id>`, the contacts subsystem): the contact is granted for this session or for good, never once and never for a task.

```
- click ❌ to deny, or 🔁 to allow for this session
- or click 👤 to allow **{{refused-tool}}** to the contact `{{contact}}`, for good, whatever the session
- or reply `deny` or `allow-session`, or `allow-contact` for 👤
- the word first; a comment after a comma, or on the next lines
```

# Reactions

The emoji the tooling places under the post, as Slack names.

## grant

```
x
one
repeat
```

## grant, with folder

```
x
one
repeat
file_folder
```

## grant, with folder and project

```
x
one
repeat
file_folder
building_construction
```

## grant, with contact

```
x
repeat
bust_in_silhouette
```

## confirm

```
+1
x
```

# Authority

The words of a request for the authority over a session or a run (F6.10): the post of an operation refused for the authority it needs, which the person at a console or a member asks of whoever holds it. It is this template's post, so its first line is the refused call said plainly (`{{refused-tool}}`, for example `end session <name or id> (<routine>, <members>)`), its reason and its task are the two blocks below, and its answers, emoji and reading are the permission's. `allow-session` gives the one who asked the authority over the named session while it lives.

## reason

```
{{requester}} does not hold the authority of {{holder}} for this, and asks for it.
```

## task

```
{{requester}} ran `{{operation}}`, which needs that authority.
```

## unclear

```
Your reply names none of the answers, so nothing is granted and this request stays open. Reply in this thread with `allow-once`, `allow-session` or `deny`, or click one of the emoji under the request.
```

## unthreaded

```
A message you wrote in this conversation outside this thread answers nothing: an answer is read in the thread of the request. Reply to the request in its thread with `allow-once`, `allow-session` or `deny`, or click one of the emoji under it.
```

# Marks

What the tooling puts on a post of this question once it changes. A reaction is a Slack name.

## revised

```
✏️ updated
```

## superseded

```
recycle
```

## cancelled

```
no_entry_sign
```

# Returned

What the asker is told when a reply names none of the answers.

## hint

```
The reply names none of the answers, so the question comes back to you. It stays open, and nothing is granted or decided.
This may be a communication and not a rejection: a request to explain, a correction, or an instruction. Read the reply, then take one of these ways.
- explain: {{explain-call}}. The question stays open, and the next reply or click is the answer.
- update: {{revise-call}}. The same question is asked again, changed, in its thread.
- discard: {{withdraw-call}}.
```

# Scope words

How far a grant reaches, in plain words, by the answer that gave it.

## once

```
for this one call
```

## session

```
for this session
```

## task

```
for this task
```

## contact

```
for the contact, whatever the session
```

# Reasons

Why an answer that was read could not be applied, as the `not-applied` confirmation says it.

## not-offered

```
This request offers no {{offer}} that can be allowed.
```

# Confirmations

The one reply the tooling posts in the thread an answer was read in: what was read, and what was done with it.

## granted

```
✅ Read: `{{verdict}}` by {{by}}. Granted: {{tool}}[[ on {{target}}]] to {{member}}, {{scope-words}}.
```

## denied

```
❌ Read: `{{verdict}}` by {{by}}. Nothing is granted to {{member}}.
```

## not-applied

```
⚠️ Read: `{{verdict}}` by {{by}}, and it could not be applied: nothing is granted, and the question stays open. {{reason}}
```

## sent-up

```
⚠️ Read: `{{verdict}}` by {{by}}, and it is not applied: {{reason}}. Nothing is granted yet. The question now goes to {{holder}}, and stays open.
```

# Contract

- rule: The post is the one fenced block under `## post`, sent through the member send. Asked of a team member, it is the asking member's own message. Asked of the human-owner (`to` is `human-owner`), it is the team bot's message, whatever `as_bot` says: it stands in the bot's own conversation with the owner, as a Permission set does, and its record then says `ask-identity: bot`, so its answer emoji and every later read, edit and reminder are the bot's too. It names its addressee as every member message does.
- rule: Who it is addressed to is settled when it is asked: the party named, where it holds the refused call and can be reached (the human-owner always, magic-coordinator, any other member only with a live run in the session); else a holder running in the session; else the human-owner. Where that is not the party named, the asker is told in a `NOTE` line of the result. A conversation, an account id or a routine given as the addressee is asked as given.
- rule: Required: `{{refused-tool}}`, `{{refusal-id}}`, `{{reason}}` and `{{task}}`. Optional: `{{tag}}`, the question's number where it shares a thread, and `{{context}}`. `{{how-to-answer}}` is filled from `# Answers` on every post that takes an answer.
- rule: The first line of the post, under its title, is the block under `# Parts` named `question`, which stands wherever a post shows `{{question}}`: the refused tool, its target and who the call was refused for, as the refusal record holds them, and the sentence that an allow grants exactly that. It is never the asker's words, so the post never asks for more than its answer grants. The three are said there and nowhere else in the post.
- rule: The asker's words are the reason only: the tooling says what is asked, and the asker says why. The call gives the reason, and a question of its own is optional. `{{reason}}` in a post is the block under `# Parts` named `reason`: the question as the asker worded it, where the call gave one, then the reason the call gave. They are shown under `Why this task needs it`, and nowhere else.
- rule: A request is known by its refused call, never by the asker's words: the tool, the exact target, the member the call was refused for and the session it was refused in. A request for a call that the member already has a request open for in that session, to the same party, is not posted again, however it is worded.
- rule: `{{refused-tool}}`, `{{refused-target}}` and `{{refused-for}}` are the refused call as the refusal record holds it, never as the asker words it. The target is shown by its location root, `<place>:<relative path>`, where it lies in a registered place, and then no absolute path is shown beside it; where it lies in none it is shown as the record holds it. A target or a member the record leaves empty leaves its words out of the first line.
- rule: `{{refusal}}` is the block under `# Parts` named for it: the id of the refusal record the request is for, on the last line of the post, always shown, so a person can find that record. It repeats nothing the first line says, and no reader takes it from the post: the request's own record holds it.
- rule: A slot outside `[[ … ]]` is required: with one empty, nothing is posted. Text in `[[ … ]]` is kept only when every slot in it has a value, and a group may span lines, so a heading is left out together with its empty field. No field is ever shown as a placeholder.
- rule: The answer form is `grant`. `{{how-to-answer}}` is the block under `# Answers` named for it.
- rule: The emoji placed under the post are the block under `# Reactions` named for the answer form, one Slack name each, in that order. They are placed by the identity that posted, and a reaction by that identity is never an answer.
- rule: A name placed here must be one the verdict reader takes for a permission (`AgentsEscalationVerdict.awk`): `x` to deny, `one` to allow once, `repeat` to allow for this session, `file_folder` for the folder and `building_construction` for the project, each only where the post offers it. A thumbs up is never placed and never grants.
- rule: A request for one refused file offers one more answer: the folder of that file. `{{folder}}` is that folder as a post shows a target, `<place>:<folder>/**`, and the answers and the emoji are then the blocks named `grant, with folder`: a block headed `<form>, with <slot>` is taken where that slot has a value (`AgentsAskPostFill.awk`). Their folder line says exactly what that answer grants, before he gives it: `{{refused-tool}}` on everything in that folder, for this session. Its word is `allow-folder` and its emoji `file_folder`. The first line of the post is unchanged: it says what a plain allow grants.
- rule: The folder is the one the refused file lies in, and nothing wider. It is not offered, and `allow-folder` is then no answer of the request, typed or clicked, where it cannot be right: a tool that has no place; a target that is no absolute path, is a pattern, or has a `..` segment; a write in a read-only place; and a folder that is the root of the file system, the home directory or the root of a workspace, so that this answer never gives a whole workspace (`AgentsToolsPermissionFolderEntry`, `AgentsTools.InternOpPermission.include`).
- rule: An `allow-folder` is granted as a permission set of one entry, of scope session, for the member whose call was refused, by the code that applies every set (`AgentsToolsPermissionSetApply`). What it grants is worked out from the refusal record when the answer is applied, never from the post. A grant to Edit or Write a folder reads it too, as every such grant does. Its confirmation is the block `granted`: the tool, the folder as the post showed it, and `for this session`.
- rule: A request for one refused file that lies in a project offers the project too, beside the folder. A project is a project of a workspace's source tree: the nearest folder, at or above the refused file, that holds a `project.inf`, inside the `source` folder of a workspace this machine knows. `{{project}}` is that folder as a post shows a target, `<place>:<project>/**`, and the answers and the emoji are then the blocks named `grant, with folder and project`: a block whose heading names several slots, ` and ` between them, is taken where each of them has a value, and of the blocks that can be taken the one that names the most is (`AgentsAskPostFill.awk`). Its project line says exactly what that answer grants, before he gives it: `{{refused-tool}}` on everything in that project, its `project.inf` included, for this session. Its word is `allow-project` and its emoji `building_construction`. The folder line and the first line of the post are unchanged.
- rule: The project is offered only where the folder is, so under every limit of the folder answer, and only where it is wider than the folder: where the project is the very folder of the refused file the two answers would grant the same, and the folder answer alone is offered. The source tree itself is never a project, and a folder that holds a `project.inf` outside a source tree is none. A write is never offered for a project that is a read-only place. Where it is not offered, `allow-project` is no answer of the request, typed or clicked (`AgentsToolsPermissionProjectEntry`, `AgentsTools.InternOpPermission.include`).
- rule: An `allow-project` is granted as an `allow-folder` is: a permission set of one entry, of scope session, for the member whose call was refused, worked out from the refusal record when the answer is applied, never from the post. No file of the project is set apart: its `project.inf` is granted as every file beside it. Its confirmation is the block `granted`: the tool, the project by its place, and `for this session`.
- rule: `## not-offered` under `# Reasons` is the `{{reason}}` of the `not-applied` confirmation of an `allow-folder` or an `allow-project` that names nothing to grant when it is applied: the request offered none, or the folder or the project can no longer be granted. `{{offer}}` is the word of that answer after `allow-`: `folder` or `project`.
- rule: `{{revised}}` is the `## revised` text under `# Marks`, shown only on the post of the question asked again, changed.
- rule: A post that no longer takes an answer is this same text without its `How to answer` group: the post of a discarded question, and a superseded version of a question asked inside a thread that is not its own. The tooling edits that post to it, and takes its own answer emoji off it.
- rule: `## superseded` under `# Marks` is the reaction the tooling puts on a version of the question that an update replaced, and `## cancelled` the one it puts on the post of a discarded question.
- rule: `## hint` under `# Returned` is what the asker is told when a reply names none of the answers. `{{explain-call}}`, `{{revise-call}}`, `{{withdraw-call}}` and `{{readback-call}}` are the exact calls, given by the tool.
- rule: Once an answer is read, the tooling says so with one reply in the thread it was read in, as the identity that posted there: the block under `# Confirmations` named `granted` for an allow that is applied, with what is granted (`{{tool}}`, `{{target}}`), to whom (`{{member}}`, the one whose call was refused) and how far (`{{scope-words}}`, the block under `# Scope words` named for the grant: once, session or task); `denied` for a deny; `not-applied` for an answer that could not be applied, with `{{reason}}`; and `sent-up` for an allow from someone who does not hold the permission, with `{{reason}}` and `{{holder}}`, who the question goes to now. `{{by}}` is who answered, as a name. It is posted once for an answer, never again on a later read.
- rule: This post asks for one refused call. A further refused call of the same session, asked while this one is open to the human-owner and nothing from him stands in its thread, makes no new post: it is added to this one, which is then edited to the permission set post (`permission-set.post.format.md`). That post lists every call asked for, and its answers, its emoji and its confirmation are that template's.
- rule: `## grant, with contact` under `# Answers` and under `# Reactions` stand for a call refused for a contact (`{{contact}}`, its id), in place of the folder and project answers, which such a call never offers: deny, the session, and the contact itself (👤, `allow-contact`, written into the contact's record as a standing grant by the escalation apply). `## contact` under `# Scope words` says how far that grant reaches.
- rule: Every text outside the slots and the marks is posted exactly as written here.
- rule: A request for the authority (F6.10, `# Authority`) is posted in this form, whatever it asks for, as the team bot when it goes to the human-owner and as the asking member otherwise. Its answers are `allow-once`, `allow-session` and `deny`, each a reply or a click (`# Reactions` `grant`): `allow-session` gives the requester the authority over the named session for as long as the session lives, through the `session` grant of the refusal the request logs; no allow is timed. A request that asks for a text takes the block `grant, with text` and one that asks for a choice among answers `grant, with choices`; neither places emoji. The confirmation to the owner of a mapped console is the form `confirm`, with its emoji `+1` and `x`.
