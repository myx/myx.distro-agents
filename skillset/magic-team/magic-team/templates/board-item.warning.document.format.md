---
maintainers: [magic-librarian, magic-coordinator, human-owner]
---
# board-item.warning document — the shape of one warning

Normative contract: `board-item.warning.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

An open risk, kept visible in an active state until it is mitigated, accepted or converted. Every spawn brief lists the open ones.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: board-item.warning
type: warning
from: <member>
date: <date-time>
owner: <member, the current assignee>
---
# Warning: <matter, one line>

<the risk, what it endangers, and what would mitigate it>
```
