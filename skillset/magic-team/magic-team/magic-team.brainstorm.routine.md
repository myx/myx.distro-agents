---
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
session: coworking
---
# magic-team.brainstorm.routine — the actual procedure

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

`magic-team.brainstorm.routine` generates ideas, "crazy" ones included, and assesses them lightly, with no pressure to decide.

## Goals

- Fill a goal that has no good options yet with ideas to investigate and rank. Forcing convergence here kills the crazy idea that turns out good.
- Hand promising ideas on to `magic-team.discuss.routine` or the task-creation lifecycle; a brainstorm never decides.

## Scope

- Does:
  - Idea generation and light assessment. Any member runs it, on request.
- Doesn't:
  - Decide (`magic-team.discuss.routine`), capture one party's vision (`magic-team.interview.routine`), or review feasibility in depth.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **process-own-inbox**: run `magic-team.process-inbox.routine <own-name>`, collecting ideas parked there earlier.
2. **set-topic-loosely**: state the area, kept open. An example given with the topic is a floor, never a ceiling, unless a ceiling was stated.
3. **generate-without-filtering**: put out ideas, the impractical and unlikely included. The first reasonable idea never ends generation.
4. **assess-lightly**: give each idea a quick read — promising, interesting but needs work, or probably not — and why.
5. **hand-off-promising-ideas**: file each promising idea for real evaluation, steps:
   - propose the item (piece, type, goal) and wait for confirmation, unless the human-owner asked for that filing.
   - `magic-coordinator` files it as an `idea-*` item, or folds it into the item it relates to. Another executor hands it to `magic-coordinator` with `post-inquiry`.
   - it continues in `magic-team.discuss.routine` when it needs a decision or has real tradeoffs, or straight into the task-creation lifecycle when it is already clear-cut.

# Closure steps

1. **close-session**: run `magic-team.coworking.routine`'s **close-session** group.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- The executing member is permitted and obliged to execute every step exactly as written, in order.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- Ending with several candidates and no winner is a valid outcome. Nothing promising is valid too; never manufacture a winner.
- An idea that sounds bad stands during generation; filtering happens at **assess-lightly**.
- One idea steering toward a decision: return to generation while there is ground left, or say the session has become a discussion.
- Every exchange is kept as a `transcript-*` with `--member-append-session-transcript`. Waiting follows **wait-never-quit**.
- Goal-directedness: cover the loosely set topic. Off-goal items are recorded quickly, not acted on now.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-append-session-transcript <team-member> --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <text>|--from-stdin|--from-file <path>) --transcript-name <transcript-file-name> [--create]`
- `--member-upsert-member-inquiry <member> <item-filename> [--from-file <path>]`
- `--magic-grooming-create-backlog <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...` — `magic-coordinator` only

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives the team a lower-stakes place to throw out ideas, including "crazy" ones, without the pressure of reaching a decision or precisely capturing one party's settled vision.

## Verbatim-tests (benchmarks)

- A brainstorm session ending with several live candidate ideas and no chosen winner is a normal, valid outcome, not an incomplete session.

## Librarian Comments

### Reference

- `magic-team.discuss.routine` — the follow-on for a promising idea needing a decision.
- `magic-team.interview.routine` — capture of one party's vision.

### Conventions

None.
