---
maintainers: magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner
---
# undo-approve post — the post that asks a person whether an act stands

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text of the one prompt the tooling posts when a member records a promise of undo: an act of its own that the human-owner may reject later. The tooling fills its slots and sends it as the team bot, through the member send. It is not an event-track post.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
  - post
- Lines
  - act
  - inverse
- Answers
  - verdict
- Reactions
  - verdict
- Marks
  - cancelled
- Returned
  - hint
- Confirmations
  - taken
- Contract

# Summary

One prompt for one recorded act: who acted, what it did, the operation that undoes it, and the material kept from cleanup until the answer comes. The answer is the verdict on the act: accept, reject or rework.

## Goals

- The person sees what was done and what would undo it, without knowing an id, and answers with one click or one word.
- An accept releases the material, a reject runs the inverse, and a rework keeps both and carries his words back.
- Changing the wording, an icon or an emoji is an edit to this file, not to the operation that fills it.

## Scope

- Does: fix the text and the slots of the post, the lines that say how to answer, the emoji placed under the post, and what the member that acted is told.
- Doesn't: decide what an answer means. The verdict reader does (`AgentsEscalationVerdict.awk`), and the lane carries it out (`AgentsTools.UndoRecord.include`).

# Skeleton

## post

```
# ↩️ Undo

{{member}} acted, and the promise of undoing it waits for your verdict.

[[**🗂 Act**
{{act}}

]][[**🪃 To undo it**
{{inverse}}

]][[**📦 Kept from cleanup until you answer**
{{hold}}

]][[**✅ How to answer**
{{how-to-answer}}]]
```

# Lines

One line of the post that is filled on its own.

## act

```
`{{kind}}` on `{{target}}`
```

## inverse

```
{{steps}}
```

# Answers

The lines under `How to answer`.

## verdict

```
- click 👍 to accept the act as it stands, or ❌ to reject it and have it undone
- or reply `accept`, `reject` or `rework`
- the word first; a comment after a comma, or on the next lines
- a rework needs your words: write what to do instead, and the act is kept while that is done
```

# Reactions

The emoji the tooling places under the post, as Slack names.

## verdict

```
leftwards_arrow_with_hook
+1
x
```

# Marks

What the tooling puts on the post once it takes no answer any more. A reaction is a Slack name.

## cancelled

```
no_entry_sign
```

# Returned

What the member that acted is told when an answer gives no verdict, or gives one that is not carried out. Each is one line.

## hint

```
This is the undo prompt of the act you recorded. What the person wrote or clicked under it names no one verdict, so it comes back to you: it may be a comment, a question, or a rework asked for with no words.
The act and its hold stand, and the prompt stays open.
Read it, and answer where it asks something: {{explain-call}}. The next reply or click there is read as the verdict.
```

# Confirmations

The one reply the tooling posts in the prompt's own thread once an answer is read there: what was read, and what was done with it.

## taken

```
✅ Read: `{{verdict}}` by {{by}}. It is the verdict of this undo.[[ {{text}}]]
```

## not-applied

```
⚠️ Read: `{{verdict}}` by {{by}}, and it is not carried out. {{reason}}
```

# Contract

- rule: The post is the one fenced block under `## post`, sent as the team bot through the member send, addressed to the human-owner. It is posted once for each record the lane opens, and only where the act's material is held.
- rule: Required: `{{member}}`, the member or run that acted. A slot outside `[[ … ]]` is required: with one empty, nothing is posted. Text in `[[ … ]]` is kept only when every slot in it has a value, and a group may span lines, so a heading is left out together with its empty field. No field is ever shown as a placeholder.
- rule: `{{act}}` is the `## act` line: `{{kind}}`, the inverse kind of the record as its closed list names it, and `{{target}}`, the thing the act was on, in code style.
- rule: `{{inverse}}` is the `## inverse` line: `{{steps}}`, the operation that undoes the act, one step a line, as the lane would run it.
- rule: `{{hold}}` is the folder kept from cleanup, by its place name where one holds it, else its path in code style.
- rule: The answer form is `verdict`. `{{how-to-answer}}` is the block under `# Answers` named for it, on every post that takes an answer.
- rule: The emoji placed under the post are the block under `# Reactions` named `verdict`, one Slack name each, in that order: `+1` accepts, `x` rejects, `leftwards_arrow_with_hook` asks for a rework. They are placed by the identity that posted, and a reaction by that identity is never an answer: only a click by the one the post is addressed to is.
- rule: A name placed here must be one the verdict reader takes for an undo (`AgentsEscalationVerdict.awk`).
- rule: A reply answers by its first line, as the verdict reader takes it: `accept`, `reject` or `rework` alone, or the word, a punctuation mark and then words. What follows the mark, the rest of that reply and every later reply are the text of the verdict.
- rule: A rework is his words, and a rework with none names no verdict: the reply goes back to the member as `RETURNED` and the prompt stays open. A click that asks for a rework carries no words, so it too is no verdict.
- rule: No plain affirmation is a verdict here. `ok` accepts nothing, as it approves nothing for a permission or a proposal.
- rule: The verdict is carried out by the lane as the record's own operation applies it: an accept purges the record and releases the hold, a reject runs the recorded inverse and releases the hold, and a rework keeps both and keeps his words on the record. The record of the prompt closes with it.
- rule: A reply that names no verdict is not an answer. It goes back to the member that acted as `RETURNED`, the prompt stays open, and a later reply or click is the verdict.
- rule: `## hint` under `# Returned` is what that member is told then. `{{explain-call}}` is the exact call, given by the tool.
- rule: A post that no longer takes an answer is this same text without its `How to answer` group. The tooling edits the post to it, takes its own answer emoji off it, and puts on it the reaction under `# Marks` named `cancelled`.
- rule: Once an answer is read, the tooling says so with one reply in the prompt's own thread, as the identity that posted the prompt: the block under `# Confirmations` named `taken`, with the verdict, who gave it (`{{by}}`, as a name) and what was written with it. It is posted once for an answer, never again on a later read.
- rule: Every text outside the slots is posted exactly as written here.
