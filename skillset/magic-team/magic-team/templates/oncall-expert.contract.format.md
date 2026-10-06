---
maintainers: [<group, e.g. magic-coordinator magic-librarian magic-architect>, human-owner]
---
# <name>.armed.md — example skeleton (`oncall-*`/`expert-*`)

Normative contract: this file's own `# Contract` section, at its end. Where it and the skeleton disagree, `# Contract` wins. `# Contract` is not part of the skeleton and is not copied. No live `oncall-*`/`expert-*` member exists yet — roster category reserved.

## Contents

- Summary
  - Goals
  - Scope
    - Engagement shape
- Terminology: <topic>
  - Term: <term-name>
- Team-Member's (-specific) local procedures
  - `<local-procedure-name>` — [goal+intent short summary]
- Team-Member's (-specific) local rules
- Domain knowledge: <topic>
- Team-Member's (-specific) tooling
  - DistroAgentsTools magic-tooling operations
  - `--operation-name` Operation Reference
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions
- Contract

# Summary

[One short sentence, names the team-member.]

## Goals

- [Compact narrative, still detailed.]

## Scope

- Does:
  - [Invocation conditions, auto-trigger behavior.]
  - [...]
- Doesn't:
  - [...]

### Engagement shape

- Not a standing team member: a costed, external AI-service resource, spawned into a billed pay-per-time session, brought in to boost/accelerate one specific, complicated task.
- Domain of expertise: [the specific type(s) of work this member is brought in for — not a workspace, a work-type].
- Remote execution account info: this member's own settings name whatever account/credential the billed remote service is actually reached through.
- Spawn trigger, cost/billing tracking, session lifecycle: [not yet defined team-wide — state whatever this specific member's own instructions already settle, flag the rest as open].

# Terminology: <topic>

[Pure glossary, `term` → definition. `# Terminology: none` if empty.]

## Term: <term-name>

[Only when a term needs more than one line.]

# Team-Member's (-specific) local procedures

Named procedure blocks. Steps below call them by name. Not separate routines — not visible outside this file.

## `<local-procedure-name>` — [goal+intent short summary]

Steps:
1. [...]

# Team-Member's (-specific) local rules

All statements apply at the same time, always. These rules override a magic-team's own general `.armed.md` rules while working in this member's own routine.

- This team-member is permitted and obliged to execute every one of its own local procedures and duties exactly as written.
- [Flat, present-tense rule bullet: limit, restriction, or decision-making guidance.]

# Domain knowledge: <topic>

[This member's own reference material, or `: none`.]

# Team-Member's (-specific) tooling

Every `magic-tooling` operation this team-member uses. Behaviour is read with `--member-help`. Steps use its name only.

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

- [Pointers to this folder's own typed files, cross-referenced skill folders, shared material.]

### Conventions

- [...]

# Contract

- Frontmatter: `maintainers:` only.
- `# Summary`
  - One short sentence, names the team-member.
  - `## Goals`
    - Compact narrative, still detailed.
  - `## Scope`
    - What it does.
    - What it deliberately doesn't do.
    - Invocation conditions and auto-trigger behavior stated here.
    - `### Engagement shape` — present even if N/A.
      - Not a standing team member: a costed, external AI-service resource, spawned into a billed pay-per-time session, brought in to boost/accelerate one specific, complicated task.
      - Domain of expertise: the specific type(s) of work this member is brought in for — not a workspace, a work-type.
      - Remote execution account info: this member's own settings name whatever account/credential the billed remote service is actually reached through.
      - Spawn trigger, cost and billing tracking, and session lifecycle are not yet defined team-wide. State whatever this specific member's own instructions already settle, and flag the rest as open.
- `# Terminology: <topic>`
  - Pure glossary, `term` → definition.
  - `## Term: <name>` only when a term needs more than one line.
  - `# Terminology: none` when empty.
- `# Team-Member's (-specific) local procedures`
  - Named procedure blocks, `## <local-procedure-name>`, called by name.
  - Not separate routines.
  - Not visible outside this file.
- `# Team-Member's (-specific) local rules`
  - text: "All statements apply at the same time, always. These rules override a magic-team's own general `.armed.md` rules whenever this member is acting."
  - nested list of rules, flat, present-tense, no dedicated sub-headings, always including:
    - "This team-member is permitted and obliged to execute every one of its own local procedures and duties exactly as written."
    - Decision authority: this member relays between `magic-coordinator` and the task. It never decides design or approach independently unless explicitly granted. It cross-references its own `magic-team.authority.<type>.contract.md` (`oncall` or `expert`), never restated in full.
    - this member's own further limits, restrictions, decision-making guidance.
- `# Domain knowledge: <topic>`
  - This member's own reference material, or `: none`.
- `# Team-Member's (-specific) tooling`
  - Every `magic-tooling` operation this member uses, listed with its syntax. Behaviour is read with `--member-help`; an Operation Reference carries only what that help does not.
- `# Maintainer Notes`
  - `## Verbatim-goals (intents)`
  - `## Verbatim-tests (benchmarks)`
  - `## Librarian Comments`
    - `### Reference`
    - `### Conventions`
- This contract applies once such a member is created.
