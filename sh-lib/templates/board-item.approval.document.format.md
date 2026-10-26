---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# board-item.approval document — the shape of one approval

Normative contract: `board-item.approval.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton the board writer fills from the member's slots, and states the slots.

# Summary

A live negotiation for the human-owner's go or no-go on another item.

# Skeleton

## document
```
[[---
blocks: {{blocks}}
---
]]
# Approval: {{matter}}

{{body}}
```

# Slots

- `matter` — the matter, one line, the title after `# Approval:`.
- `blocks` — the item names this approval blocks, comma-separated. The `blocks:` front-matter line is emitted only when it is given.
- `body` — what the human-owner is asked to approve, with the options and the recommendation.
