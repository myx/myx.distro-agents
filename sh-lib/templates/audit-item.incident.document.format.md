---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# audit-item.incident document — the shape of one incident

Normative contract: `audit-item.incident.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton and states the slots; no writer fills it yet.

# Summary

An incident record. Thin until a writer exists: the team's model defines this type in one line, so this contract carries the common keys and the body is free.

# Skeleton

## document
```
---
document-contract: audit-item.incident
type: incident
from: {{from}}
date: {{date}}
---
# Incident: {{matter}}

{{body}}
```

# Slots

- `from` — the member the incident is recorded for.
- `date` — the date-time.
- `matter` — the matter, one line, the title after `# Incident:`.
- `body` — what happened, when, and what it affected.
