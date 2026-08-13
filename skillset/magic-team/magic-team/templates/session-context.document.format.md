---
maintainers: [magic-coordinator, magic-librarian, keeper-myx]
---
# session-context document — `# Session Sweep Report` format

Normative contract: `magic-team.shared.md`'s "Session-context document" entry. This file is the
derived skeleton; where the two disagree, `magic-team.shared.md` wins.

Not a member/routine contract — this is the shape of a **generated** document, produced by tooling
and read by a session at its start. Nothing writes it by hand. The producing operation is internal
tooling; a session never calls it directly, only through its own routine's/member's own stub, and
each stub passes exactly the scopes its own invocation place needs.

# Summary

One document carrying everything a session needs to start: what was asked for, what arrived over
comms since it last looked, the member's own live inbox, and the board rows that concern it.

## Goals

- A reader can tell, for every scope, whether it was **not requested**, **requested and empty**, or
  **requested and impossible to check** — never guess between them.
- Shell-readable, human-readable and agent-readable at once: stable headings, one item per block,
  `key: value` lines, blank line between blocks.

## Scope

- Does:
  - State its own generated-for identity and the exact scopes requested.
  - Carry comms, inbox and board sections, each capped and each self-describing.
- Doesn't:
  - Restructure board rows. The board section keeps the per-item shape the existing
    `--*-input-scan` documents already emit — it is inserted into this structure, not rewritten.
  - Imply a scan happened. A scope that was not requested says so; a scope that could not be
    scanned says so, per scope, never once for the whole run.

# Skeleton

```
# Session Sweep Report

## Contents & Abstract

generated-for: <team-member>
generated-at: <date-time>
requested-scopes: <the scopes actually requested, space-separated, or "none">
comms-cut-off: <--comms-since-* kind and value, or "none — per-service unread semantics used where available">

# New Incoming Communications

**NOTE:** no new incoming communications          <- only when every requested comms scope is empty

## Incoming IM Updates

**NOTE:** no new incoming IM updates              <- when requested and empty
**NOTE:** not requested                           <- when the scope was not asked for
**NOTE:** no scan was made — <reason>             <- when asked for but not performable

## <type-name> <id>
<key>: <value>
...

<- a slack-message item block additionally carries `identity: <user|bot>` when
   known -- see "Rules" below.

## Incoming Email Updates
## Incoming Trello Updates

## Active Inbox Inquiry Items
## Current Inbox Reflections
## Current Inbox Notes

## Board Items
## <state>/<item-filename>
<frontmatter, per the existing --*-input-scan per-item shape>
```

# Rules

- rule: Every section carries its items, or a single `**NOTE:**` line, and never neither. The one
  permitted combination is items **plus** a `**NOTE:** partial — …` line (below); nothing else
  carries both.
- rule: The three `**NOTE:**` forms are distinct and not interchangeable — *no new X* (looked,
  found nothing), *not requested* (never looked), *no scan was made — reason* (asked, could not
  look). Collapsing them loses the one distinction this document exists to preserve.
- rule: **Form 1 never appears without a denominator and the filter that produced it**:
  `**NOTE:** no new X — scanned <N> items, <M> matched <filter>`. Of the three forms it is the
  only one asserting a fact about the *world* rather than about the process, so it is the only one
  that can be wrong while looking right. A zero over a zero denominator and a zero over 256 are
  different facts, and only the second is evidence about the tree. Without this, a broken filter
  and an empty tree render identically — which is exactly how the `--owner` extraction defect
  (0 of 256 items, every board scope silently empty) would have read as a truthful "no board
  items".
- rule: A section whose sources are plural carries `sources-scanned: <N> of <M>`. When `N < M` it
  also carries `**NOTE:** partial — <source> not scanned, <reason>` alongside its items. A section
  that has items must still be able to report that something underneath it failed; otherwise a
  populated section reads as complete no matter how many sources errored.
