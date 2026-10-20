---
maintainers: [magic-librarian, magic-coordinator, human-owner]
---
# board-item.approval document — the shape of one approval

Normative contract: `board-item.approval.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

A live negotiation for the human-owner's go or no-go on another item.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: board-item.approval
type: approval
from: <member>
date: <date-time>
owner: <member, the current assignee>
blocks: <item-names>
---
# Approval: <matter, one line>

<what the human-owner is asked to approve, with the options and the recommendation>
```
