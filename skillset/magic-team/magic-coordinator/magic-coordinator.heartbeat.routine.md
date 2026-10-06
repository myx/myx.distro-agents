---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-coordinator.heartbeat.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
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
  - Run `magic-coordinator.external-inbox-handle-loop.routine` and `magic-coordinator.advance.routine` inline.
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

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **check-required-config**: Run `--magic-heartbeat-config-check`. On a FAIL, report the output (each FAIL line carries its fix) and go to **report-status-to-spawner**: nothing else runs this pass.
2. **acquire-lock**: Run the `single-instance-lock` procedure's acquire. Contention means another pass is live: go to **report-status-to-spawner**, nothing else runs. An unexpected lock state is reported in the pass status.
3. **read-state-and-branch**: Read the `heartbeat-state-note` (`--magic-heartbeat-state-read`) and pick this pass's branch by the `day-rhythm-state` procedure.
4. **load-iteration-input**: Run `--magic-heartbeat-input-scan`. The steps below work from it.
5. **handle-external-owner-items**: Run `magic-coordinator.external-inbox-handle-loop.routine` inline.
6. **dispatch-due-routine**: Per the branch, steps:
   - first-today: dispatch `magic-team.grooming.routine` through `spawn-one-dispatch` (`--magic-spawn-session --routine magic-team.grooming`), and set `today-stage: grooming-dispatched`.
   - later-today, `today-stage: grooming-dispatched`, and `--magic-grooming-lock-status` shows today's grooming finished: dispatch `magic-coordinator.daily.routine` the same way, and set `today-stage: daily-dispatched`.
   - weekend, or nothing due: dispatch nothing.
7. **send-test-report**: Once an hour has passed since `last-test-email-sent`, email the human-owner a test report (`--member-comms-email-send`): a pass header, the `## board counts` from `--magic-heartbeat-input-scan`, and one line per active or blocked item from `--magic-advance-input-scan`'s rows (`<state>/<item-filename>`). Record `last-test-email-sent`. This step runs on every branch.
8. **register-owner-decisions**: An open decision this pass found that only the human-owner can make becomes an `approval-*` item in `board-running` (`--magic-board-create-running`, `blocks` set to the item it gates) unless one exists. Advance asks and re-asks it.
9. **update-heartbeat-state**: Rewrite the `heartbeat-state-note` (`--magic-heartbeat-state-upsert`) with this pass's `last-iteration-date`, `last-iteration-timestamp` and `today-stage`, and one short "Last iteration" paragraph replacing the previous one. Anything worth keeping beyond this pass goes to the session thread or a `reflection-*`, never into this note.
10. **run-advance**: Run one `magic-coordinator.advance.routine` pass inline, every pass, last. This pass is not finished, and the lock is not released, until advance has finished.

# Closure steps

1. **close-state-and-unlock**: Release the lock with `--magic-heartbeat-close-state-and-unlock`. Reached only after **run-advance** finished.
2. **conclude-event-track-thread**: React ✅ on the pass's session thread root (`--member-comms-slack-react`).
3. **report-status-to-spawner**: Report the pass status, advance's outcome included, to the spawner, then hand back and end: the host loop is blocked on this pass (`magic-team.armed.md`'s **wait-never-quit** exception).

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

## `day-rhythm-state` — what is due today

- `heartbeat-state-note` fields: `last-iteration-date`, `last-iteration-timestamp`, `today-stage` (`not-started` → `grooming-dispatched` → `daily-dispatched`), `last-test-email-sent`, `human-owner-broadcast-thread-ts`/`human-owner-broadcast-thread-date` (today's human-owner DM thread), and `active-project` (the project today's dispatched work belongs to). `NO_STATE` means a first run.
- First-today: `last-iteration-date` differs from today's real date, or no state. `today-stage` resets to `not-started`.
- Later-today: the dates match; continue from `today-stage`.
- Weekend: recompute the weekday from the real date every pass. Saturday and Sunday allow comms and reactive admin only, in answer to an actual request. Grooming, daily and work dispatch are denied, unless the work is tied to a live human-owner activity a `magic-coordinator` in contact with him confirmed firsthand.
- The branch is date-driven. Low activity on a weekday is no reason to skip a step.

## `single-instance-lock` — one pass at a time

- Acquire with `--magic-heartbeat-lock-acquire <team-member> main-loop` before any other step.
- Each `--magic-heartbeat-state-upsert` refreshes it; `--magic-heartbeat-lock-refresh` only for a long stretch without a state write.
- Release in **close-state-and-unlock**, every pass that acquired it.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- This routine extends `magic-team.coworking.routine`, with these overrides: the pass's session thread is the `event-track` thread the tooling opened for it; **fold-in-learned-lessons** does not run; the opening and closing groups reduce to posting into that thread and **conclude-event-track-thread**.
- Post a short progress line into the session thread after each step. Something the human-owner must act on goes per `magic-team.shared.md`'s "Anything needing the human-owner to act reaches him on his own direct channel".
- Between steps, read what spawned sessions sent. Assess each, dispatch any real work through `spawn-one-dispatch`, and record the outcome in the session thread.
- Running unattended, every caution rule applies at full strength: no unilateral epics, the per-platform send rules, no manufactured work.
- A real pass follows existing instructions and operations, one plain call at a time. A better approach that occurs mid-pass is filed as an idea, never built inline. Testing and investigation sessions are exempt.
- New work found mid-pass is filed into an inbox or the board queue. Only the human-owner's live override in answer to an active blocker skips the queue.
- A permission prompt mid-pass means a call bypassed the tooling channel, or a configuration gap. Report it; never work around it.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-heartbeat-config-check`
- `--magic-heartbeat-lock-acquire <team-member> <owner-label>`
- `--magic-heartbeat-lock-refresh <team-member>`
- `--magic-heartbeat-close-state-and-unlock <team-member>`
- `--magic-heartbeat-state-read <team-member>`
- `--magic-heartbeat-state-upsert <team-member>`
- `--magic-heartbeat-input-scan <team-member>`
- `--magic-advance-input-scan <team-member>`
- `--magic-grooming-lock-status <team-member>`
- `--magic-spawn-session (--routine <selector>|--routine-default) [<team-member>...]`
- `--magic-board-create-running <team-member> <item-filename> [--header:...]...`
- `--member-comms-email-send <team-member> <email@address>... -- <subject> -- <body...>`
- `--member-comms-slack-send-message <team-member> <target> [text...]`
- `--member-comms-slack-react <team-member> <channel>:<ts> <emoji-name>`

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
- `magic-team.grooming.routine`, `magic-coordinator.daily.routine` — dispatched at **dispatch-due-routine**.
- The host loop and its call contract — this package's own `MAGIC.md`.

### Conventions

- Preserve the single-instance lock, the day-rhythm state machine, the one-pass shape and the inline advance precisely. Each exists to prevent a failure mode that summarising would reintroduce.
