---
type: routine
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: coworking
input-scan-def: none
review-by: inherit
runs-at: none
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
  - `defect-branch` — why something deviates from what was expected
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

`magic-team.investigate.routine` finds out what is true about a thing by looking into the thing itself: its content, its records and its behaviour. It ends with one decision — record, investigate further, or act — and names the next flow step for it.

Handles: investigation, task, project

## Goals

- Answer a question about a thing with findings shown by evidence, never a guess. The thing may be a codebase, a tool, a data set, a set of accounts, a document, a 3D model or a process.
- Keep what is shown apart from what is inferred or assumed.
- End every investigation with a decision someone can act on, and the next step it leads to.

## Scope

- Does:
  - Look into one thing to answer one question about it: find it, read its detail, state the assumptions, check them, and establish what is true. Any member runs it, on request, or when an activity raises a question.
  - Find why something deviates from what was expected, through **defect-branch**.
- Doesn't:
  - Answer a question from outside sources. That is `magic-team.research.routine`: a question answered from sources. This routine finds out what is true by looking into the thing itself, its records and its behaviour. A question that needs both is led here, and research is called for the outside facts.
  - Act beyond the approved scope. Work outside it is filed, per **decide-the-outcome**.
  - Assign blame. It finds causes in systems and processes.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **process-own-inbox**: run `magic-team.process-inbox.routine <own-name>` inline (`--routine-run-inline magic-team.process-inbox.routine`), collecting earlier notes on the same question.
2. **state-the-question**: state what is to be found out, before looking. Write it in the investigation's own document, its `investigation-*` item (`board-item.investigation`). Its sections are Question, Goal, Current, Settled, Open and Log. Steps:
   - the question, the thing it is about, and what the answer is for.
   - the scope: what the investigation may touch, and what it must not touch.
   - the answer that would settle it.
   - read the statement back to whoever asked, per **rephrase-and-confirm-before-acting**.
3. **read-the-record-first**: read what the team already holds on the thing, steps:
   - the `MAGIC.md` of its tree, the help of the tool involved, the item's `## Decisions`, open `warning-*` items, earlier reports on it.
   - a question the record already answers is answered from it, with its file and line, and goes to **decide-the-outcome**.
4. **look-into-the-thing**: find the thing and read its detail, steps:
   - find every part the question touches: the files, the records, the ledgers, the logs, the models, the people's own statements on record.
   - read the detail itself, never a summary of it. Note what each part says, with where it says it.
   - a question about why something deviates from what was expected continues in **defect-branch**, then returns to **establish-what-is-true**.
5. **state-the-assumptions**: write down every assumption the answer could rest on, the unlikely ones included. Give each one the observation that would disprove it.
6. **check-the-assumptions**: check each assumption against the thing, steps:
   - one check per assumption, chosen so it can fail. State its disproving result before running it.
   - change nothing in the thing to check it, unless the approval that change needs is held.
   - record each check: what was looked at or run, where, the expected result, the actual one.
7. **establish-what-is-true**: set down the findings, steps:
   - each finding labelled shown, inferred or assumed, with its evidence.
   - an assumption that failed its check is dropped, and the check that dropped it is kept.
   - what could not be established is stated as open, with what would settle it.
8. **decide-the-outcome**: end with one of three decisions, and state why, steps:
   - **record**: the answer is known and needs no change now, or the change is not the team's. Write it where its reader reads it: the `MAGIC.md` of the tree, the item, or a `reflection-*`.
   - **investigate further**: the answer is not yet shown. Name the next check and what it needs.
   - **act**: the findings call for a change. Name the change and whose it is.
9. **report-and-route**: post the report into the session thread with `ReportFindings`, then name the next flow step, steps:
   - the answer and the decision first, with how firmly each is shown.
   - the evidence next: what was looked at, each check and its result, the assumptions dropped and why.
   - the next flow step, by outcome:
     - **record** — done once written; the handback closes the investigation.
     - **investigate further** — filed as an item for `magic-team.investigate.routine`, with the next check named.
     - **act**, small, clear and inside the approved scope — make the change, then `magic-team.verify.routine`.
     - **act**, larger or several pieces — `magic-team.plan.routine`.
     - **act**, with a choice between options — `magic-team.discuss.routine`.
     - outside facts needed — `magic-team.research.routine`.
   - on closing, the settled answer becomes an investigation report, an `ivr-*` vault item (`vault-item.investigation-report`), named in the item's `references`.
   - a technical decision the investigation took or needs is recorded as an `adr-*` vault item (`vault-item.decision-record`), by `magic-architect`, one per distinct question.
   - a handback to the session's own parent follows, carrying the decision and the next step, per "The ladder: one rung at a time".

