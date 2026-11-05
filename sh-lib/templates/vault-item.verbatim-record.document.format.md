---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# vault-item.verbatim-record document — the shape of one verbatim record

Normative contract: `vault-item.verbatim-record.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton and states the slots; `--upsert-vault-verbatim-record` writes the document.

# Summary

A verbatim record: a standing statement kept word for word. Thin until a writer exists: the team's model defines this type in one line, so this contract carries the common keys and the body is free.

# Skeleton

## document
```
---
document-contract: vault-item.verbatim-record
type: verbatim-record
from: {{from}}
date: {{date}}
---
# Verbatim: {{matter}}

{{body}}
```

# Slots

- `from` — the member the verbatim is recorded for.
- `date` — the date-time.
- `matter` — the matter, one line, the title after `# Verbatim:`.
- `body` — the statement, word for word.
