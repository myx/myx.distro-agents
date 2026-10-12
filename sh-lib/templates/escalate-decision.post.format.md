---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# escalate-decision post — the post of an `EscalateDecision`

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text of the decision a member posts with `EscalateDecision`. The tool fills its slots and sends it through the member send: as that member's own message, or as the team bot's when it is asked of the human-owner by a member that has no Slack account of its own. It is not an event-track post.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
  - post
- Options
  - numbered
- Answers
  - one
  - one, recommended
- Reactions
  - one
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

A decision asks a person to choose one option: the question, the options, each numbered, the context where one is given, and how to answer.

## Goals

- The person sees the options and takes one with one click or one word.
- Changing the wording, an icon or a hint is an edit to this file, not to the tool that fills it.

## Scope

- Does: fix the text and the slots of the post, the line of each option, the lines that say how to answer, and the emoji placed under the post.
- Doesn't: decide what an answer means. The verdict reader does (`AgentsEscalationVerdict.awk`).

# Skeleton

## post

```
# 🧭 Decision[[ {{tag}}]][[ {{revised}}]]

{{question}}

**📋 Options**
{{options}}

[[**⚙ Context**
{{context}}

]][[**✅ How to answer**
{{how-to-answer}}]]
```

# Options

One line per option.

## numbered

```
- {{number}} {{option}}
```

# Answers

The lines under `How to answer`.

## one

```
- reply with the first word of the option you choose
- or click its number, or reply with the number
```

## one, recommended

```
- reply with the first word of the option you choose
- or click its number, or reply with the number
- or reply `ok` (or react with :+1:) to take the recommended option
```

# Reactions

The emoji the tooling places under the post, as Slack names.

## one

```
{{numbers}}
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
[[- take it as the answer: {{readback-call}}. The person may still object there.]]
```

# Confirmations

The one reply the tooling posts in the thread an answer was read in: what was read.

## taken

```
✅ Read: `{{verdict}}` by {{by}}. It is recorded as the decision.[[ {{text}}]]
```

# Contract

- rule: The post is the one fenced block under `## post`, sent through the member send as the asking member's own message. Asked of the human-owner (`to` is `human-owner`) by a member that has no Slack account of its own, it is the team bot's message, whatever `as_bot` says: that member's own send to the owner would go out under another member's account, in a conversation where the bot can place no answer emoji. It then stands in the bot's own conversation with the owner, as a permission does, and its record says `ask-identity: bot`, so its answer emoji and every later read, edit and reminder are the bot's too. It names its addressee as every member message does.
- rule: Required: `{{question}}` and `{{options}}`. Optional: `{{tag}}`, the question's number where it shares a thread, and `{{context}}`. `{{how-to-answer}}` is filled from `# Answers` on every post that takes an answer.
- rule: A slot outside `[[ … ]]` is required: with one empty, nothing is posted. Text in `[[ … ]]` is kept only when every slot in it has a value, and a group may span lines, so a heading is left out together with its empty field. No field is ever shown as a placeholder.
- rule: `{{options}}` is one line per option, in the order given, each by the `## numbered` line. `{{option}}` is the option as given, a leading `- ` dropped. `{{number}}` is its number as a keycap emoji, 1️⃣ to 🔟. An option past the tenth is numbered in plain digits.
- rule: The answer form is `one`. `{{how-to-answer}}` is the block under `# Answers` named for it: `one, recommended` where an option is marked `(recommended)`, else `one`.
- rule: The emoji placed under the post are the block under `# Reactions` named for the answer form. `{{numbers}}` is one number emoji per option, up to the tenth, in that order. They are placed by the identity that posted, and a reaction by that identity is never an answer.
- rule: A name placed here must be one the verdict reader takes for a decision (`AgentsEscalationVerdict.awk`): the numbers.
- rule: `{{revised}}` is the `## revised` text under `# Marks`, shown only on the post of the question asked again, changed.
- rule: A post that no longer takes an answer is this same text without its `How to answer` group: the post of a discarded question, and a superseded version of a question asked inside a thread that is not its own. The tooling edits that post to it, and takes its own answer emoji off it.
- rule: `## superseded` under `# Marks` is the reaction the tooling puts on a version of the question that an update replaced, and `## cancelled` the one it puts on the post of a discarded question.
- rule: `## hint` under `# Returned` is what the asker is told when a reply names none of the answers. `{{explain-call}}`, `{{revise-call}}`, `{{withdraw-call}}` and `{{readback-call}}` are the exact calls, given by the tool. The last line is kept only where a readback may close the question.
- rule: Once an answer is read and applied, the tooling says so with one reply in the thread it was read in, as the identity that posted there: the block under `# Confirmations` named `taken`, with the option taken (`{{verdict}}`), who gave it (`{{by}}`, as a name) and, where the answer carried one, its text. It is posted once for an answer, never again on a later read.
- rule: Every text outside the slots and the marks is posted exactly as written here.
