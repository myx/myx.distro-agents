---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# tooling-note post — a short line the tooling itself posts in a thread

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — these are the fixed texts of the short lines the tooling posts on its own, in the thread each belongs to: that a member was brought into a session, how a member's run ended, told to whoever requested it, that it ended with a question of its own still open, and what was done about an ask after it was asked. The tooling fills a line's slots and sends it through the member send, so it names its sender and its addressee as every member message does. None of them is an ask: an ask is posted from the template of its own tool. The blocks under `# Death` are no line of their own: they are the fields of the one question the tooling asks about a run that died, a decision, posted from the template of a decision. None is an event-track post.

## Contents

- Summary
  - Goals
  - Scope
- Session
  - joined
  - handback-missing
  - run-ended
  - run-killed
  - run-closed
  - run-stopped
  - run-bound
  - run-died
  - death-resumed
  - death-fresh
  - death-new-process
  - death-closed
  - death-killed
  - death-failed
  - unrequested
  - question-open
- Death
  - question
  - question-again
  - executor
  - participant
  - options
  - context
  - again
- Ask
  - readback
  - withdrawn
  - reminder
  - forwarded
  - now-yours
  - console-answered
  - console-rejected
  - console-dismissed
  - authority
  - authority-text
  - authority-confirm
- Reasons
  - not-held
  - session-killed
  - asker-killed
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

What the tooling says in a session's thread about the session itself, and what it tells whoever requested a run about how that run ended.

## joined

```
{{member}} joined[[: {{description}}]]
```

## handback-missing

```
📦 {{member}} ended its run[[ `{{run}}`]] and posted no handback. What it did is not reported in this thread.[[ {{unrequested}}]]
```

## run-ended

```
🏁 {{member}} ended its run[[ `{{run}}`]]. Its handback was posted in another thread, not in this one.[[ {{unrequested}}]]
```

## run-killed

```
🛑 The run[[ `{{run}}`]] of {{member}} was killed from the console by {{by}}[[, {{at}}]].[[ {{unrequested}}]]
```

## run-closed

```
🛑 The run[[ `{{run}}`]] of {{member}} had ended and left its record open: the record was closed from the console by {{by}}[[, {{at}}]], with the kill of its session.[[ {{unrequested}}]]
```

## run-stopped

```
🛑 The run[[ `{{run}}`]] of {{member}} was stopped by {{by}}, with TaskStop[[, {{at}}]].[[ {{unrequested}}]]
```

## run-bound

```
⏱ The run[[ `{{run}}`]] of {{member}} was ended by the tooling: it had run for its bound of {{seconds}} seconds.[[ {{unrequested}}]]
```

## run-died

```
💀 The run[[ `{{run}}`]] of {{member}} died: its process is gone, and nothing closed its record.[[ {{unrequested}}]]
```

## death-resumed

```
▶️ {{member}} is started again after its run[[ `{{run}}`]] died, from the context it kept. {{by}} answered `{{option}}`.
```

## death-fresh

```
▶️ {{member}} is started again after its run[[ `{{run}}`]] died, from its brief, with no context. {{by}} answered `{{option}}`.
```

## death-new-process

```
▶️ {{member}} is started again after its run[[ `{{run}}`]] died, as a new process from its brief: its context could not be resumed[[ ({{reason}})]]. {{by}} answered `{{option}}`.
```

## death-closed

```
☑️ The run[[ `{{run}}`]] of {{member}} that died stays ended: its record is closed[[, and its item `{{item}}` is accepted]]. {{by}} answered `{{option}}`.
```

## death-killed

```
🛑 The session of {{member}}, whose run[[ `{{run}}`]] died, is ended: what still lived of it was killed, and the record of the dead run is closed. {{by}} answered `{{option}}`.
```

## death-failed

```
⚠️ The answer `{{option}}` of {{by}} about the run[[ `{{run}}`]] of {{member}} that died was not carried out: {{reason}}.[[ Its item `{{item}}` is back in review.]] Nothing is tried again by itself: {{by}} is asked again what to do.
```

## unrequested

```
No session requested this run, so its end is told here.[[ Its session: {{session}}.]]
```

## question-open

```
❓ {{member}} ended its run[[ `{{run}}`]] and left questions of its own open: {{count}}. Each one stays open and can still be answered.
```

# Death

What the tooling asks the reviewer of a run that died: the fields of a decision, which is posted from the template of a decision.

## question

```
{{member}} died. It was {{role}} of the session[[ {{session}}]][[ `{{session-id}}`]]: its process is gone, and nothing closed its run[[ `{{run}}`]]. What should be done with it?
```

## question-again

