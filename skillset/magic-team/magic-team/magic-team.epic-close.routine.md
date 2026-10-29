---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: standalone
runs-at: none
review-by: inherit
---
# magic-team.epic-close.routine — the actual procedure

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

`magic-team.epic-close.routine` closes an epic in this order. First the
owner's commit before the last large change, then the final run, then the
librarian pass, then the owner's rig update. Last, the scratch is packed into
the next epic's input and deleted.

## Goals

- End the epic cleanly: nothing applied is left uncommitted, untested or unreported.
- Feed the librarian pass from the builders' knowledge lines, never a loose file.
- Pack and delete the run's scratch into the next epic's input, so nothing of the run lingers.

## Scope

- Does: the ordered close of one epic, after every feature is done or moved.
- Doesn't: build, or re-decide what the epic already settled. This routine runs the close, not the work.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, `magic-team.standalone.routine`).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **owner-commit**: Tell the owner a large change is about to start, and get his commit before it, so its diff stands apart.
2. **final-run**: Run the final run: the retests and the guards, once, late. Run
the whole suite only before one large atomic switch, in a scratch, never on
live.
3. **librarian-pass**: Run the librarian pass over the builders' knowledge lines, from the librarian's queue (`AgentLibrarianTools.fn.sh --queue-take`, `--queue-done`), never a loose file.
4. **rig-update**: The owner runs his rig update. The fixes kept under "The rigs,
once, at the end" are then applied in place, once, after the installer update.
5. **pack-delete**: Pack every temporary file and scratch folder of the run into
the next epic's input, and delete them from the workspace. That way nothing of
the run lingers.

# Closure steps

Run inline: none. Run as its own session: none of its own.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- The owner commits what is applied; this routine tells him when, and never commits for him.
- No production host is touched: the rigs get changes only through their installers, fixed in place once, at the epic's end.
- The builders' knowledge lines reach the librarian through the queue (`--request-update`), never a loose file.
- The tail moves to the next epic's input; nothing of the run is deleted before it is packed there.
- Keep `event-track` current as the routine runs.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## Tooling operations

- `--queue-take`
- `--queue-done <name> --apply | --refuse <reason> | --result <text>`
- `--slack-send-message <target> [text...]`
- `--intern-op-state-note-upsert magic-coordinator`
- `--state-note-read magic-coordinator`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- An epic closes only when every feature is done or moved, and nothing of the run lingers after it.

## Verbatim-tests (benchmarks)

- A scratch folder still standing after the close is a fault, unless it was packed into the next epic's input first.

## Librarian Comments

### Reference

- `magic-team.epic-wave.routine` — the loop that ends before this routine begins.
- `AgentLibrarianTools.fn.sh` — the queue this routine drains in **librarian-pass**.

### Conventions

- The close is ordered and final: commit, final run, librarian pass, rig update, pack-and-delete — in that order, never out of order.
