---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# Board

The team's current-work index: the one live status source for work. Item types and fields: `magic-team.armed.md`'s "Board & Inbox board-items entity model".

## Contents

- Who actually reads/writes the board
- States
- General item lifecycle
- GC (garbage collection)
- Process-Flow, the board dynamics

## Who actually reads/writes the board

- **`magic-coordinator` is the board's only writer**: creating an item, moving it, scoring it, updating its fields. A routine it runs (grooming, advance, interview, discuss, proposal) scopes what it does there; no routine and no dispatch gives any other member board-write authority.
- Every other member reads one item with `--member-board-item-read`, and contributes through its session's tracking document, or an `inquiry-*` to `magic-coordinator`.
- `magic-librarian` joins once per workday under `magic-coordinator`'s lead, in `magic-librarian.morning-review.routine`.
- A dispatched member does not check the board: its dispatch carries its work.
- The board matters at grooming, at the daily meeting, and on request.
- Inboxes are not part of the board.

## States

Always written `board-<state>`.

- **Triage** is a process, not a state: `magic-coordinator` turns inbox content into a board item in `board-backlog`. During grooming it decides with `magic-librarian` and `magic-architect` (the authority group). A small, obvious item it triages alone.
- **`board-backlog`** — newly created, not yet assessed.
- **`board-pending`** — `approved-by`/`approved-at` recorded, not yet dispatched.
  - Deferred, not built: a `magic-coordinator.heartbeat.routine` session may move a backlog item straight to `board-running` when its restart is trivial.
- **`board-running`** — dispatched and in progress, including its testing round and while waiting on an ask. An item reaches it only through dispatch, or by creation for `approval-*`, `dispatch-*` and `interview-*`.
  - When implementation is claimed complete, `magic-coordinator` dispatches `magic-tester` for a testing round, in place.
  - Clean → `board-processed`; or `board-blocked` awaiting the human-owner's sign-off where the work needs it — where "The ladder: one rung at a time" climbs that far, not by default.
  - Concerns → an investigation `task-*`, `spawned-by` the parent, ending as **escalate** or **solve**; after a fix the round repeats.
- **`board-review`** — a handback arrived, or the child ended with no verdict; it awaits its reviewer, named in `review-by` (`human-owner`, a member, a session, `<session-id>:<member>`, or a routine such as `grooming.routine`). The reviewer applies `magic-team.handback-review.routine`: accept (→ `board-processed`), return (→ `board-running`, the same session), reject (→ `board-pending`, for a fresh session), follow-up, or a combination. An unset `review-by` means the run's `reports-to`. `magic-coordinator` reviews when it is the one named, or when the item has neither a `review-by` nor a run of its own. `none`, given or by default, means no review: the item closes straight to `board-processed`, with `review: none` in its Decisions.
  - Built for `human-owner`, given or by default: entering this state posts him one review prompt, once. 👍 accepts, ↩️ returns, ❌ rejects; a reply whose first line is just `accept`, `return` or `reject`, or that word followed by a mark and his comment, does the same, a return or a reject carrying his words on what to change. A review settled another way closes the open prompt. Every other `review-by` still posts no prompt.
  - The tooling also posts, in the thread of the session that requested the run, a fact-only note of how it ended: no handback; handed back in another thread; killed from the console, by whom; stopped by whose `TaskStop`; ended at the bound of a wait; or died (its process gone, nothing closed its record). The note decides nothing; the reviewer's own verdict does. For a death, the control thread of the session instead asks the item's own reviewer a decision: `resume`, `fresh`, `close` or `kill`; with no reviewer set, no question is asked and the record is simply closed. The reviewer answers in the question's own thread; the tooling then starts the member again, closes, or kills, and says what it did there and in the requesting session's thread. While that question is open, the review limit does not dismiss any run of that session. An answer that could not be carried out asks the reviewer again, once for each failure, saying why; nothing is tried a second time without a fresh answer, and an item a failed restart left running with no run goes back to review.
- **`board-blocked`** — could not proceed: a human-owner decision, an external dependency, or another item. Every review attempts something: a request, a chase, an alternative. An item needing the human-owner's go waits here, gated by an `approval-*` item, per "The ladder: one rung at a time".
- **`board-parked`** — deliberately deferred until a condition arrives. Nothing is done; a recheck only asks whether the condition has arrived.
- **`board-processed`** — resolved: completed or denied. The resolution is written into the item. An ignored item is removed instead.
- **`board-archived`** — abandoned for good, or a processed item marked `archive: true`.
- **`board-retained`** — concluded, but a live item (backlog, pending, running, review, blocked, parked, or archived) still points at it by `blocked-by` or `spawned-by`. Rechecked by `recheck-date`; once nothing live points at it, it returns to `board-processed`.

Every move into `board-blocked` carries an `execution-receipt`.

**Uncommitted work never blocks.** Waiting for the human-owner's commit is a `board-blocked` reason only once the whole project is finished and verified.

**A Slack-originated item's message gets its outcome reaction** once the item resolves: ✅ for a positive outcome, a fitting negative emoji otherwise. The resolving step writes a clear resolution; `magic-coordinator`'s `check-pending-comms-actions` procedure reacts later.

## General item lifecycle

- An item is filed, routed to the inbox or board where it belongs, and processed when its holder's rules say so.
- Processing either finishes it in one step, or moves it and splits it into subtasks routed the same way. A parent is reprocessed once its subtasks are done. A subtask's own result stays with that parent; only an escalation climbs further, per "The ladder: one rung at a time".
- One-step finish only when no subtask and no hand-off is needed.
- Denial can come at any stage: quickly, by an obvious rule, or after a full discussion.
- New follow-on work is a new item linked by `spawned-by` or `blocked-by`; it never reopens a processed item. A processed item reopens only on an explicit new signal, back to `board-backlog`.

## GC (garbage collection)

The tooling removes processed board and inbox items after a retention period; `archive: true` and retained items are kept. An item still wanted is not moved or marked processed.

# Process-Flow, the board dynamics

- `magic-team.grooming.routine` decides and applies: triage, RICE scoring, backlog readiness and promotion (approved backlog → pending included), recall to backlog. Once per workday or on request.
- `magic-coordinator.advance.routine` applies decided moves only, every main-loop iteration: dispatch → running, review and unblock handling, signalled reopens, dependency recompute, deferred comms actions. It never makes a go decision.
