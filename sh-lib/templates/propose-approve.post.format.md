---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# propose-approve post — the two posts of a `ProposeApprove`

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text of the two posts a proposal makes with `ProposeApprove`: the root of its thread, which is the question the proposal answers, and the proposal itself, a reply under that root. The tool fills their slots and sends each as the proposing member's own message, through the member send. Neither is an event-track post.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
  - root
  - post
- Answers
  - approve
- Marks
  - cancelled
- Returned
  - hint
- Confirmations
  - taken
- Contract

# Summary

A proposal puts one document to the human-owner. The root is the question the proposal answers, and it stays. The reply under it is the proposal: the proposed form, the link to its document, the context where one is given, and how to answer.

## Goals

- The human-owner approves the document itself, by its link, with one click on the root or one word.
- The root carries only his own reaction: the tooling places no emoji under it and never changes it.
- Changing the wording, an icon or a hint is an edit to this file, not to the tool that fills it.

## Scope

- Does: fix the text and the slots of the root and of the proposal reply, and the lines that say how to answer.
- Doesn't: decide what an answer means. The verdict reader does (`AgentsEscalationVerdict.awk`).
- Doesn't: publish the document. It is published first, and the proposal carries its link.
- Doesn't: keep the approved text. The verdict is recorded with the link; saving the document verbatim is a later step.

# Skeleton

## root

```
# 📜 Proposal

{{question}}
```

## post

```
# 📄 The proposal

{{proposal}}

**🔗 Document**
{{document}}

[[**⚙ Context**
{{context}}

]][[**✅ How to answer**
{{how-to-answer}}]]
```

# Answers

The lines under `How to answer`.

## approve

```
- react on the first message of this thread: ✅ approves the document, ❌ rejects the proposal
- or reply here `approved` or `rejected`
- any other reply here is a comment: the proposal is worked out from it, and this message is replaced by the changed one
```

# Marks

What the tooling puts on the proposal reply once it takes no answer. A reaction is a Slack name. The root has no mark: the tooling never reacts on it.

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
- update: {{revise-call}}. The proposal reply is replaced by the changed one, under the same root.
- discard: {{withdraw-call}}.
```

# Confirmations

The one reply the tooling posts in the thread an answer was read in: what was read.

## taken

```
✅ Read: `{{verdict}}` by {{by}}. It is recorded as the answer to this proposal.[[ {{text}}]]
```

# Contract

- rule: A proposal makes two posts, each sent as the proposing member's own message through the member send, and each names its addressee as every member message does. The root is the one fenced block under `## root`: a message of its own, which opens the thread. The proposal is the one fenced block under `## post`: a reply in that thread.
- rule: The root is posted once. The tooling never edits it, deletes it or reacts on it, and places no emoji under it: this template has no `# Reactions`. Its only reactions are a person's own.
- rule: Required: `{{question}}` in the root, `{{proposal}}` and `{{document}}` in the reply. Optional: `{{context}}`. `{{how-to-answer}}` is filled from `# Answers` on every reply that takes an answer.
- rule: `{{document}}` is the link to the proposal document: the absolute `http://` or `https://` URL of a page that exists. The document is what the human-owner approves. A proposal with no document is never posted.
- rule: A slot outside `[[ … ]]` is required: with one empty, nothing is posted. Text in `[[ … ]]` is kept only when every slot in it has a value, and a group may span lines, so a heading is left out together with its empty field. No field is ever shown as a placeholder.
- rule: The answer form is `approve`. `{{how-to-answer}}` is the block under `# Answers` named for it.
- rule: The verdict is the human-owner's own reaction on the root, as the verdict reader takes it for a proposal (`AgentsEscalationVerdict.awk`): `white_check_mark` approves and `x` rejects, reject first where he holds both. A reply whose first word is `approved` or `rejected` gives the same verdict, and the rest of that line is its text. A reaction under the proposal reply is no verdict, and no plain agreement approves.
- rule: A changed proposal replaces the reply: the reply before it is deleted and the changed one is posted under the same root, so one proposal reply is live at a time. Nothing is marked, and the root is not touched. Once a verdict is on the root, no changed proposal is posted.
- rule: A post that no longer takes an answer is the reply's same text without its `How to answer` group: the reply of a discarded proposal. The tooling edits that reply to it. `## cancelled` under `# Marks` is the reaction the tooling puts on that reply, never on the root.
- rule: `## hint` under `# Returned` is what the asker is told when a reply names none of the answers. `{{explain-call}}`, `{{revise-call}}` and `{{withdraw-call}}` are the exact calls, given by the tool. No readback closes a proposal: only the human-owner's own verdict does.
- rule: Once an answer is read and applied, the tooling says so with one reply in the thread it was read in, as the identity that posted there: the block under `# Confirmations` named `taken`, with the answer (`{{verdict}}`), who gave it (`{{by}}`, as a name) and, where the answer carried one, its text. It is posted once for an answer, never again on a later read.
- rule: Every text outside the slots and the marks is posted exactly as written here.
