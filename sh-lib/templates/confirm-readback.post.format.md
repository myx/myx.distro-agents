---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# confirm-readback post — the post of a `ConfirmReadback`

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text of the readback a member posts with `ConfirmReadback`. The tool fills its slots and sends it as that member's own message, through the member send. It is not an event-track post.

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
- reply `yes` (or `ok`, `agreed`, `confirm`) to confirm, `no` to stop, or `correct` followed by the correction
- or react with :white_check_mark: or :+1: for yes, :x: for no
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

# Contract

- rule: The post is the one fenced block under `## post`, sent as the asking member's own message through the member send. It names its addressee as every member message does.
- rule: Required: `{{question}}`, `{{understood}}`, `{{source}}` and `{{will-do}}`. Optional: `{{tag}}`, the question's number where it shares a thread, and `{{context}}`. `{{how-to-answer}}` is filled from `# Answers` on every post that takes an answer.
- rule: A slot outside `[[ … ]]` is required: with one empty, nothing is posted. Text in `[[ … ]]` is kept only when every slot in it has a value, and a group may span lines, so a heading is left out together with its empty field. No field is ever shown as a placeholder.
- rule: The answer form is `confirm`. `{{how-to-answer}}` is the block under `# Answers` named for it.
- rule: The emoji placed under the post are the block under `# Reactions` named for the answer form, one Slack name each, in that order. They are placed by the identity that posted, and a reaction by that identity is never an answer.
- rule: A name placed here must be one the verdict reader takes for a readback (`AgentsEscalationVerdict.awk`): `+1` for yes, `x` for no.
- rule: `{{revised}}` is the `## revised` text under `# Marks`, shown only on the post of the question asked again, changed.
- rule: A post that no longer takes an answer is this same text without its `How to answer` group: the post of a discarded question, and a superseded version of a question asked inside a thread that is not its own. The tooling edits that post to it, and takes its own answer emoji off it.
- rule: `## superseded` under `# Marks` is the reaction the tooling puts on a version of the question that an update replaced, and `## cancelled` the one it puts on the post of a discarded question.
- rule: `## hint` under `# Returned` is what the asker is told when a reply names none of the answers. `{{explain-call}}`, `{{revise-call}}`, `{{withdraw-call}}` and `{{readback-call}}` are the exact calls, given by the tool.
- rule: Every text outside the slots and the marks is posted exactly as written here.
