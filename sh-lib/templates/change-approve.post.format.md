---
maintainers: magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner
---
# change-approve post — the two posts that show a held change to the human-owner

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text of the one prompt the tooling posts when a member's `Edit` or `Write` is held for approval: a call an `approve` grant covers, that no grant given for its task, its session or the one call allows. The prompt is two posts: a short message that opens a thread and takes the answer, and the change itself, the first reply in that thread. The tooling fills their slots and sends each as the team bot, through the member send. Neither is an event-track post.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
  - post
  - detail
  - post, with diff
- Acts
  - change
  - rewrite
  - create
- Lines
  - task
  - session
  - asked-by
  - cut
- Answers
  - approve
- Reactions
  - approve
- Marks
  - cancelled
- Returned
  - hint
- Notes
  - dropped
- Confirmations
  - applied
  - rejected
  - not-applied
  - not-yet
- Contract

# Summary

One prompt for one held change, in two posts. The first opens a thread and stays short: who asks, the file by its place name, what the change is for, and how to answer. The second is the first reply in that thread: the change as a diff, the task in words, the session, and who asked. The answer is the verdict on the change itself: approve or reject. An approve applies the change exactly as it is shown there.

## Goals

- The person sees the result he approves: the diff, not a path he is asked to open.
- The conversation stays short to read: the message that opens the thread is a few lines, and the change itself is in its thread.
- He approves or rejects with one click or one word, and whatever he writes reaches the member.
- A change too long to show is shown cut, and says so in a plain line.
- Changing the wording, an icon or an emoji is an edit to this file, not to the operation that fills it.

## Scope

- Does: fix the text and the slots of the two posts, the lines that say how to answer, the emoji placed under the first post, and what the member that made the change and the prompt's own thread are told.
- Doesn't: decide what an answer means. The verdict reader does (`AgentsEscalationVerdict.awk`).
- Doesn't: keep or apply the change. The change operation does (`AgentsTools.InternOpChange.include`).

# Skeleton

The two posts of the prompt: the message that opens its thread, and the first reply there. Then the one post a prompt was before its change moved to that reply.

## post

```
# ✏️ Change for approval

{{member}} wants to {{act}} `{{file}}`.

[[**💡 What it is for**
{{purpose}}

]][[**✅ How to answer**
{{how-to-answer}}]]
```

## detail

```
**📝 The change**
{{fence}}
{{diff}}
{{fence}}
[[{{cut}}
]][[
**🗂 Task**
{{task}}
]][[
**🧵 Session**
{{session}}
]][[
**🙋 Asked by**
{{asked-by}}
]]
```

## post, with diff

```
# ✏️ Change for approval

{{member}} wants to {{act}} `{{file}}`.

[[**💡 What it is for**
{{purpose}}

]][[**🗂 Task**
{{task}}

]][[**🧵 Session**
{{session}}

]][[**🙋 Asked by**
{{asked-by}}

]]**📝 The change**
{{fence}}
{{diff}}
{{fence}}
[[{{cut}}
]]
[[**✅ How to answer**
{{how-to-answer}}]]
```

# Acts

What the call does to the file, in a word.

## change

```
change
```

## rewrite

```
rewrite the whole of
```

## create

```
create
```

# Lines

One line of the detail reply that is filled on its own.

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

## asked-by

```
{{member}}[[ · {{host}}]][[ / {{workspace}}]]
```

## cut

```
✂️ The diff is cut here: {{hidden}} more of its {{total}} lines are not shown. The whole diff is kept in `{{diff-file}}`.
```

# Answers

The lines under `How to answer`.

## approve

```
- click 👍 to approve: the change is then applied exactly as shown. Or click ❌ to reject it
- or reply `approve` or `reject`
- the word first; a comment after a comma, or on the next lines
- any other reply is a comment: it goes back to the member that asked, and the change stays held
```

# Reactions

The emoji the tooling places under the first post, as Slack names.

## approve

```
+1
x
```

# Marks

What the tooling puts on the first post once it takes no answer any more. A reaction is a Slack name.

## cancelled

```
no_entry_sign
```

# Returned

