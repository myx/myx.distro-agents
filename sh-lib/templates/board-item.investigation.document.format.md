---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# board-item.investigation document — the shape of one investigation

Normative contract: `board-item.investigation.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton the board writer fills from the member's slots, and states the slots.

# Summary

A running investigation: the process document `magic-team.investigate.routine` works on, round by round. Its result is a `vault-item.investigation-report` (a vault `investigation-*`), which this item names in `references` when it closes.

# Skeleton

## document
```
# Investigation: {{matter}}

# Question

{{question}}

Audience: {{audience}}

# Goal

{{goal}}

# Current

{{current}}

# Next

{{next}}

# Settled

{{settled}}

# Open

{{open}}

# Log

{{log}}
```

# Slots

- `matter` — the matter, one line, the title after `# Investigation:`.
- `audience` — who reads this, in a word or two. A hint its reader interprets, never a closed list.
- `question` — the question, the thing it is about, and what the answer is for.
- `goal` — the exit conditions, each able to pass or fail; the round limit or time box; the walk-away point.
- `current` — what is established so far, each finding labelled shown, inferred or assumed, with its evidence.
- `next` — the next step, in one present-tense statement.
- `settled` — each settled part as one present-tense statement, with who settled it and when.
- `open` — the open parts, nearest to closing first. `none` when nothing is open.
- `log` — one line per round: what moved, what closed, what stays open.
