# Board-state procedures: `check-process-board` and `check-pending-comms-actions`

The steps of two local procedures of `magic-coordinator.armed.md`.

## Contents

- `check-process-board` — board-state work, never an item's own task
- `check-pending-comms-actions` — deferred Slack reactions and Trello updates

## `check-process-board` — board-state work, never an item's own task

Moves and fields only. An item's own task is `magic-coordinator.advance.routine`'s `check-execute-board`. Any routine this member runs may call it. It applies decided moves only; it never makes a go decision.

Steps:
1. **board-read-state**: Use this pass's board read. With none loaded, call the calling routine's own scan.
2. **board-state-vs-content**: An item whose body already records a move its state does not show (body says moved to `board-blocked`, item still in `board-running`) is moved to match. Note the correction in the report.
3. **board-mechanical-moves**: Apply the decided moves. Announce each one in the session thread as it happens:
   - `board-pending` item whose content records a dispatch → `board-running` (`--magic-advance-to-running`).
   - Never `board-backlog` straight to `board-running`.
4. **board-dependencies**: The tooling keeps both directions of `blocks`/`blocked-by` whole, once for each change of the board, and the scan carries `## board dependencies`: the cycles, what must happen first, what waits and on what, what is blocked with no blocker on the board, and how many items are independent. What is left to judgement:
   - Record an edge that only an item's text shows, as `blocks`/`blocked-by` on the item. An unclear edge is described in the item's body, never forced into a field.
   - A real cycle in the report is flagged to `magic-architect`.
   - A high-RICE item blocked on a low-RICE one is recorded plainly, never reordered.
   - In a time-boxed caller, such as the daily roll call, keep it proportionate.
5. **board-per-type-state-rules**: For each `board-running` item, by filename prefix:
   - `approval-*`: approved (`approved-by`/`approved-at`, or an explicit go recorded as them) → `board-processed`. The move carries the go to what it `blocks`.
   - `task-*`/`project-*`: a clean testing round recorded → `board-processed`, accepted by the task's own parent, per "The ladder: one rung at a time".
   - `proposal-*`: nothing here. `magic-team.discuss.routine` (among the team) owns its state changes first; `magic-team.proposal.routine` (in front of the human-owner) takes over only where the ladder climbs that far.
   - `interview-*`: nothing here. `magic-team.interview.routine` owns its state changes.
   - `dispatch-*`, `change-*`, `warning-*`: nothing here. `check-execute-board` handles them.
   - `idea-*`: not expected in `board-running` → flag for grooming.
   - Any type outside the board types (`magic-team.armed.md`'s entity model): misfiled → flag once for grooming.
6. **board-reopen-signaled-items**: An in-scope item that explicitly says a `board-processed`/`board-archived` item needs reopening → move that item to `board-backlog` (`--magic-board-to-backlog`), noting the trigger.
7. **board-reassess-parked-blocked**: `board-parked`/`board-blocked` items whose `recheck-date` has arrived, or which carry none, from this pass's data only:
   - An external check is needed: file an `inquiry-*` for it (`post-inquiry`), reference it on the item, with `--recheck-in 17`.
   - `condition` not met: leave it in place with `--recheck-in 17`, note why.
   - `condition` met: move `board-parked` → `board-backlog`, or `board-blocked` → `board-backlog`/`board-pending`/`board-running` as its content decides, noting why.
8. **board-reassess-archived-missing-flag**: A `board-archived` item carrying `processed-at` but no `archive: true` is flagged once for grooming, which decides whether to restore it. An item without `processed-at` was dropped directly and is in its normal state.
9. **board-scan-backlog-readiness**: Where this pass's read includes `board-backlog`, flag dependency-clear, ready-looking items for grooming. Never decide "go", never dispatch.
10. **board-run-pending-comms-actions**: Run `check-pending-comms-actions`.
11. **board-report**: Post one `event-track` trace every run, even "nothing to update": moves, reopens, flags, comms actions done and still pending.

A `recheck-date` is set with the board op's `--recheck-in <minutes>[±<jitter-minutes>]`, never computed by hand.

## `check-pending-comms-actions` — deferred Slack reactions and Trello updates

Reads the comms-action records in this member's own inbox. Steps:
1. **pending-read-slack**: Read every `note-pending-slack-reaction-*` record: a `communication-channel-id` and the board item it waits on.
2. **pending-resolve-slack**: The board item is resolved (`board-processed`/`board-archived`): read its resolution, react ✅ for a positive outcome or a fitting negative emoji otherwise (`--member-comms-slack-react`), and mark the record processed (`--member-inbox-to-processed`). Still open: leave it.
3. **pending-read-trello**: Read every `note-pending-trello-update-*` record: target card and gist.
4. **pending-post-trello**: Post the gist (`--magic-comms-trello-post-comment`) and mark the record processed (`--member-inbox-to-processed`). A failed post leaves it for the next pass.
