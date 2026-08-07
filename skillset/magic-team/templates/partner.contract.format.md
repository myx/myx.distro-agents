---
maintainers: [<group, e.g. magic-coordinator magic-librarian magic-architect>]
---
# <name>.armed.md — example skeleton (`partner-*`)

Copy this file's shape into a new `<name>.armed.md`, alongside a matching `<name>.basic.md` and `SKILL.md`. Fill every bracketed placeholder. Full contract: `magic-team.shared.md`'s "Armed & Routine contracts" → Partner. No distinct mandatory subsection beyond this shape exists yet in any real `partner-*.armed.md` file — same shape as Team-member, written out here as its own copyable skeleton.

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

- [Flat, present-tense rule bullet: limit, restriction, or decision-making guidance.]

# Domain knowledge: <topic>

[This member's own reference material, or `: none`.]

# Team-Member's (-specific) tooling

Every `magic-tooling` operation this team-member uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- [`--operation-name <args>`]

## `--operation-name` Operation Reference

[Syntax again, plus every exact description/comment needed to run it correctly.]

# Maintainer Notes

Used to check this file's own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- [Abstract goal statement, for conflict testing.]

## Verbatim-tests (benchmarks)

- [Concrete edge-case test.]

## Librarian Comments

### Reference

- [Pointers to this folder's own typed files, cross-referenced skill folders, shared material.]

### Conventions

- [...]
