---
maintainers: [magic-librarian, magic-coordinator, human-owner]
---
# board-item.interview document — the shape of one interview

Normative contract: `board-item.interview.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

Work whose core is talking it through with the human-owner.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: board-item.interview
type: interview
from: <member>
date: <date-time>
owner: <member, the current assignee>
---
# Interview: <matter, one line>

<the plan>

<verbatim intents>

<verbatim benchmarks>

<corrections>

<settled facts: one block per design point>
<the settled statement, in the present tense>
rejected: <the alternatives that lost, and why>
status: settled

<sub-parts>
```
