---
maintainers: magic-librarian, magic-coordinator
---
# Board

The team's current-work index — a shared, cross-workspace, cross-day status source every routine reads/writes, with a concrete `board-item`/folder shape. See `magic-team.armed.md`'s "Board & Inbox board-items entity model" section for the `board-item` entity model this operates on.

This file's own content is binding and obligatory on every team member who reads it — not merely informational or reference material.

**Ownership**:
- `magic-coordinator` reads/modifies this continuously, on its own authority — its own active work tool (think: a PM's own Jira board).
- `magic-librarian` joins once per workday, jointly, under `magic-coordinator`'s lead — not an independent pass. See `magic-librarian.morning-review.routine` for what that session actually does.

**`magic-coordinator`'s write authority is exclusive over the board — full stop.** Same structural shape as the "sole mandated channel to the human-owner" rule (`magic-coordinator/magic-coordinator.armed.md`'s Local rules). Covers:
- Creating a `board-item`.
- Moving one between states: `board-running`, `board-blocked`, `board-parked`, `board-processed`, `board-archived`, `board-retained`.
- Scoring one (RICE).
- This file itself.

**A routine is not a second authority.** `magic-team.grooming.routine` and `magic-coordinator.advance.routine` declaring `--magic-*-to-*` ops is `magic-coordinator` acting under that routine's overridden rules — the routine scopes what the executor does, it never grants board-write authority of its own. Nothing gains that authority by being run under a routine, and no member gains it by being dispatched into one.

**Every other member contributes through the session document, not the board.** `magic-coordinator` creates it, typically before spawning. Members edit it where their own routine instructions dictate — that is how work reaches tracked state without a second writer touching the board. The document is the same tracking document that carries the item's `participants` record. Which document types allow which edits, and by whom, is to be settled — not yet defined.

**The board does not include inboxes.** Each member's personal inbox lives separately — not nested here. See `magic-team.process-inbox.routine` for the full model (location, write-access, non-acting-owner handling, Slack visibility, the main-loop nudge, the morning self-review pattern).

This file itself stays thin: a rollup pointing into `board/`'s folders, not where substance lives. Substance lives in the individual `board-item` files.

## States

- **`triage` is a process, not a folder** — not board-only.
  - Trigger: something in a member's own inbox (see `magic-team.process-inbox.routine`) needs to become a real, formally-tracked `board-item`.
  - Performed by: the three-person authority group (`magic-coordinator` + `magic-librarian` + `magic-architect`) during grooming, or by `magic-coordinator` alone via `magic-team.process-inbox.routine` for smaller/faster cases.
  - There is no `triage/` folder.