```
[[`{{option}}` has now failed {{count}} times in a row, each time for the same reason.
]]The answer `{{option}}` about {{member}}, whose run[[ `{{run}}`]] died, was not carried out: {{reason}}.[[ Its item `{{item}}` is back in review.]] What should be done with it now?
```

## executor

```
the executor
```

## participant

```
a participant
```

## options

```
resume: start it again from the context it kept
fresh: start it again from its brief, with no context
close: leave it ended, and close its record and its item as they are
kill: end what still lives of its session, and close it
```

## context

```
Nothing is started, closed or ended until this is answered.[[ Its task: `{{item}}`.]]
```

## again

```
Your run died, and {{by}} answered `{{option}}`: you are started again on the same task. Go on with it, then hand back.
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

## console-answered

```
🖥️ Answered from the console by {{by}}: `{{option}}`[[ -- {{text}}]]
```

## console-rejected

```
🖥️ Rejected from the console by {{by}}: `{{option}}`[[ -- {{text}}]]
```

## console-dismissed

```
🖥️ Dismissed from the console by {{by}}[[: {{reason}}]]
This question no longer needs an answer.
```

## authority

```
🔐 {{requester}} asks for the authority of {{holder}} to {{what}}. Answer `allow-once` to let it do that, or `deny` to refuse it.
```

## authority-text

```
🔐 {{requester}} asks for the authority of {{holder}} to {{what}}. Reply with the text to give in its place, `allow-once` to let it give its own, or `deny` to refuse it.
```

## authority-confirm

```
🔐 Confirm: the console account {{requester}} asks to {{what}}, which takes the authority of the owners role. Answer `yes` to let it do that, or `no` to refuse it.
```

# Reasons

Why an answer was not applied, as a line above says it.

## not-held

```
{{by}} does not hold {{tool}}[[ on `{{target}}`]]
```

## session-killed

```
the session was killed from the console by {{by}}
```

## asker-killed

```
the run that asked it was killed from the console by {{by}}
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
- rule: The five lines of an end, `## handback-missing`, `## run-ended`, `## run-killed`, `## run-stopped` and `## run-bound`, say how the run of a member ended. Whoever closes the record of that run posts one of them, once, as the team bot: its supervising shell, or the advance pass for a dead run that it closes. `{{member}}` is the member whose run it is, and `{{run}}` the first 8 characters of that run's id. The line is posted in the thread of the session that requested the run, which is the run's own session thread where it joined that session, and it is addressed to the member that brought the run in, where the send can address it, never to the member it is about. A run that no session requested, and whose item names no reviewer, is told to the human-owner in the bot's direct conversation, addressed to him: the line then ends with `{{unrequested}}`, the `## unrequested` line. Each is a message that states a fact and asks nothing, never a tracking post.
- rule: `## handback-missing` is the line of a run that ended by itself with no `SubagentHandback` call seen in its output, after the one retry that asks it for one. The box that tracks the same fact goes to the session's tracking thread, and only there (`event-track.post.format.md`, `handback`).
- rule: `## run-ended` is the line of a run that ended by itself and handed back, where none of its handbacks was posted in the thread it is told in. A run whose handback stands in that thread gets no line: the handback said it.
- rule: `## session-killed` and `## asker-killed` under `# Reasons` say why a question was dismissed by a kill from the console: of its whole session, or of the one run that asked it. Each is the `{{reason}}` of `## console-dismissed`, and is kept as the reason on the record of the question. `{{by}}` is the name the console's user has in the operating system.
- rule: `## run-closed` is the line of a run whose record the kill of its session closed with no process behind it: the run had ended before and nobody had closed its record, so it is not said to have been killed. `{{by}}` and `{{at}}` are those of `## run-killed`, as the record keeps them.
- rule: `## run-killed` is the line of a run that the console killed: `{{by}}`, the name the console's user has in the operating system, and `{{at}}`, when, a Slack date token so each reader sees it in their own timezone, both as the run's record keeps them. It is posted whatever the run had handed back, and in place of `## handback-missing`.
- rule: `## run-stopped` is the line of a run that a member's `TaskStop` ended: `{{by}}`, that member, and `{{at}}`, when, a Slack date token, both as the run's transcript records that ending. It is posted whatever the run had handed back, and in place of `## handback-missing`.
- rule: `## run-bound` is the line of a run that the tooling ended because the wait of its caller reached its bound: `{{seconds}}`, that bound. It is posted whatever the run had handed back, and in place of `## handback-missing`.
- rule: `## run-died` is the line of a run that died: its process is gone, the shell that supervised it is gone, its record is still open, and nobody ended it on purpose. The control thread of its session posts it, once, as the team bot, where a line of an end is posted and to whom, in place of the five lines above, and nothing where a handback of the run stands in that thread. Where the death is asked about in that same thread, the question is the message, and this line is not posted.
- rule: The six lines `## death-resumed`, `## death-fresh`, `## death-new-process`, `## death-closed`, `## death-killed` and `## death-failed` say what became of the answer to the question about a run that died. The control thread of the session posts one of them, once, as the team bot, in the thread of the question, addressed to the one who answered, and in the thread of the session that requested the run, addressed to the member that brought it in, where that is another thread: `{{member}}`, the member whose run died; `{{run}}`, the first 8 characters of that run's id; `{{by}}`, who was asked and answered; `{{option}}`, the option taken. `## death-new-process` is the line of a `resume` whose context could not be resumed, with why, `{{reason}}`. `## death-closed` names the item that was accepted, `{{item}}`, where the run had one. `## death-failed` says why the answer was not carried out, `{{reason}}`, and names the item, `{{item}}`, where a restart that failed left it and it was put back in review: the death then stays unsettled, and the one who answered is asked again, by a question of its own.
- rule: `## question-again` under `# Death` is the question of a decision asked again, of the same reviewer, each time an answer about a run that died could not be carried out: `{{option}}`, that answer; `{{member}}` and `{{run}}` as in `## question`; `{{reason}}`, why it was not carried out; `{{item}}`, the item that was put back in review, left out with its sentence where none was. Its first line is kept only where `{{count}}` is given: how many times in a row that same answer has failed for that same reason, three or more. Its options and its context are `## options` and `## context`. The tooling tries no answer again by itself: only a new answer starts a new try.
- rule: `## again` under `# Death` is what the member that is started again is told, as the corrections of the return that starts it: `{{by}}`, who answered, and `{{option}}`, the option taken.
- rule: `## unrequested` is what a line of an end says more of a run that no session requested: `{{session}}`, the name its spawn gave its session, left out with its sentence where it gave none.
- rule: The blocks under `# Death` are the fields of the question about a run that died, which is asked only where the item of that run names a reviewer. It is a decision: the control thread of the session posts it from the template of a decision (`escalate-decision.post.format.md`), as the team bot, to that reviewer, with a record of the kind `decision`. `## question` is its question: `{{member}}`, the member whose run died; `{{role}}`, the `## executor` words for the founder of the session and the `## participant` words for any other run; the session by the name its spawn gave it, `{{session}}`, else by the first 8 characters of its id, `{{session-id}}`, never both; and `{{run}}`, the first 8 characters of the run's id. `## options` is its options, one a line, in that order, each starting with the word that answers it. `## context` is its context: `{{item}}`, the dispatch item of the run.
- rule: `## question-open` is posted by the team bot in the run's own session thread when a run ends and at least one question it asked is still open, addressed to the member that brought that one in, where the send can address it: `{{count}}`, how many. The box that lists them goes to the session's tracking thread, and only there (`event-track.post.format.md`, `notice`).
- rule: `## readback` is posted in the thread of a decision, or of a question with an answer form, by its asker, under the identity the question was asked with, when the asker closes it with its own reading of a reply that named none of the answers: `{{member}}`, the asker; `{{option}}`, the answer it takes the reply to mean; `{{text}}`, what it understood, where it said so.
- rule: `## withdrawn` is posted in the thread of a question its asker discarded, under the identity the question was asked with: `{{member}}`, the asker, and `{{reason}}`, why, as the asker gave it.
- rule: `## reminder` is posted in the thread of an ask still waiting for its answer, under the identity it was asked with: `{{asked}}`, when it was asked, a Slack date token so each reader sees it in their own timezone, else the `## asked-earlier` words under `# Words` where the record names no time; `{{number}}`, which reminder this is; and `{{question}}`, the question as it was asked, quoted, left out with its line break where the record holds none.
- rule: `## forwarded` is the line a request forwarded to the human-owner opens with, ahead of the request's own post as its record holds it: `{{by}}`, the member that forwards it, and `{{reason}}`, the `## not-held` line under `# Reasons`, only where the request goes up because an answer was not applied. It shows no request id: the thread it stands in is kept on the request's record, and its answer is read from there.
- rule: `## now-yours` is posted by the team bot in the session's thread when a permission request goes up to a holder running in that session: `{{member}}`, who asked; `{{address-to}}`, the holder, who answers it now; `{{reason}}`, the `## not-held` line; and `{{request-id}}`, the id the holder passes to the answer operation, at the end of the line and in code style, since only that operation needs it.
- rule: `## not-held` under `# Reasons` says what an approver did not hold: `{{by}}`, the approver, as a name; `{{tool}}`; and `{{target}}`, shown by its location root, `<place>:<relative path>`, where it lies in a registered place, and then never its absolute path beside it. A call with no target has no target part. The confirmation of an answer that goes up carries the same line as its reason.
- rule: Every text outside the slots is posted exactly as written here.
