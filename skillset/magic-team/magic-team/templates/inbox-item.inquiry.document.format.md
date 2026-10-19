---
maintainers: [magic-librarian, magic-coordinator, human-owner]
---
# inbox-item.inquiry document — the shape of one inquiry

Normative contract: `inbox-item.inquiry.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

A question or hand-off that needs an answer. The one member-to-member document: any member may post one into any inbox.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: inbox-item.inquiry
type: inquiry
from: <member>
date: <date-time>
owner: <addressee member>
communication-channel-id: <optional -- channel-id, when it traces to one external message>
---
# Inquiry: <matter, one line>

<the question or hand-off, and the answer needed>
```
