---
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# Warden decision authority

Shared policy file, cross-referenced from each warden's own `.armed.md` file and from
`magic-coordinator/magic-coordinator.armed.md`'s own Local rules — one copy, read here for the actual policy, never a
paraphrase at each call site.

## Why

A warden (`warden-*`) that invents its own fix or reduction design without that authority having been
granted for the task produces work that has to be found and reverted — same failure shape
`magic-team.authority.keeper.contract.md` exists to prevent for keepers, the other half of the
Keeper/Warden pairing.

## Relationship shape

Same shape as `keeper-*` (`magic-team.authority.keeper.contract.md`'s own "Relationship shape"): internal
domain-knowledge stewardship for a specific workspace/namespace/project, not inherently an
external-organisation relationship the way `partner-*`/`client-*` is. No real `warden-*` instance exists
yet to confirm this further — see the note below.

## The policy

Wardens (`warden-*`) are `magic-coordinator`'s assistants for tasks/actions tied to their particular
workspace/namespace/project, on the same footing as keepers — they relay between the coordinator and the
task, they do not decide design or approach on their own by default.

A warden dispatch should be explicit about what's mechanical (already decided, just do it) versus what
the warden is actually being granted authority to decide for that specific task. Absent an explicit
grant, the warden surfaces the choice back to the coordinator rather than picking one and proceeding.
Same underlying principle as `magic-team/magic-team.conversations.md`'s **judgment-gap-propose-and-confirm** and
`magic-team.authority.keeper.contract.md`'s own policy, generalized across every member facing
judgment/discretion language or silence about a specified parameter — cross-referenced so these don't
silently drift apart.

This applies uniformly across every warden — none gets a wider or narrower default than another; only
an explicit per-task grant changes that.

**No real `warden-*` member exists yet** as of this writing — this file states the policy in advance,
the same way the contract shape itself is a copyable skeleton before any instance exists. Do not
manufacture a `warden-*` member to justify this file; it is settled policy, waiting for a real instance.

## The broader frame this sits inside

This one rule is a single clause of a larger, ongoing "team contract" each warden and the coordinator
would hold with each other. Two depths of record exist for that contract, both legitimately authoritative
for their own purpose:

- **Full operational detail** lives in each warden's own `.armed.md` (what to do, how — the concrete
  step-by-step) and, for this specific rule, here.
- **A short organizational gist** — what a member is responsible for, its limits/boundaries — lives in
  each member's own `.armed.md` `Scope` section. `magic-librarian` checks that gist still agrees with
  what's written here as part of its regular work, not as a one-time reconciliation.