- **Approval is a header fact, not a folder.** `approved-by`/`approved-at` (see `magic-team.armed.md`'s field list) record that the authority group or the human-owner approved an item, whatever state folder it's actually sitting in — there is no dedicated `approved/` state.
- **`board-backlog`** — concurrency-safe drop point for a freshly-triaged board-item; the default landing spot for one.
  - Who may place one here directly (without needing `magic-coordinator`'s otherwise-exclusive board-write turn): grooming, `magic-coordinator` itself, and other session-routine-mandated members (e.g. `magic-team.interview.routine`'s **run-minimal-step-cycle**).
  - An item sitting here hasn't been assessed yet — the next `magic-coordinator.advance.routine`/`magic-team.grooming.routine` pass picks it up.
- **`board-pending`**
  - An item whose `approved-by`/`approved-at` is already recorded (the "go" decision, made by the authority group or the human-owner during grooming/triage) but that hasn't actually been dispatched (no real work-session/Agent/console spun up for it) yet.
  - A physical resting-place keyed strictly off that existing header fact, not a second/parallel approval mechanism — an item can in principle carry `approved-by`/`approved-at` while sitting in any folder; `board-pending` is simply where one rests between that fact being recorded and its actual dispatch. Does not reopen "approval is a header fact, not a folder" above.
  - `magic-coordinator.advance.routine` moves an item `board-backlog`→`board-pending` purely mechanically, the moment it notices `approved-by`/`approved-at` already set — it never makes the "go" decision itself (see its own routine file's Scope).
  - Exits to `board-running` the instant real dispatch happens — dispatching work that has `approved-by`/`approved-at` recorded includes moving the board-item to `board-running` as the same action, not a separate step (see `magic-coordinator/magic-coordinator.armed.md`).
  - **Deferred, not implemented**: a session running under `magic-coordinator.heartbeat.routine` may in principle skip `board-pending` and move a `board-backlog` item straight to `board-running` when its own restart is trivial enough not to need the intermediate rest-stop — a legitimate future refinement, not built yet. The current mechanism always rests in `board-pending` first, no bypass.
- **A `board-backlog` board-item needing human-owner-level approval** (real doubt, not the ordinary authority-group-decides-inline case above) moves to `board-blocked` instead, under the existing "human-owner decision" reason (not a new reason category).
  - Gated by a dedicated `approval-*` board-item (see `magic-team.armed.md`'s item-type list) that runs the actual negotiation.
  - Once resolved: approved sets `approved-by`/`approved-at` and moves it to `board-pending`; denied moves it to `board-processed`/`board-archived` per the existing denial handling below.
  - Full mechanic (who decides, who executes the mechanical move) lives in the owning routines' own files, not here.
- **`board-running`**
  - Where an item lands the instant it's actually dispatched (see `board-pending` above for what precedes this), and where it stays through active work, claimed-completion, and its own testing round — there is no separate queued/testing folder, all of that happens in place.
  - An inbox item never sits *in* `board-running` directly — triage creates a formal board-item in `board-backlog`, which then moves through `board-pending` on its way here.
  - Once a `board-running` item's implementation is claimed complete (live during a work session, or grooming's advancement review), `magic-coordinator` dispatches `magic-tester` to run its testing round against the claimed-complete work — real test-suite execution per its own methodology, plus its security/CRA-style due-diligence pass (real test-suite execution per its Goals/Scope, the due-diligence pass per its Security/CRA section — both in `magic-tester`'s own `magic-tester/magic-tester.armed.md`).
  - Two outcomes, item stays in `board-running` throughout:
    - **Clean** — no concerns raised.
      - If the item's type/scope genuinely calls for human-owner sign-off before it can be considered final (per `magic-team.grooming.routine`'s staged task-creation lifecycle — "any doubts, approval with human-owner"), it moves to `board-blocked`, filed under `board-blocked`'s existing "human-owner decision" reason (not a new reason category) — this is the state that "may become final" once the human-owner actually approves it, after which it moves to `board-processed`.
      - If no human-owner approval is genuinely warranted (small/clear, no doubt), it moves straight to `board-processed`.
    - **Concerns raised** — `magic-tester` opens an investigation subtask (a `task-*` `board-item`, `spawned-by` the parent) — the same "investigation subtask → escalate or solve" shape used elsewhere in the team's docs (see `magic-team.armed.md`'s "Duties: three kinds, plus reflection" common abstract shape, and `magic-tester`'s own `magic-tester/magic-tester.armed.md` Security/CRA section). Resolves to either:
      - **escalate** — needs a decision from `magic-architect`/`magic-coordinator`/the human-owner before the parent can proceed. The parent stays in `board-running`, or moves to `board-blocked` if the escalation itself becomes an external stall.
      - **solve** — a fix is identified: a solution/implementation subtask is created, also `spawned-by` the parent; once it lands, the parent's testing round repeats in place.
  - A `board-running` item mid-testing is never a dead end and never sits idle on its own — it either resolves onward or spins off a tracked subtask each time it's reviewed, same active-pursuit spirit as `board-blocked` below, just scoped to verification instead of external dependencies.
  - Distinct from `board-blocked`: `board-running` is scheduled to continue (including its own testing round); `board-blocked` was supposed to continue and couldn't.
- **`board-blocked`** — an item that **was supposed to be `board-running`** but a work-session actually hitting it found something that requires action, another job to resolve or a decision before it can genuinely proceed.
  - **The defining property is that `board-blocked` demands periodic active pursuit** — every time it's reviewed (typically at grooming), something is actually attempted: a request sent, a follow-up chase, an investigation into an alternative path — not just "checked and still stuck" with nothing done.
  - Reasons include:
    - A human-owner decision (including a `board-running` item's own testing round awaiting final human-owner approval, see above).
    - An external dependency (an unlocated credential, a third party's response, a human-hands-on action).
    - Waiting on another task/project's own completion (an internal dependency — item X can't proceed until item Y ships).
  - Outcome set at each review (see `magic-team.grooming.routine`): escalate / stays blocked (only legitimate when a real attempt was actually made this pass, not a pure no-op) / becomes `board-parked` / unblocks.

**Uncommitted repo state is never itself a blocking condition.** The rule:
- Uncommitted repo changes are normal, active working state — never a reason to pause further iteration on the same epic. Work continues freely on uncommitted files, same as any other in-progress state.
- `git commit` (human-owner-only, per the standing rule in `magic-team/magic-team.armed.md`'s "Engineering & operating discipline" section) happens only once, as the actual final step, once the whole unit of work — the full epic, not one piece of it — is genuinely finished and ready, either to cleanly start a new epic or to release/ship this one.
- "Awaiting the human-owner's commit sign-off" is only a legitimate `board-blocked` reason once the referenced epic is actually, fully finished — every piece of work it needs is done and verified, with nothing left to build. If any real remaining work still exists, the item belongs in `board-running` (including mid-testing-round), not `board-blocked` — finish the work first, and only land in `board-blocked` once there's genuinely nothing left but the human's own keystroke.
- This never blocks *other*, independent work either: another item that merely depends on the same uncommitted files/epic is not itself validly blocked just because that epic hasn't been committed yet. A real dependency is "the other epic's own content/design isn't finished yet," not "isn't committed yet."

**`board-running`→`board-blocked` has at least four paths in** (not exhaustive — whichever discovers it first fires this):
- Live, during a `magic-coordinator.daily.routine` work session, when a dispatched agent genuinely can't make progress.
- Grooming's own periodic advancement review, catching what wasn't flagged live.
- A member's own async block-report — posted any time, into `magic-coordinator`'s own personal inbox (a cross-member handoff, so it sends an immediate reply to `slack-magic-team` per [magic-team.process-inbox.routine](magic-team.process-inbox.routine.md)'s own **reply-on-cross-member-handoff**), acted on the next time that routine runs over it.
- A `board-running` item's own testing round finishes clean but needs human-owner sign-off before it can be finalized (see `board-running` above).

All four are equally valid; none is the "real" or "canonical" one. **Not the same as `board-parked`**: `board-blocked` keeps getting worked *at* even while it can't move; `board-parked` is the team consciously choosing to stop that active effort and just wait instead (see below).

**Every `board-running`→`board-blocked` move carries an `execution-receipt`**, same "never a silent close-over" principle already stated for `magic-coordinator.advance.routine`'s own `board-running` continuation outcomes: the executing op (`--magic-board-to-blocked`, `--magic-grooming-to-blocked`) auto-stamps a default `blocked:<timestamp>` value itself unless the invoking routine's own call already supplied one via `--header:upsert:execution-receipt:*`/`--header:append:execution-receipt:*`, in which case that value stands. This is not a second writer — `magic-coordinator` remains the board's sole write authority throughout; what varies by call site is only how much evidence that one writer's own invocation happens to carry. Distinct from the four already-exhaustive continuation-outcome shapes (spawn-receipt-id, dispatch/session-id, `inline:<timestamp>`, `no-action:<reason-code>`) and from `board-pending`→`board-parked`'s own `<proxy-receipt-id-or-failure-marker>` shape — `blocked:<timestamp>` is its own shape, specific to this transition.

- **`board-parked`**
  - **Blocked on a subtask, parked on a condition.** That is the distinction between the two states.
  - **The defining property is pure passivity** — no periodic action is expected or taken, unlike `board-blocked`; it just sits until its trigger condition arrives on its own. A recheck asks only whether that condition has arrived; "not yet" leaves it parked.
  - Deliberately deferred by the team's/human-owner's own choice, waiting on a future internal condition or trigger (other work clearing, a project completing, priorities shifting) — not cancelled, not stalled on an external party.
  - Re-visited periodically (typically at grooming) to check whether the trigger condition has arrived — that check is itself passive (has it happened yet?), not an active push; if the team decides it never will, that's when it moves to `board-archived`, not before.
  - **Not the same as `board-blocked`**: parked items aren't waiting on anyone else, the team is simply choosing not to work them yet.
  - Reachable from `board-running` directly (a fresh deferral decision), or from `board-blocked` (the team stops actively chasing a resolution and decides to just wait instead — same destination, different starting point).
- **`board-processed`**
  - Terminal, resolved state. Covers both successfully-completed items *and* denied items — there is no separate `done/` folder.
  - Both get grooming's resolution text appended plus a substantive reply logged (as many reply rounds as actually happened over the item's life).
  - Reached either:
    - Directly — a quick denial matching an obvious rule in `magic-coordinator/magic-coordinator.armed.md`'s "Dispatch & delegation" section, no deep work needed.
    - Via `board-running`'s own testing round — a testing round confirms a completion claim clean, and either no human-owner approval is warranted, or the human-owner has since approved a `board-blocked` item that was awaiting exactly that (see `board-running` above) — then the item moves here and statuses update.
  - **Before filing anything here (or into any archive-style migration), verify it's actually closed — don't mechanically relocate content just because it's old.** Ask concretely: does this content describe work that's actually finished, or does it just happen to be old? If any part is still open/actionable, that part needs its own live tracked item (`board-running`/`board-blocked`-equivalent), not just a historical note — even when most of the surrounding content really is closed. Don't trust a dispatch instruction's mention of this check to have been followed just because it was written in the prompt — verify it was actually applied, especially across a bulk/repetitive migration where the same mistake can repeat silently many times.
- **Ignored** items do not go to `board-processed` — removed from the board entirely instead, no resolution text, nothing else kept.
- **`board-archived`** — terminal, with two distinct populations:
  - Items the team has decided are genuinely abandoned/cancelled for good, not just deferred — reached directly, if dropped outright at triage with no future intent, or from `board-parked`, once the team concludes the trigger condition it was waiting on is never coming.
  - A `board-processed` item grooming judged worth permanent retention, marked `archive: true` (presence-only header, no `archive: false` — its absence is the ordinary default) — this diverts the item from GC's normal eventual-removal path to `board-archived` instead once its retention threshold fires.
  - Neither population is part of grooming's regular all-board scan.
- **`board-retained`**
  - Terminal-adjacent, passive holding state for an item that has otherwise concluded (would ordinarily proceed through `board-processed` toward GC) but is kept from being removed/`board-archived` because at least one other still-*live* board-item's `blocked-by` or `spawned-by` field points at it.
  - This is a **structural** reason ("something else still needs this to resolve"), distinct from `board-archived`'s `archive: true` population, which is a **value judgment** about the item's own importance — `archive: true` is always checked first and always wins: an item carrying it goes straight to `board-archived` regardless of dependency status, so `board-retained` only ever catches what `archive: true` doesn't, never both at once.
  - No new frontmatter field for the still-depended-on check itself: that fact is never hand-set — it's derived fresh via lookup whenever it's actually checked, the same "no reciprocal stored, derive via lookup" property `blocks`/`spawns` already have on their own paired-field side (`magic-team.armed.md`). Scheduling a **`recheck-and-exit`** pass (below) reuses the existing `recheck-date` header instead of a new field name — it already fits `board-retained`'s own "when to next look" need the same way it fits `board-blocked`/`board-parked` (`magic-team.armed.md`'s frontmatter field list).
  - A qualifying `blocked-by`/`spawned-by` pointer must originate from an active state (`board-backlog`/`board-pending`/`board-running`/`board-blocked`/`board-parked`) or from `board-archived` itself — one from another `board-processed`/`board-retained` item, or from an already-removed item, never qualifies, which is what stops two mutually-dependent concluded items from retaining each other forever.
  - Reached either:
    - Directly — an item concludes and is immediately still depended-on (e.g. an assessed `inquiry-*` whose spawned children carry `spawned-by` pointing back at it, never passing through `board-processed` at all).
    - From `board-processed` — the same periodic GC check that already looks for `archive: true` also finds it newly still depended-on.
  - **`recheck-and-exit`**: grooming's own job, not automatic GC — a judgment call for the authority group (`magic-coordinator` + `magic-librarian` + `magic-architect`), `recheck-date`-scheduled rather than run unconditionally every pass. Still depended-on → stays, `recheck-date` renewed. No longer depended-on → exits into the normal `board-processed` GC flow (eligible for removal or `board-archived` per `archive: true`).
  - **Why `blocked-by`/`spawned-by` specifically, not `supersedes`/`superseded-by`**: a qualifying pointer must be structurally load-bearing — something that genuinely can't resolve without this item still being here to point at (a child that depends on its parent still being resolvable, such as an `inquiry-*`'s spawned children; a blocked item's own blocker). `blocks`/`blocked-by` and `spawns`/`spawned-by` are hard-typed relations by construction (`magic-team.armed.md`'s frontmatter field list) — an incidental passing mention never lands in either field to begin with. `supersedes`/`superseded-by` describes a replacement, not a resolvability dependency, so it never qualifies here.

**Resolving a Slack-originated `board-item` also closes the loop on its originating message.**
- Whenever a Slack-origin `board-item` — one whose `communication-channel-id` value starts with `slack:` (see `magic-team.armed.md`'s "Board & Inbox board-items entity model" section) — moves into `board-processed`, `board-archived`, or `board-retained`, the originating Slack message eventually gets a reaction reflecting the real outcome.
- `:white_check_mark:` for a positive/successful resolution; an assessed negative-outcome emoji for a negative one (denied, dropped, archived without a positive outcome) — `:x:`/❌ is a sensible floor/fallback, not a fixed choice, `:-1:`/thumbsdown or another may fit a given case better.

**The move and the reaction are decoupled, not one write-time action.**
- Whichever routine resolves the `board-item` (`magic-team.grooming.routine`'s triage, an inline `magic-coordinator` resolution, or any other path) does not react itself — it only needs to write a clear resolution (so positive-vs-negative can be judged later, since `board-processed` holds both outcomes and folder placement alone never distinguishes them).
- Separately, at the moment a message's reaction first needs to stay deferred (its handling spawned/is the source of a still-open `board-item`), `magic-coordinator.communication-sweep.routine` files a lightweight `pending-slack-reaction` record — the `communication-channel-id` plus the tied `board-item`'s bare name stated in the record's own body prose (no typed frontmatter field fits a plain "this record is about that item" pointer, and no deep classification is needed here) — into `magic-coordinator`'s own inbox or `board-running`.
- **`magic-coordinator.advance.routine`'s own pending-reaction-lookup step is the actual reactor** (`check-process-board`'s **board-run-pending-comms-actions**) — every `magic-coordinator.heartbeat.routine` iteration, once that pass's own board read has already loaded, it looks up all outstanding pending-reaction records, checks whether each referenced `board-item` has resolved, reacts via `DistroAgentsTools.fn.sh --member-comms-slack-react` if so, and clears the record.
- It never *performs the move itself* (its own Scope only ever moves items *out of* `board-processed`/`board-archived`, the narrow `check-process-board` **board-reopen-signaled-items** case) — it is the sole reactor for this mechanism, via its own independent queue-lookup, not by being the trigger for the move.

`board-item`s carrying no `communication-channel-id` at all, or one whose value is not `slack:`-prefixed, have no originating Slack message to react to — this rule is silent for them, not a gap.

## Two independent dimensions: item types vs. routines/activities

Two orthogonal axes — not one list to sort things into:
- **Dimension 1: workflow queue item *types*** — `task-`, `project-`, `inquiry-`, `reflection-`, `proposal-`, `assignment-`, `change-`, `note-`, `transcript-`, `approval-`, etc. (non-exhaustive). Describes *what kind of thing* an item is.
- **Dimension 2: team routines/activities** — `daily`, `grooming`, `retro`, `one-on-one`, `main-loop`, `interview`, `discuss`, `brainstorm`, `coworking`, etc. (non-exhaustive). Describes *the session/process* work happens in or through.

Any item type can arise from or relate to any routine (a `proposal-` can come out of an `interview`, a `grooming` session, or a `coworking` session), and any routine can produce/process many different item types.

## General item lifecycle (non-exhaustive — a floor of required beats, not a closed cycle)

The default shape for *any* item — the real flow may have many more beats once fully assessed, this is a floor, not a ceiling:

- A `board-item` gets recorded (e.g. an `inquiry-*` one).
- It's routed/delivered into whichever inbox matches it, per item-type/routine/member routing rules (see `magic-team.process-inbox.routine`).
- The team-member holding that inbox, combined with that member's own rules, determines it should process this item now.
- Processing it (a) moves/updates its state — likely to `board-blocked` — and (b) decomposes it into sub-tasks, each posted to its own correct inbox per the same routing rules.
- Later, in some other loop/spawn, someone processes their own inbox and picks up a sub-task — sometimes deliberately held until a contextually-right moment (e.g. a `reflection-*` item held until right before retro or a one-on-one).
- Once every sub-task referencing the blocked parent is done, the parent is reprocessed: it can change state, get updated, or block again on newly-arisen sub-tasks — recursively, until it actually resolves.

**Rigid obvious-vs-non-obvious test for whether an item needs this full treatment at all**: at initial assessment, it's processed right now, in one indivisible step, inline, straight to done/processed — only if both hold:
- (a) no subtasks need decomposing, **and**
- (b) no assignee-transfer/hand-off is needed.

Anything failing either part gets the full lifecycle above.

## Denial can happen at any stage, at (at least) two speeds

Not gated to inbox-intake time — an already-approved or in-progress item can still end up denied/cancelled later, possibly after a chain of prior non-denial replies (acks, status updates) before the eventual denial. Two illustrative speeds, not an exhaustive split:
- **Quick/immediate**: matches a simple rule/permission/common-sense check in `magic-coordinator/magic-coordinator.armed.md`'s "Dispatch & delegation" section — resolved right away, no deep investigation.
- **Slow/considered**: full grooming discussion + investigation report before the denial.

## Distinct follow-on work spawns a new subtask, it doesn't reopen the original

Genuinely new, distinct work following on from an already-`board-processed` (or any-state) item is a brand-new `board-item` — own scope, own author, own assignee — naming the parent via `spawned-by` (or, where the new item's own existence gates the parent, `blocked-by`/`blocks` instead — pick the typed field that actually describes the relationship, per `magic-team.armed.md`'s frontmatter field list).

The same item's *own* ongoing back-and-forth (still-pending replies on the identical piece of work) stays in `board-running` instead — both mechanisms coexist, they're not alternatives.

## GC (garbage collection)

`board-processed` items are retained then deleted — timing is **not uniform**, it varies by `board-item` type/size (a completed Project shouldn't be purged on the same clock as a resolved Note).

**Per-type retention thresholds** — days in `board-processed` before GC removes an item from the board, subject to the `archive: true`/still-referenced diversions below:

| `board-item` prefix | Days |
|---|---|
| default | 7 |
| `warning-*` | 1 |
| `reflection-*` | 1 |

GC is not a standalone routine — it's folded into `magic-coordinator.heartbeat.routine`'s own sub-step:
- Each run checks whether any `board-processed` items have passed their retention threshold and, if so, removes them from the board rather than deleting them directly (real deletion mechanics live outside this file — see `magic-coordinator.heartbeat.routine`'s own GC step).
- Before removal, checked in this order:
  1. An item carrying `archive: true` diverts to `board-archived` instead (see `board-archived`'s own entry above) — checked first, always wins.
  2. Failing that, an item still depended on (via another live board-item's `blocked-by`/`spawned-by` field) diverts to `board-retained` instead (see `board-retained`'s own entry above).
  - Both are diversions from the same default removal path; only one ever applies, `archive: true` taking precedence when both would otherwise fire.
- **Not board-only**: the same GC sub-step covers every per-member `<member>/processed/` folder (each keeper's own converted log) the same way, on the same type-dependent-threshold/removal-or-archived mechanism — see `magic-coordinator.heartbeat.routine`'s own GC step for the generalized version.

**Per-member `<member>/processed/` file shape** (each keeper's own converted log, same GC treatment as above but not board-items themselves — no `owner` field, no typed relation fields, this isn't the board's own `board-item` model):
- One file per dated entry, named `<document-type>-<date>-<short-topic>.md` — the prefix is one real, already-established document type, same vocabulary the board itself uses (see "Two independent dimensions" above: `task-`, `note-`, `proposal-`, `inquiry-`, `interview-`, etc.), picked per entry to fit what it actually is; never an invented word.
- Frontmatter carries:
  - `date` — the entry's own date.
  - `type` — a separate, finer-grained genre-of-work tag describing what kind of entry this is, distinct from the filename's document type — e.g. `investigation`, `proposal`, `bug-fix`, `feature`, `verification`, `audit`, `documentation`, `interview` — never a selection-mechanism label like `idle`/`assigned`/`ad-hoc`, since which idle-menu item got picked or how the work was dispatched is prose context, not the entry's actual kind.
  - `topic` — short slug, matching the filename.
- Floor, not ceiling — add a new genre `type` value when a genuinely new kind of entry shows up, don't force-fit into the existing set.

# Process-Flow, the board dynamics

Two routines drive the board, each a distinct, non-overlapping part:
- `magic-team.grooming.routine` — decides state, once per workday or on request. Works on backlog progress:
  - triage
  - RICE re-score
  - `check-backlog-promote` (backlog readiness)
  - `check-reassess` (recall to backlog)
- `magic-coordinator.advance.routine` — mechanically applies already-decided moves only, never new judgment, every main-loop iteration. Works on active non-terminal states (`board-pending`/`board-running`/`board-blocked`/`board-parked`):
  - `check-process-board` — board-state work only, never a board-item's own task: mechanical moves (`board-mechanical-moves`), dependency-edge recompute (`board-recompute-dependencies`, bounded to once a day or on direct request — this procedure's own one bounded exception to "never new judgment"), parked/blocked reassessment (`board-reassess-parked-blocked`), backlog readiness flagging (`board-scan-backlog-readiness`), deferred Slack/Trello actions (`check-pending-comms-actions`)
  - `check-execute-board` — all work on a board-item's own task, spawned or inline: starting `board-pending` items, continuing already-dispatched `board-running` items

## What counts as process-flow

- A `board-item` is a process-flow job — it moves through the lifecycle/states this file defines.
- A `vault-item`/`audit-item` is not a job, even carrying task text — carrying task text never makes a document a job, being on the board does (full definition: `magic-team.armed.md`'s "Vault-items, audit-items, referencing and enveloping" section).
- Process-flow items may reference either kind; the reverse never happens.

## Who actually reads/writes the board

`magic-coordinator` — exclusively, per the write-authority note at the top of this file.

Not something every individual member independently maintains or is expected to check: a member with a properly-registered task (dispatched the normal way — background `Agent` invoking its own `Skill`, with a clearly assigned item, per `magic-coordinator/magic-coordinator.armed.md`'s `spawn-one-dispatch` local procedure) doesn't need separate "go check the board" behavior; the dispatch itself already carries what it needs to do.

The board matters at three points:
- **Grooming** — the authority group's periodic deep read/write pass (triage, advancement, re-scoring).
- **Daily-meeting** — the roll call narrates from it, and the coordinator's own todo-assignment step (**update-todos**) is where a relevant board item gets folded into a properly-scoped dispatch for that day's work session, same as any other assignment.
- **On request** — any member (or the human-owner) can ask about the board's current state at any time; it's a legitimate thing to consult, just not a mandatory per-dispatch step for everyone.

This board has exactly one writer, so there's no multi-writer race to solve here — that concern only applies to personal inboxes (many members writing into each other's), which is `magic-team.process-inbox.routine`'s territory, not this file's.

## Sole live status source

`board/` — this file plus the individual `board-item` files — is the sole live status source.

Two kinds of state deliberately live outside it, and are not exceptions to that rule so much as different things entirely — neither is board status:

- Per-platform mechanical comms-sweep state lives as structured fields in the `heartbeat-state-note` (`last_swept_ts`/`known_comms_gaps`). The operations that read and rewrite that record are `magic-coordinator`'s own, executed by the coordinator instance present in the session — same rule as this file's opening "A routine is not a second authority" statement.
- Open-thread status lives on the owning `board-item`s directly (`communication-channel-id`) — `magic-coordinator.communication-sweep.routine` reads/writes those, not this file.