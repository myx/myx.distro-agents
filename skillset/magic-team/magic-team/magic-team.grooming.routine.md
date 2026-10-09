---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
invitees: magic-librarian, magic-architect
session: coworking
---
# magic-team.grooming.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Steps
- Closure steps
- Routine's local procedures
  - `rice-scoring` — the four-dimension scoring model
  - `check-backlog-promote` — whether a `board-backlog` item advances
  - `check-reassess` — whether an active item returns to `board-backlog`
- Routine's local rules
- Routine-specific tooling
  - DistroAgentsTools magic-tooling operations
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions

# Summary

`magic-team.grooming.routine` reviews, triages, scores and reprioritises the team's open backlog.

## Goals

- Ask of every open item: still worth doing, owned by the right member, sequenced correctly? A daily roll call reports items; grooming re-examines them.
- Make the board's state decisions: triage, backlog promotion, unblocking, recall to backlog, scoring. `magic-coordinator.advance.routine` only applies moves already decided.

## Scope

- Does:
  - Per-item triage of the board and of `magic-coordinator`'s inbox, bounded RICE scoring, active pursuit of `board-blocked` items, rechecks of parked and retained items.
  - Runs once per workday (`magic-coordinator.heartbeat.routine`'s first iteration of the day) or on request.
- Doesn't:
  - Daily status reporting (`magic-coordinator.daily.routine`).
  - Start work: nothing it writes lands in `board-running` except an `approval-*`.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **acquire-lock**: take this routine's lock with `--magic-grooming-lock-acquire`, before anything else. Contention means another grooming pass is live: this pass does not start.
2. **session-start**: run `magic-team.coworking.routine`'s **session-start** group, then invite `magic-librarian` and `magic-architect` per its **invite-participants-visibly**.
3. **gather-the-backlog**: open with what changed since the last pass and today's top priority, steps:
   - read the open board and `magic-coordinator`'s inbox with `--magic-grooming-input-scan`. Its `state-and-lock` note is this pass's tracking document: keep it current with `--magic-grooming-state-and-lock-upsert`, and hold the lock with `--magic-grooming-lock-refresh` during a long pass.
   - run `magic-team.process-inbox.routine magic-coordinator`, so fresh inbox items are triaged with the backlog.
   - refresh the `roster-note` with `--magic-team-roster-upsert` where a member's `SKILL.md` description drifted from it.
   - check Trello board coverage.
   - check Google Drive and Sheets for files modified since the last grooming, with `--member-comms-google-file-find`.
   - collect the approved items needing the human-owner's own hands (app configuration, scope grants) into one batch, and send it to him with `--member-comms-slack-send-message` during this pass — at **review-with-the-user** if he is live, else once this step ends.
4. **triage-per-item**: give every open item, old or new, one recorded triage verb or an explicit skip reason. Time-box each item. Steps:
   - decide each item by this tree, first match wins:
     - duplicate of another open item → **Merge**.
     - depends on something external that has not happened → **Block**.
     - blocked, and its blocker cleared → **Unblock**.
     - stale, no longer worth doing → **Drop**.
     - too big for one work session → **Split**.
     - owned by the wrong member → **Reassign**.
     - otherwise → **Refine**: change at least one of description, size, order or `recheck-date`.
   - apply the verb, each one call:
     - **Refine**, **Reassign**: same-state `--magic-grooming-to-<state>` with `--from-state:` that state.
     - **Defer**: `--magic-grooming-to-parked`.
     - **Block**: `--magic-grooming-to-blocked`, with `condition` and `recheck-date`.
     - **Unblock**: `--magic-grooming-to-pending` for an approved item, `--magic-grooming-to-backlog` for one never approved.
     - **Split**: create each child with `--magic-grooming-create-backlog`, `spawned-by` the parent; move the parent to `board-blocked`, `blocked-by` the children. A child needing several members' judgement carries `restart-session:` with them.
     - **Drop**: `--magic-grooming-to-archived`, or remove an item that never had substance.
     - **Merge**: fold the duplicate's new information into the survivor (`supersedes`), and close the duplicate to `board-processed` (`superseded-by`). Settled information is applied into the survivor's content; in-flight information is added as a dated note. Merge only when sure it is the same ask; in doubt, keep both.
   - triage each inbox item, after a cheap duplicate look across the inbox, `board-backlog`, `board-pending` and `board-running`:
     - **Promoted** → a new board item in `board-backlog` (`--magic-grooming-create-backlog`). Where the group already holds the go, create it in `board-pending` (`--magic-grooming-create-pending`) with `approved-by`/`approved-at`.
     - **Needs the human-owner's go** → the item in `board-blocked` (`--magic-grooming-create-blocked`) and an `approval-*` in `board-running` (`--magic-grooming-create-running`), linked by `blocks`/`blocked-by`.
     - **Denied** → a `board-processed` record with the resolution (`--magic-grooming-create-processed`), and a reply to the asker. An auto-reject cites its rule.
     - **Not yet ready** → stays in the inbox.
     - **Ignored** → nothing on the board.
     - every handled inbox item is closed per `magic-team.process-inbox.routine`.
   - a promoted item tracing to one Slack message carries `communication-channel-id: slack:<channel>:<ts>` on its create call. Every move carries the field unchanged.
   - an item whose type has a `resume-review` (`interview-*` → `magic-team.interview.routine`; the list grows as more types define one) gets it run before its triage.
   - a cross-member hand-off this step creates gets `magic-team.process-inbox.routine`'s **reply-on-cross-member-handoff**.
   - run `check-backlog-promote` over `board-backlog`, and `check-reassess` over `board-pending`, `board-parked`, `board-blocked` and `board-running`.
   - adjudicate closed spawn records left in `board-pending`:
     - `status: dispatch-succeeded` → `board-processed`.
     - `status: dispatch-failed` with `tracks:` → close it to `board-processed` with the reason; to retry, return the tracked item to `board-pending` with what the retry needs.
     - `status: dispatch-failed`, no `tracks:` → close it to `board-processed` with the failure. Its work may be dispatched anew by judgement.
   - apply `magic-team.handback-review.routine` to each item the scan's `## review items addressed to grooming.routine` section lists.
   - recheck `board-running` items, steps:
     - a claimed completion gets a `magic-tester` testing round, in place.
     - testing clean → `board-processed`; clean but needing the human-owner's sign-off → `board-blocked`.
     - testing raised concerns → an investigation item `spawned-by` the parent: `board-pending` if ready to run, `board-backlog` if it needs more assessment. The parent stays running, or moves to `board-blocked` when the escalation is an external stall.
     - a stalled item → `board-blocked`.
   - recheck every `board-blocked` item, with a real attempt each pass:
     - **Escalate** — push for resolution now; it stays blocked meanwhile.
     - **Stays blocked** — only with something actually tried this pass. Any open `blocked-by` keeps it blocked.
     - **Becomes parked** — active pursuit is no longer worth it: `--magic-grooming-to-parked`.
     - **Unblocks** — its blocker cleared or dropped: `--magic-grooming-to-pending`. An approved `approval-*` just moves to `board-processed`; the move unblocks what it gated.
     - **Archived** — even waiting is not worth it: `--magic-grooming-to-archived`.
   - recheck every `board-parked` item: its trigger arrived → `--magic-grooming-to-pending` or `--magic-grooming-to-backlog`; never coming → `--magic-grooming-to-archived`.
   - **recheck-and-exit** every `board-retained` item whose `recheck-date` is due or unset: still referenced → renew `recheck-date` (`--magic-grooming-to-retained --from-state:retained`); no longer referenced → `board-processed`.
5. **assess-finished-unresolved**: assess every item carrying `processed-at` and no `resolved-at`. Write its decided outcome into the item with a same-state `--magic-grooming-to-<state>` call. No outcome decidable: say why; it stays visible next pass.
6. **rescore-backlog-rice**: score per `rice-scoring`, one pass over `board-backlog`, `board-pending`, `board-running`, `board-blocked` and `board-parked`, steps:
   - give every item triaged this pass that has no score its first one.
   - re-score the 10 open items with the oldest scores, oldest first.
7. **reprioritize-across-members**: order the triaged, scored set, steps:
   - apply the important-vs-eager distinction, informed by the scores, never decided by them.
   - read the recorded `blocks:`/`blocked-by:` edges and surface them; never recompute them here.
   - among items close in priority, prefer the one nearest to approval: the smallest remaining gap and the likeliest clean approval, whatever its size.
8. **review-with-the-user**: present the reprioritised backlog to the human-owner as a conversation. He reorders, pushes back or approves before it is final.

# Closure steps

1. **close-session**: run `magic-team.coworking.routine`'s **close-session** group.
2. **close-state-and-unlock**: release the lock with `--magic-grooming-close-state-and-unlock`, passing the closing status. Reference items by name rather than copying them.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

## `rice-scoring` — the four-dimension scoring model

Used by **rescore-backlog-rice** and by any member scoring an item.

- Four numbers per item, each 0–1, normalised against the current open set at each grooming pass:
  - **Profit** — 0 least valuable, 1 most.
  - **Cost** — 0 cheapest, 1 costliest.
  - **Time** — 0 fastest, 1 slowest. Distinct from Cost.
  - **Dependencies** — 0 fully ready, 1 heavily blocked. A companion to the board state, never a replacement.
- Optional sort key: `Priority = Profit / (Cost + Time + Dependencies)`.
- Scores are recorded on the item, tagged by who gave them. Official scores come from `magic-architect` (architecture level) and `magic-coordinator` (cross-team). Any member may add a personal score. A structural score (risk, coupling, blast radius) carries one line of reasoning.
- Set at grooming, by `magic-architect`'s `grooming-scores-review` idle activity, or ad hoc by any member.
- A score informs a decision and never makes one. A high Cost or Time questions the scope; a high Dependencies asks what lands first. Disagreeing scores are reconciled in conversation, never averaged. A high score never jumps an item that gates it.

## `check-backlog-promote` — whether a `board-backlog` item advances

Run per item during **triage-per-item**. Steps:
1. `interview-*`, or a `task-*`/`proposal-*` explicitly awaiting interview (read its content, not its title):
   - `owner-session: interactive` with `owner-session-since` within about an hour: skip; a live session holds it.
   - otherwise: `--magic-grooming-to-pending`. `magic-coordinator.advance.routine` starts it and runs its interview rounds.
2. Any other item already carrying `approved-by`/`approved-at` (created approved by another routine) → `--magic-grooming-to-pending`.
3. Any other item, by the group's consensus this pass:
   - dependencies clear and priority confirmed, nobody dissents → `--magic-grooming-to-pending` with `approved-by`/`approved-at`.
   - a dependency still open → `--magic-grooming-to-blocked`, with a note. No `approval-*`: not a human decision.
   - real doubt about priority or a dependency → an `approval-*` in `board-running` (`--magic-grooming-create-running`), and the item to `board-blocked`, linked by `blocks`/`blocked-by`.
   - not yet assessed → stays in `board-backlog`.

## `check-reassess` — whether an active item returns to `board-backlog`

Decided jointly by `magic-coordinator`, `magic-librarian` and `magic-architect`. Steps:
1. The item's scope or assumptions shifted so its state no longer reflects reality:
   - all three agree → `--magic-grooming-to-backlog` with a note on the trigger.
   - they disagree → resolve it in discussion; escalate when still unresolved. Never a silent default.
2. Framing still holds → no move; update only what narrower changed (owner, `recheck-date`, a note).

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- `magic-coordinator` is permitted and obliged to execute every step exactly as written, in order.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- This routine extends `magic-team.coworking.routine`; on conflict, this file wins.
- `magic-coordinator`, `magic-librarian` and `magic-architect` make every judgement call jointly; `magic-coordinator` alone executes the steps and writes the board. Another member may request a pass, never run one.
- The group never lets one view win by default. Unresolved: escalate. Running unattended: leave the item where it is and flag the disagreement for the next pass.
- Running unattended (the heartbeat's first iteration of the day): **review-with-the-user** does not block. Its findings are recorded as provisional and confirmed when the human-owner is next present. Silence is never approval.
- Grooming never spawns a session. Work needing one lands in `board-pending`, for `magic-coordinator.advance.routine` to start.
- Triage decides an item's state; **rescore-backlog-rice** decides its numbers. Never fold one into the other.
- A pass-level "deferred" or "reviewed later" without per-item outcomes is invalid.
- An item unchanged since the last pass still gets a glance, not a re-litigation.
- A `blocked` item with nothing left to try is parked, never given a token action.
- Scores and recorded dependency order that disagree are both recorded truthfully.
- A promoted item passes the task-creation lifecycle before it reaches `board-pending`: investigation, assessment with `magic-architect`, doc and proposal check with `magic-librarian`, a polished proposal with `magic-coordinator`, the human-owner only on real doubt. `magic-coordinator`'s "Dispatch & delegation" fast gate is a separate permission check, run at intake.
- Each board move is announced in the session thread as it happens, plus one closing summary. A pass that finds nothing still reports "nothing new".
- Slack reactions on resolved items are `magic-coordinator`'s `check-pending-comms-actions` procedure's job, never this routine's.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-grooming-lock-acquire <team-member> <owner-label>`
- `--magic-grooming-lock-refresh <team-member>`
- `--magic-grooming-close-state-and-unlock <team-member> [--from-file <path>|--edit-patch-from-stdin]`
- `--magic-grooming-input-scan <team-member>`
- `--magic-grooming-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--upsert-from-stdin|--edit-patch-from-stdin]`
- `--magic-grooming-to-<state> <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]`, `<state>` one of `backlog`, `pending`, `parked`, `blocked`, `processed`, `archived`, `retained`
- `--magic-grooming-create-<state> <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...`, `<state>` one of `backlog`, `pending`, `running`, `blocked`, `processed`
- `--magic-team-roster-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]`
- `--member-comms-slack-send-message <team-member> <target> [text...]`
- `--member-comms-google-file-find <team-member> <drive-query> --raw-query [--limit <n>]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- `magic-team.grooming.routine` exists to give the three-actor authority group a regular, joint checkpoint for reprioritizing the backlog together — so priority decisions don't silently drift to whichever member happens to be looking at the board.
- A provisional reprioritization recorded without a live human present stays provisional until actually confirmed — silence is never treated as approval.
- A backlog only ever added to, never re-assessed, accumulates stale/mis-owned/mis-sequenced items a daily roll-call alone never catches.
- A `blocked/` item stays blocked only if something was actually tried this review, never a silent re-stamp.

## Verbatim-tests (benchmarks)

- A grooming session that finds nothing to reprioritize still reports "nothing new this session" to `slack-magic-team`, rather than skipping the report.
- A `blocked/` item with no real attempt made this pass moves to `parked/`.

## Librarian Comments

### Reference

- `magic-team/magic-team.board.md` — board states and the grooming/advance split.
- `magic-coordinator.advance.routine` — applies the moves this routine decides.
- `magic-team.handback-review.routine` — settles the `board-review` items addressed to this routine.
- `magic-coordinator/magic-coordinator.armed.md` — "Dispatch & delegation" fast gate; `check-pending-comms-actions`.

### Conventions

- `rice-scoring`, `check-backlog-promote` and `check-reassess` are cited by name from other files.
