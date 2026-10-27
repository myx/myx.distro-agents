---
type: routine
executors: magic-tester
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

`magic-team.verify.routine` is the testing round on a change claimed complete: `magic-tester` checks it against its done criteria and against what was asked, and gives a verdict carried by real output.

## Goals

- Settle whether a claimed completion is real, by checks that were shown able to fail.
- Check both questions: does the change meet its criteria, and does it do what was asked.

## Scope

- Does:
  - The testing round `magic-coordinator` dispatches for a `board-running` item claimed complete, and a testing round any member asks for on a change. Its executor is `magic-tester`.
- Doesn't:
  - Fix what it finds. A concern goes to `magic-team.investigate.routine`, or back to the builder.
  - Move the item on the board. `magic-coordinator` does that from the verdict.
  - Restate `magic-tester`'s methodology. The steps cite it by section.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **process-own-inbox**: run `magic-team.process-inbox.routine magic-tester` inline (`--routine-run-inline magic-team.process-inbox.routine`), collecting notes on the same change.
2. **state-the-claim**: state what is claimed done, before any check, steps:
   - the item, its done criteria from the plan or the task, and the ask it came from.
   - the files and the places the change touched, read from the change itself, never from the claim.
   - the scope of the round: what it checks, and what it leaves out.
3. **find-the-real-suite**: find the tests that cover the touched code, per `magic-tester.armed.md`'s "Running the real test suite". A "no tests exist" claim is checked against the real test tree.
4. **design-the-checks**: give each done criterion a check, per `magic-tester.armed.md`'s "Test design: the short form", steps:
   - the existing test that covers it, or a narrow new one in the suite's own form.
   - the inputs the design is silent about: empty, one element, absent, extreme.
   - a criterion with no possible check is reported as unverifiable, never as passed.
5. **show-each-check-can-fail**: run each check against a case it must fail on, before trusting it, per `magic-tester.armed.md`'s "Evidence discipline: the short form" ("The failing case comes first").
6. **run-the-checks**: run the checks and the real suite, steps:
   - queue the tests the change touched with `--retest-queue --wait`, and read each result with `--retest-result`.
   - a check with real side effects follows `magic-tester.armed.md`'s "Verifying a change with real side effects: the short form".
   - read back what was stored, through a separate path, per "Verify what stores".
   - record each check: what ran, where, the expected result and the actual one.
7. **run-the-security-pass**: run the Security/CRA pass on the change, per `magic-tester.armed.md`'s "Security/CRA".
8. **check-against-the-ask**: compare the result with the ask the change came from, not only its criteria. A change that meets its criteria and misses the ask is a concern.
9. **give-the-verdict**: give one verdict, with its evidence, steps:
   - **clean**: every criterion checked and passed, the security pass clean or not applicable, the ask met.
   - **concern**: a check failed, the security pass raised a concern, or the ask is missed. Each concern opens `magic-team.investigate.routine` work, or goes back to the builder where the cause is plain.
   - **not verified**: a criterion could not be checked. Say which, and what the check needs.
10. **report-findings**: post the report into the session thread with `ReportFindings`, steps:
    - the verdict first, in one sentence.
    - each criterion with its check and its result, expected against actual.
    - the security pass, each item checked-clean, concern-raised or not-applicable.
    - what stays open.
    - a handback to the session's own parent follows, so `magic-coordinator` can record the round on the item.

# Closure steps

1. **closing-reflection**: reflect on the round: a check that could not fail, a criterion nobody could check, a gap in the suite. A coverage gap goes to `magic-coordinator` with `post-inquiry`, per `magic-tester.armed.md`'s local rules.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- `magic-tester` is permitted and obliged to execute every step exactly as written, in order.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- **The claim is not evidence.** The builder's report of a pass is read as a claim. The round runs its own checks.
- **A clean result needs a dirty one first.** A check never seen failing carries no verdict.
- **Partial is not clean.** A round with any criterion unchecked gives "not verified", whatever the rest shows.
- **Run on a copy.** A check runs against a copy, a scratch workspace or the package's own test rig, per `magic-tester.armed.md`'s local rules.
- **Domain questions go to the owner.** A testing question touching domain internals goes to the owning member, per **routing-to-owner**.
- **Nothing destructive without a confirm.** A destructive or irreversible check waits for its confirmation, per **escalate-before-acting**.
- Waiting follows **wait-never-quit**.
- Goal-directedness: verify the claimed change. Other findings are recorded quickly and filed, not checked now.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

Harness tools: `ReportFindings` posts the report.

## Tooling operations

- `DistroAgentsTesting.fn.sh --retest-queue [--by <who>] [--about <scratch-folder>] --why <text> [--project <p>] [--file <changed-file>]... [--wait|--no-wait] [<test>...]`
- `DistroAgentsTesting.fn.sh --retest-result <request-id>...`
- `DistroAgentsTesting.fn.sh --test-list [--team-member <team-member>] [--project <p>] [--namespace <n>] [--keyword <k>]`
- `--upsert-inbox-inquiry <member> <item-filename> [--include-processed] [--from-file <path>]`
- `--get-board-item <item-filename>`
- `--routine-run-inline <routine>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- (draft) This routine exists so that a claimed completion becomes a verdict carried by checks shown able to fail, against both the criteria and the ask.

## Verbatim-tests (benchmarks)

- (draft) The builder reports every test green. The round runs its own checks, and shows each one failing on a bad case first.
- (draft) Four criteria pass and one cannot be checked. The verdict is "not verified", naming the unchecked criterion.
- (draft) Every criterion passes, but the change does not do what the ask wanted. The verdict is "concern".

## Librarian Comments

### Reference

- `magic-tester/magic-tester.armed.md` — the methodology the steps cite: "Running the real test suite", "Test design: the short form", "Evidence discipline: the short form", "Verifying a change with real side effects: the short form", "Security/CRA".
- `magic-team.plan.routine` — names the checks for each piece.
- `magic-team.investigate.routine` — takes each concern.
- `magic-team/reference/board-model.md` — the testing round of a `board-running` item.

### Conventions

- **show-each-check-can-fail** and **give-the-verdict** are the steps other routines may cite by name.
