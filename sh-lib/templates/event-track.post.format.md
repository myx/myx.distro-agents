---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# event-track post — the tooling's own tracking posts

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text of every post the tooling makes to track a session: the posts in a spawn's event-track thread, and the tooling's own status notes in a session thread. `--intern-op-event-track-post` fills its slots and posts it. A member's own message never uses it.

## Contents

- Summary
  - Goals
  - Scope
- Subjects
  - member
  - session
  - system
- Skeleton
  - start
  - end
  - handback
  - notice
  - refusal
  - error
  - activity
  - feed
- Operations
  - Read, Grep, Glob, Edit, Write, NotebookEdit, execute, Bash, Monitor, Skill, WebFetch, WebSearch, ToolSearch, TaskOutput
  - SendMessage, ReportFindings, PushNotification, Artifact, Wait, AskUserQuestion, Agent, SubagentHandback
  - tool, tool error, tool refused
  - ROUND, RESULT, MODEL, START, RESTART, END, FINAL, NOTE, REVIEW, VERDICT, DISMISSED, ERROR
  - event, text
- Contract

# Summary

A post is one or more blocks. A block is a subject header, saying what its lines are regarding (a member, the session, or the system), then one line each: the kind's own labelled lines, or one operation each, formatted by its own template. Lines in a row about the same subject share one header, which repeats only after another subject came in between, and an empty line sets each block apart. Nothing given is ever posted as it came: no raw log line, no code block.

## Goals

- A tracking post reads at a glance: what happened, regarding whom, in which session, the most important first.
- It is the tooling's own record, posted by the bot, so it names no addressee and never looks like a member's message.
- Changing the wording is an edit to this file, not to the operation that fills it.

## Scope

- Does: fix the text and the slots of every tracking post, its block headers and every operation's line.
- Doesn't: shape a member's own message, the DISMISSED or RETURNED a reviewer sends to a child, or a session thread's opening line. Those are messages to a member, and keep the member send.
- Doesn't: decide when a post goes. The event-track feed decides that (`AgentsTools.EventTrackFeed.include`).

# Subjects

What a block's lines are regarding. Every post comes from the bot: a header names a subject, never a sender.

## member

```
👤 *{{member}}*[[ · {{span}}]]
```

## session

```
🧵 session `{{session}}` · *{{member}}*[[ · {{span}}]]
```

## system

```
⚙️ system[[ · `{{session}}`]][[ · {{span}}]]
```

# Skeleton

## start

```
{{subject:session}}
🚀 session start[[ — {{what}}]]
[[cli: {{cli}}]][[ · runs: {{runs}}]][[ · tier: {{tier}}]][[ · wait: {{wait}}]]
[[routine: `{{routine}}`]][[ · dispatch: `{{dispatch}}`]][[ · resume: `{{resume}}`]]
[[spawn: `{{spawn-id}}`]][[ · session: `{{session-id}}`]][[ · parent: `{{parent-session-id}}`]][[ · tracking: `{{tracking-name}}`]]
[[session thread: `{{session-thread}}`]]
[[where: {{host}}]][[ / {{workspace}}]][[ · started: {{started-at}}]]
```

## end

```
{{subject:session}}
🏁 session end
[[outcome: {{outcome}}]][[ · exit: {{exit-code}}]][[ · launched: {{launched}}]]
[[tokens: {{tokens}}]]
[[cli: {{cli}}]][[ · armed: {{armed}}]][[ · setup: {{setup}}]]
[[timed out after: {{timed-out-after}}s]]
[[ended: {{ended-at}}]]
```

## handback

```
{{subject:session}}
📦 handback[[: {{handback}}]]
```

## notice

```
{{subject:session}}
⚠️ notice[[: {{what}}]]
{{operations}}
```

## refusal

```
{{subject:system}}
🚫 refusal[[: {{what}}]]
[[tool: `{{tool}}`]][[ · target: `{{target}}`]]
[[reason: {{reason}}]]
[[refusal-id: `{{refusal-id}}`]]
[[dispatch: `{{dispatch}}`]][[ · entry: `{{entry}}`]]
[[where: {{host}}]][[ / {{workspace}}]]
```

## error

```
{{subject:system}}
⛔ error[[: {{what}}]]
[[detail: {{detail}}]]
[[where: {{host}}]][[ · at: {{at}}]]
```

