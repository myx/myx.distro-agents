---
type: routine
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: standalone
input-scan-def: none
review-by: inherit
---
# magic-team.verify.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Opening steps
- Steps
- Closure steps
- Routine's local procedures
  - `software-checks` — the checks of a software change
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

`magic-team.verify.routine` checks a piece of work claimed complete against its done criteria and against what was asked, and gives a verdict carried by real evidence. For software it is `magic-tester`'s testing round.

## Goals

- Settle whether a claimed completion is real, by checks shown able to fail.
- Check both questions: does the work meet its criteria, and does it do what was asked.

## Scope

- Does:
  - Verify one piece of work claimed complete: a software change, a set of accounts, a document, a model, a configured system. The executor is the verifier the plan names: `magic-tester` for software, else the domain owner.
  - The testing round `magic-coordinator` dispatches for a `board-running` item claimed complete.
- Doesn't:
  - Fix what it finds. A concern goes to `magic-team.investigate.routine`, or back to the builder.
  - Move the item on the board. `magic-coordinator` does that from the verdict.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **process-own-inbox**: run `magic-team.process-inbox.routine <own-name>` inline (`--routine-run-inline magic-team.process-inbox.routine`), collecting notes on the same work.
2. **state-the-claim**: state what is claimed done, before any check, steps:
   - the item, its done criteria from the plan or the task, and the ask it came from.
   - what the work changed, read from the work itself, never from the claim.
   - the scope of the round: what it checks, and what it leaves out.
3. **design-the-checks**: give each done criterion a check that is independent of the work's own report, steps:
   - recompute, reconcile, inspect or run, by the kind of work: a total recomputed from its source records, a document read against its requirements, a model measured, a program tested.
   - the cases the work is silent about: empty, one element, absent, extreme.
   - a criterion with no possible check is reported as unverifiable, never as passed.
   - for software, run **software-checks** as well.
4. **show-each-check-can-fail**: run each check against a case it must fail on, before trusting it. A check never seen failing carries no verdict.
5. **run-the-checks**: run every check, steps:
   - a check with real consequences is previewed first, and runs only with the confirmation it needs.
   - read back what was stored, through a separate path, never the write's own success.
   - record each check: what ran, where, the expected result and the actual one.
6. **check-against-the-ask**: compare the result with the ask the work came from, not only its criteria. Work that meets its criteria and misses the ask is a concern.
7. **give-the-verdict**: give one verdict, with its evidence, steps:
   - **clean**: every criterion checked and passed, the ask met.
   - **concern**: a check failed, or the ask is missed.
   - **not verified**: a criterion could not be checked. Say which, and what the check needs.
8. **report-and-route**: post the report into the session thread with `ReportFindings`, then name the next flow step, steps:
   - the verdict first, in one sentence.
   - each criterion with its check and its result, expected against actual.
   - what stays open.
   - the next flow step, by verdict:
     - **clean** — acceptance: the item's reviewer settles it with `magic-team.handback-review.routine`.
     - **concern**, cause plain — back to the builder, with the failed check.
     - **concern**, cause unknown — `magic-team.investigate.routine`, through its **defect-branch**.
     - **not verified** — `magic-team.plan.routine`, to plan the missing check.
   - a handback to the session's own parent follows, so `magic-coordinator` can record the round on the item.

# Closure steps

1. **closing-reflection**: reflect on the round: a check that could not fail, a criterion nobody could check, a gap in the checks the work has. A coverage gap goes to `magic-coordinator` with `post-inquiry`.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

## `software-checks` — the checks of a software change

Run by `magic-tester`, with its own methodology, cited by name. Steps:
1. **find-the-real-suite**: find the tests that cover the touched code, per "Running the real test suite". A "no tests exist" claim is checked against the real test tree.
2. **design-by-the-suite**: give each criterion the existing test that covers it, or a narrow new one in the suite's own form, per "Test design: the short form".
3. **failing-case-first**: per "Evidence discipline: the short form".
4. **queue-and-read**: queue the tests the change touched with `--retest-queue --wait`, and read each result with `--retest-result`. A check with real side effects follows "Verifying a change with real side effects: the short form".
5. **security-pass**: run the "Security/CRA" pass on the change. Each item is checked-clean, concern-raised or not-applicable in the report.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- The executing member is permitted and obliged to execute every step exactly as written, in order.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- **The claim is not evidence.** The builder's report of a pass is read as a claim. The round runs its own checks.
- **The verifier is not the builder.** The member who did the work never gives its verdict.
- **Partial is not clean.** A round with any criterion unchecked gives "not verified", whatever the rest shows.
- **Run on a copy.** A check runs against a copy, a scratch workspace or a test rig, never the live original, unless the approval for that is held.
- **Domain questions go to the owner.** A question touching a domain's internals goes to the owning member, per **routing-to-owner**.
- Waiting follows **wait-never-quit**.
- Goal-directedness: verify the claimed work. Other findings are recorded quickly and filed, not checked now.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

Harness tools: `ReportFindings` posts the report.

## Tooling operations

- `DistroAgentsTesting.fn.sh --retest-queue [--by <who>] [--about <scratch-folder>] --why <text> [--project <p>] [--file <changed-file>]... [--wait|--no-wait] [<test>...]` — software only
- `DistroAgentsTesting.fn.sh --retest-result <request-id>...` — software only
- `DistroAgentsTesting.fn.sh --test-list [--team-member <team-member>] [--project <p>] [--namespace <n>] [--keyword <k>]` — software only
- `--upsert-inbox-inquiry <member> <item-filename> [--include-processed] [--from-file <path>]`
- `--get-board-item <item-filename>`
- `--routine-run-inline <routine>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- (draft) This routine exists so that a claimed completion becomes a verdict carried by checks shown able to fail, against both the criteria and the ask.

## Verbatim-tests (benchmarks)

- (draft) The builder reports every test green. The round runs its own checks, and shows each one failing on a bad case first.
- (draft) Four criteria pass and one cannot be checked. The verdict is "not verified", naming the unchecked criterion, and the next step is a plan for the missing check.
- (draft) A quarterly report is claimed complete. The verifier recomputes its totals from the source records, not from the report.

## Librarian Comments

### Reference

- `magic-tester/magic-tester.armed.md` — the methodology **software-checks** cites by section name.
- `magic-team.plan.routine` — names the checks and the verifier for each piece.
- `magic-team.investigate.routine` — takes a concern whose cause is unknown.
- `magic-team/reference/board-model.md` — the testing round of a `board-running` item.

### Conventions

- **show-each-check-can-fail**, **give-the-verdict**, **report-and-route** and **software-checks** are cited by name from other files.
