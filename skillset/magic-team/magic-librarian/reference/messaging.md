# Messaging platforms — size limits, silent truncation, identity-scoped access

Read this when sending, reading, or storing messages through any chat/messaging platform, when
composing a message that asks the human-owner for something, and when writing or revising the
conventions that govern how the team reaches him and how it composes messages.

This module carries the **evidence and reasoning**. The **operative rules** members follow live in
`magic-team/magic-team.conversations.md`, "Message and reaction discipline" — **message-shape-is-correctness**,
**one-message-one-speech-act**, and **human-owner-action-to-slack-dm** — written platform-neutrally on
purpose, and self-sufficient on their own. Read those for what to do; read this for why it is true and
what was actually measured. Keep the two layers cross-referenced, never duplicated: a rule stated twice
drifts.

Platform specifics belong here, and an operation's own platform behaviour belongs in that package's
help pair, which is its real manual. Routine docs and the conventions file stay platform-agnostic, so a
future platform inherits the rules instead of needing its own set. That abstraction boundary is the
reason this module exists as a separate layer.

## Why a session reply does not reach the human-owner

- **A request that needs him goes to his own direct channel** — a decision, a ratification, an answer,
  a blocker — whatever the installation has configured as that channel. No rule names a transport.
- **He answers in a live session when he is in one, but he does not go there to look.** A question
  raised only in a session does not reach him, and the work stalls silently while it looks, from the
  agent's side, as though it was asked. This is the module's core property seen from the other side: the
  send succeeded, so nothing reports that the ask never arrived.
- **The ask goes out when it becomes open**, not batched into a later summary and not left sitting in a
  session reply.

## Why an ask leads its own message

- **Bundling unrelated topics is the fault, not a shape to be tested for.** The split tests decide when
  a related, decomposable message needs splitting; unrelated matters never reach a test.
- **The ask leads, and the work that produced it is not sent with it.** A one-line question inside a
  screen of status and findings has not been asked — he had to do the finding, which is the work the
  message existed to save him.
- **Brevity is the instrument, not the standard.** No rule carries a word count. An ask that will not
  state itself briefly identifies a choice not yet found, and the work owed is finding it.
- **An intent given is a thing to act on, not a subject to write about.** Generating text about an ask,
  in place of putting the ask, is the failure these rules catch — and it binds a session relaying
  someone else's ask as much as one raising its own.

## The core property: a response describes acceptance, not retention

**A success response describes the call, not the payload that survived it.**

An oversized message can be accepted, reported as sent, and stored with content missing — no error, no
warning, no indication of loss. The send path has no way to tell you, because from its point of view
nothing failed.

This generalises well past messaging. **Any capped sink whose response describes acceptance rather
than retention has this shape**: log ingestion, metric labels, database columns that truncate instead
of rejecting, form fields, URL parameters. Whenever the receiver silently trims and still answers
"OK", the only detection is reading back what was stored.

## Measured behaviour (Slack, `chat.postMessage`)

Controlled test, three lengths, each read back to establish what is actually stored:

| Characters sent | Characters stored |
|---|---|
| 8000 | 4018 |
| 16000 | 4019 |
| 40000 | 4019 |

Success returned every time. The practical limit sits at roughly four thousand characters.

**The most important part is the shape, not the number.** Past the limit, stored size stops tracking
sent size entirely — 16000 and 40000 both land on 4019. A message ten times too long and one twice too
long are **indistinguishable in the response**. There is no gradient to notice and no partial-success
signal to catch. That is precisely why reading back is the only detection, and why "keep messages
reasonably short" is not a sufficient mitigation: there is no feedback channel that tells you when you
crossed the line.

Truncation keeps the tail: an over-long post is stored as its last paragraphs only, with `rc=0` and a
success status returned. Reading back is the only detection; splitting the post into parts is the
only fix.

**Do not put the constant into the conventions file.** It is a vendor detail with a shelf life; the
rule that survives is "platforms impose limits and may truncate silently".

## Consequences for composition

- One point per message. Sub-points only within a report.
- Long content — code, diffs, plans, anything awaiting approval — goes in a snippet or attachment,
  never the message body. That content is simultaneously the most likely to exceed a limit and the
  most damaging to lose unnoticed. **A truncated plan still looks like a plan**, which is what makes
  silent truncation dangerous rather than merely annoying.
- When completeness actually matters, read back what was stored.

## Retry output can carry more than one verdict

A retrying send can emit more than one `ok`/verdict field across its own retry attempts. Read the
**last** verdict in the output, not the first — a retried send that ultimately lands can still show an
earlier failed attempt's `ok:false` ahead of it, and reading the first field alone misreports a landed
post as failed.

## Identity-scoped access — send and read are not symmetric

Measured on both sides, not argued:

- **Send**: `chat.postMessage` accepts a **user id** as its `channel` and resolves the DM itself. No
  explicit conversation-open call is needed.
