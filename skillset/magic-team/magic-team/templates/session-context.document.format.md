---
maintainers: [magic-coordinator, magic-librarian, keeper-myx, human-owner]
---
# session-context document — `# Session Sweep Report` format

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the shape of a **generated** document, produced by tooling
and read by a session at its start. Nothing writes it by hand. The producing operation is internal
tooling; a session never calls it directly, only through its own routine's/member's own stub, and
each stub passes exactly the scopes its own invocation place needs.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
- Rules
- Recorded gaps
- Contract

# Summary

One document carrying everything a session needs to start: what was asked for, what arrived over
comms since it last looked, the member's own live inbox, and the board rows that concern it.

## Goals

- A reader can tell, for every scope, whether it was **declined**, **neither requested nor declined**,
  **requested and empty**, or **requested and impossible to check** — never guess between them. A
  declined scope has no section at all; each of the other three says which it is.
- Shell-readable, human-readable and agent-readable at once: stable headings, one item per block,
  `key: value` lines, blank line between blocks.

## Scope

- Does:
  - State its own generated-for identity and the exact scopes requested.
  - Carry comms, inbox and board sections, each capped and each self-describing.
- Doesn't:
  - Restructure board rows. The board section keeps the per-item shape the existing
    `--*-input-scan` documents already emit — it is inserted into this structure, not rewritten.
  - Imply a scan happened. A scope that was requested but could not be scanned says so, per scope,
    never once for the whole run; a scope that was neither requested nor declined says that instead.

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
**NOTE:** not requested                           <- when neither requested nor declined
**NOTE:** no scan was made -- <reason>            <- when asked for but not performable

<- a DECLINED scope emits no section at all: no heading, and no **NOTE:** line.

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
  found nothing), *not requested* (nobody asked and nobody declined, so nothing looked), *no scan was
  made -- reason* (asked, could not look). Collapsing them loses the one distinction this document
  exists to preserve.
- rule: **Every scope is in one of three states, and no two of them render alike.** A scope is
  requested, declined, or neither. Requested produces the section. Declined produces no section at
  all — no heading, no `**NOTE:**` line. Neither produces the heading and `**NOTE:** not requested`,
  and nothing beside it. `**NOTE:** not requested` therefore reports the request and never the tree:
  the run stated nothing about that section, which is not the same as that section being empty.
- rule: **Requesting is per breadth, declining is per section.** A scope offering two breadths is
  requested at exactly one of them, one breadth per run, and passing both is an error rather than a
  union. Its decline names the section alone — one decline per section, never one per breadth.
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
  keeps its no-cap rule — board bodies were not asked for, and `--member-board-item-read` already
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

# Contract

Not a contract — the shape of a **generated** document, produced by tooling and read by a session at its start. Nothing writes it by hand. No session calls the producing operation directly. Each routine or member invokes its own stub, and each stub requests exactly the scopes its own invocation place needs.

- `# Session Sweep Report`
  - `## Contents & Abstract` — `generated-for`, `generated-at`, the scopes actually requested, and the comms cut-off in force. Scopes are named as this document names its own sections, never as tooling option spellings. Where no cut-off was set, it says so.
- `# New Incoming Communications`
  - Carries `**NOTE:** no new incoming communications` only when every requested comms sub-section is empty.
  - `## Incoming IM Updates` (cap 128), `## Incoming Email Updates` (cap 128), `## Incoming Trello Updates` (cap 64).
- Four inbox sections:
  - `## Active Inbox Inquiry Items` (`inquiry-*`)
  - `## Current Inbox Reflections` (`reflection-*`)
  - `## Current Inbox Notes` (`note-*`)
  - `## Other Inbox Items` — every inbox item whose prefix is none of those three
- All four alike: cap 64 items, oldest first by file modification time, a `scope:` line first, and item bodies per the body-framing rule below.
- The fourth section exists because without it the other three silently drop everything else an inbox turns out to hold. It carries two different things at once, and they are not read alike:
  - a legitimate `warning-*`. That is an inbox type, one of `magic-team.armed.md`'s four, but it has no section of its own here.
  - a board-type document — `task-*`, `proposal-*`, `change-*`, `interview-*` and the rest. It does not belong in an inbox at all, and it is misfiled.
