---
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-team.handback-review.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Steps
- Closure steps
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

`magic-team.handback-review.routine` is how a reviewer settles a `board-review` item: a handback arrived, or its child ended with no verdict. Its executor is the reviewer the item's `review-by` names; it is assigned to the `board-review` state.

## Goals

- Every handback gets a verdict from the reviewer it names, and the verdict ends or continues the work on purpose, never by silence.
- The reviewer chooses freely: any verdict, any combination, in any order.

## Scope

- Does:
  - Read the item, the handback, the output and the item's `## Decisions`.
  - Choose a verdict, or a combination, and run its operations.
- Doesn't:
  - Move the item or dismiss the child by hand: the operations do that, and record it.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **review-read**: Read the item, its handback, the output it names, and its `## Decisions`.
2. **review-choose**: Choose a verdict, or a combination of them:
   - accept: the work is done.
   - return: the same session continues, with your corrections. You may edit its documents or its sandbox first.
   - reject: the item goes back to `board-pending`, for a fresh session, with your corrections.
   - follow-up: a new pending item for work the handback left open.
3. **review-apply**: Run the operation of each chosen verdict.

# Closure steps

No closing tail of its own: **review-apply** closes it.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- Every verdict and every combination of verdicts is allowed by every policy. The examples below are floors, not limits:
  - accept, then spawn 12 parallel follow-ups for 12 separate imperfections;
  - return to the same session after editing its documents;
  - reject, and respawn on a different CLI or tier.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-board-item-read <team-member> <item-name> [--board-state <state>]...`
- `--member-review-accept <team-member> <item-filename> [--summary <text>]`
- `--member-review-return <team-member> <item-filename> (--message <text>|--from-stdin)`
- `--member-review-reject <team-member> <item-filename> (--message <text>|--from-stdin)`
- `--member-review-follow-up <team-member> <item-filename> <new-item-name> --from-stdin`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- An agent never quits on its own: the system or its caller orders every end, and a handback's verdict is one of those orders.
- Tooling does the mechanical work; this routine only says what a reviewer may do.

## Verbatim-tests (benchmarks)

- A reviewer accepts, then spawns 12 follow-ups for 12 imperfections in one pass: allowed.
- A reviewer edits the session's documents, then returns it: the same session continues with the corrections.

## Librarian Comments

### Reference

- `magic-team.board.md` — the `board-review` state.
- `magic-team.armed.md` — **wait-never-quit**.
- `myx.distro-agents/MAGIC.md` — "Review and ordered endings", the mechanics.

### Conventions

None.
