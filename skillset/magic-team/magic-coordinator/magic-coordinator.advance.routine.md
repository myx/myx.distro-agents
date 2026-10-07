---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-coordinator.advance.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Steps
- Closure steps
- Routine's local procedures
  - `check-execute-board` — work on board items' own tasks
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

`magic-coordinator.advance.routine` is the every-iteration pass that brings the board's recorded state in line with reality and starts or continues decided work.

## Goals

- Keep the board trustworthy between grooming passes: sessions die, dispatches go stale, approvals land at any time.
- Apply only moves already decided — an approval recorded, a review accepted, a completion recorded, a condition met. This is what makes the pass safe to run unattended.
- Two bounded judgements are allowed: recording dependency edges (`check-process-board`'s **board-recompute-dependencies**), and accepting a trivial `board-review` item reviewed by this member.

## Scope

- Does, every pass:
  - Process `magic-coordinator`'s own inbox, and run the full communication sweep.
  - Work every `board-running` and `board-pending` item, the `board-review` items this member reviews, and the `board-parked`/`board-blocked` items whose `recheck-date` has arrived or which carry none.
  - Run the deferred comms actions (`check-pending-comms-actions`).
  - Dismiss spawned sessions whose work is finished.
- Doesn't:
  - Decide a go. Promotion and readiness are `magic-team.grooming.routine`'s (`check-backlog-promote`).
  - Resolve blockers by judgement, score RICE, or triage (keep, defer, reassign, split, drop). Those are grooming's.
  - Hunt state-model drift (`magic-librarian.morning-review.routine`), review Trello board content, or read Google Drive.
  - Settle an open design question an investigation surfaced. It is flagged for grooming and `magic-architect`.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **advance-acquire-lock**: Acquire the lock (`--magic-advance-lock-acquire`) before anything else. Contention means another pass is live: this pass does not start.
2. **advance-process-inbox**: Run `magic-team.process-inbox.routine magic-coordinator`. This is the pass's one inbox processing.
3. **advance-read-board-state**: Run `--magic-advance-input-scan`. Keep the pass's tracking note current as the pass proceeds (`--magic-advance-state-and-lock-upsert`), and refresh the lock during a long pass (`--magic-advance-lock-refresh`).
4. **advance-reconcile-sessions**: Compare the scan's session registries with the board before any other work. Each handler states its outcome, steps:
   - **reconcile-read**: Read the spawned-sessions and pending-replies registries, and match each `board-running` item to its session by `session-id`.
   - **reconcile-dead-session**: A `board-running` item other than a `dispatch-*` whose session is not live is a failed spawn. Record the registry reading in its `execution-receipt`. It carries `restart-session`: respawn that group at the item's recorded state, outcome `respawned`. Otherwise: move it to `board-blocked` with a `condition` naming the dead session, outcome `flagged-once`.
   - **reconcile-untracked-session**: A live session with no board item is flagged once in `event-track`, naming its session id, member and sandbox. No item is created; whether it becomes tracked work is a judgement. Outcome `flagged-once`.
   - **reconcile-finished-session**: A live session whose tracked work reports finished and which nothing else needs is dismissed (`spawn-one-dispatch`'s **spawn-dismiss**). This covers sessions a heartbeat pass dispatched.
   - **reconcile-lost-reply**: A `board-blocked` item waiting on a reply the registry no longer holds open: read its `communication-channel-id` thread. The addressee's answer is there: apply it and continue the item. None: re-ask the same party in that thread (`AskUserQuestion`, `wait: false`) and keep the item blocked, outcome `nudged`. A missing record is never consent and never a deny. An open ask never expires by age: the human may be away for weeks. It is closed only when its question is no longer current, is a duplicate, was resolved another way, or its session is complete and closed.
5. **advance-review-items**: For each `board-review` item whose `review-by` is `magic-coordinator`, `advance.routine` or empty, read its Result block, the output log it names, the session's handback and its output folder, steps:
   - trivial and complete: accept it (`--magic-board-to-processed`), and dismiss its session if live
   - trivial and not complete: return it to `board-running` (`--magic-advance-to-running`), comments appended
   - anything else: leave it in `board-review`
6. **advance-process-comms**: Run `magic-coordinator.communication-sweep.routine`'s Steps inline, against this pass's board read.
7. **advance-run-process-board**: Run `check-process-board` (`magic-coordinator.armed.md`) against this pass's read.
8. **advance-run-execute-board**: Run `check-execute-board` (below) against this pass's read.

# Closure steps

1. **advance-report**: Post one `event-track` record (`--member-comms-slack-send-message`): `check-execute-board`'s outcomes per item and their counts, the items left untouched, and what was started. It never repeats `check-process-board`'s **board-report**.
2. **advance-close-state-and-unlock**: Release the lock with `--magic-advance-close-state-and-unlock`, passing the closing status in the same call. Reference items by name rather than copying them.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

## `check-execute-board` — work on board items' own tasks

All work on an item's own task, first start or continuation. Called only from this routine.

### Working an item

Decide what the item's gap needs, then act this pass:
- Nothing left to decide: do the one concrete action (send, spawn, check) through its operation, verify it happened, and record what was done.
- A real choice: list the options with their outcome and risk, pick one, record the reasoning on the item, then act.
- Missing information: get it if one call away. Otherwise flag it once, naming the missing fact.

An outcome is done only when real state backs it: a message sent, a session spawned, a round run.

### Starting `board-pending` items

- Candidates: approved `board-pending` items with no dispatch recorded. The approval is the go; the running `main-loop` or session covers the spawn.
- Conflict gate — any one keeps the item in `board-pending`, with `recheck-date` advanced:
  - Package or topic overlap with a running job.
  - Resource contention shown by a live signal this pass (an active lock or channel).
  - A document the item needs is being edited by another live session.
  "Dispatched earlier today" or "liveness unknown" alone is never evidence. Ambiguous evidence counts as a conflict.
- Start at most one per pass, oldest first: spawn its `restart-session` group, or else its `owner`, through `spawn-one-dispatch`, and move it to `board-running`. One item per session.
- A spawn that fails: move the item to `board-parked` (`--magic-advance-to-parked`) with `condition`, `handoff-action: spawn retry`, `execution-receipt` and `--recheck-in 17`, and post once to `event-track`. Each recheck retries once.
- This is the only starter of an unrequested `board-pending` item. Another routine may call `spawn-one-dispatch` only on its own instruction.

### Continuing `board-running` items

Every `board-running` item, every pass. An item whose `recheck-date` is still in the future, or below the staleness threshold, is skipped untouched: no write, no record.

- `session-id` set: nudge the session with this pass's relevant findings (`SendMessage`). Never spawn a second session for it. A failed nudge, or a session with no state change past the staleness threshold, is treated as `session-id` absent.
- `session-id` absent:
  - `interview-*`: run its per-type rule, never the respawn below.
  - `restart-session` present: respawn that group through `spawn-one-dispatch`, with `--magic-advance-to-running --from-state:running --recheck-in 7±2`.
  - Approved, but no session, no `restart-session` and no dispatch recorded, past the threshold since `started-at`: dispatch its `participants`, else its `owner`, through `spawn-one-dispatch`. Outcome `respawned`.
  - No per-type rule matches: post "running item with no handler: `<item>`" to `event-track` and flag it for grooming. Outcome `no-action`.
- Staleness threshold: about 5 main-loop iterations or 1 hour, whichever comes first.
- Console-backed work: check its channel with `--console-list`. A channel expected but gone is flagged, never restarted.
- A live item that this pass's findings concern gets them relayed through its own channel: `SendMessage`, or `--console-send` for console-backed work.
- At most two respawns per pass, oldest `date`/`owner-session-since` first. What started is named in **advance-report**, never in a DM.
- Work order: by real coverage of the item's goal, then by age. A sub-task count is never the measure.

### Per-type rules for `board-running` items

Each item is a tracking document. Spawning work on it spawns the group its `participants` names, with the goal, the task, the document and this rule.

- `approval-*`: `recheck-date` due and not resolved → ask the human-owner in its tracked thread, else on his direct channel (`AskUserQuestion`, `wait: false`), leading with `NEEDS REPLY:`. Extend it with `--recheck-in 17±2`. The ask is open, so it is not posted twice.
- `interview-*`: run exactly one round of `magic-team.interview.routine`'s **resume-review** and **reassess-before-next-message** over its tracked thread. The round dispatches only pieces already approved, and sends at most one outward message, or one explicit close-out, then move on: the next pass continues it. With no tracked thread (`communication-channel-id` not `slack:<channel>:<ts>`), post the round to the human-owner and write the returned thread back as `communication-channel-id` (`--magic-advance-to-running --from-state:running`). A round finding every question resolved and none new moves the item to `board-processed` (`--magic-board-to-processed`).
- `proposal-*`: carrying a `communication-channel-id`, it is in front of the human-owner (`magic-team.proposal.routine`). Read the thread root's closing reaction first: one is there, apply its outcome per that routine's **close-on-root-reaction**. None: take the `approval-*` rule. Otherwise run `magic-team.discuss.routine` over it this pass. That routine's **record-the-outcome** makes the move; approved or rejected, the item goes to `board-processed`.
- `task-*`/`project-*`: completion claimed and no clean testing round → dispatch a `magic-tester` round in place. A stale testing round gets a fresh one. Otherwise apply the staleness checks above.
- `dispatch-*`: nudge per the rule above, and append its report as a dated log entry (`--magic-advance-to-running --from-state:running`). The tooling moves a finished dispatch to `board-review`.
- `change-*`: `recheck-date` due → check whether the change landed. Landed → `board-processed`. Not yet → `--recheck-in 17`.
- `warning-*`: `recheck-date` due → condition no longer true: `board-processed`. Still true: re-escalate once in `event-track` and extend `recheck-date`. No `recheck-date`: set one.
- **base restart**: a named participant cannot be spawned → move the item to `board-parked` (`--magic-advance-to-parked`) with `condition` naming that participant and a `recheck-date`, and report it.

### Per-pass outcomes

- Every due `board-running` item ends the pass with one outcome: `nudged`, `respawned`, `redispatched`, `flagged-once` or `no-action`. A spawn-failure park is `parked-spawn-failed`. "Deferred" is invalid.
- `no-action` has exactly two valid reasons: no per-type rule matches the prefix, or a temporary error this pass stopped the real handling.
- `execution-receipt` is one of: a spawn receipt id, a dispatch or session id, `inline:<timestamp>`, or `no-action:<reason-code>`.
- Bookkeeping-only outcomes for several items go in one `--magic-advance-batch-outcome` call. `interview-*` and `proposal-*` outcomes never do: each comes from its own round.
- A side-effecting call (spawn, nudge, redispatch, park) is followed by `--magic-advance-sleep-run` before the next item.

### What reaches the human-owner

- The whole pass record goes to `event-track` in **advance-report**.
- A DM goes only for something he can act on: a decision only he can make, something blocked on him that he does not know, or something that changes what he believed. A tally, an extension, a re-confirmed no-action or "nothing new" never qualifies.
- A pass with nothing qualifying sends nothing. That is the step completing.
- A DM carries one topic and leads with what is needed. A continuation goes into its own thread; a new topic is a new message.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- This routine extends `magic-team.coworking.routine`, with these overrides: the session thread is `event-track`; **fold-in-learned-lessons** does not run; **advance-report** is the closing obligation.
- Keep `event-track` current as things are found, not batched.
- A `recheck-date` is set with `--recheck-in <minutes>[±<jitter-minutes>]`, never computed by hand.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-advance-lock-acquire <team-member> <owner-label>`
- `--magic-advance-lock-refresh <team-member>`
- `--magic-advance-close-state-and-unlock <team-member>`
- `--magic-advance-state-and-lock-upsert <team-member> [--header:...]...`
- `--magic-advance-input-scan <team-member>`
- `--magic-advance-to-running <team-member> <item-filename> --from-state:<state> [--header:...]...`
- `--magic-advance-to-parked <team-member> <item-filename> --from-state:<state> [--header:...]...`
- `--magic-board-to-blocked <team-member> <item-filename> --from-state:<state> [--header:...]...`
- `--magic-board-to-processed <team-member> <item-filename> --from-state:<state> [--header:...]...`
- `--magic-advance-batch-outcome <team-member> --items:<item-filename>:<outcome>:<execution-receipt>[,...]`
- `--magic-advance-sleep-run`
- `--member-comms-slack-send-message <team-member> <target> [text...]`
- `--console-list`
- `--console-send <channel> [-- <command...>]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine does the periodic board reconciliation process-flow needs to keep moving — without it, board state can drift from reality between full daily/grooming cycles.
- `check-process-board`'s own dependency-recompute step exists so task-ordering/dependency reasoning (what blocks what) is a standing, repeatable step recorded on the board itself — not a one-off answer that evaporates once the conversation moves on.
- The pass's full record is kept without spending the human-owner's attention on it: the record goes to `slack-event-track` every pass, and his own channel carries only what he can act on.

## Verbatim-tests (benchmarks)

- A pass re-confirms every `board-running` item and finds nothing needing him. It posts the full record to `slack-event-track` and sends him nothing — the silence is the closing step completing, not a step skipped.
- A `board-running` item whose own content already says it moved to `board-blocked`, but is still physically sitting in `board-running`, gets moved to match — without waiting for the next grooming pass.
- Dependency reasoning worked out ad hoc in a chat reply gets recorded on the board-item files themselves — the next pass doesn't have to redo it from scratch.
- An approved `board-running` item carrying none of `session-id`, `restart-session:`, an active console session, or an unresolved dispatch note, sitting past the staleness threshold, gets a real dispatch this pass — never a blanket `no-action` stamp with nothing actually tried.
- A `session-id`-set item that keeps getting nudged with zero observed state change past the staleness threshold is treated as if the nudge failed — not renudged indefinitely as "still working."
- A high-RICE item blocked on a low-RICE one still records the gate plainly — never silently reordered to make the numbers look consistent.

## Librarian Comments

### Reference

- `magic-coordinator.heartbeat.routine` — runs this routine inline, last, every pass. `magic-coordinator.coordination-session.routine` runs it on a new update.
- `magic-coordinator.armed.md` — `check-process-board`, `check-pending-comms-actions`, `spawn-one-dispatch`.
- `magic-team.board.md` — board states and the advance/grooming split.

### Conventions

None.
