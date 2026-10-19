---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: coworking
skips-inherited: declare-session-type, assign-transcript-name, fold-in-learned-lessons, collect-reflections-output, secure-continuity, compact-session-context, offer-skill-update-discussion, conclude-session-thread, dismiss-participants
routine-lock-document: inbox:magic-coordinator:note-20260809T155000Z-heartbeat-state-and-lock.md, inbox:magic-coordinator:note-20260809T154715Z-advance-state-and-lock.md
input-scan-def: heartbeat
review-by: inherit
---
# magic-coordinator.heartbeat.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Opening steps
- Steps
- Closure steps
- Routine's local procedures
  - `day-rhythm-state` — what is due today
  - `single-instance-lock` — one pass at a time
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

`magic-coordinator.heartbeat.routine` is one `main-loop` pass: it decides what is due, dispatches it, and runs one advance pass inline.

## Goals

- Give the team a continuous operating rhythm, seven days a week, that does not wait for a human to re-trigger each step.
- Every pass runs `magic-coordinator.advance.routine`. The backlog is groomed once a day, and the daily meeting's work session happens.

## Scope

- Does:
  - Run as one pass, spawned by the host loop through `--intern-root-harness --routine heartbeat --non-interactive`. No member starts, stops or relays into it.
  - Dispatch `magic-team.grooming.routine` and `magic-coordinator.daily.routine` as their own sessions when due.
  - Run `magic-coordinator.external-inbox-handle-loop.routine`, `magic-coordinator.permission-escalation.routine` and `magic-coordinator.advance.routine` inline.
  - Keep the `heartbeat-state-note` current.
- Doesn't:
  - Repeat itself. Repetition is the host loop's.
  - Run `magic-coordinator.retro.routine`, which is manual.
  - Work board items itself. Its board work happens inside the advance pass, apart from registering a decision only the human-owner can make.
- Open, pending:
  - Open: the team calendar / full-sprint routine each pass would check what is due against. Until it exists, the `day-rhythm-state` procedure decides.
  - Open: autonomous retro invocation from a day-rhythm branch; retro stays manual until designed.
  - Open: the real report cadence — hourly during the day and an evening wrap-up — and its HTML/multipart layout. **send-test-report** is the hourly testing stand-in.
  - Open: a light staleness check across acting members' inboxes, raising a `warning-*` for a member's stale item. It waits for a scan that reads other members' inbox ages.
  - Open: slow-tier platforms (deep Trello board reads, Google Drive/Sheets, Confluence) checked every few passes or from grooming, not every pass.
  - Open: what happens to an advance pass that hangs. The human-owner's policy call; no bound is set.
  - Open: `TEAM-ORGANIZATION-VISION.md` addenda for main-loop elevation and the architect's resolution of it.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **check-required-config**: Run `--magic-heartbeat-config-check`. On a FAIL, report the output (each FAIL line carries its fix) and go to **report-status-to-spawner**: nothing else runs this pass.
2. **read-state-and-branch**: Read this run's input scan result (`input/input-scan.md`) by line range, and do not scan again. Its `branch:`, `today-stage:` and `grooming-today:` lines decide this pass, by the `day-rhythm-state` procedure. The steps below work from it.
3. **handle-external-owner-items**: Run `magic-coordinator.external-inbox-handle-loop.routine` inline (`--routine-run-inline magic-coordinator.external-inbox-handle-loop.routine`).
4. **handle-permission-asks**: Run `magic-coordinator.permission-escalation.routine` inline (`--routine-run-inline magic-coordinator.permission-escalation.routine`). Its input scan reading `(none)` ends it at once.
5. **dispatch-due-routine**: Per the branch, steps:
   - first-today: dispatch `magic-team.grooming.routine` through `spawn-one-dispatch` (`--magic-spawn-session --routine magic-team.grooming`), and set `today-stage: grooming-dispatched`.
   - later-today, `today-stage: grooming-dispatched`, and `grooming-today: finished`: dispatch `magic-coordinator.daily.routine` the same way, and set `today-stage: daily-dispatched`.
   - weekend, or nothing due: dispatch nothing.
6. **send-test-report**: Run `--magic-heartbeat-test-report-send`, every branch. `NOT_DUE` is not a failure.
7. **register-owner-decisions**: An open decision this pass found that only the human-owner can make becomes an `approval-*` item in `board-running` (`--magic-board-create-running`, `blocks` set to the item it gates) unless one exists. Advance asks and re-asks it. Running unattended, nobody is present to work it out first — the "no parent present" branch of "The ladder: one rung at a time" applies.
8. **update-heartbeat-state**: Rewrite the `heartbeat-state-note` (`--update-routine-state --document note-20260809T155000Z-heartbeat-state-and-lock.md`) with this pass's `today-stage` and one short "Last iteration" paragraph replacing the previous one. Anything worth keeping beyond this pass goes to the session thread or a `reflection-*`, never into this note.
9. **run-advance**: Run one `magic-coordinator.advance.routine` pass inline (`--routine-run-inline magic-coordinator.advance.routine`), every pass, last. This pass is not finished, and the lock is not released, until advance has finished.

