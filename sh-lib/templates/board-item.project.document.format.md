---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# board-item.project document — the shape of one project

Normative contract: `board-item.project.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton the board writer fills from the member's slots, and states the slots.

# Summary

A container for related work, an epic. Its children link to it by `spawns` and `spawned-by`. `epic-*` is not a type; a container is a `project-*`.

# Skeleton

## document
```
# Project: {{matter}}

{{body}}

Audience: {{audience}}
```

# Slots

- `matter` — the matter, one line, the title after `# Project:`.
- `audience` — who reads this, in a word or two. A hint its reader interprets, never a closed list.
- `body` — what the container holds together, why, and the state it is in now.
