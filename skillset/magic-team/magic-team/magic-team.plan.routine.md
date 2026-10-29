---
type: routine
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: coworking
input-scan-def: none
review-by: inherit
runs-at: none
---
# magic-team.plan.routine — the actual procedure

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

`magic-team.plan.routine` turns one decided piece of work, smaller than an epic, into a plan the team can approve and run. The plan holds the pieces, their order, who and what each needs, and how each is verified.

Handles: task, project

## Goals

- Give an implementation one approved plan to follow, so no builder invents its scope, its order or its checks.
- Find the risks of the plan before the work starts, not during it.

## Scope

- Does:
  - Plan one task whose goal is decided: a `task-*` item, an approved proposal, or a settled interview piece. Any member runs it, on request.
- Doesn't:
  - Decide what to do (`magic-team.discuss.routine`), plan an epic (`magic-team.epic-intake.routine`), or order the backlog (`magic-team.grooming.routine`).
  - Build anything. An approved plan is implemented by its own dispatch.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **process-own-inbox**: run `magic-team.process-inbox.routine <own-name>` inline (`--routine-run-inline magic-team.process-inbox.routine`), collecting notes on the same task.
2. **state-the-outcome**: state what the task delivers, before any breakdown, steps:
   - the outcome, as a result someone can see, never as a list of actions.
   - the done criteria: each one a check that can pass or fail.
   - the scope boundary: what is in, what is out, and what must not be touched.
   - the constraints: deadlines, approvals, places, budgets.
   - read the statement back to whoever asked, per **rephrase-and-confirm-before-acting**.
3. **read-the-record-first**: read the task's item and its `## Decisions`, the `MAGIC.md` of each tree it touches, and the help of each tool it uses. Find the sibling the work should match, per the family's existing form.
4. **break-down-by-outcome**: split the outcome into pieces, steps:
   - name each piece by what it delivers, not by the actions inside it.
   - the pieces together cover the whole scope, and nothing outside it.
   - no two pieces overlap. Each piece has one owner.
   - split a piece again only while it is too big for one work session.
5. **order-the-pieces**: put the pieces in an order that keeps the work usable, steps:
   - what others build on comes first. In software, a definition comes before its callers.
   - after each piece, the work stays usable. A piece that breaks it until a later one lands is split or reordered.
   - record each dependency as `blocks`/`blocked-by` between the pieces.
6. **name-what-each-piece-needs**: for each piece, make the best guess its dispatch can carry, steps:
   - the members and expertise, the access permissions, and the tools, worked out from its targets: paths, pages, any text.
   - its verification: the check that proves it done, and the case it must fail on. Agree both with the member who will verify it (`magic-tester` for software).
   - a destructive or irreversible step inside it, marked for confirmation before it runs.
7. **imagine-it-failed**: assume the plan was carried out and failed, steps:
   - each participant names what went wrong, without debate.
   - for each cause worth acting on: add a check, a mitigation or a fallback to the piece it hits, or record the risk as accepted.
8. **check-the-plan**: put the plan to the members whose lens it needs, steps:
   - `magic-architect` for a new structure, dependency or contract.
   - the verifier of each piece for its check: `magic-tester` for software, else the domain owner.
   - `magic-librarian` for the plan's text.
   - a disagreement becomes the no-quorum document, per "The ladder: one rung at a time".
9. **propose-and-route**: write the plan into the task's tracking document, put it up for approval, and name the next flow step, steps:
   - the outcome and done criteria, the pieces in order, each piece's needs and checks, and the accepted risks.
   - a plan that binds the team, or needs the human-owner's go, goes through `magic-team.proposal.routine`.
   - otherwise the session's own parent approves it, per "The ladder: one rung at a time".
   - the next flow step, by outcome:
     - **approved** — each piece goes to the board for its implementation dispatch, then `magic-team.verify.routine` on each piece claimed complete.
     - **returned with a choice to make** — `magic-team.discuss.routine`.
     - **returned because the ask is unclear** — `magic-team.interview.routine`.
     - **a fact missing** — `magic-team.investigate.routine` for the thing itself, `magic-team.research.routine` for outside sources.

# Closure steps

1. **closing-reflection**: reflect on how the planning went: a piece that would not split, a dependency found late, a risk nobody named. A pattern with no written rule behind it becomes a `reflection-*`.
2. **hand-off-approved-pieces**: each approved piece is handed to `magic-coordinator` with `post-inquiry`, for the board. Approving a plan is not a go to start it.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- The executing member is permitted and obliged to execute every step exactly as written, in order.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- Each round follows **run-a-round** and **stop-or-go**.
- **Plan, never build.** No piece starts during planning. An experiment the plan needs is filed as `magic-team.investigate.routine` work.
- **Every piece is checkable.** A piece with no check that can fail is not ready for the plan.
- **The whole scope, and only it.** A piece outside the stated scope is filed as a proposal, never planned in.
- **A gap is asked, not filled.** A fact the plan needs and nobody holds goes to `magic-team.investigate.routine`, `magic-team.research.routine` or the owner, never into a guess.
- Every exchange that decides something is kept as a `transcript-*` with `--append-transcript --transcript-name`. Waiting follows **wait-never-quit**.
- Goal-directedness: plan the stated task. Other work found on the way is recorded quickly, not planned now.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## Tooling operations

- `--append-transcript --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <text>|--from-stdin|--from-file <path>) --transcript-name <transcript-file-name> [--create]` — the named `transcript-*` this routine keeps. `SessionTranscriptAppend` takes a note line.
- `--upsert-inbox-reflection <member> <item-filename> [--include-processed] [--from-file <path>|--edit-patch-from-stdin]`
- `--upsert-inbox-inquiry <member> <item-filename> [--include-processed] [--from-file <path>]`
- `--get-board-item <item-filename>`
- `--routine-run-inline <routine>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- (draft) This routine exists so that every task smaller than an epic starts from one approved plan. The plan is whole in scope, ordered so the work stays usable, and checkable piece by piece.

## Verbatim-tests (benchmarks)

- (draft) A piece would leave the work unusable until the next piece lands. The plan splits or reorders it, so each step leaves the system working.
- (draft) A piece has no check that can fail. The plan is not proposed until the piece has one.
- (draft) The plan is approved. Nothing is built until a dispatch is given the go.

## Librarian Comments

### Reference

- `magic-team.epic-intake.routine` — planning for an epic, above the threshold where waves and lanes are needed.
- `magic-team.verify.routine` — runs the checks this plan names.
- `magic-team.proposal.routine` — approval for a plan that binds the team.

### Conventions

- **state-the-outcome**, **order-the-pieces**, **imagine-it-failed** and **propose-and-route** are the steps other routines may cite by name.