What the member that made the change is told when an answer gives no verdict.

## hint

```
This is the approval prompt of a change you made, which is held. What the human-owner wrote or clicked under it names no verdict, so it comes back to you: it may be a comment, a question or an instruction. The change stays held, and nothing is applied.
Read it, then take one of these ways.
- explain: {{explain-call}}. The change stays held, and the next reply or click there is read as the verdict.
- make it another way: {{withdraw-call}}, then make the changed call. It is held and shown to him anew.
- give it up: {{withdraw-call}}.
```

# Notes

What the prompt's own thread is told.

## dropped

```
This change is dropped: {{reason}}. Nothing is applied, and the prompt above takes no answer any more.
```

# Confirmations

The one reply the tooling posts in the prompt's own thread once an answer is read there: what was read, and what was done with it.

## applied

```
✅ Read: `{{verdict}}` by {{by}}. The change is applied to `{{target}}`, exactly as shown.[[ {{text}}]]
```

## rejected

```
❌ Read: `{{verdict}}` by {{by}}. The change is dropped: nothing is applied to `{{target}}`.[[ {{text}}]]
```

## not-applied

```
⚠️ Read: `{{verdict}}` by {{by}}, and the change is not applied to `{{target}}`: {{reason}}. It is dropped, and {{member}} is told to make it again: it is then shown to you anew.
```

## not-yet

```
⚠️ Read: `{{verdict}}` by {{by}}, and nothing is done with it yet: {{reason}}. The change to `{{target}}` stays held.
```

# Contract

