---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# audit-item.declaration document — the shape of one declaration

Normative contract: `audit-item.declaration.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton the output-style writer fills, and states the slots.

# Summary

The record of text a member declared as not message group, kept for a reader to judge. Written by the tooling, never by hand.

# Skeleton

## document
```
---
document-contract: audit-item.declaration
type: declaration
topic: output-style text-group declarations
---

# Declarations: text sent as not message group

date-time	kind	member	group	destination	text
```

# Slots

None: the declaration log header is written whole by the output-style writer; the rows it appends carry the member's own declaration.
