---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
access-control: magic-librarian:allow-tool:skillset-upsert
requires-session-kind: standalone
routine-lock-document: inbox:{{team-member}}:note-20261020T000000Z-work-duty-state-and-lock.md
input-scan-def: work-duty --session-id {{session-id}}
wait-sources: inbox:{{team-member}} tagged:{{team-member}} mentions:{{team-member}} board:backlog board:pending board:running board:review board:blocked board:parked
reports-to: none
review-by: none
runs-at: none
cache-prefix: extended
---
# magic-coordinator.work-duty.routine — the actual procedure

# Summary

The coordinator's duty session: it works what its work-duty scan found, then waits, and works what arrives, until it is dismissed. Its scan carries what the team's duty scan carries, and three things more. They are the due items of the human-owner and the external contacts, the open permission asks, and the board. The tooling starts it when the schedule's flags allow and something waits. That is an item of its inbox, one of the board that changed, or a recheck-date that arrived. The tooling has it dismissed at its next idle point when the flags stop allowing. It wakes within seconds of an item arriving in its inbox or in an active state of the board.

# Opening steps

None of its own: the Opening steps of its session kind run first.

# Steps

1. **work-the-input**: the input the spawner gave you is `input/input-scan.md`. Read it by line range, and do not scan again. Work what it holds, in this order, a section reading `(none)` skipped:
   - the inbox: run `magic-team.process-inbox.routine magic-coordinator` inline (`--routine-run-inline magic-team.process-inbox.routine`). This is the round's one inbox processing.
   - the due items of the human-owner and the external contacts: `magic-coordinator.external-inbox-handle-loop.routine`, inline (`--routine-run-inline magic-coordinator.external-inbox-handle-loop.routine`).
   - the permission asks: `magic-coordinator.permission-escalation.routine`, inline (`--routine-run-inline magic-coordinator.permission-escalation.routine`).
   - the board and what is tagged to you: the board steps below, **reconcile-sessions** to **continue-running**, against the scan's sections. Keep the round's tracking note current as the round proceeds (`--update-routine-state`), referencing items by name rather than copying them.