# Closure steps

1. **conclude-event-track-thread**: React ✅ on the pass's tracking thread root (`--member-comms-slack-react`).
2. **report-status-to-spawner**: Report the pass status, advance's outcome included, to the spawner, then hand back and end: the host loop is blocked on this pass (`magic-team.armed.md`'s **wait-never-quit** exception). The report states what was agreed this pass, per "The ladder: one rung at a time".

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

## `day-rhythm-state` — what is due today

- `today-stage` runs `not-started` → `grooming-dispatched` → `daily-dispatched`. The scan computes the branch and resets the stage on a new day.
- Weekend allows comms and reactive admin only, in answer to an actual request. Grooming, daily and work dispatch are denied, unless the work is tied to a live human-owner activity a `magic-coordinator` in contact with him confirmed firsthand.
- The branch is date-driven. Low activity on a weekday is no reason to skip a step.

## `single-instance-lock` — one pass at a time

- The spawner takes the lock before any step runs (`routine-lock-document:`), and the start fails while another pass holds it.
- Each `--update-routine-state` refreshes it; `--magic-heartbeat-lock-refresh` only for a long stretch without a state write.
- The spawner gives the lock back when the session ends, every pass that took it.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- This routine extends `magic-team.coworking.routine`, with these overrides: while the pass runs alone it has a tracking thread in `event-track`, never a session thread; the first member it brings in opens the session thread in `magic-team`, addressed to that member; the opening and closing groups reduce, through `skips-inherited:`, to posting into the tracking thread and **conclude-event-track-thread**.
- Post a short progress line into the tracking thread after each step. Something the human-owner must act on goes per `magic-team.armed.md`'s "Anything needing the human-owner to act reaches him on his own direct channel".
- Between steps, read what spawned sessions sent. Assess each, dispatch any real work through `spawn-one-dispatch`, and record the outcome in the tracking thread.
- Running unattended, every caution rule applies at full strength: no unilateral epics, the per-platform send rules, no manufactured work.
- A real pass follows existing instructions and operations, one plain call at a time. A better approach that occurs mid-pass is filed as an idea, never built inline. Testing and investigation sessions are exempt.
- New work found mid-pass is filed into an inbox or the board queue. Only the human-owner's live override in answer to an active blocker skips the queue.
- A permission prompt mid-pass means a call bypassed the tooling channel, or a configuration gap. Report it; never work around it.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-heartbeat-config-check`
- `--magic-heartbeat-lock-refresh <team-member>`
- `--update-routine-state [--document <note>] [--header:upsert:<name>:<value>]... [--header:remove:<name>]... [--from-file <path>|--edit-patch-from-stdin]`
- `--magic-heartbeat-test-report-send <team-member>`
- `--magic-spawn-session (--routine <selector>|--routine-default) [--spawn-settings-workspace <name>] [--spawn-cli-service <name>] [<team-member>...]`
- `--magic-board-create-running <team-member> <item-filename> [--header:...]...`
- `--member-comms-slack-send-message <team-member> <target> [text...]`
- `--member-comms-slack-react <team-member> <channel>:<ts> <emoji-name>`
- `--routine-run-inline <routine>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- `magic-coordinator.heartbeat.routine` is a thin orchestration layer over `magic-team.grooming.routine`/`magic-coordinator.daily.routine` — it feeds the daily meeting better material, it doesn't replace human-supervised decisions.
- New work always files into the relevant inbox or board queue first — never routed around because it's convenient in the moment.
- Give the team a real, continuous operating rhythm instead of only ever doing work when a human happens to be present asking for it.

## Verbatim-tests (benchmarks)

- New work discovered mid-loop files into the relevant inbox or board queue rather than `main-loop` routing around it inline because it's convenient.
- If this routine is already running (holding its own lock) and gets invoked again from anywhere, the second invocation's own lock-acquire fails and it exits without duplicating any work.
- A pass whose **Board advance** step has not yet finished has not reached any Closure step: its lock is still held, no ✅ has been reacted, and no status has been reported. A pass that released the lock or reacted ✅ with advance unfinished has failed, however complete its report reads.

## Librarian Comments

### Reference

- `magic-coordinator.advance.routine` — run inline at **run-advance** (the "Board advance" step the benchmarks name); it runs the comms sweep and inbox processing.
- `magic-coordinator.external-inbox-handle-loop.routine` — run inline at **handle-external-owner-items**.
- `magic-coordinator.permission-escalation.routine` — run inline at **handle-permission-asks**.
- `magic-team.grooming.routine`, `magic-coordinator.daily.routine` — dispatched at **dispatch-due-routine**.
- The host loop and its call contract — this package's own `MAGIC.md`.

### Conventions

- Preserve the single-instance lock, the day-rhythm state machine, the one-pass shape and the inline advance precisely. Each exists to prevent a failure mode that summarising would reintroduce.
