---
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# Oncall decision authority

Shared policy file, cross-referenced from each oncall's own `.armed.md` file and from
`magic-coordinator/magic-coordinator.armed.md`'s own Local rules — one copy, read here for the actual policy, never a
paraphrase at each call site.

## Why

An oncall (`oncall-*`) that invents its own fix or design without that authority having been granted for
the task produces work that has to be found and reverted — same failure shape
`magic-team.authority.keeper.contract.md` exists to prevent for keepers.

## The policy

Oncalls (`oncall-*`) are costed, external, billed-per-time resources brought in to boost/accelerate one
specific, complicated task — they are not standing team members and hold no default authority beyond the
task's own explicit scope. They relay between the coordinator and the task, they do not decide design or
approach on their own by default.

An oncall dispatch should be explicit about what's mechanical (already decided, just do it) versus what
the oncall is actually being granted authority to decide for that specific task. Absent an explicit
grant, the oncall surfaces the choice back to the coordinator rather than picking one and proceeding.
Same underlying principle as `magic-team/magic-team.conversations.md`'s **judgment-gap-propose-and-confirm** and
`magic-team.authority.keeper.contract.md`'s own policy, generalized across every member facing
judgment/discretion language or silence about a specified parameter — cross-referenced so these don't
silently drift apart.

This applies uniformly across every oncall engagement — none gets a wider or narrower default than
another; only an explicit per-task grant changes that.

**No real `oncall-*` member exists yet** as of this writing — this file states the policy in advance,
the same way the contract shape itself is a copyable skeleton before any instance exists. Do not
manufacture an `oncall-*` engagement to justify this file; it is settled policy, waiting for a real
instance.

## The broader frame this sits inside

This one rule is a single clause of a larger, ongoing "team contract" each oncall engagement and the
coordinator would hold with each other. Two depths of record exist for that contract, both legitimately
authoritative for their own purpose:

- **Full operational detail** lives in each oncall's own `.armed.md` (what to do, how — the concrete
  step-by-step) and, for this specific rule, here.
- **A short organizational gist** — what a member is responsible for, its limits/boundaries — lives in
  each member's own `.armed.md` `Scope` section. `magic-librarian` checks that gist still agrees with
  what's written here as part of its regular work, not as a one-time reconciliation.
