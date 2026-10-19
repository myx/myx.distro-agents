---
maintainers: [magic-librarian, magic-coordinator, human-owner]
---
# board-item.proposal document — the shape of one proposal

Normative contract: `board-item.proposal.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

An undecided design.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: board-item.proposal
type: proposal
from: <member>
date: <date-time>
owner: <optional -- member, the current assignee>
---
# Proposal: <matter, one line>

## Goal
<what the design is for>

## Approaches considered
- **<approach one>.** <the approach and its cost>
- **<approach two>.** <the approach and its cost>

## Recommendation
<the approach recommended, and why>

## Open questions
<what is still undecided, or none>
```
