---
type: routine
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: standalone
input-scan-def: none
review-by: inherit
runs-at: none
---
# magic-team.advance.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Opening steps
- Steps
- Closure steps
- Routine's local procedures
- Routine's local rules
- Next iteration by document type
- Routine-specific tooling
  - Tooling operations
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions

# Summary

`magic-team.advance.routine` says, for each kind of running document, which routine runs its next iteration, and hands the document to that round.

## Goals

- Give every running document one obvious next iteration, so no document waits for someone to remember it.
- Let an item name its own handler where its type's default would run the wrong iteration, without ever bypassing a gate.

## Scope

- Does:
  - Pick the routine for a document's next iteration. The order is its gate row at a gate, else its `handler-routine:` when set and valid, else its type's default.
  - Hand the document to the session that holds it, or run one round of the picked routine on it, per **run-a-round** and **stop-or-go**.
  - Any member runs it inline for a document it owns. `magic-coordinator`'s duty runs it for board items with no live holder and no owning duty.
- Doesn't:
  - Read an input scan, sweep communications, reconcile sessions or start pending items. Those are the duty sessions' own steps.
  - Decide a go, triage or score. Those are `magic-team.grooming.routine`'s.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **pick-the-iteration**: name the routine that runs the document's next iteration, first match wins, steps:
   - the document is at a gate — a row of "Next iteration by document type" with `gate` `yes` applies: run that row. `handler-routine:` never overrides a gate row.
   - the item carries `handler-routine:`: it must name an existing routine whose `# Summary` carries a `Handles:` line naming the item's type. Valid: that routine. Not valid: flag the item once, naming the value and why it fails, and run nothing. Outcome `flagged-once`.
   - otherwise: the type default from the table.
   - no row and no `handler-routine:`: flag the item for grooming once. Outcome `no-action`.
2. **hand-or-run**: decide who runs the round, steps:
   - the digest marks the item `held` (by <holder>): run nothing, and name the holder. Outcome `no-action`.
   - a live session holds the document: send it this pass's findings (`SendMessage`). Never start a second session for it. Outcome `nudged`.
   - the document's owner has a live duty: leave it to that duty, per the round's single-writer rule. Outcome `no-action`.
   - otherwise: run **run-a-round** with the picked routine, then **stop-or-go**. Outcome `advanced`, or the outcome **stop-or-go** ends on.

# Closure steps

None of its own: the Closure steps of the routine it inherits from run (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- The executing member is permitted and obliged to execute every step exactly as written, in order.
- **`handler-routine:` chooses, never overrides a gate.** It names which routine runs an item's next round. It never replaces a row whose `gate` is `yes`.
- **Who sets `handler-routine:`.** Only `magic-team.grooming.routine` or `magic-coordinator` sets or changes it, and records the setting and its reason in the item's `## Decisions`.

# Next iteration by document type

| type | routine | gate |
|---|---|---|
| approval | - | yes |
| proposal-root | magic-team.proposal.routine | yes |
| proposal | magic-team.discuss.routine | no |
| task | magic-team.verify.routine | yes |
| project | magic-team.verify.routine | yes |
| interview | magic-team.interview.routine | no |
| investigation | magic-team.investigate.routine | no |
| dispatch | - | no |
| change | - | no |
| warning | - | no |

`type` is the item's board type word; `proposal-root` is a `proposal` item that carries a `communication-channel-id`. `routine` is the routine file name without `.md`, or `-` where the iteration is an action with no routine of its own. A row with `gate` `yes` is never overridden by `handler-routine:`. A routine also handles a type when its `# Summary` carries the line `Handles: <type>, <type>`.

What each row does:
- `approval`: `recheck-date` due and unresolved — ask the human-owner again in its tracked thread, else on his direct channel (`AskQuestion`, `wait: false`), alone in its own message. Extend it with `--recheck-in 17±2`.
- `proposal-root`: read the thread root's closing reaction (the human-owner's own) and apply it per `magic-team.proposal.routine`'s **close-on-root-reaction**. None there: take the `approval` row.
- `proposal`: one round of `magic-team.discuss.routine` over it. Its **record-the-outcome** makes the move.
- `task`, `project`: completion claimed and no clean verification — `magic-team.verify.routine`; a stale verification gets a fresh one. No completion claimed: no row runs, and the board round's staleness rules apply.
- `interview`: one round of `magic-team.interview.routine` — **resume-review** and **reassess-before-next-message**, at most one outward message or one explicit close-out. With no tracked thread, post the round to the human-owner and write the returned thread back as `communication-channel-id`. A round finding every question resolved and none new moves the item to `board-processed`.
- `investigation`: one round of `magic-team.investigate.routine` on its `investigation-*` document.
- `dispatch`: nudge its session, and append its report as a dated log entry. The tooling moves a finished dispatch to `board-review`.
- `change`: `recheck-date` due — check whether the change landed. Landed: `board-processed`. Not yet: `--recheck-in 17`.
- `warning`: `recheck-date` due — condition no longer true: `board-processed`. Still true: re-escalate once in `event-track` and extend `recheck-date`. No `recheck-date`: set one.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## Tooling operations

- `--get-board-item <item-filename>`
- `--advance-to-running <item-filename> --from-state:running [--header:<upsert|append|remove>:name[:value]]...`
- `--move-to-processed <item-filename> --from-state:<state> [--header:...]...`
- `--routine-run-inline <routine>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- (draft) This routine exists so that every running document has one next iteration, run as one round toward its goal. Its gate, its `handler-routine:` or its type picks it.

## Verbatim-tests (benchmarks)

- (draft) An `interview-*` item has no live session and no owning duty. One pass runs one interview round on it, sends at most one message, and leaves it open for the next pass.
- (draft) An item carries `handler-routine: magic-team.research.routine` though its type default is investigate. The pass runs a research round.
- (draft) An `approval-*` item carries a `handler-routine:`. The gate row runs; the `handler-routine:` is not used.
- (draft) An item's `handler-routine:` names no existing routine. The item is flagged, and nothing runs.

## Librarian Comments

### Reference

- "The round" in `magic-team.armed.md` — **run-a-round** and **stop-or-go**, which this routine hands each document to.
- `magic-coordinator.work-duty.routine` — runs this routine at **continue-running**, for items with no live holder and no owning duty.
- `magic-team/reference/board-model.md` — the `handler-routine:` header.

### Conventions

- **pick-the-iteration** and **hand-or-run** are cited by name from other files.
