---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
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
- Reactions
  - grant
  - grant, with folder
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
- rule: A name placed here must be one the verdict reader takes for a permission (`AgentsEscalationVerdict.awk`): `x` to deny, `one` to allow once, `repeat` to allow for this session, and `file_folder` for the folder, only where the post offers it. A thumbs up is never placed and never grants.
- rule: A request for one refused file offers one more answer: the folder of that file. `{{folder}}` is that folder as a post shows a target, `<place>:<folder>/**`, and the answers and the emoji are then the blocks named `grant, with folder`: a block headed `<form>, with <slot>` is taken where that slot has a value (`AgentsAskPostFill.awk`). Their folder line says exactly what that answer grants, before he gives it: `{{refused-tool}}` on everything in that folder, for this session. Its word is `allow-folder` and its emoji `file_folder`. The first line of the post is unchanged: it says what a plain allow grants.
- rule: The folder is the one the refused file lies in, and nothing wider. It is not offered, and `allow-folder` is then no answer of the request, typed or clicked, where it cannot be right: a tool that has no place; a target that is no absolute path, is a pattern, or has a `..` segment; a write in a read-only place; and a folder that is the root of the file system, the home directory or the root of a workspace, so that this answer never gives a whole workspace (`AgentsToolsPermissionFolderEntry`, `AgentsTools.InternOpPermission.include`).
- rule: An `allow-folder` is granted as a permission set of one entry, of scope session, for the member whose call was refused, by the code that applies every set (`AgentsToolsPermissionSetApply`). What it grants is worked out from the refusal record when the answer is applied, never from the post. A grant to Edit or Write a folder reads it too, as every such grant does. Its confirmation is the block `granted`: the tool, the folder as the post showed it, and `for this session`.
- rule: `{{revised}}` is the `## revised` text under `# Marks`, shown only on the post of the question asked again, changed.
- rule: A post that no longer takes an answer is this same text without its `How to answer` group: the post of a discarded question, and a superseded version of a question asked inside a thread that is not its own. The tooling edits that post to it, and takes its own answer emoji off it.
- rule: `## superseded` under `# Marks` is the reaction the tooling puts on a version of the question that an update replaced, and `## cancelled` the one it puts on the post of a discarded question.
- rule: `## hint` under `# Returned` is what the asker is told when a reply names none of the answers. `{{explain-call}}`, `{{revise-call}}`, `{{withdraw-call}}` and `{{readback-call}}` are the exact calls, given by the tool.
- rule: Once an answer is read, the tooling says so with one reply in the thread it was read in, as the identity that posted there: the block under `# Confirmations` named `granted` for an allow that is applied, with what is granted (`{{tool}}`, `{{target}}`), to whom (`{{member}}`, the one whose call was refused) and how far (`{{scope-words}}`, the block under `# Scope words` named for the grant: once, session or task); `denied` for a deny; `not-applied` for an answer that could not be applied, with `{{reason}}`; and `sent-up` for an allow from someone who does not hold the permission, with `{{reason}}` and `{{holder}}`, who the question goes to now. `{{by}}` is who answered, as a name. It is posted once for an answer, never again on a later read.
- rule: This post asks for one refused call. A further refused call of the same session, asked while this one is open to the human-owner and nothing from him stands in its thread, makes no new post: it is added to this one, which is then edited to the permission set post (`permission-set.post.format.md`). That post lists every call asked for, and its answers, its emoji and its confirmation are that template's.
- rule: Every text outside the slots and the marks is posted exactly as written here.
