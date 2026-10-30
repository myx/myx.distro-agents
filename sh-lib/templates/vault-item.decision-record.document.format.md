---
maintainers: magic-librarian, magic-coordinator, magic-architect, human-owner
---
# vault-item.decision-record document — the shape of one decision record

Normative contract: `vault-item.decision-record.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton and states the slots; no writer fills it yet.

# Summary

A decision record, in the manner of an architecture decision record (ADR): one technical question, the decision taken on it, and why. `magic-architect` produces one per distinct question it assesses, or finds the one that already exists.

# Skeleton

## document
```
---
document-contract: vault-item.decision-record
type: adr
from: {{from}}
date: {{date}}
status: {{status}}
---
# Decision: {{matter}}

# Question

{{question}}

# Context

{{context}}

# Options

{{options}}

# Decision

{{decision}}

# Linchpin

{{linchpin}}

# Consequences

{{consequences}}
```

# Slots

- `from` — the deciding member, normally `magic-architect`.
- `date` — the `date-time` the record was written.
- `status` — `proposed`, `accepted`, `superseded` or `deprecated`.
- `matter` — the matter, one line, the title after `# Decision:`.
- `question` — the one technical question, stated so another reader recognises it.
- `context` — the forces and constraints that make it a question: what must hold, what it costs, what it touches.
- `options` — every option weighed, each with what speaks for and against it.
- `decision` — the option chosen, in one or two sentences.
- `linchpin` — the assumption the decision rests on, and what changes if it is wrong.
- `consequences` — what follows: what gets easier, what gets harder, what must now be done.
