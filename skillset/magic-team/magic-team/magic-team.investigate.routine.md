---
type: routine
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: coworking
input-scan-def: none
review-by: inherit
---
# magic-team.investigate.routine — the actual procedure

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

`magic-team.investigate.routine` finds out why something in the team's own systems behaves other than expected, and ends with one decision: record it, investigate further, or fix it.

## Goals

- Turn a concern — a failure, a surprise, a contradiction — into a cause shown by evidence, never a guess.
- End every investigation with a decision someone can act on, and the evidence that carries it.

## Scope

- Does:
  - Investigate one concern in the team's own code, tooling, data or process: reproduce it, bound it, find its cause, and decide what happens next. Any member runs it, on request, or when an activity raises a concern.
- Doesn't:
  - Answer a question from outside sources (`magic-team.research.routine`).
  - Fix anything beyond the approved scope. A fix outside it is filed, per **decide-the-outcome**.
  - Assign blame. It finds causes in systems and processes.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **process-own-inbox**: run `magic-team.process-inbox.routine <own-name>` inline (`--routine-run-inline magic-team.process-inbox.routine`), collecting earlier notes on the same concern.
2. **state-the-concern**: state the deviation before any search, steps:
   - what was expected, what happened instead, where and when. Quote the output, the file and line, the message.
   - the scope the investigation may touch, and what it must not touch.
   - read the statement back to whoever raised the concern, per **rephrase-and-confirm-before-acting**.
3. **read-the-record-first**: read what the team already holds on the concern, steps:
   - the `MAGIC.md` of the tree, the help of the tool involved, the item's `## Decisions`, open `warning-*` items.
   - a concern already explained there is answered from it, with its file and line, and goes to **decide-the-outcome**.
4. **reproduce-it**: make the deviation happen on demand, steps:
   - run the smallest case that shows it, with a wall-clock limit on every run.
   - run the same case where it works, if such a place exists. The difference between the two runs is the first evidence.
   - a deviation that will not reproduce is reported as not reproduced, with what was tried. It is not reported as gone.
5. **bound-it**: describe where the deviation is and where it could be but is not, steps:
   - for each of what, where, when and how much: what is affected, and what similar thing is not.
   - list what is distinct about the affected side, and what changed there, and when.
   - a cause must explain both columns. A candidate that fits only the affected side is dropped.
6. **build-a-timeline**: for a deviation that appeared at some point, set down the last known good state, each change since, and the first known bad state. Read the changes; never infer them from a working tree you do not own.
7. **list-candidate-causes**: write down every cause that fits the bounds, the unlikely ones included, before testing any. One favourite is not a list.
8. **test-the-candidates**: test each candidate by an experiment that can fail, steps:
   - state, before running it, what result would rule the candidate out.
   - change one thing per experiment, and keep the rest fixed.
   - narrow a large difference by halves: half the input, half the change set, half the history.
   - record each experiment: what ran, where, the expected result, the actual result.
   - a candidate is the cause only when switching it off ends the deviation, and switching it back brings the deviation back.
9. **trace-to-the-root**: from the shown cause, ask why it was possible, one step at a time, steps:
   - stop at the first cause a change in the team's control would remove: a missing check, a wrong rule, a gap in a process.
   - each step carries its evidence. A step with none is labelled as reasoned.
   - several contributing causes are listed together. One root is not forced where there are several.
10. **decide-the-outcome**: end with one of three decisions, and state why, steps:
    - **record**: the cause is known and needs no change now, or the change is not the team's. Write it where its reader reads it: the `MAGIC.md` of the tree, the item, or a `reflection-*`.
    - **investigate**: the cause is not yet shown. Name the next experiment and what it needs, and file it with **hand-off-open-work**.
    - **fix**: the fix lies inside the approved scope and is clear. Write the failing case first, watch it fail, apply the fix, watch it pass. A fix outside the scope is filed as a proposal, never made in passing.
11. **report-findings**: post the report into the session thread with `ReportFindings`, steps:
    - the decision and the cause first, in one or two sentences, with how firmly it is shown.
    - the evidence next: the reproduction, the bounds, each experiment and its result.
    - the candidates ruled out, and the experiment that ruled each out.
    - what stays open, and what would settle it.
    - a handback to the session's own parent follows, carrying what was agreed, per "The ladder: one rung at a time".

# Closure steps

1. **closing-reflection**: reflect on how the investigation went: a test that could not fail, a wrong first guess, a record that was missing. A pattern with no written rule behind it becomes a `reflection-*`.
2. **hand-off-open-work**: every open part — the next experiment, a fix outside the scope, a cause in another member's domain — is filed for its owner: propose the item (piece, type, goal) and wait for confirmation from the session's own parent, per "The ladder: one rung at a time".

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- The executing member is permitted and obliged to execute every step exactly as written, in order.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- **Evidence before cause.** A cause is named only with the experiment that showed it. Until then it is a candidate, and is called one.
- **A check that cannot fail proves nothing.** Show each probe able to fail on a known bad case before trusting its clean result.
- **Not reproduced is not fixed.** A deviation that stopped on its own stays open until its cause is shown.
- **Read before you change.** No experiment changes a live system, a shared checkout or another member's work without the approval that change needs.
- **Systems, not people.** The report names the conditions that let the deviation happen, never a person or a member to blame.
- **Root outside the scope.** A root cause outside the named scope is escalated, never fixed in passing.
- **The owner of the domain.** A concern in another member's domain loops that member in, never works around it.
- Every exchange that decides something is kept as a `transcript-*` with `--append-transcript`. Waiting follows **wait-never-quit**.
- Goal-directedness: investigate the stated concern. Other concerns found on the way are recorded quickly, not investigated now.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

Harness tools: `ReportFindings` posts the report.

## Tooling operations

- `--append-transcript --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <text>|--from-stdin|--from-file <path>) --transcript-name <transcript-file-name> [--create]`
- `--upsert-inbox-reflection <member> <item-filename> [--include-processed] [--from-file <path>|--edit-patch-from-stdin]`
- `--upsert-inbox-inquiry <member> <item-filename> [--include-processed] [--from-file <path>]`
- `--get-board-item <item-filename>`
- `--routine-run-inline <routine>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- (draft) This routine exists so that every concern in the team's own systems ends in a decision — record, investigate or fix — carried by a cause shown by evidence.

## Verbatim-tests (benchmarks)

- (draft) A failure stops after a restart and cannot be reproduced. The report says "not reproduced", lists what was tried, and files the investigation as open.
- (draft) The cause lies in a file outside the approved scope. The report names it, and the fix is filed as a proposal, not made.
- (draft) Two candidate causes both fit the affected cases, and only one fits the unaffected ones. The other is dropped, and the report says which bound dropped it.

## Librarian Comments

### Reference

- `magic-team.research.routine` — a question answered from outside sources.
- `magic-team.discuss.routine` — the follow-on when the decision has real tradeoffs.
- `magic-team.grooming.routine` — files the investigation items testing raises.

### Conventions

- **reproduce-it**, **bound-it**, **test-the-candidates** and **decide-the-outcome** are the steps other routines may cite by name.
