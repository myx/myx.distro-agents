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
- Skeleton
  - start
  - activity
  - state
  - handback
  - review
  - dismissed
  - refusal
  - error
  - end
  - notice
- Contract

# Summary

One compact post per tracked event: a header line with the kind's emoji, the member, the kind and the session; a few labelled fields; then the session's own lines as a code block.

## Goals

- A tracking post reads at a glance: what happened, to which member, in which session, the most important first.
- It is the tooling's own record, so it names no addressee and never looks like a member's message.
- Changing the wording is an edit to this file, not to the operation that fills it.

## Scope

- Does: fix the text and the slots of every kind of tracking post.
- Doesn't: shape a member's own message, the DISMISSED or RETURNED a reviewer sends to a child, or a session thread's opening line. Those are messages to a member, and keep the member send.

# Skeleton

## start

```
🚀 *{{member}}* · session start · `{{session}}`
cli: {{cli}} · wait: {{wait}} · dispatch: {{dispatch}}
spawn: {{spawn-id}} · session: {{session-id}} · parent: {{parent-session-id}}
tracking: {{tracking-name}} · output: {{output-file}}
where: {{host}} / {{workspace}} · started: {{started-at}}
context: {{context}} · receipt: {{receipt}}
```

## activity

```
📋 *{{member}}* · activity · `{{session}}`
what: {{what}}
events: {{events}} · span: {{span}}
part: {{part}}
{{lines}}
```

## state

```
🔄 *{{member}}* · state change · `{{session}}`
events: {{events}} · span: {{span}}
part: {{part}}
{{lines}}
```

## handback

```
📦 *{{member}}* · handback · `{{session}}`
handback: {{handback}}
events: {{events}} · span: {{span}}
part: {{part}}
{{lines}}
```

## review

```
🔍 *{{member}}* · review · `{{session}}`
events: {{events}} · span: {{span}}
part: {{part}}
{{lines}}
```

## dismissed

```
🛑 *{{member}}* · dismissed · `{{session}}`
events: {{events}} · span: {{span}}
part: {{part}}
{{lines}}
```

## refusal

```
🚫 *{{member}}* · refusal · `{{session}}`
what: {{what}}
tool: `{{tool}}` · target: `{{target}}`
reason: {{reason}}
refusal-id: {{refusal-id}}
dispatch: {{dispatch}} · entry: `{{entry}}`
where: {{host}} / {{workspace}}
events: {{events}} · span: {{span}}
part: {{part}}
{{lines}}
```

## error

```
⛔ *{{member}}* · error · `{{session}}`
what: {{what}}
detail: {{detail}}
where: {{host}} · at: {{at}}
events: {{events}} · span: {{span}}
part: {{part}}
{{lines}}
```

## end

```
🏁 *{{member}}* · session end · `{{session}}`
outcome: {{outcome}} · exit: {{exit-code}} · launched: {{launched}}
tokens: {{tokens}}
cli: {{cli}} · armed: {{armed}} · setup: {{setup}}
timed out after: {{timed-out-after}}s
ended: {{ended-at}}
part: {{part}}
{{lines}}
```

## notice

```
⚠️ *{{member}}* · notice · `{{session}}`
what: {{what}}
part: {{part}}
{{lines}}
```

# Contract

- rule: A kind is one `## <kind>` heading under `# Skeleton` and the one fenced block after it. A kind with no block here posts nothing.
- rule: The block's first line is the header: the kind's emoji, the member in bold, the kind, and the session in code. It is always posted.
- rule: `{{member}}` is the member the post is about, and the identity it posts under. `{{session}}` is the first 8 characters of the session id the post is about, or `-` with none.
- rule: Every other `{{<name>}}` is a field the caller gives. A line whose every slot is empty is left out. An empty slot on a line kept for another slot reads `-`.
- rule: The tooling fills three slots itself. `{{events}}` counts the lines by their kind, in order of first appearance. `{{span}}` is the time of the first and the last line. `{{part}}` is `<n> of <total>` when one post is cut into several, and empty otherwise.
- rule: The line `{{lines}}` becomes the given lines, as one code block, or nothing with none. A block with no such line takes them at its end.
- rule: A post is at most `MDAT_EVENT_TRACK_CHUNK_BYTES` bytes (default 3000). Longer, its lines are cut at line boundaries into several posts, each with the same header and fields. A post to a conversation, not a thread, puts the later parts in the thread of the first.
- rule: Slack's control characters `&`, `<` and `>` in a value or a line are sent escaped, so no line can mention anyone. A backtick in a value is sent as `%60`, and a code fence inside a line is broken, so neither ends a code span or block.
- rule: No post names an addressee or a channel-wide mention, and none carries the member send's author line.
- rule: Every line outside the slots is posted exactly as written here.
