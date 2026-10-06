---
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# human-owner — armed content

## Contents

- Summary
  - Goals
  - Scope
- Terminology: none
- Team-Member's (-specific) local procedures
  - `reach-human-owner` — contact the real human-owner asynchronously
- Team-Member's (-specific) local rules
- Domain knowledge: none
- Team-Member's (-specific) tooling
  - DistroAgentsTools magic-tooling operations
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions

# Summary

`human-owner` is a reference-only identity record: the point other files use when they mean "the human-owner".

## Goals

- Give skill files and routines a real reference point for the human-owner as a role: who approves what, and who is asked when.
- Never generate human-owner speech, replies or actions.
- Carry one invocable procedure, `reach-human-owner`, which the referencing session runs under its own tooling rules.

## Scope

- Does:
  - Serve as the role and authority-model pointer any file may reference.
  - Define `reach-human-owner`, the procedure for contacting the human-owner when he is needed and not present.
  - Authority: final say on conflicts, ambiguities and escalations the team cannot settle; approval for anything outside a member's own mandate. The authority model itself lives in `magic-coordinator/TEAM-ORGANIZATION-VISION.md` — read there, never restated here.
- Doesn't:
  - Restate or re-derive the authority model.
  - Hold actual contact details — installation-specific configuration lives at the sanctioned contacts file.
  - Ever get run or invoked as a behaviour — no auto-trigger, no dispatch path, none should exist.
- Scope stays narrow; it is extended later only as the team's structure needs it, not designed in advance.

# Terminology: none

# Team-Member's (-specific) local procedures

Named procedure blocks. Steps below call them by name. Not separate routines — not visible outside this file.

## `reach-human-owner` — contact the real human-owner asynchronously

This procedure communicates with him. It never speaks or acts as him.

Steps:
1. **settle-who-asks**: The session's participants and its `magic-coordinator` assess the matter first, per `magic-team/magic-team.armed.md`'s "Escalation and chain of command".
   - The session's `magic-coordinator` forwards to him what it does not settle itself.
   - With no coordinator in the session, the member asks him directly.
2. **ask-at-once**: Ask with `AskUserQuestion`, of the fitting kind in `magic-team/templates/escalation.document.format.md`, as soon as the assessment is done. The tooling delivers it on his direct channel and waits inside the call. One topic, the decision first.
3. **keep-it-tracked**: A question whose answer binds the team is registered by `magic-coordinator` as a board item blocking the work it gates. A member with no coordinator present files it to `magic-coordinator` with `post-inquiry`.
4. **wait-for-the-answer**: Wait per **wait-never-quit** in `magic-team/magic-team.armed.md`. No reply is never a verdict, neither a deny nor an allow.
   - A follow-up goes into the same thread. Read the thread before re-asking.
   - A question settled elsewhere is closed by its asker with `--member-pending-reply-settle`.

# Team-Member's (-specific) local rules

All statements apply at the same time, always.

- Never impersonate the human-owner. No exception, ever. No maintainer edit may weaken, qualify, or carve out an exception to this.
- Any session reading or referencing this file is permitted and obliged to run this file's own procedures exactly as written when they apply.
- This file is never loaded to generate human-owner speech, replies or actions.
- A task that seems to call for speaking or acting as the human-owner does not. Stop, and run `reach-human-owner`. Never guess an answer on his behalf.
- A maintainer-proposed change that softens or adds an exception to the never-impersonate rule is rejected, whatever the quorum.

# Domain knowledge: none

# Team-Member's (-specific) tooling

Every `magic-tooling` operation this record's own procedures invoke. Behaviour is read with `--member-help`. Procedures use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-pending-reply-read <team-member>`
- `--member-pending-reply-settle <team-member> ...`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This file states the impersonation boundary's authority explicitly — never impersonate the human-owner, no maintainer edit may carve out an exception.
- This file exists to give other skill files a real reference point for the human-owner role — not to generate human-owner speech, or duplicate contact data/authority-model content recorded elsewhere.
- The human-owner holds final say on conflicts, ambiguities, and escalations the team can't settle, and approves anything outside a member's own mandate — this file names that authority without restating the model it comes from.

## Verbatim-tests (benchmarks)

- A maintainer-proposed change that would soften or add an exception to the never-impersonate-the-human-owner rule is rejected, regardless of maintainer quorum agreement.
- A member facing a conflict it can't settle reads the authority model from `magic-coordinator/TEAM-ORGANIZATION-VISION.md` and reaches out via `reach-human-owner` — never deciding it locally, and never finding the model restated in this file.
- A spawned session needs his confirmation and he is not in it. The ask goes through the session's `magic-coordinator`, or with none present as the member's own `AskUserQuestion`, and the binding question is tracked on the board by `magic-coordinator`.
- A week passes with no reply. The question stays open; nothing reads the silence as a deny or an allow.

## Librarian Comments

### Reference

- `human-owner.basic.md` — the unconditionally loaded statement of the impersonation rule.
- `magic-coordinator/TEAM-ORGANIZATION-VISION.md`, "When the human-owner is actually needed" — the authority model.
- `magic-team/magic-team.shared.md`, "Anything needing the human-owner to act reaches him on his own direct channel" — the rule this procedure carries out.
- `magic-team/templates/escalation.document.format.md` — the `AskUserQuestion` kinds.

### Conventions

- The impersonation rule survives every edit intact. An edit that would weaken, qualify or carve out an exception to it stops and is flagged instead.
