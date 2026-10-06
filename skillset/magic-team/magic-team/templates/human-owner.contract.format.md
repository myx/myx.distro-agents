---
maintainers: [<group, e.g. magic-coordinator, magic-librarian, magic-architect>, human-owner]
---
# <name>.armed.md — example skeleton (`human-owner`)

Normative contract: this file's own `# Contract` section, at its end. Where it and the skeleton disagree, `# Contract` wins. `# Contract` is not part of the skeleton and is not copied.

## Contents

- Summary
  - Goals
  - Scope
- Terminology: <topic>
- Team-Member's (-specific) local procedures
  - `reach-human-owner` — contact the real human-owner asynchronously
- Team-Member's (-specific) local rules
- Domain knowledge: <topic>
- Team-Member's (-specific) tooling
  - DistroAgentsTools magic-tooling operations
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions
- Contract

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

Every `magic-tooling` operation this record's own procedures invoke. Behaviour is read with `--member-help`. Procedures use its name only.

## DistroAgentsTools magic-tooling operations

- [Operation, with argument syntax — or `None.` if no procedure invokes any.]

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- [Abstract goal statement, for conflict testing — including the authority-role intent, anchored here rather than in a Scope subsection.]

## Verbatim-tests (benchmarks)

- [Concrete edge-case test.]

## Librarian Comments

### Reference

- [Pointers to this folder's own typed files, cross-referenced skill folders, shared material.]

### Conventions

- [...]

# Contract

A non-acting identity record that nonetheless carries one real, invocable procedure — not an inert reference stub, and not an executor.

- Frontmatter: `maintainers:` only.
- `# Summary`
  - One short sentence, names the record.
  - `## Goals`
    - Compact narrative, still detailed.
  - `## Scope`
    - What it does — the reference point other files use for "the human-owner" as a role, plus the invocable procedure for contacting them.
    - What it deliberately doesn't do. It is never loaded to generate human-owner speech, replies, or actions. It has no auto-trigger and no dispatch path, and none should exist. It holds no actual contact details.
    - Authority is *described* here in one line. That line covers two things: final say on conflicts, ambiguities and escalations the team can't settle, and approval for anything outside a member's own mandate. The pointer naming `magic-coordinator/TEAM-ORGANIZATION-VISION.md` as its only home follows immediately. Authority is never re-derived or restated. No `### Authority` subsection: a `Scope` bullet, nothing more.
- `# Terminology: <topic>` — or `: none`.
- `# Team-Member's (-specific) local procedures`
  - Named procedure blocks, `## <local-procedure-name>`, called by name.
  - Always includes `reach-human-owner` — how a session actually contacts the human-owner asynchronously when they're needed but not present.
  - Not separate routines. Not visible outside this file.
- `# Team-Member's (-specific) local rules`
  - text: "All statements apply at the same time, always."
  - flat, present-tense bullets, always including:
    - "Never impersonate the human-owner." No exception, no maintainer carve-out, ever.
    - Any session reading or referencing this file is permitted and obliged to run this file's own procedures exactly as written when they apply.
    - Carries no member-execution bullet of its own. This record never executes anything itself. The referencing session runs its procedures, under that session's own `magic-tooling` rules.
- `# Domain knowledge: <topic>` — or `: none`.
- `# Team-Member's (-specific) tooling`
  - Every `magic-tooling` operation this record's own procedures invoke, listed with its syntax. Behaviour is read with `--member-help`; an Operation Reference carries only what that help does not. `none` only when no procedure invokes any.
- `# Maintainer Notes` — same shape as every other contract. The `## Verbatim-goals (intents)`/`## Verbatim-tests (benchmarks)` pair is where the authority-role intent is anchored — not a `Scope` subsection, and never a copy of the vision doc.
- One member only. Not a family. No second `human-owner`-shaped member exists or is expected.
