---
maintainers: magic-librarian, magic-coordinator, magic-architect, human-owner
---
# vault-item.epic-blueprint document — the shape of one epic blueprint

Normative contract: `vault-item.epic-blueprint.contract.format.md` (the skillset) for the keys, the store and the filename, and `epic.contract.format.md` for the body. Where this skeleton and either contract disagree, the contract wins. This file carries the skeleton and states the slots; `--upsert-vault-epic-blueprint` writes the document, `--epic-update` edits it, and `--epic-read` reads it.

# Summary

An epic blueprint: the tracking document of the epic-* routines, kept as a standing vault document. It states the work and how it is checked, never one executable piece.

# Skeleton

## document
```
---
document-contract: vault-item.epic-blueprint
type: epic-blueprint
from: {{from}}
date: {{date}}
---
# {{title}}

Source: `{{sketch}}`. {{source}}
Builders: {{builders}}

## Decisions

{{decisions}}

---

## {{feature-id}} - {{feature-title}}

Owner: {{owner}}. State: {{state}}.

1. {{outcome}} Owner: {{item-owner}}.

## Done

{{done}}
```

# Slots

- `from` — the author, normally `magic-coordinator`.
- `date` — the `date-time` the epic was written as an item.
- `title` — the epic's title, the only level-1 heading of the body.
- `sketch` — the owner's own sketch the epic comes from. A sketch never moves into team data, and an epic may hold a copy of it as a `## Sketch` chapter that says it is a copy.
- `source` — the one line saying what the epic holds: the next sprint, or the point it finishes before.
- `builders` — the members who build it, and what each builds.
- `decisions` — what the epic settles, as plain present-tense bullets.
- `feature-id` — `S` and a number, standing once in the file.
- `feature-title` — the feature's title, which may name its sketch section.
- `owner`, `state` — who builds the feature and where it stands.
- `outcome`, `item-owner` — one open item, one outcome a check can pass or fail, and the member who builds it.
- `done` — one line for each closed item, `- <id>: <what holds now>`.

The body's sections, features and `## Done` are `epic.contract.format.md`'s, checked by `--intern-doc-validate epic`. This file states no rule of its own about them.