- **Read**: `conversations.history` with a **user id** returns `channel_not_found`. Only the **DM id**
  succeeds.
- Reactions follow the read side, not the send side.
- **Delete**: only the identity that authored a message may remove it. The operational consequence is the part that bites — a session's posts are spread across the identities that made them, so removing them takes each of those identities in turn, and is never one member's action.

So a user id is a sufficient address for writing and an insufficient one for reading. The natural
assumption is that all paths behave alike; they do not. **Any doc covering the send path must say so
explicitly**, or a reader will generalise from the easy case.

### Why this matters for stored addresses

A DM id is **scoped to one identity pair**. It is not a shared address, even though it is shaped like
one and sits in the same field as genuinely shared channel ids.

The governing invariant, adopted team-wide: **a value scoped to one identity pair must not live in a
shared config key.** Prefix kind-checking (`D…` vs `C…`) catches only the cases whose wrongness is
visible in the value's own syntax — it cannot catch a private channel that only one identity can see.
Treat kind-checking as a partial mitigation, never as coverage.

Practical consequence for any stored address: **prefer storing the person's user id and deriving the
conversation at read time** over persisting a resolved DM id, since the derived value is correct for
whichever identity is doing the reading. Where DM ids are already persisted, they are only valid for
the identity that recorded them.

## Required permissions — the settled list, and how to re-derive it

Concrete scope names live here, in the reference layer, deliberately. They do not belong in routine or
help text: the durable rule there is platform-neutral, and a future platform inherits the rule without
inheriting this vendor's vocabulary.

### The derivation method — this is the durable part

**Derive from endpoints, not from incidents.** Grep the source for the API endpoints actually called,
union them into the scopes those endpoints require, and grant that set.

**One grep is not the derivation.** An endpoint reaches the wire in two forms — written as a literal
URL, or passed by name as an argument to a shared caller — and a pattern matching only the first
misses the second silently. Union both:

```
grep -Rhho "slack\.com/api/[a-zA-Z.]*" sh-lib sh-scripts | sed 's|slack.com/api/||'
grep -Rhho -- "--api [a-zA-Z]*\.[a-zA-Z.]*" sh-lib sh-scripts | sed 's|^--api ||'
```

Sort and unique the two together. The literal-URL grep alone misses every endpoint passed by name —
`conversations.history`, `conversations.replies` and `reactions.add` among them.

**A scope with no endpoint of its own is invisible to this method.** `chat:write.customize` modifies
`chat.postMessage` rather than adding an endpoint, so no endpoint grep can find it and an
endpoint-derived list omits it by construction. Read the app's own declared scopes alongside the
derived list before concluding a capability is missing.

**Re-run this whenever an endpoint is added.** A list produced any other way is a snapshot that starts
drifting immediately; a list with a re-derivation command attached stays true — but only while the
command still matches every call form the code actually uses. The derivation command is itself
something to re-check, never a standing guarantee.

### Endpoints actually called

Literal-URL form: `auth.test`, `chat.postMessage`, `conversations.info`, `conversations.join`,
`conversations.list`, `conversations.open`, `rtm.connect`, `users.list`.

Argument form: `chat.delete`, `chat.update`, `conversations.history`, `conversations.info`,
`conversations.replies`, `files.info`, `reactions.add`, `search.messages`.

`rtm.connect` is the exception to the list below: it is the presence path, it takes a user token only
(a bot token answers `not_allowed_token_type`), and its scope `rtm:stream` is therefore required on
the user identity alone.

### Required scopes (16) — needed on BOTH identities

`chat:write`, `users:read`, `channels:read`, `channels:history`, `channels:join`, `groups:read`,
`groups:history`, `im:read`, `im:history`, `im:write`, `mpim:read`, `mpim:history`, `mpim:write`,
`reactions:read`, `reactions:write`, `files:read`

Current gaps: **BOT** missing `mpim:history`, `mpim:write`; **USER** missing
`channels:join`, `files:read`, `mpim:write`. **`mpim:write` is missing on both — no identity can open a
group DM.**

Scopes are fixed at authorization, so granting one requires re-installing the app and storing the new
token; adding a scope in a settings page does not change a token already issued.

### The honesty bound — never separate it from the check

**A permission check verifies GRANTED SCOPES, not EFFECTIVE ACCESS.**

The bot holds `files:read` and **still cannot read a file in a DM it is not in**. A green result means
*"the scopes are granted"*, never *"this works"*. Capability and access are separate things sitting on
separate identities (see the identity section above), and no scope audit can see the second one.

Anyone reading "scope check passes" later will assume more than it means unless this bound travels
with it. State it wherever the result is reported, not only where the check is defined.

## Reading list

- `magic-team/magic-team.conversations.md`'s **message-shape-is-correctness** — the operative message-structure rule.
- `magic-librarian/magic-librarian.armed.md` — this module's owner and the reference-module role generally.
- `reference/mcp.md` — the sibling protocol module; same axis, different protocol.
