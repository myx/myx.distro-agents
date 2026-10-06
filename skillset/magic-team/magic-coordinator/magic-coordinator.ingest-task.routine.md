---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-coordinator.ingest-task.routine — the actual procedure

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

`magic-coordinator.ingest-task.routine` turns a loosely stated idea into a filed task through real back-and-forth.

## Goals

- Close the gap between "roughly what I want" and a task someone can execute, without guessing unstated intent and without deciding what was never settled.

## Scope

- Does: gather, agree and file. Any natural phrasing of "ingest this", "turn this into a task" triggers it, from any requester. `magic-coordinator` runs it whoever asked.
- Doesn't: triage, score or make backlog decisions (grooming's), or start the work it files.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **process-own-inbox**: Run `magic-team.process-inbox.routine magic-coordinator`, so asks already queued are settled with this one rather than duplicated.
2. **gather-and-agree**: Gather and agree with the requester, one topic at a time, with small, minimal-assumption questions, until the content is settled. Once a point is clear and agreed, move on.
3. **output**: Once settled, file it, steps:
   - Default: a `note-*` in `magic-coordinator`'s own inbox (`--member-inbox-note-upsert`), or an `inquiry-*` to the member it belongs to (`post-inquiry`). Never the board. Filing does not start the work.
   - Dispatch: only within `magic-coordinator`'s own mandate, or on a live authorisation from someone holding it — still filed first, then dispatched through `spawn-one-dispatch`.
4. **relationship-to-grooming**: Content that needs working out rather than writing down goes to `magic-team.interview.routine`, which takes each part through propose-approve as it settles.

# Closure steps

Run inline: none. Run as its own session: `magic-team.coworking.routine`'s **close-session** group.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- Which **output** branch applies is checked fresh each time against the mandate or a live authorisation, never taken from precedent.
- Real ambiguity keeps the questions going. A task written from a guess looks settled when it is not.
- Urgency is not an instruction to execute inline. Inline execution in the root chat happens only under `magic-coordinator.root-harness.routine`'s **enforce-root-never-inline** exception: the human-owner's explicit instruction, for this one request.
- Unclear which inbox it belongs in: `magic-coordinator`'s own, which routes it on.
- A requester declining further questions is respected, and the filed task states plainly what remains ambiguous.
- Keep `event-track` current as the routine runs.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-inbox-note-upsert <team-member> <item-filename>`
- `--member-upsert-member-inquiry <member> <item-filename>`
- `--member-comms-slack-send-message <team-member> <target> [text...]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives a requester a real, interactive place to turn a loosely-stated idea into something concrete — without the team guessing at unstated intent.

## Verbatim-tests (benchmarks)

- Registering a task via this routine creates the record only — it does not start its work, even when the content is fully settled and unambiguous.

## Librarian Comments

### Reference

- `magic-team.interview.routine` — the pacing **gather-and-agree** shares (**collect-dont-converge**).
- `magic-team.grooming.routine` — triages what this routine files.

### Conventions

- Filing is the default and never starts work. Preserve the distinction from the narrow, authorised dispatch branch.