## activity

```
{{subject:system}}
📋 {{what}}
{{operations}}
```

## feed

```
{{operations}}
```

# Operations

One line per operation, chosen as `# Contract` says.

## Read

```
📖 [[{{comment}} — ]]Read[[ `{{file}}`]][[ · lines {{range}}]][[ · pages {{pages}}]][[ → {{size}}]]
```

## Grep

```
🔍 [[{{comment}} — ]]Grep[[ `{{pattern}}`]][[ in `{{where}}`]][[ → {{result-lines}}]]
```

## Glob

```
📁 [[{{comment}} — ]]Glob[[ `{{pattern}}`]][[ in `{{where}}`]][[ → {{entries}}]]
```

## Edit

```
✏️ [[{{comment}} — ]]Edit[[ `{{file}}`]][[ → {{outcome}}]]
```

## Write

```
📝 [[{{comment}} — ]]Write[[ `{{file}}`]][[ → {{outcome}}]]
```

## NotebookEdit

```
✏️ [[{{comment}} — ]]NotebookEdit[[ `{{file}}`]][[ → {{outcome}}]]
```

## execute

```
💻 [[{{comment}} — ]]execute[[ `{{cmd}}`]][[ job {{job}}]][[ · {{background}}]][[ → exit {{exit}}]][[ · {{duration}}]]
```

## Bash

```
💻 [[{{comment}} — ]]Bash[[ `{{cmd}}`]][[ · {{background}}]][[ → exit {{exit}}]][[ · {{duration}}]]
```

## Monitor

```
📡 [[{{comment}} — ]]Monitor[[ `{{cmd}}`]][[ job {{job}}]][[ → {{outcome}}]][[ · {{duration}}]]
```

## Skill

```
📚 [[{{comment}} — ]]Skill[[ `{{name}}`]][[ · `{{file}}`]][[ § {{section}}]][[ → {{size}}]]
```

## WebFetch

```
🌐 [[{{comment}} — ]]WebFetch[[ `{{url}}`]][[ → {{size}}]]
```

## WebSearch

```
🔎 [[{{comment}} — ]]WebSearch[[ `{{query}}`]][[ → {{size}}]]
```

## ToolSearch

```
🧰 [[{{comment}} — ]]ToolSearch[[ `{{query}}`]]
```

## TaskOutput

```
📜 [[{{comment}} — ]]TaskOutput[[ `{{handle}}`]][[ → {{size}}]]
```

## SendMessage

```
✉️ [[{{comment}} — ]]SendMessage[[ → *{{to}}*]][[: "{{message}}"]]
```

## ReportFindings

```
📊 [[{{comment}} — ]]ReportFindings[[ → *{{to}}*]][[: "{{subject}}"]]
```

## PushNotification

```
📣 [[{{comment}} — ]]PushNotification[[ → *{{to}}*]][[ · {{severity}}]][[: "{{headline}}"]]
```

## Artifact

```
🔗 [[{{comment}} — ]]Artifact[[ → *{{to}}*]][[ `{{url}}`]]
```

## Wait

```
⏳ [[{{comment}} — ]]Wait[[ → {{result}}]][[ from *{{from}}*]][[ by *{{by}}*]][[: "{{first}}"]][[ (+{{more}} more)]][[ · on: {{on}}]][[ · {{duration}}]]
```

## AskUserQuestion

```
❔ [[{{comment}} — ]]AskUserQuestion[[ → *{{to}}*]][[ · {{kind}}]][[: "{{question}}"]]
```

## Agent

```
🚀 [[{{comment}} — ]]Agent spawn[[ → *{{agent}}*]][[ (session {{session}}…)]][[ · {{status}}]]
```

## SubagentHandback

```
📦 [[{{comment}} — ]]handback[[ → *{{to}}*]][[: "{{summary}}"]]
```

## tool

```
🔧 [[{{comment}} — ]]{{tool}}[[ `{{target}}`]][[ → {{outcome}}]]
```

## tool error

```
⛔ [[{{comment}} — ]]{{tool}}[[ `{{target}}`]][[: "{{message}}"]] → error[[: {{reason}}]]
```

## tool refused

```
🚫 [[{{comment}} — ]]{{tool}}[[ `{{target}}`]][[: "{{message}}"]] → refused[[: {{reason}}]]
```

## ROUND