2. **reconcile-sessions**: compare the scan's session registries with the board before any other board work. Each handler states its outcome, steps:
   - **reconcile-read**: read the spawned-sessions and pending-replies registries, and match each `board-running` item to its session by `session-id`. A pending-replies row's `session-id` is the id of the run that asked, never of the coworking session that run joined.
   - **reconcile-dead-session**: a `board-running` item other than a `dispatch-*` whose session is not live is a failed spawn. Record the registry reading in its `execution-receipt`. It carries `restart-session`: respawn that group at the item's recorded state, outcome `respawned`. Otherwise: move it to `board-blocked` with a `condition` naming the dead session, outcome `flagged-once`.
   - **reconcile-untracked-session**: a live session with no board item is flagged once in `event-track`, naming its session id, member and sandbox. No item is created; whether it becomes tracked work is a judgement. Outcome `flagged-once`.
   - **reconcile-finished-session**: a live session whose tracked work reports finished and which nothing else needs is dismissed (`spawn-one-dispatch`'s **spawn-dismiss**). This covers sessions an earlier round dispatched.
   - **reconcile-lost-reply**: a `board-blocked` item waiting on a reply the registry no longer holds open: read its `communication-channel-id` thread. The addressee's answer is there: apply it and continue the item. None: re-ask the same party in that thread (`AskQuestion`, `wait: false`) and keep the item blocked, outcome `nudged`. A missing record is never consent and never a deny. An open ask never expires by age: the human may be away for weeks. It is closed only when its question is no longer current, is a duplicate, was resolved another way, or its session is complete and closed.
3. **review-items**: for each `board-review` item whose `review-by` is `magic-coordinator`, or is empty and its run reports to `magic-coordinator` (the scan's review-items section lists them), steps:
   - trivial: apply `magic-team.handback-review.routine` to it, inline (`--routine-run-inline magic-team.handback-review.routine`).
   - anything else: leave it in `board-review` for the item's own parent, per "The ladder: one rung at a time".
4. **communication-sweep**: run `magic-coordinator.communication-sweep.routine`'s Steps inline (`--routine-run-inline magic-coordinator.communication-sweep.routine`), against this round's board read.
5. **check-process-board**: run `check-process-board` against this round's read.
6. **start-pending**: start decided `board-pending` work, steps:
   - candidates: approved `board-pending` items with no dispatch recorded. The approval is the go; the running session covers the spawn.
   - conflict gate: any one of these keeps the item in `board-pending`, with `recheck-date` advanced:
     - package or topic overlap with a running job.
     - resource contention shown by a live signal this round: an active lock or channel.
     - a document the item needs, being edited by another live session.
   - "Dispatched earlier today" or "liveness unknown" alone is never evidence. Ambiguous evidence counts as a conflict.
   - start at most one per round, oldest first: spawn its `restart-session` group, or else its `owner`, through `spawn-one-dispatch`, and move it to `board-running`. One item per session.
   - a spawn that fails: move the item to `board-parked` (`--advance-to-parked`) with `condition`, `handoff-action: spawn retry`, `execution-receipt` and `--recheck-in 17`, and post once to `event-track`. Each recheck retries once.
   - this is the only starter of an unrequested `board-pending` item. Another routine may call `spawn-one-dispatch` only on its own instruction.
7. **continue-running**: every `board-running` item, every round, steps:
   - an item whose `recheck-date` is still in the future, or below the staleness threshold, is skipped untouched: no write, no record.
   - `session-id` set: nudge the session with this round's relevant findings (`SendMessage`). Never spawn a second session for it. A failed nudge, or a session with no state change past the staleness threshold, is treated as `session-id` absent.
   - `session-id` absent, and no owning duty: run `magic-team.advance.routine` for it, inline (`--routine-run-inline magic-team.advance.routine`).
   - `session-id` absent, `restart-session` present, and the item's next iteration needs that group: respawn it through `spawn-one-dispatch`, with `--advance-to-running --from-state:running --recheck-in 7±2`.
   - approved, but no session, no `restart-session` and no dispatch recorded, past the threshold since `started-at`: dispatch its `participants`, else its `owner`, through `spawn-one-dispatch`. Outcome `respawned`.
   - console-backed work: check its channel with `--console-list`. A channel expected but gone is flagged, never restarted. A live item that this round's findings concern gets them relayed through its own channel: `SendMessage`, or `--console-send` for console-backed work.
   - a named participant cannot be spawned: move the item to `board-parked` (`--advance-to-parked`) with `condition` naming that participant and a `recheck-date`, and report it.
8. **decide-inline**: for each item of this round, decide inline which it is, and move on, steps:
   - small: work it at once here, as an inline routine (`--routine-run-inline`).
   - larger: prepare its brief, record it and spawn a sub-task (the Agent tool). The sub-task reuses this session's cached prefix, so its first round is cheap.
9. **post-the-round**: post one line into the session thread (`--post-session-channel`): what this round started, moved or flagged, or that it found nothing. Post the round's record to `event-track` (`--slack-send-message`): the outcomes per item and their counts, the items left untouched, and what was started. It never repeats `check-process-board`'s **board-report**.
10. **wait-for-more**: run `DistroAgentsSession.fn.sh --idle-wait`. On an arrival, go to step 1. It returns nothing until one comes; a `DISMISSED` ends the duty.

# Closure steps

None of its own: the Closure steps of its session kind run after a dismissal.

# Routine's local procedures

None.

# Routine's local rules

- Work the input before you wait; never wait with input unworked.
- A round is one run through steps 1 to 9. Where a rule below says "pass" or "round", it means that.
- The tooling does the housekeeping in the main loop, before the scan. It closes dead spawns, moves their items to review and starts missing control threads. It records the dependency edges too. The sections `## board dependencies` and `## recheck dates due` are its findings. The lock of this session is refreshed by its wait and its state writes.
- Apply only moves already decided: an approval recorded, a review accepted, a completion recorded, a condition met. This is what makes the round safe to run unattended. Two bounded judgements are allowed:
  - recording a dependency edge that only an item's text shows (`check-process-board`'s **board-dependencies**).
  - accepting a trivial `board-review` item reviewed by this member.
- The board round decides no go, resolves no blocker by judgement, scores no RICE and triages nothing: those are `magic-team.grooming.routine`'s. An open design question an investigation surfaced is flagged for grooming and `magic-architect`.
- **Working an item**: decide what the item's gap needs, then act this round. Nothing left to decide: do the one concrete action (send, spawn, check) through its operation, verify it happened, and record what was done. A real choice: list the options with their outcome and risk, pick one, record the reasoning on the item, then act. Missing information: get it if one call away; otherwise flag it once, naming the missing fact. An outcome is done only when real state backs it: a message sent, a session spawned, a round run.
- Staleness threshold: 1 hour. At most two respawns per round, oldest `date`/`owner-session-since` first. Work order: by real coverage of the item's goal, then by age; a sub-task count is never the measure.
- Each item is a tracking document. Spawning work on it spawns the group its `participants` names, with the goal, the task, the document and its next iteration. No quorum among that group becomes the no-quorum document, carried the same way.

## Per-round outcomes

- Every due `board-running` item ends the round with one outcome: `nudged`, `advanced`, `respawned`, `redispatched`, `flagged-once` or `no-action`. A spawn-failure park is `parked-spawn-failed`. "Deferred" is invalid.
- `no-action` has exactly four valid reasons:
  - no row and no `handler-routine:` matches the item.
  - the digest marks the item `held`.
  - its owner's live duty holds it.
  - a temporary error this round stopped the real handling.
- `execution-receipt` is one of: a spawn receipt id, a dispatch or session id, `inline:<timestamp>`, or `no-action:<reason-code>`.
- Bookkeeping-only outcomes for several items go in one `--advance-batch-outcome` call. `interview-*` and `proposal-*` outcomes never do: each comes from its own round.
- A side-effecting call (spawn, nudge, redispatch, park) is followed by `--advance-sleep-run` before the next item.

## What reaches the human-owner

- The whole record of a round goes to `event-track`. Keep it current as things are found, not batched.
- A DM goes only for something he can act on:
  - a decision only he can make.
  - something blocked on him that he does not know.
  - something that changes what he believed.
- A tally, an extension, a re-confirmed no-action or "nothing new" never qualifies.
- A round with nothing qualifying sends nothing. That is the step completing.
- A DM carries one topic and leads with what is needed. A continuation goes into its own thread; a new topic is a new message.
- A `recheck-date` is set with `--recheck-in <minutes>[±<jitter-minutes>]`, never computed by hand.

# Routine-specific tooling

- `--idle-wait [--wait-timeout <seconds>]`
- `--post-session-channel [--address-to <team-member>]... (<text...>|--from-stdin)`
- `--routine-run-inline <routine>`
- `--update-routine-state [--document <note>] [--header:upsert:<name>:<value>]... [--header:remove:<name>]... [--from-file <path>|--edit-patch-from-stdin]`
- `--advance-to-running <item-filename> --from-state:<state> [--header:...]...`
- `--advance-to-parked <item-filename> --from-state:<state> [--header:...]...`
- `--move-to-blocked <item-filename> --from-state:<state> [--header:...]...`
- `--move-to-processed <item-filename> --from-state:<state> [--header:...]...`
- `--advance-batch-outcome <team-member> --items:<item-filename>:<outcome>:<execution-receipt>[,...]`
- `--advance-sleep-run`
- `--slack-send-message <target> [text...]`
- `--console-list`
- `--console-send <channel> [-- <command...>]`
- `--skillset-upsert <team-member> <pathname>`
- `--queue-list`
- `--queue-take`
- `--queue-done <name>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine does the periodic board reconciliation process-flow needs to keep moving — without it, board state can drift from reality between full daily/grooming cycles.
- `check-process-board`'s own dependencies step exists so task-ordering/dependency reasoning (what blocks what) is a standing, repeatable step recorded on the board itself — not a one-off answer that evaporates once the conversation moves on.
- The round's full record is kept without spending the human-owner's attention on it: the record goes to `slack-event-track` every round, and his own channel carries only what he can act on.

## Verbatim-tests (benchmarks)

- A round re-confirms every `board-running` item and finds nothing needing him. It posts the full record to `slack-event-track` and sends him nothing — the silence is the closing step completing, not a step skipped.
- A `board-running` item whose own content already says it moved to `board-blocked`, but is still physically sitting in `board-running`, gets moved to match — without waiting for the next grooming round.
- Dependency reasoning worked out ad hoc in a chat reply gets recorded on the board-item files themselves — the next round doesn't have to redo it from scratch.
- An approved `board-running` item carrying none of `session-id`, `restart-session:`, an active console session, or an unresolved dispatch note, sitting past the staleness threshold, gets a real dispatch this round — never a blanket `no-action` stamp with nothing actually tried.
- A `session-id`-set item that keeps getting nudged with zero observed state change past the staleness threshold is treated as if the nudge failed — not renudged indefinitely as "still working."
- A high-RICE item blocked on a low-RICE one still records the gate plainly — never silently reordered to make the numbers look consistent.

## Librarian Comments

### Reference

- `magic-team.advance.routine` — the next iteration of each running document, run at **continue-running**.
- `magic-coordinator.armed.md` — `check-process-board`, `check-pending-comms-actions`, `spawn-one-dispatch`.
- `magic-team/reference/board-model.md` — board states and the advance/grooming split.

### Conventions

- **reconcile-sessions**, **review-items**, **communication-sweep**, **check-process-board**, **start-pending** and **continue-running** are cited by name from other files.
