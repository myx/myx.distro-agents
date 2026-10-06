---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-coordinator.one-on-one.routine — the actual procedure

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

`magic-coordinator.one-on-one.routine` is a focused session between the human-owner and one member, with the coordinator present.

## Goals

- Give the human-owner, or a member needing another's input, a direct conversation with one member that carries that member's full skill, not a paraphrase.
- Keep the coordinator present to supervise and relay, without collapsing its context into the member's.

## Scope

- Does: one target member, any permanent member, or a `partner-*` willing to raise something. Manual only: the human-owner asks for a "one-on-one" or "1:1".
- Executed by a `magic-coordinator` instance the root harness spawns for it (`magic-coordinator.root-harness.routine`'s **enforce-root-never-inline**). The root relays the human-owner's turns into this session's thread.
- Doesn't: hand the human-owner to the member in the root chat, or skip the spawn because the question looks small.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **session-start**: Run `magic-team.coworking.routine`'s **session-start** group: this is a coworking-like session.
2. **pick-the-member**: Use the member the human-owner named. None named: ask, never guess.
3. **prep-member-context**: Gather the member's board items (`--member-work-session-input-scan <member>`) and any board item that references it, so the conversation does not start cold. Little or nothing found is fine.
4. **invite-target-member**: Spawn the member into this session (`spawn-one-dispatch`). It loads its own skill and processes its own inbox at its own session start.
5. **hold-the-conversation**: Carry the conversation between the human-owner's relayed turns and the member, in the session thread. Waiting is per `magic-team.armed.md`'s **wait-never-quit**. A member silent past a reply is asked; one found dead is reported to the root ("the one-on-one session appears to have died — restart it?"). Genuinely private phrasing goes to the human-owner's DM instead of the thread.

# Closure steps

1. **return-and-close**: Once the conversation concludes, steps:
   - File anything material as an `inquiry-*` (`post-inquiry`) or a `note-*` in this member's own inbox, so a later session finds it.
   - Run `magic-team.coworking.routine`'s **close-session** group, its skill-update offer scoped to this member.
   - Dismiss the target member (`spawn-one-dispatch`'s **spawn-dismiss**).
   - Report the final status to the root, then wait until it dismisses this instance.
   Follow-on work is dispatched as its own fresh session, never continued here.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- This routine extends `magic-team.coworking.routine`; this file wins on conflict.
- A decision outside the member's mandate goes through the chain of command, even though the human-owner is in the conversation.
- Keep `event-track` current as the routine runs.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-work-session-input-scan <team-member>`
- `--member-inbox-note-upsert <team-member> <item-filename>`
- `--member-comms-slack-send-message <team-member> <target> [text...]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives the human-owner a direct, focused channel to one specific member — without collapsing the coordinating instance's own context into that member's.

## Verbatim-tests (benchmarks)

- A one-on-one with `magic-architect` gets `magic-architect`'s own full `Skill` context, genuinely — the coordinating instance stays present to supervise and relay, it never steps out of the loop entirely.

## Librarian Comments

### Reference

- `magic-team.coworking.routine` — the template: **session-start** and **close-session**.
- `magic-coordinator.root-harness.routine` — spawns this routine's executor and relays the human-owner's turns.

### Conventions

- Every one-on-one has its own thread with an opening and a closing post, whatever its size. Preserve this.
