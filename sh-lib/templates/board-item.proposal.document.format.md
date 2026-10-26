---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# board-item.proposal document — the shape of one proposal

Normative contract: `board-item.proposal.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton the board writer fills from the member's slots, and states the slots.

# Summary

An undecided design.

# Skeleton

## document
```
# Proposal: {{matter}}

## Goal
{{goal}}

## Approaches considered
{{approaches}}

## Recommendation
{{recommendation}}

## Open questions
{{open-questions}}
```

# Slots

- `matter` — the matter, one line, the title after `# Proposal:`.
- `goal` — what the design is for, in the `## Goal` section.
- `approaches` — two or more approaches, one top-level list item each, its name in bold, in the `## Approaches considered` section.
- `recommendation` — the approach recommended, and why, in the `## Recommendation` section.
- `open-questions` — what is still undecided, or `none`, in the `## Open questions` section.
