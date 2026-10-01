---
executors: <team-member-or-magic-team>
maintainers: <group, e.g. magic-coordinator, magic-librarian, magic-architect>, human-owner
invitees: <only if this routine has genuine multi-member sessions>
---
# <owning-member>.<short-name>.routine — the actual procedure

Normative contract: this file's own `# Contract` section, at its end. Where it and the skeleton disagree, `# Contract` wins. `# Contract` is not part of the skeleton and is not copied.

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

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

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

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- [`--operation-name <args>`]

## `--operation-name` Operation Reference

[Only what the operation's own help, read with `--member-help`, does not carry. Omit this subsection where the help carries it all.]

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

# Contract

- Frontmatter: `executors:`, `maintainers:`, `invitees:`, `default-for-session-kind:` (optional).
- `default-for-session-kind:` (optional)
  - A single session-kind word naming this routine as the spawner's standing default for that kind, used
    only when nothing more specific was asked for.
  - At most one routine file in the whole skillset carries a given value.
  - `executors:` on the same file already states the default member identity the spawner boots for that
    session.
- `# <owning-member>.<short-name>.routine — the actual procedure`
  - The file's own title line, before `# Summary` — every existing routine file carries one.
  - The title is the file's own name minus `.md`: a routine is named by its file, never by an identity of its own.
- `# Summary`
  - One short sentence, names the routine.
  - `## Goals`
    - Compact narrative, still detailed.
  - `## Scope`
    - What it does.
    - What it deliberately doesn't do.
- `# Steps`
  - Exact instructions, execute in order, literally as written.
  - A step that can't execute as written: escalate it, and never skip it silently.
  - Exact steps as nested lists. Nested lines follow `magic-team/magic-team.shared.md`'s nested-item grammar (`goal:`/`rule:`/`step:`).
  - Every root-level step carries a name, in the established shape: `<N>. **name-of-meaning**: …` — names what the step does, never where it sits. Unique within the file.
  - A step is referred to by its name, not its number alone — inside the file and from any other file. A step with no name can only be pointed at by position, and position is the first thing an edit changes.
  - Applied as each routine file is next touched, not as a sweep.
- `# Closure steps`
  - Same shape/discipline as `# Steps`.
  - Runs only after `# Steps`, and everything it extended/dispatched/spawned, have finished.
  - An already-existing closing tail in `# Steps` relocates here verbatim — no invented content.
  - No closing tail of its own: state that plainly, plus a pointer to whatever actually closes it.
  - Sequencing: `magic-team/magic-team.shared.md`'s own "Routine" entry.
- `# Routine's local procedures`
  - Named procedure blocks, `## <local-procedure-name>`, called by name from `# Steps`.
  - Not separate routines.
  - Not visible outside this file.
- `# Routine's local rules`
  - All statements apply simultaneously.
  - Override a participant's own general `.armed.md` rules while this routine is active.
  - Executor is permitted/obliged to execute every step as written.
  - Participants obey this routine's own rules over their normal ones.
  - Any other rules, exceptions, overrides.
- `# Routine-specific tooling`
  - Every `magic-tooling` operation this routine uses — not more, not less.
  - `## DistroAgentsTools magic-tooling operations`
    - List, with argument syntax.
  - `## <--operation-name> Operation Reference`
    - Only what that operation's own help, read with `--member-help`, does not carry. Absent where the help carries it all.
- `# Maintainer Notes`
  - Not part of a participant's own instructions.
  - `## Verbatim-goals (intents)`
    - Abstract goal statements, for conflict testing.
  - `## Verbatim-tests (benchmarks)`
    - Concrete edge-case tests.
  - `## Librarian Comments`
    - `### Reference`
      - Pointers, folded in from any `.reference.md`.
    - `### Conventions`
      - This file's own conventions.
