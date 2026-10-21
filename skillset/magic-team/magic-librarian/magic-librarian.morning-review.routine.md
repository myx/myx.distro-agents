---
type: routine
executors: magic-librarian
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
allows: magic-librarian:skillset-upsert
reports-to: none
requires-session-kind: standalone
runs-at: workdays 09:00
routine-lock-document: inbox:magic-librarian:note-20261008T000000Z-morning-review-state.md
input-scan-def: morning-review
review-by: inherit
---
# magic-librarian.morning-review.routine — the actual procedure

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

`magic-librarian.morning-review.routine` is the once-per-workday `magic-librarian` checkpoint for board state-model drift and cross-file consistency. People call it the board-review session: a literal review of the board, not the `review` board state or `magic-team.handback-review.routine`.

## Goals

- Catch structural drift: does the board's state model still match what it represents, and do claims in one file still hold against another file's current content.
- Give the board a second pair of eyes once a day, `magic-librarian` alone.

## Scope

- Does:
  - Check state-model drift and cross-file consistency.
  - Run as a standalone session of `magic-librarian`, started by its autorun (`runs-at:`), the first of the day's chain: the grooming follows it, then the daily.
- Doesn't:
  - The broad skillset audit — `magic-librarian`'s `team-self-sufficiency-audit`.
  - Board writes by `magic-librarian`, or garbage collection.
  - Rechecking blocked and parked items — `magic-coordinator.advance.routine` and `magic-team.grooming.routine`.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **read-board-shape**: `magic-librarian` reads this run's input scan result (`input/input-scan.md`).
2. **check-state-shape-drift**: Check the state model itself, not only content, from the scan's state shape — for example `board-blocked` and `board-parked` items collapsed into `board-running` or `board-archived`, losing the difference between "stalled on something external" and "deliberately deferred".
   - step: check the skillset files the scan lists as changed for accreted dated narration, per `magic-librarian/magic-librarian.armed.md`'s "Skillset content hygiene"; a rewrite is proposed for the skillset change rule.
3. **check-cross-file-consistency**: Check status claims in one file against the current content of another, starting from the skillset files the scan lists as changed.

# Closure steps

1. **advance-cutoff**: `magic-librarian` updates the routine's state with the new cut-off: `--update-routine-state --header:upsert:last_reviewed_ts:<the scan's next: value>`.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- Only `magic-coordinator` writes the board (`magic-team/reference/board-model.md`).
- A state-model drift outranks ordinary staleness: fix the model gap, not only the one instance, since one gap likely misfiled several items.
- A cross-file inconsistency where it is unclear which file is right is surfaced and resolved explicitly, never by silently picking a winner. No quorum there is the no-quorum document, carried up by "The ladder: one rung at a time".
- A finding that is not about the board goes to `magic-librarian`'s own daily audit with `post-inquiry`.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## Tooling operations

- `--update-routine-state [--document <note>] [--header:upsert:<name>:<value>]... [--header:remove:<name>]... [--from-file <path>|--edit-patch-from-stdin]`
- `--upsert-inbox-inquiry <team-member> <item-filename>`
- `--skillset-upsert <team-member> <pathname>`
- `--queue-list`
- `--queue-take`
- `--queue-done <name>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This session's real purpose is catching structural drift — does the board's own state model still match what it's supposed to represent, and do claims in one file still hold against another file's real current content.

## Verbatim-tests (benchmarks)

- This session has exactly one responsibility — the board-review session described in its own Goals section, not two.
- `magic-librarian` finds a misfiled item. It reports it; `magic-coordinator` moves it.

## Librarian Comments

### Reference

- `magic-team.grooming.routine` — runs after this routine (`runs-after:`), on each workday.
- `magic-team/reference/board-model.md` — the state model checked here.

### Conventions

- none
