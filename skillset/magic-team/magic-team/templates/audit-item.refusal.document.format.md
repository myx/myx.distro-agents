---
maintainers: [magic-librarian, magic-coordinator, human-owner]
---
# audit-item.refusal document — the shape of one refusal

Normative contract: `audit-item.refusal.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

The output-style check's record of text the floor stopped or only reported, one row per fault. Written by the tooling, never by hand.

The skeleton is shown for reading and for tests; this document is not written by hand.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: audit-item.refusal
type: refusal
topic: output-style refusals, per predicate
---
# Refusals: text the floor stopped

date-time<TAB>kind<TAB>member<TAB>group<TAB>destination<TAB>predicate<TAB>detail
<iso-utc><TAB><refusal or report><TAB><member><TAB><group><TAB><destination><TAB><predicate><TAB><detail>
```
