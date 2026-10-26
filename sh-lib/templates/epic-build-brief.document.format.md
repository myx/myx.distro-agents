---
maintainers: magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner
---
# epic build brief — what a builder is dispatched with

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text the tooling fills and emits as a builder's build brief when `magic-team.epic-wave` dispatches one feature. The coordinator supplies only what it alone knows: which feature, and the epic that names it. Nothing of this text is copied into the routines.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
- Contract

# Summary

The brief every builder of an epic is given, by its dispatch, so each lane works from the same words: the inputs to read, the gaps rule, the tests, the reading, the messages, the never-do list, and what is fixed.

## Goals

- A builder reads the epic as the full spec and invents no gaps of its own.
- A builder sends its gaps and its gate in the one compact form, and ends its turn after sending.
- Changing a sentence of the brief is an edit to this file, not to the routine that dispatches.

## Scope

- Does: fix the words and the slots of the brief a builder is dispatched with.
- Doesn't: choose the builder, the feature, or how many build at once. `magic-team.epic-wave` decides those.

# Skeleton

```
You are dispatched to build one feature of an epic.

Inputs: {{epic-file}}; read "How a feature is delivered", the ground rules, the section of feature {{feature-id}} with its Settled lines, and the constraints naming that feature, and nothing else.

No gaps are invented: the epic is the full spec. Send a gap at once, one line, with your proposed reading by the owner's rules — no one-word keys; one mechanism, reuse before adding; existing name forms and `MAGIC.md` conventions; existing defaults; explicit values; keep it simple. Build only the parts the gap does not touch until it is answered.

Tests: the feature's tests, those of the files touched, and the guards; quietly, only failure lines and the summary reaching the context; never a full sweep, except before one large atomic switch, in the scratch.

Reading: only the ranges needed of big files (the console's python, `MAGIC.md`, the harness).

Messages: at most ten lines, the gate's form; after sending, end the turn; never idle in a long `Wait` for the coordinator.

Never: git outside a throwaway rig; a production host; a secret printed; a `CLAUDE.md` edited; posts as the human-owner; edits of `myx.common` or `myx.distro-.local` unless the feature says so.

A mechanical step is one plain run of the tooling. A tool unsafe to use is fixed itself, never wrapped in rehearsals or compatibility layers.

What the epic, the owner's rulings and the tests say is fixed. A proposal contradicting them is wrong by definition.
```

# Contract

- rule: `{{epic-file}}` is the path of the epic file the dispatch names, as it names it.
- rule: `{{feature-id}}` is the feature's id, the word after `## ` in its heading, as the dispatch names it.
- rule: every line outside the slots is emitted exactly as written here.