- rule: `# New Incoming Communications` carries its own `**NOTE:** no new incoming communications`
  only when every requested comms sub-section is **empty and successfully scanned**. A sub-section
  that could not be scanned is unknown, not empty, and blocks the aggregate note outright — the
  parent must never assert emptiness over a scope nobody successfully read.
- rule: Each comms sub-section opens with its own `identity:` line, before `instrument:` — the
  account that sub-section was read through, and the member whose config supplied the credentials:
  `identity: slack <user-id> (config: <member>)`, `identity: email <address> (config: <member>)`,
  `identity: trello @<username> / <id> (config: <member>)`. An absent value is stated, never an
  error — `<unresolved>`, or `<not configured>` for email. A sub-section carrying
  `**NOTE:** not requested` has no `identity:` line.
- rule: `identity:` carries **identifiers only** — a Slack user id, an email address, a Trello
  username and id. Credential values (tokens, passwords, keys) never appear in it, and this is the
  only line in this document that names an account at all.
- rule: Each comms sub-section states its own instrument, because the services differ:
  `instrument: cut-off <kind> <value>` or `instrument: unread-semantics (<service mechanism>)`.
  The global `comms-cut-off:` in `## Contents & Abstract` records what was *requested*; it cannot
  describe what was actually used, since Slack takes a cut-off and offers no unread flag while
  email and Trello offer unread and take no cut-off. Stated once at the top, form 1 would be
  ambiguous across exactly the services it reports on.
- rule: Every item block states its **type name and id** on its heading line.
- rule: A `slack-message` item block additionally carries `identity: <user|bot>` right after
  `channel:` — **optional**, present only when the leg it came from is known to be one identity or
  the other (a human-owner fan-out read's own per-leg marker), absent otherwise. Not the same line
  as a comms sub-section's own `identity:` (the account a sub-section was read *through* — see the
  rule above); this one names which identity the message was originally found under. Diagnostic
  only — `reply-if-warranted` never needs to read or pass it: `--member-comms-slack-send-message`
  resolves the correct identity internally on its own.
- rule: Caps: **128** IM conversations — a thread, a channel or a DM is **one** unit, not one
  message — **128** email, **64** Trello, **32** each inbox section. A truncated section says so on
  its own line, naming every dropped conversation and its message count, and stating the cap as a
  display limit, not a source of unread state.
- rule: The board section has **no cap** and is never truncated — the board is the work list, and
  silently dropping part of a member's own work is the exact failure this document exists to
  prevent.
- rule: Inbox sections sort by file modification time, newest first.
- rule: Comms sections sort by **message timestamp**, newest first — comms items have no file
  modification time. (Recorded gap: the spec says "modification time" for all sections.)
- rule: IM is the carve-out, and it is two stages: the cap **selects** the newest **N**
  conversations, ranked by each conversation's own newest message; the document then **renders**
  them oldest-first, with messages oldest-first inside each conversation and no message-level merge
  across conversations. Email and Trello follow the rule above unchanged.
- rule: The board section keeps the existing per-item format verbatim.

# Recorded gaps

Stated, deliberately not solved here. Each needs its own decision before it can be closed.

- gap: `assignee` does not exist in the entity model. `magic-team.armed.md` defines `owner` as
  "current assignee" — one field, not two; 0 of 256 board items carry `assignee:`. Board-related
  scopes match on `owner` alone, and the unnamed further fields in the spec's "`assignee`,
  `owner`, …" remain unnamed.
- rule (design, not a gap): The inbox sections carry `note-*`, `inquiry-*` and `reflection-*` only.
  Other document types — `task-`, `proposal-`, `change-`, `interview-` — are **technically allowed
  in an inbox** and are not misfiled; they are simply not carried here, because no step stores them
  there or takes them from there. The sections cover what steps store. `routine-process-inbox` is
  the one consumer that does not enumerate types, since its job is whatever actually landed.
- gap: Per-service cut-off support is uneven at the source: Slack accepts a cut-off but offers no
  unread semantics; email and Trello offer unread semantics but accept no cut-off. Where a service
  cannot take the cut-off directly, a lagging pointer is the sanctioned mechanism.