```
🧠 round[[ {{n}}]][[ · in {{in}}]][[ · cache {{cache}}]][[ · out {{out}}]]
```

## RESULT

```
🧠 run[[ {{outcome}}]][[ · {{turns}} turns]][[ · in {{in}}]][[ · cache {{cache}}]][[ · out {{out}}]]
```

## MODEL

```
🤖 model[[ `{{model}}`]][[ · {{service}}]][[ on {{host}}]]
```

## START

```
🚀 session start[[ · `{{item}}`]]
```

## RESTART

```
♻️ restart[[ {{n}}]][[ · summary {{summary}}]][[ · {{text}}]]
```

## END

```
🏁 session end[[ · {{outcome}}]][[ · exit {{exit}}]][[ · {{tokens}}]]
```

## FINAL

```
💬 final answer[[: "{{text}}"]]
```

## NOTE

```
🗒️ note[[ by *{{by}}*]][[: "{{text}}"]]
```

## REVIEW

```
🧾 review[[ `{{item}}`]][[ · {{kind}}]][[ by *{{by}}*]][[: {{text}}]]
```

## VERDICT

```
⚖️ verdict[[ on `{{item}}`]][[ by *{{by}}*]][[: {{text}}]]
```

## DISMISSED

```
🛑 dismissed[[ `{{item}}`]][[ by *{{by}}*]][[: {{text}}]]
```

## ERROR

```
⛔ error[[ · {{source}}]][[ · {{kind}}]][[: {{reason}}]]
```

## event

```
🔹 {{event}}[[: {{text}}]]
```

## text

```
• {{text}}
```

# Contract

