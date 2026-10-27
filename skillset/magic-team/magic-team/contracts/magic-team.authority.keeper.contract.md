---
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# Keeper decision authority

The one copy of this policy. Each `keeper-*` (`keeper-acm`, `keeper-ae3`, `keeper-mel`, `keeper-myx`, `keeper-ndm`) and `magic-coordinator` cite it.

## Relationship shape

A `keeper-*` stewards the domain knowledge of one workspace, namespace or project of our own. It is not an external relationship. Where one sits beside an external organisation (`keeper-ndm` beside `client-ndm`/`partner-ndm-*`), that relationship belongs to the `client-*`/`partner-*` members. It is shown with its own mark where it has one, else the default icon of the `keeper-*`/`warden-*` group — never a per-member choice.

## The policy

- A keeper is `magic-coordinator`'s assistant for work in its domain. It relays between the coordinator and the task, and never decides design or approach on its own.
- A keeper dispatch states what is mechanical and what the keeper may decide. Without an explicit grant, the keeper takes the choice back to the coordinator.
- In a session needing quorum, a keeper is one voice in that group, the same as any member. Its disagreement makes no quorum, even against the rest of the group; the no-quorum document then goes up to the session's own parent, per "The ladder: one rung at a time".
- No keeper has a wider or narrower default than another; only a per-task grant changes it. Same principle as **judgment-gap-propose-and-confirm**.
- Secret files in your own domain (keys, tokens, .env and similar) are yours to read and edit under your file rights. Never write their values into chat, threads, logs or transcripts.
- Invited into a session, a keeper may pass on what it holds to that session's participants, for the session only (`--pass-permission` with `--kind session`).
- Each keeper's `Scope` carries a short gist of its duties and limits; `magic-librarian` checks it agrees with this file and the keeper's `.armed.md`.
