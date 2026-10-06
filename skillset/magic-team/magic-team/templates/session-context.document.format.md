---
maintainers: [magic-coordinator, magic-librarian, keeper-myx, human-owner]
---
# session-context document — `# Session Sweep Report` format

Normative contract: this file's own `# Contract` section. Not a member or routine contract: the shape of a document the tooling generates and a session reads at its start. Nothing writes it by hand; each routine or member calls its own input-scan operation.

## Contents

- Summary
- Skeleton
- Contract

# Summary

Everything a session needs to start: what was requested, comms that arrived, the member's live inbox, and the board items it owns.

# Skeleton

```
# Session Sweep Report

## Contents & Abstract
generated-for: <team-member>
generated-at: <date-time>
requested-scopes: <scopes, or "none">
comms-cut-off: <cut-off, or "none -- per-service unread semantics used where available">

# New Incoming Communications
## Incoming IM Updates
## Incoming Email Updates
## Incoming Trello Updates

## Active Inbox Inquiry Items
## Current Inbox Reflections
## Current Inbox Notes
## Other Inbox Items

## Board Items
## <state>/<item-filename>
<frontmatter, no body>
```

# Contract

How to read it:

- **A section carries items, or exactly one status `**NOTE:**`, never neither:**
  - `**NOTE:** no new X -- scanned <N> items, <M> matched <filter>` — looked, found nothing.
  - `**NOTE:** not requested` — nobody asked for this section. It reports the request, never the content.
  - `**NOTE:** no scan was made -- <reason>` — asked, could not look. Unknown, not empty.
  - A declined scope has no section at all.
- `**NOTE:** no new incoming communications` appears only when every requested comms section was scanned and is empty.
- **Annotation marks** accompany items: `**NOTE:** partial -- <source> not scanned, <reason>` (with `sources-scanned: <N> of <M>`) and `**NOTE:** truncated -- …`. An inbox section's truncation keeps the oldest items; newer ones are not shown.
- Each comms section opens with `identity:` and `instrument:` lines saying how it was read; each inbox and board section opens with a `scope:` line.
- **Inbox item blocks** are `## inbox/<filename>`, frontmatter `key: value` lines, optional `body-truncated:` and `body-final-newline: absent`, then `body-lines: <N>` as the last key, then exactly `N` body lines, then a blank line. After `N` lines the next thing is `##` or end of file; anything else means the document is corrupt. A zero-byte item shows `item-empty:` and `body-lines: 0`. A truncated body says so in `body-truncated:`; read the item for the rest.
- Inbox sections are oldest first. `## Other Inbox Items` holds anything that is not `inquiry-*`, `reflection-*` or `note-*`: such an item is misfiled and is reported to `magic-coordinator`.
- The narrow inbox breadth leaves out items marked processed; the wider one adds them while not yet collected, so it is never complete history.
- **`## Board Items` is never capped or truncated.** It lists items whose `owner:` is the member, frontmatter only; `--member-board-item-read` returns a body.
- A routine's own input scan may wrap this document in sections of its own (state and lock, pending questions, registries). They are part of what that session reads.
- Emitted strings use ASCII `--`.
