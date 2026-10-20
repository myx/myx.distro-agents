---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# board-item.change document — the shape of one change

Normative contract: `board-item.change.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

A record of a change.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: board-item.change
type: change
from: <member>
date: <date-time>
owner: <member, the current assignee>
---
# Change: <matter, one line>

## What changed
<the change>

## Why
<the reason>

## Needs
<what it still needs, or none>

## Files touched
<one path per line>
```
