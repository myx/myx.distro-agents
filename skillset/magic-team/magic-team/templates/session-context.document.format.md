---
maintainers: [magic-coordinator, magic-librarian, keeper-myx]
---
# session-context document — `# Session Sweep Report` format

Normative contract: `magic-team/magic-team.shared.md`'s "Session-context document" entry. This file is the
derived skeleton; where the two disagree, `magic-team/magic-team.shared.md` wins.

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
requested-scopes: <the scopes actually requested, named as this document names its own sections, space-separated, or "none">
comms-cut-off: <--comms-since-* kind and value, or "none — per-service unread semantics used where available">

# New Incoming Communications

**NOTE:** no new incoming communications          <- only when every requested comms scope is empty

## Incoming IM Updates

**NOTE:** no new incoming IM updates              <- when requested and empty
**NOTE:** not requested                           <- when the scope was not asked for
**NOTE:** no scan was made -- <reason>            <- when asked for but not performable

## <type-name> <id>
<key>: <value>
...

<- a slack-message item block additionally carries `identity: <user|bot>` when
   known -- see "Rules" below.

## Incoming Email Updates
## Incoming Trello Updates

## Active Inbox Inquiry Items
scope: inboxes/<member>/*.md -- top level only, excluding processed/

<- or "-- top level plus processed/" at the wider breadth. Always the section's
   first line, before any item block and before any **NOTE:**.

## inbox/<item-filename>
<key>: <value>
...
body-truncated: <T> bytes stored, capped at 8192 -- <N> of <M> lines emitted
body-final-newline: absent
body-lines: <N>
<exactly N lines, byte-identical to the corresponding prefix of storage>

<- then one blank line, then the next ## or EOF. body-lines: is the LAST key
   before the body, and states the lines ACTUALLY EMITTED.
   body-truncated: appears only when the body was cut at the 8192-byte cap.
   body-final-newline: absent appears only when the body was emitted WHOLE and
   storage did not end in a newline; a cut body never carries it.
   Both sit before body-lines:, in that order.

## inbox/<item-filename>
item-empty: 0 bytes stored -- no frontmatter and no body; an interrupted write leaves exactly this
body-lines: 0

<- a zero-byte item still gets a block, in its own position. item-empty:
   is what tells it apart from an item with frontmatter and no body.

## Current Inbox Reflections
scope: inboxes/<member>/*.md -- top level only, excluding processed/

## Current Inbox Notes
scope: inboxes/<member>/*.md -- top level only, excluding processed/

## Other Inbox Items
scope: inboxes/<member>/*.md -- top level only, excluding processed/

<- every inbox item whose prefix is none of inquiry-/reflection-/note-.

## Board Items
scope: board/<state>/*.md -- backlog|pending|running|blocked|parked, all types, owner: <member>

<- or the every-state list at the wider breadth:
   backlog|pending|running|blocked|parked|processed|archived|retained
   Present whenever this section has content. No cap line, no truncated mark.

## <state>/<item-filename>
<frontmatter, per the existing --*-input-scan per-item shape; no body>
```

# Rules

- rule: Every section carries items, or a `**NOTE:**` line, and never neither. `**NOTE:**` covers two
  distinct kinds, and which kind it is decides what may sit alongside it. **Status forms** — `no new X`,
  `not requested`, `no scan was made` — are mutually exclusive, exactly one, and appear only *instead
  of* items. **Annotation marks** — `partial`, `truncated` — accompany items, and may co-occur with
  each other: a section can be over its cap and missing a source at once.
- rule: The three status forms are distinct and not interchangeable — *no new X* (looked,
  found nothing), *not requested* (never looked), *no scan was made -- reason* (asked, could not
  look). Collapsing them loses the one distinction this document exists to preserve.
- rule: **A string this document emits is code. Every emitted string uses ASCII `--`, never an em
  dash.** It governs every `scope:`, `**NOTE:**`, `identity:`, `instrument:` and `sources-scanned:`
  line quoted in this file — reproduce those characters exactly and never compose one at the point of
  use. The prose around them is unconstrained and is not touched by this rule. Recorded because
  getting this wrong has already cost re-emitted sites more than once.
- rule: **Wherever anything is cut, the document says so at the point it was cut.** A rule of the whole
  document, not one section's feature. Two ratified forms, never a fresh one, each stating *what* was
  cut and *how much* rather than merely that something was. Base form, for the email and Trello
  sections, emitted exactly:
  `**NOTE:** truncated -- <N> items found, capped at <M>`. Inbox form, for all four inbox sections,
  emitted exactly:
  `**NOTE:** truncated -- <N> items found, capped at <M> -- OLDEST kept, newest not shown` — it names
  the end it kept, because a count alone does not say which items are out of reach. IM superset, for
  `## Incoming IM Updates`
  only: the same counts, then the dropped-conversation list, then that this is a display cap and not
  an unread source — that clause exists because the IM cap counts conversations, and a dropped
  conversation is not an unread source. The `**NOTE:** ` prefix is part of every form; a form quoted
  without it is a different string.
- rule: **Two distinct marks, both required, and independent of each other.** The section-level mark
  above fires when the item *count* is cut. A second, per-item mark fires when a *body* is cut at the
  8192-byte cap, emitted exactly, as a header key inside that item's own frame:
  `body-truncated: <T> bytes stored, capped at 8192 -- <N> of <M> lines emitted` — `<T>` the body's
  full stored size in bytes, `<N>` the lines emitted (the same number `body-lines:` carries), `<M>`
  the lines the body has in storage.
  A section can be over its item cap while an item it did carry also had its body cut; each mark is
  reported where it happened.
- rule: The per-item mark is a key, not a `**NOTE:**`, and sits before `body-final-newline:` and
  `body-lines:`. **It cannot be omitted.** `body-lines:` is a count a reader consumes literally: a body
  cut without the mark yields a count that no longer describes the whole stored body, and a reader
  that consumes `N` lines and finds neither `##` nor EOF has walked into the next block. A cut without
  its mark is a corrupt document, not a terse one. A mark placed *after* `body-lines:` would be counted
  as a body line; a `**NOTE:**` placed before it would break the `key: value` grammar the block is
  parsed with.
- rule: The 8192-byte cut falls at the last line boundary at or before 8192 bytes — whole lines only,
  so no multi-byte character is ever split. Where a single line exceeds the cap on its own, no lines
  are emitted: `body-lines: 0`, with the mark stating `0 of <M> lines emitted`. That is a truthful
  empty body and not a silent one; the reader is told the size and goes to the item.
- rule: **Inbox item bodies are framed by a declared line count, with no delimiter.** No delimiter can
  work — every fence or sentinel is a string a body may legally contain. Each inbox item block runs
  `## inbox/<filename>`, its frontmatter `key: value` lines verbatim, `body-truncated:` where it
  applies, `body-final-newline: absent`
  where it applies, `body-lines: <N>`, then exactly `N` lines, then one
  blank line, then the next `##` or EOF. `body-lines:` is the **last key before the body** — a reader
  stops treating lines as headers there — and is `body-lines: 0` when there is no body.
- rule: **A zero-byte item still gets a block**, emitted in its own position, carrying exactly
  `item-empty: 0 bytes stored -- no frontmatter and no body; an interrupted write leaves exactly this`
  then `body-lines: 0`. Without it the item produces no block at all while the section's
  `scanned`/`matched` counts still include it — the document asserts an item it never shows, which is
  the one false-completeness failure a reader cannot detect, because the counts agree with themselves.
  `item-empty:` is what keeps it distinguishable from an item that legitimately has frontmatter and no
  body; the two must never read alike. It retains `body-lines:` rather than omitting it, so every block
  still ends with the same last key and a reader still consumes `N` lines and then expects `##` or EOF.
  `body-lines:` states the lines **actually emitted**, and those lines are byte-identical to the
  corresponding prefix of storage; where no body was cut, that prefix is the whole body.
  `body-final-newline: absent` appears only when the body was emitted **whole** and storage did not end
  in a newline, and sits
  immediately before `body-lines:` so that `body-lines:` stays last; the emitter supplies the missing
  newline and nothing else is added or removed. A cut body never carries it — a body that did not reach
  its own last byte says nothing about how storage ended. A count rather than a delimiter is what makes the body
  byte-exact and the framing self-checking: after `N` lines a reader must find `##` or EOF, and if it
  does not, the document is corrupt and can say so. It also stays line-oriented, so `awk`/`grep` still
  work.
- rule: Bodies are carried for **inbox items only**. The board section keeps frontmatter alone and
  keeps its no-cap rule — board bodies were not asked for, and `--member-read-board-item` already
  returns one.
- rule: There are **four** inbox sections, not three: `## Active Inbox Inquiry Items` (`inquiry-*`),
  `## Current Inbox Reflections` (`reflection-*`), `## Current Inbox Notes` (`note-*`), and
  `## Other Inbox Items` — every inbox item whose prefix is none of those three. All four alike: cap
  64 items, oldest first by file modification time, `scope:` line first, bodies framed as
  above and each body itself capped at 8192 bytes.
- rule: `## Board Items` carries its `scope:` line whenever it has content, stating the states walked,
  the type filter, and the owner filter or that any owner matched. It never carries a cap line and
  never carries a `truncated` mark, because it is uncapped. A board walk that declares nothing is the
  failure this rule closes.
- rule: **Form 1 never appears without a denominator and the filter that produced it**:
  `**NOTE:** no new X -- scanned <N> items, <M> matched <filter>`. Of the three forms it is the
  only one asserting a fact about the *world* rather than about the process, so it is the only one
  that can be wrong while looking right. A zero over a zero denominator and a zero over 256 are
  different facts, and only the second is evidence about the tree. Without this, a broken filter
  and an empty tree render identically — which is exactly how the `--owner` extraction defect
  (0 of 256 items, every board scope silently empty) would have read as a truthful "no board
  items".
- rule: A section whose sources are plural carries `sources-scanned: <N> of <M>`. When `N < M` it
  also carries `**NOTE:** partial -- <source> not scanned, <reason>` alongside its items. A section
  that has items must still be able to report that something underneath it failed; otherwise a
  populated section reads as complete no matter how many sources errored.
- rule: The inbox and board sections each open with their own `scope:` line — the section's **first**
  line, before any item block and before any `**NOTE:**`. Same per-section metadata convention the
  comms sub-sections carry with `identity:`/`instrument:`/`sources-scanned:`, extended to the four
  sections that had none. Present whenever that scope was requested, on empty and non-empty sections
  alike, exactly as `identity:` is; a section carrying `**NOTE:** not requested` has no `scope:` line.
  The heading names the section, `scope:` names the run — which is what lets two runs under the same
  heading tell themselves apart, and is why the heading set stays fixed rather than growing a variant
  per breadth.
- rule: Four exact `scope:` forms, one per breadth, and no others:
  `scope: inboxes/<member>/*.md -- top level only, excluding processed/` (reflections, notes and other
  items always, inquiry at its narrower breadth); `scope: inboxes/<member>/*.md -- top level plus
  processed/` (inquiry at its wider breadth); `scope: board/<state>/*.md -- backlog|pending|running|blocked|parked,
  <type filter>, owner: <member>` (board, narrower); and the same board form listing every state
  `backlog|pending|running|blocked|parked|processed|archived|retained` (board, wider). The board form
  alone carries a type filter between its states and its owner — `all types` when none was applied,
  otherwise the prefixes that were; `owner: any owner` where no owner filter applied. The inbox forms
  carry none, because each inbox section already is its type. These are
  strings this document emits, describing what was read — no member constructs or resolves them, and
  item lookup still goes through the operations that own it.
- rule: Six requestable scopes feed these four sections — two mutually exclusive pairs and two
  singles. Inbox inquiry items (active, or active plus collected); inbox reflections; inbox notes;
  board items related to the member (active states, or every state). A pair's two breadths are
  mutually exclusive: one breadth per run, never both.
- rule: The wider inbox breadth is live **plus not-yet-collected** `processed/`, never complete
  history. `processed/` is garbage-collected on a retention threshold that varies by document type,
  so what it still holds when the document is generated is what that section reports. It is not an
  archive and must not be read as one.
- rule: Relatedness is `owner:` alone. `participants:` and `restart-session:` are deliberately not
  consulted — an item naming a member is not thereby that member's work, and widening relatedness to
  them would return items nobody has been assigned.
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
  message — **128** email, **64** Trello, **64** each inbox section, and **8192 bytes** per inbox item
  body. A truncated section says so on
  its own line, naming every dropped conversation and its message count, and stating the cap as a
  display limit, not a source of unread state.
- rule: The board section has **no cap** and is never truncated — the board is the work list, and
  silently dropping part of a member's own work is the exact failure this document exists to
  prevent.
- rule: Inbox sections sort by file modification time, **oldest first**. The window advances only from
  oldest toward newest, and an item leaves it by being moved to `processed/`. No inbox pointer is
  stored anywhere: the live root's own oldest edge is the pointer, materialised as the difference
  between what is filed and what has been drained.
- rule: **Handled means moved, never edited in place.** The sort key is modification time, so any write
  that leaves an item where it is — an in-place edit, a header change — makes it the newest item in the
  inbox and buries it behind the far edge, beyond the cap's reach. Draining does not reorder the live
  root: the drained item leaves it rather than moving within it. The processed copy carries the drain
  time, so a scope reading `processed/` too sorts recently drained items to the newest edge — the end
  an oldest-first cap cuts first.
- rule: Comms sections sort by **message timestamp**, newest first — comms items have no file
  modification time. (Recorded gap: the spec says "modification time" for all sections.)
- rule: IM is the carve-out, and it is two stages: the cap **selects** the newest **N**
  conversations, ranked by each conversation's own newest message; the document then **renders**
  them oldest-first, with messages oldest-first inside each conversation and no message-level merge
  across conversations. Email and Trello follow the rule above unchanged.
- rule: The board section keeps the existing per-item format verbatim.

# Recorded gaps

Stated, deliberately not solved here. Each needs its own decision before it can be closed.

- gap: `assignee` does not exist in the entity model. `magic-team/magic-team.armed.md` defines `owner` as
  "current assignee" — one field, not two; 0 of 256 board items carry `assignee:`. Board-related
  scopes match on `owner` alone, and the unnamed further fields in the spec's "`assignee`,
  `owner`, …" remain unnamed.
- rule (design, not a gap): The inbox sections carry `note-*`, `inquiry-*` and `reflection-*` only.
  Other document types — `task-`, `proposal-`, `change-`, `interview-` — are **technically allowed
  in an inbox** and are not misfiled; they are simply not carried here, because no step stores them
  there or takes them from there. The sections cover what steps store. `magic-team.process-inbox.routine` is
  the one consumer that does not enumerate types, since its job is whatever actually landed.
- gap: Per-service cut-off support is uneven at the source: Slack accepts a cut-off but offers no
  unread semantics; email and Trello offer unread semantics but accept no cut-off. Where a service
  cannot take the cut-off directly, a lagging pointer is the sanctioned mechanism.
