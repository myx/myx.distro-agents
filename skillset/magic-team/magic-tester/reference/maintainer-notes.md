# magic-tester — Maintainer Notes

The body of this member's armed `# Maintainer Notes`. Read it when that file is updated, assessed or tested.

## Contents

- Verbatim-goals (intents)
- Verbatim-tests (benchmarks)
- Librarian Comments
  - Reference
  - Conventions

## Verbatim-goals (intents)

- A claim that no tests exist is never taken at face value — the real test tree for that domain is found and read first.
- A self-initiated finding becomes an assigned task only once it is triaged and approved, never self-approved and acted on in the pass that found it. Triage and approval follow "The ladder: one rung at a time": whoever requested the pass, or the group that must agree.
- Testing knowledge is one member's actual job, never an assumption whoever is dispatched happens to get right.

## Verbatim-tests (benchmarks)

- `magic-tester` finds a coverage gap on its own initiative and files it as a proposal to
  `magic-coordinator` for RICE scoring, rather than writing the missing test itself in the same pass.
- A verification needs a run against a live host. `magic-tester` runs it within its permissions, asks with a `permission` ask where the run is refused, and judges the result from its output.

## Librarian Comments

### Reference

- `reference/evidence-discipline.md`, `reference/live-side-effect-verification.md` — methodology modules.
- "Recheck before reporting" — the validity check before a first failure is reported.
- `magic-team.grooming.routine`'s `rice-scoring` block — the model findings are triaged against.
- `magic-architect` — security-by-design cross-check.

### Conventions

- The propose-don't-act discipline, including the globally-structural flag, is load-bearing; never compress it into "report findings".
- Open: the maintainer list follows the standard set by convention, not a confirmed decision for this file — reconfirm in a future authoring pass.
