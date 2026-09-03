---
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# magic-librarian.conventions-check.routine — the actual procedure

# Summary

Routine-conventions-check is a review pass checking a proposed change — a source-code diff, a skill/routine file, or a chat message — against the team's own established conventions before it lands.

## Goals

A review pass: check something — a proposed source-code diff, a skill/routine `.md` file's internal consistency, or even a chat message, if that's the actual thing being reviewed — against this team's own established conventions, before it lands. Scope is judged from context, not hard-coded to one category: read whatever is actually being proposed, identify the closest existing analog already in the codebase/skill-set, and check the proposal against it directly, never from memory/assumption — read the actual file, don't guess.

## Scope

Does: check a proposed change against the closest existing real analog already in the repo/skill-set — naming, error-message shape, placement, style rules stated in that analog's own header/comments, substance (does it interact correctly with related rules elsewhere), and formulation quality (clarity, no dropped intent/benchmark, whether a better candidate existed).
Doesn't do: invent a "convention" that isn't actually demonstrated somewhere in the real files — a finding must cite the actual file/line it's checked against.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **identify-target-and-analog**: identify what's actually being reviewed and its closest existing real analog already in the repo/skill set (an existing sibling op, an existing sibling `.md` file of the same type, etc.) — read that analog directly, don't rely on a recalled description of it. Across a multi-file or multi-finding batch, the analog is resolved per finding, not once per batch.
2. **compare-against-analog**: compare the proposal against the actual pattern in that analog file — naming, error-message shape, where things are placed, and any style rules stated in that file's own header/comments — including `magic-librarian`'s own "Two writing modes" standard for skill-folder `.md` files.
3. **structure-the-output**: structure all output from this operation — findings, fixes, comparisons, anything — with clear, labeled sections and before/after where relevant, never blended prose.
4. **classify-each-finding**: report each finding as one of — genuine violation (blocks, per the blocking-model rule below, unless the invoker is `magic-coordinator`/human-owner), stylistic judgment call worth flagging but not blocking, or clean. A reviewed formulation fails review if it isn't clearly and easily understandable, if a readback of it drops any intent, important detail, or benchmark the original had, or if a better candidate was available but wasn't chosen — any of these is a genuine finding, same blocking model as above.
5. **cite-real-evidence**: never invent a "convention" that isn't actually demonstrated somewhere in the real files — a finding must cite the actual file/line it's checked against.
6. **check-substance-not-wording**, steps:
   - check that the reviewed content interacts correctly with related rules elsewhere — no contradiction, no missing connection
   - check for any real behavior or pattern with no actual rule backing it anywhere
   - report a missing or incomplete rule as its own finding, same blocking model as a wording problem
7. **recheck-the-fix**: once a blocking finding is addressed, re-run this same check on the fix before it lands — a fix isn't clean just because someone says it's fixed. **Capped at 3 rounds on the same fix**: the same fix failing this check 3 times in a row is a stop-and-escalate signal, not a puzzle to keep iterating on solo — flag it for `magic-coordinator`/human-owner review instead of running a 4th round.
8. **find-best-replacement-wording**: runs only on a formulation whose own wording is the finding — **classify-each-finding**'s formulation clause fired (unclear, a readback drops an intent/detail/benchmark, or a better candidate is suspected). A substance-only finding, or a clean one, skips this step. For each such finding, steps:
   - generate several (around ten) alternative phrasings of that formulation
   - compare them directly against each other against the simple/hard-to-misinterpret bar
   - check whether the one under review is actually the best of that set — not just acceptable on its own
9. **include-replacement-in-finding**: a wording finding includes the actual best replacement found via **find-best-replacement-wording**'s method — never just a flag that something is unclear. This comparison must account for every intent and benchmark of the magic-team that applies, given the type of document and the document itself.

# Closure steps

Invoked inline: nothing. Run as its own session: execute `magic-team.coworking.routine`'s Closure Steps.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines - not visible outside this file.