- Whether this section is kept as is, removed, or repurposed as a misfiling report is an open human-owner decision, not settled here.
- **The inbox window advances only from oldest toward newest, and an item leaves it by being moved to `processed/`**. No inbox pointer is stored anywhere. The live root's own oldest edge is the pointer. It is materialised as the difference between what is filed and what has been drained.
- **Handled means moved, never edited in place**. The sort key is modification time. Any write that leaves an item where it is makes it the newest item in the inbox — an in-place edit, a header change. Such a write buries it behind the far edge, beyond the cap's reach. Draining does not reorder the live root. The drained item leaves the root rather than moving within it. The processed copy carries the drain time. A scope reading `processed/` too therefore sorts recently drained items to the newest edge, the end an oldest-first cap cuts first.
- `## Board Items` — inserted into this structure keeping the existing `--*-input-scan` per-item shape (`## <state>/<item-filename>` then its frontmatter). Never restructured, and **never capped**: the board is the work list, and silently dropping part of it is the failure this document exists to prevent.
- **Six requestable scopes feed the inbox and board sections** — two mutually exclusive pairs and two singles. Inbox inquiry items: the active ones, or the active ones plus collected ones. Inbox reflections. Inbox notes. Board items related to the member: the active states, or every state. A pair's two breadths are mutually exclusive — one breadth per run, never both.
- **Each of those four sections states its own `scope:` as its first line** — before any item block and before any `**NOTE:**`, extending the same per-section metadata convention the comms sub-sections already carry with `identity:`/`instrument:`/`sources-scanned:`. Present whenever the scope was requested, on empty and non-empty sections alike, exactly as `identity:` is. The heading names the section, `scope:` names the run — which is what lets two runs under the same heading tell themselves apart, and is why the heading set stays fixed rather than growing a variant per breadth.
- Four exact `scope:` forms, one per breadth. They are strings this document emits, describing what was read; no member constructs or resolves them, and item lookup still goes through the operations that own it:
  - `scope: inboxes/<member>/*.md -- top level only, excluding processed/` — the reflections, notes and other-items sections always, and the inquiry section at its narrower breadth.
  - `scope: inboxes/<member>/*.md -- top level plus processed/` — the inquiry section at its wider breadth.
  - `scope: board/<state>/*.md -- backlog|pending|running|blocked|parked, <type filter>, owner: <member>` — the board section at its narrower breadth.
  - `scope: board/<state>/*.md -- backlog|pending|running|blocked|parked|processed|archived|retained, <type filter>, owner: <member>` — the board section at its wider breadth.
  - The board form carries a **type filter** between its state list and its owner, because the board section is the one that can be filtered by board-item type: `all types` when none was applied, otherwise the prefixes that were. The two inbox forms carry no type filter — each inbox section already *is* its type. `owner: any owner` where no owner filter applied.
- **The wider inbox breadth is live plus not-yet-collected `processed/`, never complete history.** `processed/` is garbage-collected on a retention threshold that varies by document type, so what it still holds when the document is generated is what that section reports. A reader must not treat it as an archive.
- **Relatedness is `owner:` alone.** `participants:` and `restart-session:` are deliberately not consulted: an item naming a member is not thereby that member's work, and widening relatedness to them would return items nobody has been assigned.
- **Every scope is in one of three states, and no two of them render alike.** A scope is requested, declined, or neither. A requested scope produces its section. A declined scope produces no section at all — no heading, no `**NOTE:**` line. A scope that was neither requested nor declined produces its heading and `**NOTE:** not requested`, and nothing beside it.
- **`**NOTE:** not requested` reports the request, never the tree.** It says the run stated nothing about that section — neither asking for it nor excluding it — so a reader takes it as an incomplete request and never as an absence of content.
- **Requesting is per breadth, declining is per section.** A scope offering two breadths is requested at exactly one of them, one breadth per run. Its decline names the section alone — one decline per section, never one per breadth.
- **`# New Incoming Communications` is emitted whenever any of its three comms sub-sections is emitted**, and carries `**NOTE:** not requested` when none of the three was requested. With all three declined the heading goes with them.
- Every emitted section carries items or a `**NOTE:**` line, and never neither. `**NOTE:**` covers two distinct kinds, and which kind it is decides what the section may carry alongside it:
  - **Status forms** — `no new X`, `not requested`, `no scan was made`. Mutually exclusive, exactly one, and only ever *instead of* items.
  - **Annotation marks** — `partial`, `truncated`. They accompany items, and may co-occur with each other: a section can be over its cap and missing a source at the same time.
