---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# tooling-note post — a short line the tooling itself posts in a thread

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — these are the fixed texts of the short lines the tooling posts on its own, in the thread each belongs to: that a member was brought into a session, and what was done about an ask after it was asked. The tooling fills a line's slots and sends it through the member send, so it names its sender and its addressee as every member message does. None of them is an ask: an ask is posted from the template of its own tool. None is an event-track post.

## Contents

- Summary
  - Goals
  - Scope
- Session
  - joined
- Ask
  - readback
  - withdrawn
  - reminder
  - forwarded
  - now-yours
- Reasons
  - not-held
- Words
  - asked-earlier
- Contract

# Summary

One block for each line: who it is about, what happened, and what its reader does next where there is something to do.

## Goals

- A reader of the thread sees what happened in words. No line opens with an id, and a target is shown by its place.
- Changing the wording or an icon is an edit to this file, not to the operation that posts the line.

## Scope

- Does: fix the text and the slots of each line.
- Doesn't: decide where a line is posted, under which identity, or who it is addressed to. The operation that posts it does.
- Doesn't: say what became of an answer. The confirmation does, from the template of the ask's kind (its `# Confirmations`).

# Session

What the tooling says in a session's thread about the session itself.

## joined

```
{{member}} joined[[: {{description}}]]
```

# Ask

What the tooling says about an ask, after it is asked.

## readback

```
🔁 Readback by {{member}}: I take your reply to mean `{{option}}`[[ -- {{text}}]]
If that is wrong, reply here. Your reply is kept on this decision.
```

## withdrawn

```
Withdrawn by {{member}}: {{reason}}
This question no longer needs an answer.
```

## reminder

```
⏰ Still waiting for your answer (asked {{asked}}, reminder {{number}}):[[
{{question}}]]
```

## forwarded

```
Forwarded by {{by}}. The answer in this thread is the verdict for this request.[[ {{reason}}, so that answer is not applied.]]
```

## now-yours

```
A permission request asked by {{member}} is now yours to answer, {{address-to}}. {{reason}}, so that answer is not applied. Answer it with the escalation answer operation, naming request `{{request-id}}`.
```

# Reasons

Why an answer was not applied, as a line above says it.

## not-held

```
{{by}} does not hold {{tool}}[[ on `{{target}}`]]
```

# Words

A value a line above takes where the record gives none.

## asked-earlier

```
an earlier date
```

# Contract

- rule: Each line is the one fenced block under its heading, sent through the member send by the operation that owns it, in the thread it belongs to. This file fixes its words only.
- rule: Who a line is addressed to is settled by the operation that posts it, and is named by the send, in the author line of the message. Every block is given that addressee as `{{address-to}}` wherever the operation names one, so a line that speaks to its addressee names it by that slot, never by a name written here.
- rule: A slot outside `[[ … ]]` is required. Text in `[[ … ]]` is kept only when every slot in it has a value, and a group may span lines. No field is ever shown as a placeholder. A line that cannot be filled is not posted, and the operation says so on stderr.
- rule: `## joined` under `# Session` is posted by the team bot in a session's thread for every member brought into it, but not for the one whose own session the thread is: `{{member}}`, the member brought in, and `{{description}}`, what it was brought in for, as its spawn said.
- rule: `## readback` is posted in the thread of a decision, or of a question with an answer form, by its asker, under the identity the question was asked with, when the asker closes it with its own reading of a reply that named none of the answers: `{{member}}`, the asker; `{{option}}`, the answer it takes the reply to mean; `{{text}}`, what it understood, where it said so.
- rule: `## withdrawn` is posted in the thread of a question its asker discarded, under the identity the question was asked with: `{{member}}`, the asker, and `{{reason}}`, why, as the asker gave it.
- rule: `## reminder` is posted in the thread of an ask still waiting for its answer, under the identity it was asked with: `{{asked}}`, when it was asked, a Slack date token so each reader sees it in their own timezone, else the `## asked-earlier` words under `# Words` where the record names no time; `{{number}}`, which reminder this is; and `{{question}}`, the question as it was asked, quoted, left out with its line break where the record holds none.
- rule: `## forwarded` is the line a request forwarded to the human-owner opens with, ahead of the request's own post as its record holds it: `{{by}}`, the member that forwards it, and `{{reason}}`, the `## not-held` line under `# Reasons`, only where the request goes up because an answer was not applied. It shows no request id: the thread it stands in is kept on the request's record, and its answer is read from there.
- rule: `## now-yours` is posted by the team bot in the session's thread when a permission request goes up to a holder running in that session: `{{member}}`, who asked; `{{address-to}}`, the holder, who answers it now; `{{reason}}`, the `## not-held` line; and `{{request-id}}`, the id the holder passes to the answer operation, at the end of the line and in code style, since only that operation needs it.
- rule: `## not-held` under `# Reasons` says what an approver did not hold: `{{by}}`, the approver, as a name; `{{tool}}`; and `{{target}}`, shown by its location root, `<place>:<relative path>`, where it lies in a registered place, and then never its absolute path beside it. A call with no target has no target part. The confirmation of an answer that goes up carries the same line as its reason.
- rule: Every text outside the slots is posted exactly as written here.
