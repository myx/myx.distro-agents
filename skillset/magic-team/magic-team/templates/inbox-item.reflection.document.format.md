---
maintainers: [magic-librarian, magic-coordinator, human-owner]
---
# inbox-item.reflection document — the shape of one reflection

Normative contract: `inbox-item.reflection.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

A lesson whose resolution produces a change elsewhere.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: inbox-item.reflection
type: reflection
from: <member>
date: <date-time>
owner: <member>
---
# Reflection: <matter, one line>

<what happened, what was learned, and the change it should produce>
```
