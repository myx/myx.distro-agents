---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# audit-item.snapshot document — the shape of one snapshot

Normative contract: `audit-item.snapshot.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

A resource's full content, saved byte for byte before a write that could lose it. Written by the tooling before the write; if the save fails, the write is refused.

The skeleton is shown for reading and for tests; this document is not written by hand.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: audit-item.snapshot
type: snapshot
system: <word>
resource-type: <word>
resource-id: <text>
write-op: <text>
captured-by: <member>
captured-at: <utc-stamp>
---
<the resource's content, exactly as read>
```
