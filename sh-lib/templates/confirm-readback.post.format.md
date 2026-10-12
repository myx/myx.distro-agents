---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# confirm-readback post — the post of a `ConfirmReadback`

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text of the readback a member posts with `ConfirmReadback`. The tool fills its slots and sends it through the member send: as that member's own message, or as the team bot's when it is asked of the human-owner. It is not an event-track post.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
  - post
- Answers
  - confirm
- Reactions
  - confirm
- Marks
  - revised
  - superseded
  - cancelled
- Returned
  - hint
- Confirmations
  - taken
- Contract

# Summary

A readback asks a person to confirm what a member understood before it acts: the question, what was understood, where it came from, what will be done once confirmed, and how to answer.

## Goals

- The person sees what will be done, and confirms or stops it with one click or one word.
- Changing the wording, an icon or a hint is an edit to this file, not to the tool that fills it.

## Scope

- Does: fix the text and the slots of the post, the lines that say how to answer, and the emoji placed under the post.
- Doesn't: decide what an answer means. The verdict reader does (`AgentsEscalationVerdict.awk`).

# Skeleton

## post

```
# 🔁 Readback[[ {{tag}}]][[ {{revised}}]]

{{question}}

**📥 What I understood**
{{understood}}

**📎 Where it came from**
{{source}}

**▶️ What I will do if confirmed**
{{will-do}}

[[**⚙ Context**
{{context}}

]][[**✅ How to answer**
{{how-to-answer}}]]
```

# Answers

The lines under `How to answer`.

## confirm

```
- click 👍 to confirm or ❌ to stop
- or reply `yes` (or `ok`, `agreed`, `confirm`), `no`, or `correct:` followed by the correction
- the word first; a comment after a comma, or on the next lines
```

# Reactions

The emoji the tooling places under the post, as Slack names.

## confirm

```
+1
x
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

# Confirmations

The one reply the tooling posts in the thread an answer was read in: what was read.

## taken

```
✅ Read: `{{verdict}}` by {{by}}. It is recorded as the answer to this readback.[[ {{text}}]]
```

# Contract

- rule: The post is the one fenced block under `## post`, sent through the member send as the asking member's own message. Asked of the human-owner (`to` is `human-owner`), it is the team bot's message, whoever asks and whatever `as_bot` says: the owner is asked in one place, never in the conversation of whichever account asks. It then stands in the bot's own conversation with the owner, as a permission does, and its record says `ask-identity: bot`, so its answer emoji and every later read, edit and reminder are the bot's too. It names its addressee as every member message does.
- rule: Required: `{{question}}`, `{{understood}}`, `{{source}}` and `{{will-do}}`. Optional: `{{tag}}`, the question's number where it shares a thread, and `{{context}}`. `{{how-to-answer}}` is filled from `# Answers` on every post that takes an answer.
- rule: A slot outside `[[ … ]]` is required: with one empty, nothing is posted. Text in `[[ … ]]` is kept only when every slot in it has a value, and a group may span lines, so a heading is left out together with its empty field. No field is ever shown as a placeholder.
- rule: The answer form is `confirm`. `{{how-to-answer}}` is the block under `# Answers` named for it.
- rule: The emoji placed under the post are the block under `# Reactions` named for the answer form, one Slack name each, in that order. They are placed by the identity that posted, and a reaction by that identity is never an answer.
- rule: A name placed here must be one the verdict reader takes for a readback (`AgentsEscalationVerdict.awk`): `+1` for yes, `x` for no.
- rule: `{{revised}}` is the `## revised` text under `# Marks`, shown only on the post of the question asked again, changed.
- rule: A post that no longer takes an answer is this same text without its `How to answer` group: the post of a discarded question, and a superseded version of a question asked inside a thread that is not its own. The tooling edits that post to it, and takes its own answer emoji off it.
- rule: `## superseded` under `# Marks` is the reaction the tooling puts on a version of the question that an update replaced, and `## cancelled` the one it puts on the post of a discarded question.
- rule: `## hint` under `# Returned` is what the asker is told when a reply names none of the answers. `{{explain-call}}`, `{{revise-call}}`, `{{withdraw-call}}` and `{{readback-call}}` are the exact calls, given by the tool.
- rule: Once an answer is read and applied, the tooling says so with one reply in the thread it was read in, as the identity that posted there: the block under `# Confirmations` named `taken`, with the answer (`{{verdict}}`), who gave it (`{{by}}`, as a name) and, for a correction, its text. It is posted once for an answer, never again on a later read.
- rule: Every text outside the slots and the marks is posted exactly as written here.
