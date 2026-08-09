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

- rule: Every section carries exactly one of: its items, or a single `**NOTE:**` line. Never both,
  never neither.
- rule: The three `**NOTE:**` forms are distinct and not interchangeable — *no new X* (looked,
  found nothing), *not requested* (never looked), *no scan was made* (asked, could not look).
  Collapsing them loses the one distinction this document exists to preserve.
- rule: `# New Incoming Communications` carries its own `**NOTE:** no new incoming communications`
  only when every requested comms sub-section is empty.
- rule: Every item block states its **type name and id** on its heading line.
- rule: Caps, applied after sorting: **128** IM, **128** email, **64** Trello, **32** each inbox
  section. A truncated section says so on its own line.
- rule: The board section has **no cap** and is never truncated — the board is the work list, and
  silently dropping part of a member's own work is the exact failure this document exists to
  prevent.
- rule: Inbox sections sort by file modification time, newest first.
- rule: Comms sections sort by **message timestamp**, newest first — comms items have no file
  modification time. (Recorded gap: the spec says "modification time" for all sections.)
- rule: The board section keeps the existing per-item format verbatim.

# Recorded gaps

Stated, deliberately not solved here. Each needs its own decision before it can be closed.

- gap: `assignee` does not exist in the entity model. `magic-team.armed.md` defines `owner` as
  "current assignee" — one field, not two; 0 of 256 board items carry `assignee:`. Board-related
  scopes match on `owner` alone, and the unnamed further fields in the spec's "`assignee`,
  `owner`, …" remain unnamed.
- gap: Four inbox document types have no section in this format — `task-`, `proposal-`, `change-`,
  `interview-`. They exist in real inboxes and are simply not carried.
- gap: Per-service cut-off support is uneven at the source: Slack accepts a cut-off but offers no
  unread semantics; email and Trello offer unread semantics but accept no cut-off. Where a service
  cannot take the cut-off directly, a lagging pointer is the sanctioned mechanism.