- Three distinct `**NOTE:**` forms, never interchangeable: *no new X* (looked, found nothing), *not requested* (nobody asked and nobody declined, so nothing looked) and *no scan was made* (asked, could not look). That distinction is the document's own reason to exist: an empty result, an unstated request and an unperformed scan must never read alike.
- **Form 1 always carries a denominator and its filter** — `no new X -- scanned <N> items, <M> matched <filter>`. It is the only form asserting a fact about the world rather than about the process, so it is the only one that can be wrong while looking right. Without the denominator, a broken filter and an empty tree render identically. An owner-extraction defect matching none of a full board's items reads exactly like a truthful "no board items".
- A section with plural sources carries `sources-scanned: <N> of <M>`. Where `N < M` it also carries a `**NOTE:** partial -- <source> not scanned, <reason>` beside its items. A populated section must still be able to report that something underneath it failed.
- The aggregate `no new incoming communications` fires only when every requested comms sub-section is **empty and successfully scanned**. An unscannable sub-section is unknown, not empty, and blocks it.
- Each comms sub-section states its own `identity:` before its `instrument:`. `identity:` names the account that sub-section was read through, and the member whose config supplied the credentials. Identifiers only: a Slack user id, an email address, a Trello username and id. Credential values never appear in the document.
- Each comms sub-section states its own `instrument:`. The services differ. Slack takes a cut-off and has no unread flag. Email and Trello have unread and take no cut-off. A single global cut-off line therefore cannot describe what was actually used.
- Every item block states its type name and id on its heading line.
- **Item bodies, inbox sections only, framed by a declared line count and no delimiter**. No delimiter can work. Every fence or sentinel is a string a body may legally contain. Each inbox item block runs `## inbox/<filename>` first. Then its frontmatter `key: value` lines, verbatim. Then `body-truncated:` where it applies. Then `body-final-newline: absent` where it applies. Then `body-lines: <N>`. Then exactly `N` lines. Then one blank line, then the next `##` or EOF.
  - `body-lines:` is **the last key before the body** — a reader stops treating lines as headers there. `body-lines: 0` when there is no body.
  - **An item that is zero bytes still gets a block**. It has no frontmatter and no body, so nothing about it would otherwise be emitted. Meanwhile the section's `scanned`/`matched` counts still include it. The document then asserts an item it never shows. That is the one false-completeness failure a reader cannot detect, because the counts agree with themselves. The block is emitted in that item's own position. It carries exactly: `item-empty: 0 bytes stored -- no frontmatter and no body; an interrupted write leaves exactly this`, then `body-lines: 0`.
  - `item-empty:` is what distinguishes an empty item from one that legitimately has frontmatter and no body. The two must never read alike. It keeps `body-lines:` rather than omitting it. Every block therefore still ends with the same last key, and a reader still consumes `N` lines and expects `##` or EOF. The mark distinguishes without costing the frame its uniformity.
  - `body-lines:` states the lines **actually emitted**, and those lines are byte-identical to the corresponding prefix of storage. Where no body was cut, that prefix is the whole body.
  - `body-final-newline: absent` appears only when the body was emitted **whole** and storage did not end in a newline. It sits immediately before `body-lines:`, so that `body-lines:` stays last. The emitter supplies the missing newline. Nothing else is added or removed. A cut body never carries it. A body that did not reach its own last byte says nothing about how storage ended, and asserting it would be a claim the emitter cannot make.
  - A count rather than a delimiter is what makes the body byte-exact and the framing self-checking. After `N` lines a reader must find `##` or EOF. Where it does not, the document is corrupt and can say so.
  - The board section keeps frontmatter only, and keeps its no-cap rule. Board bodies are not carried here — `--member-board-item-read` already returns one.