- rule: The prompt is two posts, each sent as the team bot through the member send, addressed to the human-owner. The first is the one fenced block under `## post`: a message of its own in the bot's own conversation with him, which opens the thread, takes the answer and carries the answer emoji. The second is the one fenced block under `## detail`: the first reply in that thread, posted by the tooling right after the first, which shows the change itself. The prompt is posted once for each held call: one `Edit` call or one `Write` call is one change, and one change is one prompt. Several calls are never joined into one.
- rule: The first post holds who asks, the act, the file, the purpose and how to answer, and nothing else, so it stays a few lines. The diff, its cut line, the task, the session and who asked stand in the detail reply.
- rule: Both posts, or neither. Where the detail reply cannot be posted, the first post is taken away again, nothing is held, and the member that made the call is told so in the result of that call. A prompt whose change is not shown under it is never left to be answered.
- rule: Required: in the first post `{{member}}`, the member that made the call, `{{act}}` and `{{file}}`; in the detail reply `{{fence}}` and `{{diff}}`. A slot outside `[[ … ]]` is required: with one empty, nothing is posted, and nothing is held. Text in `[[ … ]]` is kept only when every slot in it has a value, and a group may span lines, so a heading is left out together with its empty field. No field is ever shown as a placeholder.
- rule: `{{act}}` is the block under `# Acts` named for what the call does: `change` for an `Edit`, `rewrite` for a `Write` over a file that exists, `create` for a `Write` of a file that does not.
- rule: `{{file}}` is shown by its location root, `<place>:<relative path>`, where the file lies in a registered place, and then no absolute path is shown beside it; a file that lies in none is shown as given. One resolver gives it, for every post that names a path (`AgentsTools.Places.include`).
- rule: `{{purpose}}` is the `description` the member gave with the call, one line, redacted, cut as a message is. It is optional, and stands in the first post.
- rule: In the detail reply, `{{task}}` is the `## task` line, which says what the session works on in words: `{{task-title}}`, `{{task-names}}` and `{{task-text}}`, as the review prompt and the permission set post show them. One reader gives them (`AgentsTools.TaskText.include`). `{{session}}` is the `## session` line of the session that made the call, and `{{asked-by}}` the `## asked-by` line: the member, with the host and the workspace the call was made on.
- rule: `{{diff}}`, in the detail reply, is the change as a unified diff of the file as it stood when the call was made against the file as the call leaves it, with three lines of context and without its two file header lines. `{{fence}}` is the code fence, three backticks, which a block of this file cannot hold itself: the diff stands between two of them, so Slack shows it verbatim.
- rule: A diff of more than 60 lines or 6000 bytes, or with a line of more than 2000 bytes, is shown cut at a whole line, ahead of what would pass that, and `{{cut}}` is then the `## cut` line: `{{hidden}}`, how many lines are not shown, `{{total}}`, how many the diff has, and `{{diff-file}}`, where the whole diff is kept, shown by its location root: `change.diff` in the folder of the kept change, in the store of the session that made the call. A diff shown whole has no such line.
- rule: The answer form is `approve`. `{{how-to-answer}}` is the block under `# Answers` named for it, on every first post that takes an answer. The detail reply never carries it.
- rule: The emoji placed under the first post are the block under `# Reactions` named `approve`, one Slack name each, in that order: `+1` approves, `x` rejects. They are placed by the identity that posted, and a reaction by that identity is never an answer: only a click by the one the post is addressed to is. Neither is `white_check_mark`, the mark the tooling itself puts on a question once it is answered. None is placed under the detail reply.
- rule: The verdict is the human-owner's own, as the verdict reader takes it for a change (`AgentsEscalationVerdict.awk`): his click on `+1` under the first post approves and on `x` rejects, reject first where he holds both; his own `white_check_mark` approves too, as it does on a proposal. A reply in the thread answers by its first line, in one of the two shapes the verdict reader takes: the word alone, or the word, a punctuation mark and then his comment; `approve` or `approved`, `reject` or `rejected`, in any case. His comment on that line, the rest of that reply and every other reply of his there reach the member with the verdict. No plain agreement approves. The detail reply is the tooling's own, posted by the identity that asked: it is never an answer, and neither is any other reply of the tooling there.
- rule: An approve applies the kept change exactly as it was shown: the same call, made again by the tooling as the member, each of its edits matching what it matched when it was shown. Where the file has changed since so that they no longer do, or the member's access no longer covers the file, nothing is applied, the change is dropped, and the member is told to make it again. A change the person did not see is never applied.
- rule: A reject drops the change: nothing is applied. So does the asker taking it back, and the end of the session that made it: a verdict is applied only while that session runs.
- rule: A reply that names no verdict is not an answer. It goes back to the member as `RETURNED`, with the person's whole text, the change stays held, and a later reply or click is the verdict. `## hint` under `# Returned` is what the member is told then. `{{explain-call}}` and `{{withdraw-call}}` are the exact calls, given by the tool.
- rule: A prompt that no longer takes an answer is its first post's same text without its `How to answer` group: the prompt of a change that was rejected, taken back, not applied or dropped. The tooling edits the first post to it, takes its own answer emoji off it, and puts on it the reaction under `# Marks` named `cancelled`, as it does for the post of a discarded permission set. The detail reply is left as it is. A prompt whose change was approved and applied takes no answer any more either: once that answer is read the tooling edits its first post the same way and takes its own answer emoji off it, with the mark of an answered question on it and no `cancelled` mark. Where the tooling itself dropped the change, it says `## dropped` under `# Notes` in the prompt's thread, `{{reason}}` being why.
- rule: Once an answer is read, the tooling says so with one reply in the prompt's own thread, as the team bot: the block under `# Confirmations` named `applied` for an approve that is applied, `rejected` for a reject, `not-applied` for an approve that is not applied for good, the change dropped, and `not-yet` for an answer nothing is done with this time, the change still held and the answer read again: each of the last two with `{{reason}}`. `{{target}}` is the file as the post showed it, `{{by}}` who answered, as a name, `{{member}}` the member that made the change, and `{{text}}` what he wrote with the verdict. It is posted once for an answer, never again on a later read.
- rule: A prompt posted before its change moved to the detail reply is one post, which holds the change itself: the block under `## post, with diff`. It is taken in place of `## post` where what a record keeps of its prompt holds a diff, and only to fill such a post again once it takes no answer. No new prompt is posted by it. Such a prompt is read, answered, confirmed and closed by every rule here; it has no detail reply.
- rule: Every value comes from records on disk: the call, the file, the spawn record, the item. Nothing is looked up over the network for this post.
- rule: Every text outside the slots is posted exactly as written here.
