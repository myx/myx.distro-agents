---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-coordinator.external-inbox-handle-loop.routine — the actual procedure

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

`magic-coordinator.external-inbox-handle-loop.routine` keeps items owned by the human-owner or an external contact moving, since they have no inbox of their own.

## Goals

- Give non-acting owners the mailbox continuity acting members get from `magic-team.process-inbox.routine`, so an ask, reminder or status owed to them never sits unaddressed.

## Scope

- Does: follow up the items whose `owner` is the human-owner or an external contact. Their content lives in `magic-coordinator`'s inbox, so only `magic-coordinator` runs this. Runs inline in every heartbeat pass, or standalone when a specific owner needs checking sooner.
- Doesn't: process `magic-coordinator`'s own mail. That is `magic-team.process-inbox.routine magic-coordinator`, run in the advance pass.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **work-the-loop**: For each such item, pick one action by its own history and urgency, never by rotation:
   - **Retry**: the last attempt may not have landed; try the same channel again.
   - **Communicate**: send a fresh status, to keep the item visibly alive.
   - **Remind**: nudge on something sent and not yet answered.
   - **Switch channels**: the current channel is not working after reasonable attempts; try another this owner uses.
   - **Escalate**: last resort. Report the item to the human-owner on his direct channel.

# Closure steps

Run inline: none. Run as its own session: `magic-team.coworking.routine`'s **close-session** group.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- Every attempt is logged on the item. A retry, reminder or channel switch leaves the item where it was.
- An item reaches `board-processed` only on genuine resolution.
- "Reasonable time" is judged from the item's urgency and history. Unsure: one more attempt before escalating, unless it is time-sensitive.
- A contact's channel that appears dead is itself reported, never silently retried.
- A human-owner item likely to be handled when he is next in Slack gets a plain status rather than an urgent reminder, unless it is time-critical.
- An escalation is posted to `event-track` as it happens.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-comms-slack-send-message <team-member> <target> [text...]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives non-acting owners (human-owner, external contacts) the same working mailbox continuity acting members get from `magic-team.process-inbox.routine`, despite having no skill folder of their own.

## Verbatim-tests (benchmarks)

- An external-contact item that gets no response within a reasonable time escalates to a direct DM to the human-owner, never resolved by skipping that channel.

## Librarian Comments

### Reference

- `magic-coordinator.heartbeat.routine` — runs this routine at **handle-external-owner-items**.
- `magic-team.process-inbox.routine` — the acting-member counterpart.

### Conventions

None.
