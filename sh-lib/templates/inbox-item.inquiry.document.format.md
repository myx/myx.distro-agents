---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# inbox-item.inquiry document — the shape of one inquiry

Normative contract: `inbox-item.inquiry.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton the inbox writer fills from the member's slots, and states the slots.

# Summary

A question or hand-off that needs an answer. The one member-to-member document: any member may post one into any inbox.

# Skeleton

## document
```
# Inquiry: {{matter}}

{{body}}
```

# Slots

- `matter` — the matter, one line, the title after `# Inquiry:`.
- `body` — the question or hand-off, and the answer needed.
