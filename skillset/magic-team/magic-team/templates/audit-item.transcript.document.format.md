---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# audit-item.transcript document — the shape of one transcript

Normative contract: `audit-item.transcript.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

A verbatim record of an exchange, with UTC stamps. Append-only, through `--member-append-session-transcript`. Never on the board.

The skeleton is shown for reading and for tests; this document is not written by hand.

Entries are appended with `--member-append-session-transcript`; the file is not written by hand.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: audit-item.transcript
type: transcript
---
<speaker-name> (<iso-utc>):

> <the message, verbatim>

<speaker-name> (<iso-utc>):

> <the message, verbatim>
```
