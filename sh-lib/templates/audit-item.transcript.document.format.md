---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# audit-item.transcript document — the shape of one transcript

Normative contract: `audit-item.transcript.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton the transcript writer fills, and states the slots.

# Summary

A verbatim record of an exchange, with UTC stamps. Append-only, through `--append-transcript`. Never on the board.

# Skeleton

## document
```
---
document-contract: audit-item.transcript
type: transcript
---

```

# Slots

None: the transcript's opening frontmatter is written whole by the transcript writer; each entry it appends carries the speaker, the UTC stamp and the verbatim message.
