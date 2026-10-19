---
maintainers: [magic-librarian, magic-coordinator, human-owner]
---
# inbox-item.note document — the shape of one note

Normative contract: `inbox-item.note.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

Context or coordination.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: inbox-item.note
type: note
from: <member>
date: <date-time>
owner: <member>
---
# Note: <matter, one line>

<the context or coordination point>
```
