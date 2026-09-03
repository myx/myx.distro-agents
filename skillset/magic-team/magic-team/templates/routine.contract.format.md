---
executors: [<team-member-or-magic-team>]
maintainers: [<group, e.g. magic-coordinator magic-librarian magic-architect>]
invitees: [<only if this routine has genuine multi-member sessions>]
---
# routine-<short-name> — the actual procedure

Normative contract: `magic-team/magic-team.shared.md`'s "Armed & Routine contracts" → Routine. This file is a derived skeleton; where the two disagree, `magic-team/magic-team.shared.md` wins.

# Summary

[One short sentence, names the routine.]

## Goals

- [Compact narrative, still detailed.]

## Scope

- Does:
  - [...]
- Doesn't:
  - [...]

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **[step-one-name]**: [Step one. Every step carries a name in this shape — what it does, never where it sits; unique within the file.]
   - goal: [What this branch is for. Optional, may be several, goes first, never executed.]
   - rule: [A rule in force only inside this branch, only once it is entered. Order-independent, grouped before the steps.]
   - step: [Step-one sub-step 1, ordered.]
      - rule: [Same grammar at any depth.]
      - step: [Deeper sub-step, ordered.]
   - step: [Step-one sub-step 2, ordered.]
   ...
2. **[step-two-name]**: [Step two, whose nested lines are all the same kind — so the kind is declared once here instead of prefixing each line,] steps:
   - [Sub-step 1, ordered.]
   - [Sub-step 2, ordered.]

# Closure steps

[If `# Steps` already ends with an identifiable closing tail, relocate it here verbatim. If not, state that plainly plus a pointer to whatever actually closes this routine.]

1. **[closure-step-one-name]**: [Closure step one — runs only after `# Steps` and everything it extended/dispatched/spawned have finished.]

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

## `<local-procedure-name>` — [goal+intent short summary]

Steps:
1. [...]

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- [...]

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- [`--operation-name <args>`]

## `--operation-name` Operation Reference

[Syntax again, plus every exact description/comment needed to run it correctly.]

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- [Abstract goal statement, for conflict testing.]

## Verbatim-tests (benchmarks)

- [Concrete edge-case test.]

## Librarian Comments

### Reference

- [...]

### Conventions

- [...]