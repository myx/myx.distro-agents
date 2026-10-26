---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# inbox-item.note document — the shape of one note

Normative contract: `inbox-item.note.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton the inbox writer fills from the member's slots, and states the slots.

# Summary

Context or coordination.

# Skeleton

## document
```
# Note: {{matter}}

{{body}}
```

# Slots

- `matter` — the matter, one line, the title after `# Note:`.
- `body` — the context or coordination point.
