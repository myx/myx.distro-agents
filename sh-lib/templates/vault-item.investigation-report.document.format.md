---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# vault-item.investigation-report document — the shape of one investigation report

Normative contract: `vault-item.investigation-report.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton and states the slots; no writer fills it yet.

# Summary

An investigation report (IVR): the result of one investigation, kept as a standing document. The running investigation is its board item; this is what it established.

# Skeleton

## document
```
---
document-contract: vault-item.investigation-report
type: ivr
from: {{from}}
date: {{date}}
status: {{status}}
---
# Investigation report: {{matter}}

# Question

{{question}}

# Answer

{{answer}}

# Findings

{{findings}}

# Assumptions checked

{{assumptions}}

# Defect branch

{{defect}}

# Open

{{open}}

# Next legs

{{next}}
```

# Slots

- `from` — the investigating member.
- `date` — the `date-time` the report was settled.
- `status` — `final` or `superseded`.
- `matter` — the matter, one line, the title after `# Investigation report:`.
- `question` — the question, the thing it is about, and what the answer is for.
- `answer` — the answer and the decision (record, investigate further, act), with how firmly each is shown.
- `findings` — each finding labelled shown, inferred or assumed, with its evidence: the file and line, the record, the check and its result.
- `assumptions` — each assumption, its check, and whether it held.
- `defect` — optional: the reproduction, the bounds, the candidates ruled out, the root. `none` when there is no defect branch.
- `open` — what could not be established, and what would settle it. `none` when nothing is open.
- `next` — the next flow steps the investigation named. `none` when it ended at record.
