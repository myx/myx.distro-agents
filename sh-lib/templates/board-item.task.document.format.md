---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# board-item.task document — the shape of one task

Normative contract: `board-item.task.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton the board writer fills from the member's slots, and states the slots.

# Summary

Concrete, ready-to-execute work.

# Skeleton

## document
```
# Task: {{matter}}

{{body}}

Audience: {{audience}}
```

# Slots

- `matter` — the matter, one line, the title after `# Task:`.
- `audience` — who reads this, in a word or two. A hint its reader interprets, never a closed list.
- `body` — the work, stated so that it can start without further questions.
