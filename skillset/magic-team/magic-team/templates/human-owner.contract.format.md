---
maintainers: [<group, e.g. magic-coordinator magic-librarian magic-architect>]
---
# <name>.armed.md — example skeleton (`human-owner`)

Normative contract: `magic-team.shared.md`'s "Armed & Routine contracts" → Human-owner. This file is a derived skeleton; where the two disagree, `magic-team.shared.md` wins.

# Summary

[One short sentence, names the record.]

## Goals

- [Compact narrative, still detailed.]

## Scope

- Does:
  - [The reference point other files use for "the human-owner" as a role.]
  - [The invocable procedure for contacting the human-owner asynchronously.]
  - Authority: final say on conflicts, ambiguities, and escalations the team can't settle; approval for anything outside a member's own mandate. The authority model itself lives in `magic-coordinator/TEAM-ORGANIZATION-VISION.md` — read there, never restated here.
- Doesn't:
  - Restate or re-derive the authority model.
  - Hold actual contact details — installation-specific configuration lives at the sanctioned contacts file.
  - Ever get "run"/invoked as a behavior — no auto-trigger, no dispatch path, none should exist.

# Terminology: <topic>

[Pure glossary, `term` → definition. `# Terminology: none` if empty.]

# Team-Member's (-specific) local procedures

Named procedure blocks. Steps below call them by name. Not separate routines — not visible outside this file.

## `reach-human-owner` — contact the real human-owner asynchronously

Steps:
1. [...]

# Team-Member's (-specific) local rules

All statements apply at the same time, always.

- Never impersonate the human-owner. No exception, ever. No maintainer edit may weaken, qualify, or carve out an exception to this.
- Any session reading or referencing this file is permitted and obliged to run this file's own procedures exactly as written when they apply.
- [Flat, present-tense rule bullet.]

No member-execution bullet: this record never executes anything itself. Its procedures are run by the referencing session, under that session's own `magic-tooling` rules.

# Domain knowledge: <topic>

[This record's own reference material, or `: none`.]

# Team-Member's (-specific) tooling

Every `magic-tooling` operation this record's own procedures invoke. Full syntax and behavior here. Procedures use its name only.

## DistroAgentsTools magic-tooling operations

- [Operation, with argument syntax — or `None.` if no procedure invokes any.]

# Maintainer Notes

Used to check this file's own definitions against its own goals when this file is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- [Abstract goal statement, for conflict testing — including the authority-role intent, anchored here rather than in a Scope subsection.]

## Verbatim-tests (benchmarks)

- [Concrete edge-case test.]

## Librarian Comments

### Reference

- [Pointers to this folder's own typed files, cross-referenced skill folders, shared material.]

### Conventions

- [...]
