---
maintainers: [magic-librarian, magic-coordinator, human-owner]
---
# board-item.idea document — the shape of one idea

Normative contract: `board-item.idea.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

A raw suggestion, below a proposal's bar.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: board-item.idea
type: idea
from: <member>
date: <date-time>
owner: <member, the current assignee>
---
# Idea: <matter, one line>

<the suggestion, as raw as it is>
```
