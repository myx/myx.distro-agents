---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# ask-question post — the post of an `AskQuestion`

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text of the question a member posts with `AskQuestion`. The tool fills its slots and sends it through the member send: as that member's own message, or as the team bot's when it is asked of the human-owner by a member that has no Slack account of its own. It is not an event-track post.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
  - post
- Options
  - plain
  - numbered
- Answers
  - text
  - yes-no
  - one
  - many
- Reactions
  - yes-no
  - one
  - many
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

One question to a person: its title, the question, the options where it has any, the context where one is given, and how to answer it. How to answer follows the answer form: free text, yes or no, one option, or several options.

## Goals

- The person sees at a glance what is asked and the fastest way to answer it.
- The emoji that answer the question are already under it, so an answer is one click.
- Changing the wording, an icon or a hint is an edit to this file, not to the tool that fills it.

## Scope

- Does: fix the text and the slots of the post, the line of each option, the lines that say how to answer each form, and the emoji placed under the post for each form.
- Doesn't: decide what an answer means. The verdict reader does (`AgentsEscalationVerdict.awk`).
- Doesn't: shape a readback, a decision or a permission. Each has its own template beside this one.

# Skeleton

## post

```
# ❓ Question[[ {{tag}}]][[ {{revised}}]]

{{question}}

[[**📋 Options**
{{options}}

]][[**⚙ Context**
{{context}}

]][[**✅ How to answer**
{{how-to-answer}}]]
```

# Options

One line per option, by the style of the answer form.

## plain

```
- {{option}}
```

## numbered

```
- {{number}} {{option}}
```

# Answers

The lines under `How to answer`, by the answer form.

## text

```
- reply in this thread
```

## yes-no

```
- click 👍 for yes or ❌ for no
- or reply `yes` or `no`
```

## one

```
- click the number of your choice
- or reply with its number, or with the first word of the option
```

## many

```
- click each number you choose, then 🆗 to send
- or reply with the numbers or first words, separated by spaces or commas, for example `1 3`
```

# Reactions

The emoji the tooling places under the post, by the answer form, as Slack names.

## yes-no

```
+1
x
```

## one

```
{{numbers}}
```

## many

```
{{numbers}}
ok
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

The one reply the tooling posts in the thread an answer was read in, for a question that has an answer form: what was read.

## taken

```
✅ Read: `{{verdict}}` by {{by}}. It is recorded as the answer.[[ {{text}}]]
```

# Contract

- rule: The post is the one fenced block under `## post`, sent through the member send as the asking member's own message. Asked of the human-owner (`to` is `human-owner`) by a member that has no Slack account of its own, it is the team bot's message, whatever `as_bot` says: that member's own send to the owner would go out under another member's account, in a conversation where the bot can place no answer emoji. It then stands in the bot's own conversation with the owner, as a permission does, and its record says `ask-identity: bot`, so its answer emoji and every later read, edit and reminder are the bot's too. It names its addressee as every member message does.
- rule: Required: `{{question}}`, the question as asked. Optional: `{{tag}}`, the question's number where it shares a thread; `{{options}}`; `{{context}}`. `{{how-to-answer}}` is filled from `# Answers` on every post that takes an answer.
- rule: A slot outside `[[ … ]]` is required: with one empty, nothing is posted. Text in `[[ … ]]` is kept only when every slot in it has a value, and a group may span lines, so a heading is left out together with its empty field. No field is ever shown as a placeholder.
- rule: The answer form is `text` when the call gives no `select`, else its `select`: `yes-no`, `one` or `many`. `one` and `many` need options. `yes-no` takes none.
- rule: `{{options}}` is one line per option, in the order given, each by the `## numbered` line where the form's `# Reactions` block holds `{{numbers}}`, else by the `## plain` line. `{{option}}` is the option as given, a leading `- ` dropped. `{{number}}` is its number as a keycap emoji, 1️⃣ to 🔟. An option past the tenth is numbered in plain digits.
- rule: `{{how-to-answer}}` is the block under `# Answers` named for the answer form.
- rule: The emoji placed under the post are the block under `# Reactions` named for the answer form, one Slack name each, in that order. `{{numbers}}` is one number emoji per option, up to the tenth. A form with no block places none. They are placed by the identity that posted, and a reaction by that identity is never an answer.
- rule: A name placed here must be one the verdict reader takes for this form (`AgentsEscalationVerdict.awk`): `+1` and `x` for `yes-no`, the numbers for `one`, the numbers and `ok` for `many`.
- rule: A `many` selection is sent with `ok` (🆗) and never with the check mark: `white_check_mark` (✅) is the mark the tooling itself puts on a question once it is answered, so it must not also be what sends one. The verdict reader still takes a `white_check_mark` held with numbers as the send, only so a question posted before this rule, whose text names ✅, can still be answered as it says.
- rule: `{{revised}}` is the `## revised` text under `# Marks`, shown only on the post of the question asked again, changed.
- rule: A post that no longer takes an answer is this same text without its `How to answer` group: the post of a discarded question, and a superseded version of a question asked inside a thread that is not its own. The tooling edits that post to it, and takes its own answer emoji off it.
- rule: `## superseded` under `# Marks` is the reaction the tooling puts on a version of the question that an update replaced, and `## cancelled` the one it puts on the post of a discarded question.
- rule: `## hint` under `# Returned` is what the asker is told when a reply names none of the answers. `{{explain-call}}`, `{{revise-call}}`, `{{withdraw-call}}` and `{{readback-call}}` are the exact calls, given by the tool. The last line is kept only where a readback may close the question.
- rule: Once the answer to a question that has an answer form (yes-no, one or many) is read and applied, the tooling says so with one reply in the thread it was read in, as the identity that posted there: the block under `# Confirmations` named `taken`, with the answer (`{{verdict}}`) and who gave it (`{{by}}`, as a name). It is posted once for an answer, never again on a later read. A question answered in free text has no verdict, and gets no such reply.
- rule: Every text outside the slots and the marks is posted exactly as written here.