- rule: A post is one or more blocks. A block is its subject's header, then one or more lines. A header names what its lines are regarding, never a sender: every post comes from the bot. A header is posted only with at least one line under it: a block left with none, such as a kind's block whose lines were all left out, posts no header either. Every header but a post's first has one empty line before it.
- rule: A subject is one `## <subject>` heading under `# Subjects` (member, session or system) and the one line in the fenced block after it.
- rule: A kind is one `## <kind>` heading under `# Skeleton` and the one fenced block after it. A kind with no block here posts nothing. A block's first line `{{subject:<subject>}}` opens the post with that subject's block; the kind's other lines are that block's lines.
- rule: An operation template is one `## <name>` heading under `# Operations` and the one line in the fenced block after it.
- rule: `{{member}}` is the member the post is about, and the identity it posts under, except in a member block's header, where it is that block's member. `{{session}}` is the first 8 characters of the session id the post is about. `{{span}}` in a header is the UTC time of its block's first and last operation.
- rule: Every other `{{<name>}}` is a field: one the caller gives, on a kind's line; one of the operation, on an operation's line. Text in `[[ … ]]` is kept only when every slot in it has a value. No field is ever shown as a placeholder: a field with no value, or given as `-`, is simply not shown. A slot outside `[[ … ]]` is required: a kind's line with one empty is left out, as is a kind's line with nothing left; on an operation's line it reads as nothing. A line whose first field was left out opens with the next one, not with its ` · ` or ` / `.
- rule: The line `{{operations}}` becomes the operations, one line each, in the order given; a block with no such line takes them at its end. An operation joins the block before it when its subject is the same, and opens a new block, with its header, when it is not. A run of operations about the same subject, an immediate one (below) too, shares one header.
- rule: An operation is one transcript line `<time> <KIND> key=value …` with the `> ` body lines after it. A TOOL line renders by the template named for its tool (an `mcp__<server>__` prefix dropped), by `tool error` or `tool refused` when it came out so, and by `tool` when its tool has none. A message event (MSG-OUT, HANDBACK, WAIT-RESULT, DISMISSED, ASK, ANSWER, SPAWN) next to the TOOL line of its call joins it, so one call is one line; alone, it renders by its tool's template. A Wait's DISMISSED renders by `Wait`; an ENDING by `DISMISSED`; a RESULT with outcome=error by `ERROR`; any other KIND by its own template, else by `event`. Any other line is a `text` operation. A body line is never posted itself.
- rule: An operation's subject: the session for START, END, MODEL, RESTART, HANDBACK, DISMISSED, ENDING, REVIEW and VERDICT; the kind's own subject for a `text` operation (system in a `feed`); else a member, the one its `by=` names where that is a member of the team, else `{{member}}`.
- rule: Immediate: an error (an ERROR line, a TOOL line ending error, a line with outcome=error), a refusal (a TOOL line ending refused), and START, END, MODEL, RESTART, HANDBACK, DISMISSED and ENDING. The event-track feed (`AgentsEventTrackFeedPlan.awk`) ends a post right after one; within a post it opens no block of its own.
- rule: An operation's fields come from its parsed line and the few body lines named here only: a call's key arguments, outcome, size (`size`), line count (`result-lines`, `entries`), duration and comment; an event's own fields; a message's first line that is not blank, from its MSG-OUT, else from its TOOL line's `message=`; a handback's `outcome:`; a Wait's lines named below; a spawn's `SESSION_ID=` and `STATUS=`; an error's first line as `reason`. A command's `exit` is 0 when it came out ok, else the code its error names.
- rule: `comment` is the agent's own intent for the call, the line's main text, before the tool and its compact arguments: the call's own description where its arguments carry one (any tool's `description`, which every harness and served tool declares, an `action_summary`, a task's `subject`, a TodoWrite's item in progress), else the model's short text just before the call (the TOOL line's `| "…"`, `stlArgComment`, AgentsSessionTranscriptFormat.awk). A comment shows once, not again on the next line that has the same.
- rule: A command reads without the boilerplate that opens it (`stlCompactCmd`): each leading DistroSystemContext, DistroAgentsContext or Require step ended by `;` or `&&`, then the Distro word before a tool name; it reads as given when nothing else would be left.
- rule: A Wait says how it resolved, as `result`: RECEIVED, TIMEOUT with its bound, DISMISSED, CLOSED, or `answered <verdict>` where an ask it waited on was answered with a verdict. On RECEIVED or an answer, `from` is the author of the first message that came (the member its `[sender: …]` names, else its Slack account, named by the team's account cache where that holds it), `first` that message's first line that is not blank, without the member send's author line and with a Slack link as its label, and `more` how many others came with it. On DISMISSED, `by` is who dismissed it: the author of the message `WAIT-DISMISSED-BY:` names, else that line's own words, its parenthesised reason as `first`.
- rule: A Wait's `on` is the set it waited on, its result's `# sources:`, else its own `sources=`, each source as a short name: `ask:` and the first 8 characters of its id; a named conversation by its name; a thread as `thread` (any post in it) or `reply` (a reply to me), `DM ` before it in a direct message; `inbox`; `board:<state>`; `file:<name>`. It shows whole on the session's first Wait, then only where it differs from that session's previous Wait, as `+added −removed`, and not at all when it is the same. A Wait that failed waited on nothing, and one whose set is unknown (a bare continue, a TIMEOUT) changes nothing. A `feed` post reads the session's previous set from `sessions/<sid>/event-track.wait-on` and leaves its last one there.
- rule: A path is shortened to its last component, with its parent when that is 10 bytes or shorter. A command is cut at 80 bytes; a pattern, name or target at 60; a message, question, summary, comment, first line or text at 100 to 120; a reason at 160; each at its first line, with `…`. Sizes read as B, KB or MB, token counts as K or M, durations as ms, s or m. A given `tokens` of `in=… cache-read=… cache-write=… out=…` reads as `in … · cache … · out …`.
- rule: Every value, given or parsed, is redacted as the transcript redacts it (`stlRedact`, AgentsSessionTranscriptFormat.awk) before it is cut.
- rule: Nothing given is posted as it came: no raw transcript line, no log line, and no code block.
- rule: A post is at most 4000 characters, Slack's limit for a message's `text`, counted as UTF-16 counts them. Longer, it is cut at line boundaries into several posts, and a post that starts inside a block repeats its header. A post to a conversation, not a thread, puts the later posts in the thread of the first.
- rule: A post is never edited. A `start` post is made once, when everything it names is known; a fact learned after it is a new post, a reply in its thread.
- rule: A `start` post's caller gives each id it names as its first 8 characters, and leaves out a field that only repeats another: the parent and the tracking name where they are the session's own.
- rule: Slack's control characters `&`, `<` and `>` in a value are sent escaped, so nothing can mention anyone. A backtick in a value is sent as `%60`, so none ends a code span.
- rule: No post names an addressee or a channel-wide mention, and none carries the member send's author line.
- rule: Every text outside the slots is posted exactly as written here.