- **Wherever anything is cut, the document says so at the point it was cut**. That is a rule of the whole document, not a feature of one section. Two forms exist, never a fresh one. Each states *what* was cut and *how much*, never merely that something was:
  - **Section-level mark**, when the item *count* is cut. Base form, for the email and Trello sections, emitted exactly: `**NOTE:** truncated -- <N> items found, capped at <M>`
  - Inbox form, for all four inbox sections, emitted exactly: `**NOTE:** truncated -- <N> items found, capped at <M> -- OLDEST kept, newest not shown`
  - The inbox form names the end it kept, because a count alone does not say which items are out of reach.
  - IM superset, for `## Incoming IM Updates` only: the same counts, then the dropped-conversation list, then that this is a display cap and not an unread source. That clause exists because the IM cap counts conversations, and a dropped conversation is not an unread source.
  - The `**NOTE:** ` prefix is part of every section-level form. A form quoted without it is a different string.
  - **Per-item mark**, when a *body* is cut at the 8192-byte cap. Emitted exactly, as a header key inside the item's own frame: `body-truncated: <T> bytes stored, capped at 8192 -- <N> of <M> lines emitted`. `<T>` is the body's full stored size in bytes. `<N>` is the lines emitted, the same number `body-lines:` carries. `<M>` is the lines the body has in storage.
  - It is a key, not a `**NOTE:**`, and it sits before `body-final-newline:`/`body-lines:`. The reason is that `body-lines:` must stay the last key before the body. A mark placed after `body-lines:` would be counted as a body line. A `**NOTE:**` placed before it would break the `key: value` grammar the block is parsed with.
  - **The per-item mark is not stylistic and cannot be omitted**. `body-lines:` is a count a reader consumes literally. A body cut without the mark still yields a count that no longer describes the whole stored body. A reader that consumes `N` lines and finds neither `##` nor EOF has walked into the next block. A cut without its mark is a corrupt document, not a terse one.
  - Both marks are required, and they are independent. A section can be over its item cap while one of the items it did carry also had its body cut.
  - **Where the 8192-byte cut falls**: at the last line boundary at or before 8192 bytes. Whole lines only, so no multi-byte character is ever split. Where a single line exceeds the cap on its own, no lines are emitted: `body-lines: 0`, with the mark stating `0 of <M> lines emitted`. That is a truthful empty body and not a silent one. The reader is told the size and goes to the item.
- **A string this document emits is code: every emitted string uses ASCII `--`, never an em dash**. It governs every `scope:`, `**NOTE:**`, `identity:`, `instrument:` and `sources-scanned:` line quoted here or in the skeleton. Reproduce those characters exactly, and do not compose one at the point of use. Contract prose around them is unconstrained and is not touched by this rule.
- **`## Board Items` carries a `scope:` line whenever it has content**, stating the states walked, the type filter, and the owner filter or that any owner matched. It never carries a cap line and never carries a `truncated` mark, because it is uncapped. A section that walked the board and declared nothing is the failure this rule closes.
- Shell-readable, human-readable and agent-readable at once: stable headings, one item per block, `key: value` lines, blank line between blocks.
- The inbox sections carry **every** inbox item: `inquiry-*`, `reflection-*` and `note-*` in their own three sections, and everything else in `## Other Inbox Items`. Reading the inbox whole is a property of this document, not a widening of what an inbox may hold. `magic-team.armed.md`'s restriction stands. A member's own inbox holds `note-*`, `inquiry-*`, `reflection-*` and `warning-*` only, and a board-type document found in one is misfiled. This document reports what is actually in an inbox rather than only what belongs there. That is also what makes `magic-team.process-inbox.routine`'s own non-enumerating job actually reachable from it.
- Recorded gaps live in this file's `# Recorded gaps`, stated rather than solved. Two of them: `assignee` not existing in the entity model, and the uneven per-service cut-off support that makes lagging pointers the sanctioned mechanism.
- **A routine's own input scan wraps this document in sections of its own, and they are part of what its session reads.** The heartbeat scan emits, in order:
  - `## state-and-lock (routine-heartbeat)` — the routine's lock note, frontmatter then its prose.
  - `## questions (pending replies)` — optionally a `Last collect by the main loop:` block first, then the line `Every question still open:`, then one blank-separated record per open question and a closing `PENDING-REPLIES: <count>`. Each record opens `PENDING-REPLY: <id>`, then `key: value` lines: `status`, `owner`, `kind`, `question-tag` (only on a tagged question), `channel`, `question-ts`, `thread-ts`, `address-to`, `session-id`, `asked-at`, then `question:` with the question's first line. Closed questions are not listed. Where the list cannot be read, the section carries `(the open questions could not be read)`.
  - `## board digest` — this document's own sections, at the scopes the heartbeat requests.
- The advance scan emits `## state-and-lock (routine-advance)`, then `## board digest`, then three registry sections, in order. Each opens with a `registry: <path> -- rebuilt by this scan` line and a `columns:` line, then one whitespace-separated row per record, with `-` for a missing value:
  - `## team members` — columns `member workspace link-kind skillset-path`.
  - `## spawned sessions` — adds a `this-host:` line; columns `tracking-name session-id parent-session-id host owner status exit-code live`. `live` is measured during the scan, never stored, and measurable only for rows this machine owns. A fixed paragraph after the rows says to compare them with the board's `running/` items before acting on either. Where no spawn sandbox root exists, or the registry cannot be rebuilt, the section carries a `**NOTE:** no scan was made -- <reason>` instead.
  - `## pending replies` — columns `key source session-id owner status blocked-on communication-channel-id`. It lists closed records as well as open ones, unlike the heartbeat's `## questions (pending replies)`.
