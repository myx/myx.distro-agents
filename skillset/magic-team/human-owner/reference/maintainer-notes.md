# human-owner — Maintainer Notes

The body of `# Maintainer Notes` in `human-owner.armed.md`. Read it when that file is updated, assessed or tested.

## Contents

- Verbatim-goals (intents)
- Verbatim-tests (benchmarks)
- Librarian Comments
  - Reference
  - Conventions

## Verbatim-goals (intents)

- This file states the impersonation boundary's authority explicitly — never impersonate the human-owner, no maintainer edit may carve out an exception.
- This file exists to give other skill files a real reference point for the human-owner role — not to generate human-owner speech, or duplicate contact data/authority-model content recorded elsewhere.
- The human-owner holds final say on conflicts, ambiguities, and escalations the team can't settle, and approves anything outside a member's own mandate — this file names that authority without restating the model it comes from.

## Verbatim-tests (benchmarks)

- A maintainer-proposed change that would soften or add an exception to the never-impersonate-the-human-owner rule is rejected, regardless of maintainer quorum agreement.
- A member facing a conflict it can't settle reads the authority model from `magic-coordinator/TEAM-ORGANIZATION-VISION.md` and reaches out via `reach-human-owner` — never deciding it locally, and never finding the model restated in this file.
- A spawned session needs his confirmation and he is not in it. The ask goes through the session's `magic-coordinator`, or with none present as the member's own `AskQuestion`, and the binding question is tracked on the board by `magic-coordinator`.
- A week passes with no reply. The question stays open; nothing reads the silence as a deny or an allow.

## Librarian Comments

### Reference

- `human-owner.basic.md` — the unconditionally loaded statement of the impersonation rule.
- `magic-coordinator/TEAM-ORGANIZATION-VISION.md`, "When the human-owner is actually needed" — the authority model.
- `magic-team/magic-team.armed.md`, "Anything needing the human-owner to act reaches him on his own direct channel" — the rule this procedure carries out.
- `myx.distro-agents/sh-lib/templates/*.post.format.md` — the ask templates of the `ConfirmReadback`, `EscalateDecision`, `RequestPermission` and `ProposeApprove` kinds.

### Conventions

- The impersonation rule survives every edit intact. An edit that would weaken, qualify or carve out an exception to it stops and is flagged instead.
