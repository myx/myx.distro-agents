---
type: routine
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: coworking
input-scan-def: none
review-by: inherit
---
# magic-team.discuss.routine — the actual procedure

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

`magic-team.discuss.routine` is a conversation whose goal is a decision reached by its end.

## Goals

- Converge a framed decision among the members it concerns, typically a `proposal-*` item past interview and brainstorm — all agreed, or the no-quorum document, per "The ladder: one rung at a time".
- Keep collection (`magic-team.interview.routine`), idea generation (`magic-team.brainstorm.routine`) and decision distinct.

## Scope

- Does:
  - Convergence on one framed decision, started by anyone asking to discuss it.
  - The team side of a `proposal-*` item: `magic-coordinator.advance.routine` runs it over a `proposal-*` not yet in front of the human-owner. It owns that item's state changes while running.
- Doesn't:
  - Put a proposal to the human-owner: `magic-team.proposal.routine` does.
  - Build what it decides.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **process-own-inbox**: run `magic-team.process-inbox.routine <own-name>` inline (`--routine-run-inline magic-team.process-inbox.routine`), collecting items that ask for a decision.
2. **frame-the-decision**: state what must be decided by the end. One topic, one thread: an unrelated topic is forked into its own thread.
3. **surface-options-and-tradeoffs**: lay out the real alternatives, never one answer dressed as a discussion, steps:
   - list every option before weighing any, the unlikely ones included.
   - weigh each piece of evidence against all the options at once, not one option against all the evidence. Evidence that fits every option settles nothing.
   - name the linchpin assumption each leading option rests on, and what changes if it is wrong.
   - bring in `magic-architect` for a structural question, `magic-librarian` for docs or conventions, the owning `keeper-*`/`partner-*` for a domain question.
   - work the sub-points as small questions or statements to approve, per **collect-dont-converge** in `magic-team.interview.routine` and `magic-team.negotiations.md`'s topic mechanics.
4. **converge-explicitly**: state the resolution plainly. Running out of time or information: say the session did not converge, and write it up as the no-quorum document — the agreed part, and each member's own argument — sent up by "The ladder: one rung at a time".
5. **checkpoint-decide-vs-build**: a decision about to become a build or edit dispatch is confirmed first by the ladder: the group's own parent, or the human-owner where he asked for it, per "The ladder: one rung at a time". A decision is never by itself a mandate to implement.
6. **keep-tracking-item-current**: with a tracking item behind the decision, keep its `# Context Detail` current: options weighed, settled, still open, and — no quorum — one section per dissenting member, as the no-quorum document. The item's body stays a timeless statement of the proposal, per "A rule statement stays a rule statement".
7. **record-the-outcome**: write the decision, and the rejected alternatives where useful, into the document it binds, per **decision-lands-in-the-document-it-binds**. Propose any new item (piece, type, goal) and wait for confirmation from the session's own parent, per "The ladder: one rung at a time", unless the human-owner asked for it himself. For a `proposal-*` item, steps:
   - a decision that binds the team, or needs the human-owner's go: put it to him with `magic-team.proposal.routine`; the item keeps its state until he closes it.
   - otherwise, `magic-coordinator` resolves the item: to `board-processed` with the decision as its resolution, approved or rejected. An approved item's `blocks:` items with every `blocked-by` resolved move to `board-pending`.
   - another executor hands the outcome to `magic-coordinator` with `post-inquiry`, which carries it back to whoever asked for this session, per "The ladder: one rung at a time".

# Closure steps

None of its own: the Closure steps of the routine it inherits from run (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- The executing member is permitted and obliged to execute every step exactly as written, in order.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- Any member may run it. `magic-coordinator` convenes a discussion spanning several members' territory; a member deciding within its own domain needs no convener.
- On any resume, apply `magic-team.negotiations.md`'s "Check-restart procedure"; a nudge restates the open decision. Waiting follows **wait-never-quit**.
- Every exchange is kept as a `transcript-*` with `--append-transcript`.
- Unsure whether this is a discussion, an interview or a brainstorm: ask what the goal is before starting.
- Goal-directedness: work toward the framed decision. Off-goal items are recorded quickly, not acted on now.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## Tooling operations

- `--slack-send-message <target> [text...]`
- `--append-transcript --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <text>|--from-stdin|--from-file <path>) --transcript-name <transcript-file-name> [--create]`
- `--upsert-inbox-inquiry <member> <item-filename> [--include-processed] [--from-file <path>]`
- `--advance-to-running <item-filename> --from-state:running [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]` — `magic-coordinator` only
- `--move-to-processed <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]` — `magic-coordinator` only
- `--move-to-pending <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]...` — `magic-coordinator` only
- `--routine-run-inline <routine>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine exists for conversations whose actual goal is reaching agreement — a decision genuinely gets made by the end, not just gathered (interview) or generated (brainstorm).

## Verbatim-tests (benchmarks)

- A discuss session about to produce a real build/edit dispatch pauses once and confirms explicitly with the user before firing it — a decision reached is not automatically a mandate to also implement it.
- A `proposal-*` item's own tracking board-item keeps its `# Context Detail` section current as options narrow and the discussion converges — not left as a stale snapshot from when the item was created.

## Librarian Comments

### Reference

- `magic-team.interview.routine`, `magic-team.brainstorm.routine` — the other two conversational shapes.
- `magic-team.proposal.routine` — puts a binding decision to the human-owner.
- `magic-coordinator.advance.routine` — runs this routine over `proposal-*` items.

### Conventions

- **record-the-outcome** is cited by name from `magic-coordinator.advance.routine`.
