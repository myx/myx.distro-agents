---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# audit-item.declaration document — the shape of one declaration

Normative contract: `audit-item.declaration.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

The record of text a member declared as not message group, kept for a reader to judge. Written by the tooling, never by hand.

The skeleton is shown for reading and for tests; this document is not written by hand.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: audit-item.declaration
type: declaration
topic: output-style text-group declarations
---
# Declarations: text sent as not message group

date-time<TAB>kind<TAB>member<TAB>group<TAB>destination<TAB>text
<iso-utc><TAB>declaration<TAB><member><TAB><group><TAB><destination><TAB><text on one line>
```
