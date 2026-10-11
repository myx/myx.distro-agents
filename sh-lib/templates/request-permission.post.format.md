---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# request-permission post — the post of a `RequestPermission`

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text of the permission request a member posts with `RequestPermission`. The tool fills its slots and sends it as that member's own message, through the member send. It is not an event-track post.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
  - post
- Parts
  - refused-call
- Answers
  - grant
- Reactions
  - grant
- Marks
  - revised
  - superseded
  - cancelled
- Returned
  - hint
- Contract

# Summary

A permission request asks for one refused call: the question, the refused call as its record holds it, why the task needs it, the task, the context where one is given, and how to answer.

## Goals

- The person sees exactly which call was refused, and denies or allows it with one click or one word.
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

{{refused-call}}

**❔ Why this task needs it**
{{reason}}

**🗂 Task**
{{task}}

[[**⚙ Context**
{{context}}

]][[**✅ How to answer**
{{how-to-answer}}]]
```

# Parts

A block of the post that has a name. It is filled, and stands where the slot of its name is: in the post above, and in the post of a call under the second name `AskUserQuestion`, which shows it for a permission only because only this template has it.

## refused-call

```
**🚫 Refused call**
- tool: [[{{refused-tool}}]]
- target: [[{{refused-target}}]]
- refused for: [[{{refused-for}}]]
- refusal: {{refusal-id}}
```

# Answers

The lines under `How to answer`.

## grant

```
- reply `deny`, `allow-once` for this one call, or `allow-session` for this session
- or click ❌ to deny, 1️⃣ to allow once, or 🔁 to allow for this session
```

# Reactions

The emoji the tooling places under the post, as Slack names.

## grant

```
x
one
repeat
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
- rule: Required: `{{question}}`, `{{refusal-id}}`, `{{reason}}` and `{{task}}`. Optional: `{{tag}}`, the question's number where it shares a thread, and `{{context}}`. `{{how-to-answer}}` is filled from `# Answers` on every post that takes an answer.
- rule: `{{refused-call}}` is the block under `# Parts` named for it, filled: the refused call, always shown. `{{refused-tool}}`, `{{refused-target}}` and `{{refused-for}}` are the refused call as the refusal record holds it, never as the asker words it. The target is shown by its location root, `<place>:<relative path>`, where it lies in a registered place, and then no absolute path is shown beside it; where it lies in none it is shown as the record holds it. One the record leaves empty shows as an empty value under its label.
- rule: A slot outside `[[ … ]]` is required: with one empty, nothing is posted. Text in `[[ … ]]` is kept only when every slot in it has a value, and a group may span lines, so a heading is left out together with its empty field. No field is ever shown as a placeholder.
- rule: The answer form is `grant`. `{{how-to-answer}}` is the block under `# Answers` named for it.
- rule: The emoji placed under the post are the block under `# Reactions` named for the answer form, one Slack name each, in that order. They are placed by the identity that posted, and a reaction by that identity is never an answer.
- rule: A name placed here must be one the verdict reader takes for a permission (`AgentsEscalationVerdict.awk`): `x` to deny, `one` to allow once, `repeat` to allow for this session. A thumbs up is never placed and never grants.
- rule: `{{revised}}` is the `## revised` text under `# Marks`, shown only on the post of the question asked again, changed.
- rule: A post that no longer takes an answer is this same text without its `How to answer` group: the post of a discarded question, and a superseded version of a question asked inside a thread that is not its own. The tooling edits that post to it, and takes its own answer emoji off it.
- rule: `## superseded` under `# Marks` is the reaction the tooling puts on a version of the question that an update replaced, and `## cancelled` the one it puts on the post of a discarded question.
- rule: `## hint` under `# Returned` is what the asker is told when a reply names none of the answers. `{{explain-call}}`, `{{revise-call}}`, `{{withdraw-call}}` and `{{readback-call}}` are the exact calls, given by the tool.
- rule: Every text outside the slots and the marks is posted exactly as written here.
