# Messaging platforms — size limits, silent truncation, composition

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

## Contents

- Why a session reply does not reach the human-owner
- Why an ask leads its own message
- The core property: a response describes acceptance, not retention
- Measured behaviour (Slack, `chat.postMessage`)
- Consequences for composition
- Reading list

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
- **Structure comes from lists and tables, never from paragraphs.** Each paragraph becomes its own
  block and the blocks render with almost no vertical separation, so prose written as several
  paragraphs collapses into one unreadable run. Bullet lists and pipe tables become real list and
  table blocks; they are the only tools in the markdown path that carry visible structure, and a
  message that needs structure is written with them from the start.
- **An emoji reaches a message body as a real character, and a shortcode is not converted there.**
  `:name:` written into body text is delivered as those literal characters, and the send still
  reports success, so the fault is visible only to the reader. A reaction is the opposite case, and
  is why this gets confused: that call names the emoji by shortcode, because a name is what its own
  parameter takes. A shortcode in a reaction argument is correct and the same shortcode in a body is
  a defect. Neither is fixed by changing the other.
- **A markdown send parses CommonMark, not the platform's own native markup.** One delimiter is
  italic and two is bold, which inverts the convention on a platform whose native form makes a single
  delimiter bold — writing the native form there produces visibly wrong output that the send still
  reports as success. The grammar a send path actually parses is stated in that operation's own help
  pair, which is the thing to read before composing; a platform's public formatting guide describes
  the platform, not the path the message takes. Where the markdown grammar cannot express something,
  the raw block-structure format is the escape hatch.

## Reading list

- `magic-team/magic-team.conversations.md`'s **message-shape-is-correctness** — the operative message-structure rule.
- `magic-librarian/magic-librarian.armed.md` — this module's owner and the reference-module role generally.
- `reference/mcp.md` — the sibling protocol module; same axis, different protocol.
