---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
invitees: human-owner
---
# magic-coordinator.coordination-session.routine — the actual procedure

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

`magic-coordinator.coordination-session.routine` is the loop a `magic-coordinator` instance runs in `coordination-session` mode: comms, board advance, and the session's own goal.

## Goals

- Give any `magic-coordinator` instance, root or spawned, one loop to run once in `coordination-session` mode.
- Keep comms answered, the board advanced and the session's goal driven, with incoming messages handled before every step.

## Scope

- Does:
  - Run on any `magic-coordinator` instance, root or spawned.
  - Run with a reduced scope when the human-owner sets or agrees one: every job is still considered, only in-scope ones are executed.
- Doesn't:
  - Select the mode. The spawning routine's mode selection does (`magic-coordinator.root-harness.routine`'s **select-operating-mode**).
  - Cover `armed-mode`, which has no loop.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **sweep-comms**: Run `magic-coordinator.communication-sweep.routine`.
2. **advance-on-update**: Something new was found: run `magic-coordinator.advance.routine` now.
3. **drive-session-goal**: Keep driving the session's goal: dispatch, follow through, see real changes land.
4. **goal-gap-toward-empty**: Ask small, minimal-assumption questions that narrow the gap to the goal. Resuming a tracked interview, this is `magic-team.interview.routine`'s **resume-review**.
5. **wait-between-cycles**: Wait on the session thread and the sources this session watches (`Wait`, per `magic-team.armed.md`'s **wait-never-quit**). A `TIMEOUT` is a normal result.
6. **repeat-from-sweep**: The goal gap is empty: go to **conclude-or-ask-input**. Otherwise repeat from **sweep-comms**.
7. **conclude-or-ask-input**: The goal gap is empty: say so, and ask for new input. On the human-owner's word to close, run **close-session**.

# Closure steps

1. **close-session**: Run `magic-team.coworking.routine`'s **close-session** group, reached only from **conclude-or-ask-input**.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- Before every step, read incoming messages and messages from spawned sessions. For each: assess what it needs, dispatch real work to a spawned session, and relay the result or a status back to the human-owner.
- Ending the turn to wait for a notification is always fatal: nothing is left to receive it. The only wait is `Wait`.
- Nothing substantive is done inline. Every real edit, investigation or fix is dispatched (`spawn-one-dispatch`), and its result relayed back.
- Already-approved work is spawned out by default, never executed in this session's own context.
- Every 20 completed cycles, or on notice that a loaded skill file changed, reload the skill fresh at the top of the next **sweep-comms**, never mid-step. A reload re-reads every file, never a partial set.
- This instance holds its own Slack channel to the human-owner. An unverifiable relayed message is resolved there, not through another coordinator instance.
- The heartbeat is not a mode: the host loop runs it, and no session starts, relays into or stops it. Whether a pass is live is read with `--magic-heartbeat-lock-status`. A stopped host loop explains why nothing advances on its own; it changes nothing about this loop.
- Re-pinging a visibly stalled spawned session, or restarting it where prior work is safely preserved, is this member's own call. Escalate only when the stall makes prior output untrustworthy or risks a duplicated side effect.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-heartbeat-lock-status <team-member>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- `coordination-session` never does substantive work inline — every real edit, investigation, or fix is
  dispatched to a sub-spawned session.
- The reload trigger keeps a long-running `coordination-session` instance's loaded skill files from
  silently drifting from what is actually on disk.

## Verbatim-tests (benchmarks)

- A `coordination-session` instance ends its own turn to wait for a notification with nothing left alive
  to receive it. That is always fatal, never a valid wait.
- One of this session's own watched skill files shows a newer mtime mid-cycle. The reload waits for the
  next **sweep-comms** step rather than firing mid-step.

## Librarian Comments

### Reference

- `magic-coordinator.root-harness.routine` — selects this mode and runs this routine at **run-operating-mode-cycle**.
- `magic-team.interview.routine` — its **resume-review** is **goal-gap-toward-empty** for a tracked interview.

### Conventions

None.
