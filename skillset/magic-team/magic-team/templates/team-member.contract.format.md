---
maintainers: [<group, e.g. magic-coordinator magic-librarian magic-architect>]
---
# <name>.armed.md — example skeleton (`magic-*`)

Normative contract: `magic-team.shared.md`'s "Armed & Routine contracts" → Team-member. This file is a derived skeleton; where the two disagree, `magic-team.shared.md` wins.

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
- `DistroAgentsTools.fn.sh` always executes via the `myx.distro` MCP tool `mcp__myx_distro__execute` (argument `command`, the shell script itself) — never Bash, a Python/notebook execution tool, or any other tool that runs a process directly. Any non-mutating, read-only shell command also executes via `mcp__myx_distro__execute` the same way.
- [Flat, present-tense rule bullet: limit, restriction, or decision-making guidance.]

# Domain knowledge: <topic>

[This member's own reference material, or `: none`. Owned routines named here, each pointing to its own exact `.routine.md` filename.]

# Team-Member's (-specific) tooling

Every `magic-tooling` operation this team-member uses. Full syntax and behavior here. Steps use its name only.

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

- [Pointers to this folder's own typed files, cross-referenced skill folders, shared material.]

### Conventions

- [...]