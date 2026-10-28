---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: coworking
skips-inherited: fold-in-learned-lessons, dismiss-participants
routine-lock-document: inbox:{{team-member}}:note-20260809T154715Z-advance-state-and-lock.md
input-scan-def: work-duty --session-id {{session-id}} --wait 300
wait-sources: inbox:{{team-member}} board:pending board:running board:review board:blocked board:parked
review-by: inherit
cache-prefix: routine
runs-at: none
---
# magic-coordinator.advance.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Opening steps
- Steps
- Closure steps
- Routine's local procedures
- Routine's local rules
- Routine-specific tooling
  - Tooling operations
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions

# Summary

`magic-coordinator.advance.routine` is a stub. The coordinator's board round is `magic-coordinator.work-duty.routine`'s board steps, and the next iteration of each running document is `magic-team.advance.routine`. This file stays until the tooling that starts it by name points at those.

## Goals

- Keep a console's manual start, and the tooling that names this file, working while they move to the new routines.

## Scope

- Does: one board round, by `magic-coordinator.work-duty.routine`'s steps, for a manual or tooling start.
- Doesn't: carry any rule of its own. Every rule is in the two routines it points to.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **run-the-board-round**: run `magic-coordinator.work-duty.routine`'s steps **work-the-input** to **post-the-round** once, against this run's scan. They include the inbox (`--routine-run-inline magic-team.process-inbox.routine`), the trivial reviews (`--routine-run-inline magic-team.handback-review.routine`) and the communication sweep (`--routine-run-inline magic-coordinator.communication-sweep.routine`). Never run its **wait-for-more**.

# Closure steps

None of its own: the Closure steps of the routine it inherits from run (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- The rules of the round are `magic-coordinator.work-duty.routine`'s, as written there.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## Tooling operations

- `--routine-run-inline <routine>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- The board round's goals and benchmarks are kept in `magic-coordinator.work-duty.routine`'s Maintainer Notes.

## Verbatim-tests (benchmarks)

- A manual start of this routine runs one board round and ends; it never waits for more.

## Librarian Comments

### Reference

- `magic-coordinator.work-duty.routine` — the board round.
- `magic-team.advance.routine` — the next iteration of each running document.

### Conventions

- Remove this file once `AgentsTools.DispatcherLoop.include`, `AgentsTools.BoardRoundScan.include`, `AgentsTools.RoutineLock.include`, `AgentsTools.SpawnHousekeeping.include` and their checks name the new routines.
