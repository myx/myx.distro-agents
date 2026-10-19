---
maintainers: [magic-librarian, magic-coordinator, human-owner]
---
# board-item.project document — the shape of one project

Normative contract: `board-item.project.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

A container for related work, an epic. Its children link to it by `spawns` and `spawned-by`. `epic-*` is not a type; a container is a `project-*`.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: board-item.project
type: project
from: <member>
date: <date-time>
owner: <optional -- member, the current assignee>
---
# Project: <matter, one line>

<what the container holds together, and why>
```
