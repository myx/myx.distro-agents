---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# audit-item.incident document — the shape of one incident

Normative contract: `audit-item.incident.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

An incident record. Thin until a writer exists: the team's model defines this type in one line, so this contract carries the common keys and the body is free.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: audit-item.incident
type: incident
from: <member>
date: <date-time>
---
# Incident: <matter, one line>

<what happened, when, and what it affected>
```
