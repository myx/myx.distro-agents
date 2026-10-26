---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# board-item.change document — the shape of one change

Normative contract: `board-item.change.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton the board writer fills from the member's slots, and states the slots.

# Summary

A record of a change.

# Skeleton

## document
```
# Change: {{matter}}

## What changed
{{what-changed}}

## Why
{{why}}

## Needs
{{needs}}

## Files touched
{{files-touched}}
```

# Slots

- `matter` — the matter, one line, the title after `# Change:`.
- `what-changed` — the change, in the `## What changed` section.
- `why` — the reason, in the `## Why` section.
- `needs` — what it still needs, or `none`, in the `## Needs` section.
- `files-touched` — one path per line, in the `## Files touched` section.
