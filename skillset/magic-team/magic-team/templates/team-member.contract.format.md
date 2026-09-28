---
maintainers: [<group, e.g. magic-coordinator magic-librarian magic-architect>, human-owner]
---
# <name>.armed.md — example skeleton (`magic-*`)

Normative contract: this file's own `# Contract` section, at its end. Where it and the skeleton disagree, `# Contract` wins. `# Contract` is not part of the skeleton and is not copied.

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

[This member's own reference material, or `: none`. Owned routines named here, each pointing to its own exact `.routine.md` filename.]

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
    - this member's own limits, restrictions, decision-making guidance.
- `# Domain knowledge: <topic>`
  - This member's own reference material, or `: none`.
  - Owned routines are named here, typically in a routines-index subsection. Each points to its own exact `.routine.md` filename. That is the only place in this file that filename is spelled out.
- `# Team-Member's (-specific) tooling`
  - Every `magic-tooling` operation this member uses, listed with its syntax. Behaviour is read with `--member-help`; an Operation Reference carries only what that help does not.
- `# Maintainer Notes`
  - `## Verbatim-goals (intents)`
  - `## Verbatim-tests (benchmarks)`
  - `## Librarian Comments`
    - `### Reference`
      - This folder's own knowledge index: pointers to this folder's own typed files, cross-referenced skill folders, shared (`*.shared.md`) material.
    - `### Conventions`

- **Floor-doc carve-out — `magic-team` only.** As the team-avatar whose `.armed.md` is every member's baseline, `magic-team` may carry extra top-level sections for genuinely team-wide content, placed between `# Team-Member's (-specific) local rules` and `# Team-Member's (-specific) tooling`. No other member takes this carve-out.