None currently known beyond the Steps above.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- Whichever team member invokes this routine (this routine's executor is any armed-mode `magic-team` member, not one fixed member) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- **Trigger**: any armed-mode team member may invoke this on its own proposed work before landing it (e.g. `magic-developer` checking a shell-source diff, `magic-librarian` checking its own doc edit). `magic-coordinator` and the human-owner may invoke it against anything, in any state, not gated to armed-mode.
- Mandatory, not just available: any change to a rule/instruction file's own text (per `magic-team`'s own Rule/instruction/definition/description conventions) runs this check before landing — not left to the invoker's own discretion.
- **A change is the only trigger — never a run.** Checking fires on a proposal before it lands, or on a landed change; an instruction already in force has been checked and is not re-checked because something is about to execute. "Verify the instructions before running them" is work with no trigger behind it — don't add such a step to any routine.
- When a change touches a team-member's own behavior or duties — its rules, instructions, or descriptions — this check assesses the update against the `Verbatim-goals (intents)`/`Verbatim-tests (benchmarks)` pair held in that file's own `# Maintainer Notes` section; otherwise this particular check doesn't execute. If assessment alone can't settle whether the change actually holds, `magic-librarian` formulates a concrete testing request and dispatches `magic-tester` to verify it for real. This check's own assessment exists to confirm improvements are present and no regressions exist compared to the prior version, or its absence.
- **Blocking model**: a real, concrete finding blocks the reviewed change from landing until addressed — unless the invoker is `magic-coordinator` or the human-owner themselves, in which case the finding is advisory only (surfaced, not enforced): both already hold final say regardless of this operation's output. A cosmetic/minor finding never blocks — let the normal daily self-sufficiency audit pick it up later. Unsure whether a finding is a real gap or minor: default to surfacing it.
- Every call works on a context and on specific document types. Two calls that read alike are not the same operation — check what each actually touches before treating them as duplicates.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal.
- **Duty-content check, on every skill-file change**: apply `magic-team/magic-team.shared.md`'s "Duty content only — tooling internals belong to the package, never the skillset" rule and its test — *can a member perform this step without this sentence?* Applied per sentence, not per section. A leaked flag, internal op name, under-the-surface tool behaviour, or unsettled design rationale is a real, blocking finding, and the fix is to move it to the destination that rule names, not to reword it in place. See there for the full statement.
- `# Steps`/`# Closure steps` sequencing follows `magic-team/magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

None — this routine uses no `DistroAgentsTools` operations directly; it reads/compares real files and reports findings.

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine's own assessment exists to confirm improvements are actually present and no regressions exist compared to the prior version (or its absence) — not a rubber stamp.
- A finding must cite the actual file/line it's checked against — never an invented convention with no real demonstrated precedent.

## Verbatim-tests (benchmarks)

- A reviewed formulation fails review if a readback of it drops any intent, important detail, or benchmark the original had, even if it reads cleanly on its own.
- Once a blocking finding is addressed, this same check re-runs on the fix before it lands — a fix isn't clean just because someone says it's fixed.

## Librarian Comments

### Reference

- `magic-team.coworking.routine` — its Steps are the opening a session executes; they does no instruction-currency checking of its own, since checking is triggered by a change, not by a run.
- `magic-librarian/magic-librarian.armed.md` — "Two writing modes" standard for skill-folder `.md` files, checked at **compare-against-analog**; also the sole location for a member's own `Verbatim-intents`/`Verbatim-benchmarks` pair this check assesses updates against.
- `magic-team/magic-team.armed.md` — the Rule/instruction/definition/description conventions section that makes this check mandatory (not discretionary) for any rule/instruction-file text change.

### Conventions

- This file's section shape is confirmed canonical for every `routine-*/*.routine.md` file.
  - `owner-guaranteed`.
  - This file is correctly a full `routine-*`-style member, not a single self-contained file like `magic-librarian.slib-generation.operation.md`.
  - Not a draft.
- `(draft)` markers are load-bearing provenance, not decoration. Remove one only once the human-owner confirms that specific section directly: a real chat reply in their own voice, or a real accept/reject on the file — and only that section's own label, not the others. None remain open in this file.
- The multi-candidate comparison method (**find-best-replacement-wording**) is this routine's real mechanism for judging "was this the best formulation."
  - Generate ~10 alternative phrasings, compare directly.
  - Preserve it precisely — don't compress it into "check if the wording is good."
