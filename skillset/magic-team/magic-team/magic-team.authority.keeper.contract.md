---
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# Keeper decision authority

Shared policy file, cross-referenced from each of the four keepers' own `.armed.md` files
and from `magic-coordinator/magic-coordinator.armed.md`'s own Local rules — one copy, read here for the actual policy,
never a paraphrase at each call site.

## Why

A keeper (`keeper-*`) that invents its own fix or reduction design without that authority having been
granted for the task produces work that has to be found and reverted. This contract sets the default
so that does not happen.

## Relationship shape

`keeper-*`/`warden-*` is internal domain-knowledge stewardship for a specific workspace/namespace/
project — not inherently an external-organisation relationship the way `partner-*`/`client-*` is
(`magic-team.authority.partner.contract.md`/`magic-team.authority.client.contract.md`). Most real keepers
(`keeper-acm`, `keeper-ae3`, `keeper-mel`, `keeper-myx`) steward a namespace that is entirely our own,
with no external party involved at all. `keeper-ndm` is the one keeper that happens to sit alongside an
external-organisation relationship (`client-ndm`/`partner-ndm-*`) — that pairing is `client-ndm`'s/
`partner-ndm-*`'s own shape, never something `keeper-ndm` itself takes on.

## The policy

Keepers (`keeper-*`) are `magic-coordinator`'s assistants
for tasks/actions tied to their particular workspace/namespace/project — they relay between the
coordinator and the task, they do not decide design or approach on their own by default.

A keeper dispatch should be explicit about what's mechanical (already decided, just do it) versus what
the keeper is actually being granted authority to decide for that specific task. Absent an explicit
grant, the keeper surfaces the choice back to the coordinator rather than picking one and proceeding.
Same underlying principle as `magic-team/magic-team.conversations.md`'s **judgment-gap-propose-and-confirm**, generalized there beyond
keepers to any member facing judgment/discretion language or silence about a specified parameter —
cross-referenced so the two don't silently drift apart.

This applies uniformly across the keepers — none of them gets a wider or narrower default than
the others; only an explicit per-task grant changes that.

## The broader frame this sits inside

This one rule is a single clause of a larger, ongoing "team contract" each keeper and the coordinator
hold with each other — responsibilities, duties, and constraints as understood from both sides, not
just this one decision-authority rule in isolation. Two depths of
record exist for that contract, both legitimately authoritative for their own purpose:

- **Full operational detail** lives in each keeper's own `.armed.md` (what to do, how — the
  concrete step-by-step) and, for this specific rule, here.
- **A short organizational gist** — what a member is responsible for, its limits/boundaries — lives in
  each member's own `.armed.md` `Scope` section. `magic-librarian` checks that gist still agrees with
  what's written here and in each keeper's own `.armed.md` as part of its regular work (the
  team self-sufficiency audit), not as a one-time reconciliation.

