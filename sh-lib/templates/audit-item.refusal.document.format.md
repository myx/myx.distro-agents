---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# audit-item.refusal document — the shape of one refusal

Normative contract: `audit-item.refusal.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton the output-style writer fills, and states the slots.

# Summary

The output-style check's record of text the floor stopped or only reported, one row per fault. Written by the tooling, never by hand.

# Skeleton

## document
```
---
document-contract: audit-item.refusal
type: refusal
topic: output-style refusals, per predicate
---

# Refusals: text the floor stopped

date-time	kind	member	group	destination	predicate	detail
```

# Slots

None: the refusal log header is written whole by the output-style writer; the rows it appends carry the measured faults.
