---
executors: magic-coordinator, magic-librarian
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
session: coworking
---
# magic-librarian.morning-review.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Steps
- Closure steps
- Routine's local procedures
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

`magic-librarian.morning-review.routine` is the once-per-workday joint `magic-coordinator` and `magic-librarian` checkpoint for board state-model drift and cross-file consistency. People call it the board-review session: a literal review of the board, not the `review` board state or `magic-team.handback-review.routine`.

## Goals

- Catch structural drift: does the board's state model still match what it represents, and do claims in one file still hold against another file's current content.
- Give the board a second pair of eyes once a day, `magic-coordinator` leading.

## Scope

- Does:
  - Check state-model drift and cross-file consistency.
  - Run as a coworking session, started by `magic-coordinator.daily.routine`'s **spawn-morning-review**.
- Doesn't:
  - The broad skillset audit — `magic-librarian`'s `team-self-sufficiency-audit`.
  - Board writes by `magic-librarian`, or garbage collection.
  - Rechecking blocked and parked items — `magic-coordinator.advance.routine` and `magic-team.grooming.routine`.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **session-start**: Execute `magic-team.coworking.routine`'s Steps, with `magic-coordinator` and `magic-librarian` as participants.
2. **read-board-shape**: `magic-coordinator` reads `--magic-morning-review-input-scan`, and shares the result with `magic-librarian`.
3. **check-state-shape-drift**: Check the state model itself, not only content, from the scan's state shape — for example `board-blocked` and `board-parked` items collapsed into `board-running` or `board-archived`, losing the difference between "stalled on something external" and "deliberately deferred".
   - step: check the skillset files the scan lists as changed for accreted dated narration, per `magic-librarian/magic-librarian.armed.md`'s "Skillset content hygiene"; a rewrite is proposed for the skillset change rule.
4. **check-cross-file-consistency**: Check status claims in one file against the current content of another, starting from the skillset files the scan lists as changed.

# Closure steps

1. **advance-cutoff**: `magic-coordinator` runs `--magic-morning-review-state-advance` with the scan's `next:` value.
2. **close-session**: Execute `magic-team.coworking.routine`'s Closure steps.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- This routine extends `magic-team.coworking.routine`; on a conflict, this file wins.
- Only `magic-coordinator` writes the board (`magic-team/magic-team.board.md`).
- A state-model drift outranks ordinary staleness: fix the model gap, not only the one instance, since one gap likely misfiled several items.
- A cross-file inconsistency where it is unclear which file is right is surfaced and resolved explicitly, never by silently picking a winner.
- A finding that is not about the board goes to `magic-librarian`'s own daily audit with `post-inquiry`.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-morning-review-input-scan <team-member>`
- `--magic-morning-review-state-advance <team-member> <ts>`
- `--member-upsert-member-inquiry <team-member> <item-filename>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This session's real purpose is catching structural drift — does the board's own state model still match what it's supposed to represent, and do claims in one file still hold against another file's real current content.

## Verbatim-tests (benchmarks)

- This session has exactly one responsibility — the board-review session described in its own Goals section, not two.
- `magic-librarian` finds a misfiled item. It reports it; `magic-coordinator` moves it.

## Librarian Comments

### Reference

- `magic-coordinator.daily.routine` — starts this routine at **spawn-morning-review**.
- `magic-team.coworking.routine` — the routine this one extends.
- `magic-team/magic-team.board.md` — the state model checked here.

### Conventions

- none
