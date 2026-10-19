# magic-team — Maintainer Notes

The body of `# Maintainer Notes` in `magic-team.armed.md`. Read it when that file is updated, assessed or tested.

## Contents

- Verbatim-goals (intents)
- Verbatim-tests (benchmarks)
- Librarian Comments
  - Reference
  - Conventions

## Verbatim-goals (intents)

- This file is every member's baseline; anything it does not cover passes to `magic-coordinator`.
- A member in a session never quits to wait; it waits with `Wait` and keeps obeying.
- Consent reaches a member through the chain of command; binding questions reach a human, simple ones are settled by the session coordinator.
- Process-flow actions run as tooling operations; members are told operation names and their own decisions, never tooling internals.
- Only `magic-coordinator` writes the board; any member may post an inquiry into any inbox.
- A skillset change lands by `quorum-all-agree` of its maintainers other than the human-owner, in one coworking session, then by his propose-approve where his name is among them.
- Each rule is stated once, in one place.

## Verbatim-tests (benchmarks)

- A spawned member asks its coordinator and gets `TIMEOUT`. It waits again or re-asks; it does not end its turn.
- A member finishes its part in a coworking session while the session is open. It reports, then waits on the session thread.
- A member needs a board item created. It files an inquiry to `magic-coordinator`; it never writes the board.
- A member has a factual question a participant can answer. It asks in the session thread; the human-owner never receives it.
- A rule change is agreed by every maintainer other than the human-owner, in one session. It lands only once he, as a maintainer, approves it too.
- A member needs to know which account a message goes out under. It does not: the tooling chooses.
- A count is reported without a unit or a control in the same call. It fails review.

## Librarian Comments

### Reference

- `reference/skill-folder-model.md`, `reference/authoring-rules.md` and `magic-team.armed.md` — folder/file-format model and the human-owner's standing rules.
- `reference/board-model.md` — board states and transitions.
- `magic-team.conversations.md`, `magic-team.negotiations.md` — exchange mechanics.
- `magic-team.authority.<type>.contract.md` — decision authority per member family.
- `templates/` — contract and document formats.

### Conventions

- One rule, one place. Other files cite the bold rule name or section heading.