# Closure steps

1. **closing-reflection**: reflect on how the investigation went: a check that could not fail, a wrong first assumption, a record that was missing. A pattern with no written rule behind it becomes a `reflection-*`.
2. **hand-off-open-work**: file every open part for its owner: the next check, work outside the scope, a question in another member's domain. Propose the item (piece, type, goal), and wait for confirmation from the session's own parent, per "The ladder: one rung at a time".

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

## `defect-branch` — why something deviates from what was expected

Taken from **look-into-the-thing** when the question is why something does other than expected. Examples: a failure, a wrong total, a model that will not print, a surprise. Steps:
1. **reproduce-it**: make the deviation show on demand, with the smallest case that shows it and a time limit on every run. Show the same case where it works, if such a place exists. A deviation that will not show is reported as not reproduced, with what was tried, never as gone.
2. **bound-it**: for each of what, where, when and how much, set down what is affected and what similar thing is not. List what is distinct about the affected side, and what changed there and when. A cause must explain both sides.
3. **build-a-timeline**: for a deviation that appeared at some point, set down the last known good state, each change since, and the first known bad state. Read the changes; never infer them from a working copy you do not own.
4. **list-candidate-causes**: write down every cause that fits the bounds before testing any.
5. **test-the-candidates**: test each by an experiment that can fail. Change one thing per experiment. Narrow a large difference by halves: half the input, half the changes, half the history. A candidate is the cause only when removing it ends the deviation, and restoring it brings the deviation back.
6. **trace-to-the-root**: from the shown cause, ask why it was possible, one step at a time. Stop at the first cause a change in the team's control would remove. List several contributing causes where there are several.
7. **fix-rule**: a fix chosen at **decide-the-outcome** shows the fault on one case before the fix, and its absence after. In software this is a failing test first.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- The executing member is permitted and obliged to execute every step exactly as written, in order.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- Each round follows **run-a-round** and **stop-or-go**.
- **Evidence before a finding.** A finding is named only with the check that showed it. Until then it is an assumption, and is called one.
- **A check that cannot fail proves nothing.** Show each check able to fail on a known bad case before trusting its clean result.
- **Read before you change.** No check changes a live system, a shared copy, a set of books or another member's work without its approval.
- **Systems, not people.** The report names the conditions that led to the finding, never a person or a member to blame.
- **Outside the scope.** A cause or a change outside the named scope is escalated, never handled in passing.
- **The owner of the domain.** A question in another member's domain loops that member in, never works around it.
- Every exchange that decides something is kept as a `transcript-*` with `--append-transcript --transcript-name`. Waiting follows **wait-never-quit**.
- Goal-directedness: answer the stated question. Other questions found on the way are recorded quickly, not investigated now.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

Harness tools: `ReportFindings` posts the report.

## Tooling operations

- `--append-transcript --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <text>|--from-stdin|--from-file <path>) --transcript-name <transcript-file-name> [--create]` — the named `transcript-*` this routine keeps. `SessionTranscriptAppend` takes a note line.
- `--upsert-inbox-reflection <member> <item-filename> [--include-processed] [--from-file <path>|--edit-patch-from-stdin]`
- `--upsert-inbox-inquiry <member> <item-filename> [--include-processed] [--from-file <path>]`
- `--get-board-item <item-filename>`
- `--routine-run-inline <routine>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- (draft) This routine exists so that every question about a thing is answered by looking into the thing itself. It ends in a decision — record, investigate further or act — with the next flow step named.

## Verbatim-tests (benchmarks)

- (draft) The question is which of two ledgers holds the right year-end balance. The investigation reads both, states the assumptions behind each, checks them against the source records, and reports which is right and why.
- (draft) A failure stops after a restart and cannot be reproduced. The defect branch reports "not reproduced", lists what was tried, and the outcome is investigate further.
- (draft) The findings call for a change of several pieces. The next step named is `magic-team.plan.routine`, not a change made in passing.

## Librarian Comments

### Reference

- `magic-team.research.routine` — a question answered from outside sources.
- `magic-team.plan.routine`, `magic-team.verify.routine`, `magic-team.discuss.routine` — the next flow steps an outcome leads to.
- `magic-team.grooming.routine` — files the investigation items a testing round raises.

### Conventions

- **state-the-question**, **check-the-assumptions**, **decide-the-outcome**, **report-and-route** and **defect-branch** are cited by name from other files.
