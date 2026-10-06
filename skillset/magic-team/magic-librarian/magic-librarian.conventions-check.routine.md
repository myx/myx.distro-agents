---
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-librarian.conventions-check.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Steps
- Closure steps
- Routine's local procedures
  - `override-queue-read` — review the output-style declarations log
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

`magic-librarian.conventions-check.routine` checks a proposed change — a source diff, a skillset file, a message — against the team's established conventions before it lands.

## Goals

- Judge the proposal against the closest real analog already in the codebase or skillset, read directly, never recalled.
- Confirm improvements are present and nothing regressed against the prior version.

## Scope

- Does:
  - Check naming, error-message shape, placement, shape and verbosity, style rules stated in the analog, substance, and formulation quality.
- Doesn't:
  - Invent a convention not demonstrated in real files: every finding cites the file and line it is checked against.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **identify-target-and-analog**: Identify what is reviewed and its closest real analog — a sibling operation, a sibling file of the same type. Read the analog directly. In a batch, resolve the analog per finding.
2. **compare-against-analog**: Compare the proposal with the analog: naming, error-message shape, placement, shape and verbosity, and style rules stated in the analog itself, including `magic-librarian/magic-librarian.armed.md`'s "Two writing modes".
   - rule: shape and verbosity means how much the analog carries — lead-in length, prose around the substance, element count. A proposal several times more elaborate than its analog fails here alone.
   - rule: emitted text is compared against `magic-team/magic-team.shared.md`'s "The output-style floor", as `magic-librarian/magic-librarian.armed.md`'s "Applying the output-style floor" applies it. Carried spans are not measured.
3. **structure-the-output**: Structure every output in labelled sections, with before and after where relevant.
4. **classify-each-finding**: Classify each finding: genuine violation, judgement call worth flagging, or clean. A formulation is a genuine finding when it is not easily understood, when a readback drops an intent, detail or benchmark the original had, or when a better candidate exists.
5. **cite-real-evidence**: Cite the file and line each finding is checked against. An output-style finding cites the clause number and the measured value. A clause carrying no number is a judgement call.
6. **check-substance-not-wording**, steps:
   - check the content agrees with related rules elsewhere: no contradiction, no missing connection
   - check for behaviour with no rule behind it
   - check each rule is stated, or pointed to, at the step where it must fire
   - check every sentence against `magic-team/magic-team.shared.md`'s "Duty content only": can a member perform this step without it? A leaked tooling internal is a genuine finding, fixed by moving it to the destination that rule names
   - report a missing or incomplete rule as its own finding
7. **recheck-the-fix**: Re-run this check on the fix for each blocking finding. The same fix failing three times in a row is escalated to `magic-coordinator`, not tried a fourth time.
8. **find-best-replacement-wording**: For each finding whose own wording is the fault, steps:
   - generate about ten alternative phrasings
   - compare them against each other on the simple, hard-to-misread bar
   - check whether the reviewed one is the best of the set, not merely acceptable
9. **include-replacement-in-finding**: A wording finding carries the best replacement found, checked against every intent and benchmark that applies to the document.

# Closure steps

Invoked inline: none. Run as its own session: `magic-team.coworking.routine`'s Closure steps.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

## `override-queue-read` — review the output-style declarations log

A declaration is a member's own claim about the text it labelled — relay, report — which the machine cannot verify.

Steps:
1. Read the declarations log with `--member-audit-item-read`, by document name.
   - Open: three gaps block this read — the accessor's type policy admits only `transcript-*`, its folder resolver matches only `transcript-` with a hyphenated date, and the team's compact date form conflicts with that resolver (`magic-librarian`'s to settle). Until all three close, report the after-send check as required and missing; never substitute a path read.
2. Run this routine's Steps against the text each entry carries, at the group it declares.
3. Report a declaration that does not match its text: a relay declaration on the member's own words, a report declaration on a message.
4. Apply the reader-judged clauses here.

A clean queue is not evidence the measurements are sound: a member rewriting correct text into worse text to pass leaves no entry.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- **Who runs it**: `magic-librarian` on every skillset change (`magic-team/magic-team.armed.md`, "Rule/instruction/definition/description conventions"); any armed member on its own proposed work before landing it; `magic-coordinator` and the human-owner on anything.
- **A change is the only trigger — never a run.** An instruction already in force is not re-checked because something is about to execute it.
- A change to a member's or routine's rules is assessed against that file's `Verbatim-goals (intents)`/`Verbatim-tests (benchmarks)`. Where assessment cannot settle it, a concrete testing request goes to `magic-coordinator` for a `magic-tester` round.
- **Blocking model**: a genuine finding blocks the change until addressed, except where the invoker is `magic-coordinator` or the human-owner, for whom it is advisory. A cosmetic finding never blocks. Unsure: surface it.
- **A check is shown able to pass before it gates anything.** Run a candidate check, predicate or rule against text that must pass before text that must fail. A check that refuses correct work teaches people to route around it.
- Two calls that read alike may touch different contexts and document types. Check what each touches before treating them as duplicates.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-audit-item-read <team-member> <document-name>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine's own assessment exists to confirm improvements are actually present and no regressions exist compared to the prior version (or its absence) — not a rubber stamp.
- A finding must cite the actual file/line it's checked against — never an invented convention with no real demonstrated precedent.

## Verbatim-tests (benchmarks)

- A reviewed formulation fails review if a readback of it drops any intent, important detail, or benchmark the original had, even if it reads cleanly on its own.
- Once a blocking finding is addressed, this same check re-runs on the fix before it lands — a fix isn't clean just because someone says it's fixed.
- A proposed section is modelled on one in another file and carries several times its lead-in, prose and element count. It fails **compare-against-analog** on shape and verbosity alone, even where naming, placement and header style all match.
- A rule applies at a step, but the file states it only in a different section scoped to another direction or case. The check reports a missing connection, even though the rule text exists.
- A new element is added to a file. It is measured against the siblings it joins at its own level — a section against that file's other sections, a list item against the list it enters — never against the file as a whole.

## Librarian Comments

### Reference

- `magic-librarian/magic-librarian.armed.md` — "Two writing modes", "Applying the output-style floor", the Verbatim convention.
- `magic-team/magic-team.armed.md` — the skillset change rule that makes this check part of every skillset change.

### Conventions

- `(draft)` labels are removed only on the human-owner's own confirmation of that section.
- The multi-candidate comparison in **find-best-replacement-wording** is this routine's real mechanism for judging a formulation; never compress it to "check the wording".
