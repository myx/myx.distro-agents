---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# audit-item.snapshot document — the shape of one snapshot

Normative contract: `audit-item.snapshot.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton the snapshot writer fills from its own fields, and states the slots.

# Summary

A resource's full content, saved byte for byte before a write that could lose it. Written by the tooling before the write; if the save fails, the write is refused.

# Skeleton

## document
```
---
document-contract: audit-item.snapshot
type: snapshot
system: {{system}}
resource-type: {{resource-type}}
resource-id: {{resource-id}}
write-op: {{write-op}}
captured-by: {{captured-by}}
captured-at: {{captured-at}}
---

```

# Slots

- `system` — the source system (`jira`, `confluence`).
- `resource-type` — the resource kind (`issue`, `page`).
- `resource-id` — the resource's own id.
- `write-op` — the operation the snapshot precedes.
- `captured-by` — the acting member.
- `captured-at` — the UTC stamp.

The body — the resource's content, exactly as read — is appended by the snapshot writer after the frontmatter, never a slot: it is kept byte for byte, and the filler's indentation cleaning would corrupt it.
