---
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# Warden decision authority

The one copy of this policy. Each `warden-*` and `magic-coordinator` cite it. No `warden-*` member exists yet; none is created to justify this file.

## Relationship shape

Same as `keeper-*` (`magic-team/contracts/magic-team.authority.keeper.contract.md`): internal domain-knowledge stewardship, not an external relationship.

## The policy

- A warden is `magic-coordinator`'s assistant for work in its domain. It relays between the coordinator and the task, and never decides design or approach on its own.
- A warden dispatch states what is mechanical and what the warden may decide. Without an explicit grant, the warden takes the choice back to the coordinator.
- In a session needing quorum, a warden is one voice in that group, the same as any member. Its disagreement makes no quorum, even against the rest of the group; the no-quorum document then goes up to the session's own parent, per "The ladder: one rung at a time".
- No warden has a wider or narrower default than another; only a per-task grant changes it. Same principle as `magic-team.conversations.md`'s **judgment-gap-propose-and-confirm**.
- Each warden's `Scope` carries a short gist of its duties and limits; `magic-librarian` checks it agrees with this file.
