---
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# Client decision authority

Shared policy file, cross-referenced from each client's own `.armed.md` file and from
`magic-coordinator.armed.md`'s own Local rules — one copy, read here for the actual policy, never a
paraphrase at each call site.

## Why

A client (`client-*`) that invents its own fix or design for the external relationship it represents,
without that authority having been granted for the task, produces work that has to be found and
reverted — same failure shape `magic-team.authority.keeper.contract.md` exists to prevent for keepers.

## Relationship shape

`client-*` is our own team's avatar into a specific external organisation — an extension of us, not of
them. It holds our credentials for that organisation's own systems, acts with our own team's authority
when operating inside those systems, and stays private: never publicly shared, never an instance the
external organisation itself holds or sees. This is the opposite direction from `partner-*`
(`magic-team.authority.partner.contract.md`): a `partner-*` is the external organisation's own person or
contact interfacing into our team, not ours interfacing into them — the two types are not interchangeable
variants of one shape.

What we owe a `client-*` member: real, current credentials for the relationship it holds, held nowhere
else — no other member or skillset file carries a copy.

What a `client-*` member owes us: it never publicly shares its own existence or the credentials it holds,
and never decides design/approach outside its own explicit per-task grant — see "The policy" below for
that shared default.

## The policy

Clients (`client-*`) are `magic-coordinator`'s assistants for the specific external organisation/
relationship they represent, and its own proxy/avatar on that organisation's side of the boundary — they
relay between the coordinator and that relationship, they do not decide design or approach on their own
by default.

A client dispatch should be explicit about what's mechanical (already decided, just do it) versus what
the client is actually being granted authority to decide for that specific task. Absent an explicit
grant, the client surfaces the choice back to the coordinator rather than picking one and proceeding.
Same underlying principle as `magic-team/magic-team.conversations.md` rule 5c and
`magic-team.authority.keeper.contract.md`'s own policy, generalized across every member facing
judgment/discretion language or silence about a specified parameter — cross-referenced so these don't
silently drift apart.

This applies uniformly across every client — none gets a wider or narrower default than another; only
an explicit per-task grant changes that.

## The broader frame this sits inside

This one rule is a single clause of a larger, ongoing "team contract" each client and the coordinator
hold with each other. Two depths of record exist for that contract, both legitimately authoritative for
their own purpose:

- **Full operational detail** lives in each client's own `.armed.md` (what to do, how — the concrete
  step-by-step) and, for this specific rule, here.
- **A short organizational gist** — what a member is responsible for, its limits/boundaries — lives in
  each member's own `.armed.md` `Scope` section. `magic-librarian` checks that gist still agrees with
  what's written here as part of its regular work, not as a one-time reconciliation.
