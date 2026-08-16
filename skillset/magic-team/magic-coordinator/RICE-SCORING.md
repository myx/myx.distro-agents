# RICE-style scoring

Shared scoring convention for backlog/todo/proposal items. Used by `routine-grooming`'s reprioritization step and by any member scoring an item on their own.

## Four dimensions

Every scored item carries four numbers, each 0–1, normalized against the current full set of pending/planned/active items:

- **Profit** — 0 = least valuable, 1 = most valuable.
- **Cost** — 0 = cheapest to implement, 1 = most costly.
- **Time** — 0 = fastest to complete, 1 = longest. Distinct from Cost: low-effort can still be calendar-slow, and vice versa.
- **Dependencies** — 0 = fully ready, 1 = heavily blocked. Companion to the item's actual board state, not a replacement for it.

Normalization is relative and done together at each grooming pass: rank the current backlog on each dimension, space 0–1 across that ranking (min-max or percentile). An item's numbers can shift even if the item itself didn't change, because the backlog around it did.

## Priority number (optional)

```
Priority = Profit / (Cost + Time + Dependencies)
```

A sorting convenience only. The four dimensions are the primary record.

## Multiple scores per item

- **Official**: from `magic-architect` (architecture-level: complexity, blast radius, systems touched) and `magic-coordinator` (cross-team: sequencing, dependencies, readiness).
- **Personal**: any member can attach their own view. Disagreement with the official score is useful signal for grooming, not something to average away.

Record scores on the item's own file under the board, tagged by who gave the score. A structural score (risk, coupling, blast radius) carries one line of reasoning, not just the number.

## When scores get set or updated

- **At `routine-grooming`**: every pending/planned/active item, every pass — not just newly-triaged ones, since normalization is relative to the whole backlog. See `routine-grooming`'s **rescore-backlog-rice**.
- **By `magic-architect`**, as its `grooming-scores-review` idle activity: refines existing scores, doesn't reassign/split/drop items.
- **Ad hoc**: any member, any time.

## Scores inform, they don't decide alone

Per the team's "no unilateral epics" rule and `routine-grooming`'s **review-with-the-user**: the scored backlog is reviewed with the user before anything is final.
