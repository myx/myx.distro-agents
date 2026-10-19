---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
session: coworking
---
# magic-team.proposal.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Steps
- Closure steps
- Routine's local procedures
  - `proposal-thread-mechanic` — the shape of a proposal thread
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

`magic-team.proposal.routine` takes one proposal to the human-owner through propose, work-out and approve, in one standing thread.

## Goals

- Put the invariant question as the thread root, the proposed form as a clean reply, revise it in place across his comments, and close on his own reaction to the root.
- Keep the flow in the Steps and the invariant thread shape in `proposal-thread-mechanic`.

## Scope

- Does:
  - The whole life of one proposal to the human-owner, once a proposed form exists. Reached by a request, by a decision that outlives its exchange (`magic-team.armed.md`'s **Propose-approve**), by an escalation that did not settle, or by a `proposal-*` item `magic-team.discuss.routine` hands on.
  - The state of that proposal's tracking item, if it has one, from the root post until his closing reaction.
- Doesn't:
  - Convergence among members (`magic-team.discuss.routine`) or collection (`magic-team.interview.routine`).
  - Stop the work the proposal came from, or build the approved change.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **process-own-inbox**: run `magic-team.process-inbox.routine magic-coordinator`.
2. **put-the-proposal**: call `ProposeApprove` with `question` per the root clause, `proposal` per the in-thread-proposal clause, the proposal document's link as `document`, and `task_ref` naming the tracking item, if any. It posts the root once, the proposal as its reply, and waits for the verdict.
3. **work-out-across-his-comments**: a `VERDICT: RETURNED` result is his comment, kept as a clarification. Work the proposal out against it, then call `ProposeApprove` again with `pending_id` and `revise: true`, per the revision clause. Repeat until a verdict lands.
4. **close-on-root-reaction**: `VERDICT: approved` or `VERDICT: rejected` on that call is the terminal verdict, per the root-reaction clause, already recorded on the tracking item's Decisions by the tool.

# Closure steps

1. **close-session**: run `magic-team.coworking.routine`'s **close-session** group.
2. **closing-reflection**: reflect on how the proposal process went. A behaviour or pattern with no written rule behind it becomes a `reflection-*`.
3. **carry-the-approved-work-forward**: act on the verdict, steps:
   - approved: create the work documents the approved contents call for — as many, and of whatever types, as they call for — in `board-backlog`, each carrying `approved-by`/`approved-at` and `spawned-by` the tracking item.
   - resolve the tracking item, if any, to `board-processed`, its resolution stating the verdict: approved, or rejected.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

## `proposal-thread-mechanic` — the shape of a proposal thread

- **root clause**: the root is the invariant question the proposal answers — self-contained, phone-readable, no history, narrative or references. It is posted once and never rewritten or deleted.
- **in-thread-proposal clause**: the proposal is a reply in that thread, in clean form: present or future tense, the proposed form and its tight reasoning only. No history, no account of how it was reached, no precedent or tension. The back-and-forth lives in the work's tracking document, per "A rule statement stays a rule statement".
- **revision clause**: a revision deletes the superseded reply and posts the new one into the same thread. Never stack replies, never open a new thread, never touch the root. A revision marks nothing.
- **root-reaction clause**: closure is the human-owner's own reaction on the root: ✅ approved; an assessed negative reaction (❌ at least) rejected or dropped. A negative mark means the whole proposal, never one revision. He sets it; the routine never does.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- `magic-coordinator` is permitted and obliged to execute every step exactly as written, in order.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- The routine never reacts on the root, for any reason.
- A reply that is not clean is reworked before it stands.
- **A proposal runs beside the work it came from, never in place of it.** A readback its source does not settle with yes or no goes through escalation first, and reaches here only where that does not settle it. A proposal never reduces back to a readback.
- While the thread is open, `magic-coordinator.advance.routine` re-asks it when the tracking item's `recheck-date` is due.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

`ProposeApprove` runs the whole proposal thread itself — the root, the proposal reply, its revise and the wait for a verdict — replacing a by-hand send, delete and read.

## DistroAgentsTools magic-tooling operations

- `--magic-advance-to-running <team-member> <item-filename> --from-state:running [--header:<upsert|append|remove>:name[:value]]...`
- `--magic-board-to-processed <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]`
- `--magic-grooming-create-backlog <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...`
- `--member-inbox-reflection-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- A proposal to the human-owner lives in one standing thread — a short root gist that is the invariant question and stays, the proposal as an in-thread reply revised by delete-and-replace, and only the root's own reaction (green approved / red rejected-or-dropped) closing it.
- A clean proposal is present/future-tense and states only the proposed form and its tight reasoning — no history, no narrative, no account of how it was reached, no precedent or tension recounting; a proposal describes what is proposed, not the debate that produced it.
- The routine holds the sequence/flow/logic in its Steps and references the proposal-thread mechanic; a routine referencing an instructed mechanic is the established shape, not an either/or with it.

## Verbatim-tests (benchmarks)

- A proposal is reworked after the human-owner comments — the old proposal reply is deleted and the new one posted into the same thread, the root gist and thread left intact and unmarked, and no new thread opened; the root gets `:white_check_mark:` only when he approves, or an assessed negative reaction only if the whole proposal is dropped.
- A proposal reply carrying history, narrative, an account of how it was reached, or precedent/tension recounting is not clean — it is reworked to present/future-tense, proposed-form-plus-tight-reasoning only, before it stands.
- The routine never sets the root reaction — closure is detected from the human-owner's own reaction on the root.

## Librarian Comments

### Reference

- `magic-team.discuss.routine` — hands binding `proposal-*` decisions here.
- `magic-coordinator.advance.routine` — re-asks an open proposal thread.

### Conventions

None.
