---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# audit-item.artifact document — the shape of one artifact

Normative contract: `audit-item.artifact.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton the artifact writer fills from its own fields, and states the slots.

# Summary

The record of one published document, rewritten whole at each of its states. Written by the tooling when a document is claimed and published, never by hand.

# Skeleton

## document
```
---
document-contract: audit-item.artifact
type: artifact
number: {{number}}
kind: {{kind}}
title: {{title}}
url: {{url}}
member: {{member}}
session: {{session}}
date: {{date}}
state: {{state}}
---

# {{full-title}}
```

# Slots

- `number` — the code and number (`CODE-NNN`), or `-` for an untyped document.
- `kind` — the type code (`CODE`), or `-`.
- `title` — the document title.
- `url` — the published link, or `-` while reserved.
- `member` — the publishing member.
- `session` — the session id, or `-`.
- `date` — the date-time the record is written.
- `state` — `reserved`, `published` or `released`.
- `full-title` — the `# ` title line: `number: title` for a numbered document, the title alone for an untyped one.
