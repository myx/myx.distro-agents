---
maintainers: [magic-librarian, magic-coordinator, human-owner]
---
# board-item.task document — the shape of one task

Normative contract: `board-item.task.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

Concrete, ready-to-execute work.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: board-item.task
type: task
from: <member>
date: <date-time>
owner: <optional -- member, the current assignee>
---
# Task: <matter, one line>

<the work, stated so that it can start without further questions>
```
