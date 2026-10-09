---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-coordinator.permission-escalation.routine — the actual procedure

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

`magic-coordinator.permission-escalation.routine` settles the permission asks members address to `permission-escalation.routine`.

## Goals

- Every permission ask addressed to this routine gets a verdict: granted, denied, or ruled by the human-owner.
- The asking member waits with its own `Wait` meanwhile, for days if need be, and goes on once the verdict lands.

## Scope

- Does:
  - Decide each open permission ask its input scan lists, oldest first, in every workspace this machine knows.
  - Run inline when `magic-coordinator` is told to in a coworking session, and inline in every heartbeat pass (`magic-coordinator.heartbeat.routine`'s **handle-permission-asks**).
- Doesn't:
  - Ask for a task's permission set, pass a permission on, or revoke one.
  - Close an ask with no verdict.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **read-input-scan**: Run `--magic-permission-escalation-input-scan magic-coordinator`. `(none)`: nothing else runs.
2. **decide-each-ask**: For each ask listed, oldest first, one of:
   - rule: an ask of another workspace is answered there: the `execute` tool's `workspace` argument, set to its `workspace:` line.
   - rule: the narrowest verdict the task needs: `allow-once`, else `allow-session`, else `allow-task`, which needs an `item:`.
   - **grant**: the task needs it: `--magic-escalation-answer magic-coordinator <id> <verdict> [text]`. Where `holders:` does not name `magic-coordinator`, tooling takes the ask up to a holder, else to the human-owner, whose reply is the verdict.
   - **deny**: the task does not need it, or another route serves it (a listed set-request, the session sandbox `output/`): `--magic-escalation-answer magic-coordinator <id> deny <why, and the route>`.
   - **ask-the-human-owner**: the ruling binds the team, whoever holds it: ask him with `AskUserQuestion`, kind `decision`, options `allow-once`, `allow-session`, `allow-task` and `deny`, and `Wait` as today. Then answer with his verdict, as in **grant** or **deny**, naming him in the text.
3. **record-decision**: Each answer records its verdict on its item's `## Decisions` itself. An ask with no `item:`: say the verdict in this session's thread.

# Closure steps

Run inline: none. Run as its own session: `magic-team.coworking.routine`'s **close-session** group.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- An ask still open after this pass stays open. Only a verdict closes it.
- In a heartbeat pass nothing waits on the human-owner: **ask-the-human-owner** is registered by `magic-coordinator.heartbeat.routine`'s **register-owner-decisions** instead, and the ask stays open.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-permission-escalation-input-scan <team-member>`
- `--magic-escalation-answer <magic-coordinator> <request-id> <verdict> [text]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- Runs inline when the coordinator is told to in coworking, or on its schedule. Asks may wait for days; the requester waits with the existing `Wait`. Inside, the coordinator uses `AskUserQuestion` and `Wait` as today.

## Verbatim-tests (benchmarks)

- An ask addressed to `permission-escalation.routine` is recorded with no DM to a person; the input scan lists it; the coordinator, as the routine's executor, can answer it; a non-executor cannot; `Wait` returns the answer to the requester.

## Librarian Comments

### Reference

- `magic-coordinator.heartbeat.routine` — runs this routine at **handle-permission-asks**.
- `magic-team/templates/escalation.document.format.md` — the `permission` kind and its verdicts.

### Conventions

None.
