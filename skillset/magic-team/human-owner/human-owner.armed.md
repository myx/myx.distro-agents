---
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# human-owner — armed (professional-ready) content

# Summary

`human-owner` is a reference-only identity record — never an acting member, never invoked as a behavior; it exists so other files have somewhere real to point at when they mean "the human-owner."

## Goals

- Give other skill files/routines a real reference point for "the human-owner" as a role (who approves what, who gets asked when) — not a placeholder.
- Never generate human-owner speech, replies, or actions — this file's own presence is not a trigger for impersonation.
- Non-acting and never an executor, but not inert: it carries one real, invocable procedure (`reach-human-owner`), run by the referencing session under that session's own tooling rules. Scope stays deliberately narrow — identity statement, authority-model pointer, contact-data pointer, the impersonation rule, that procedure — extended later only as the team's structure needs it, not designed in advance.

## Scope

- Does:
  - Serve as the identity/authority-model pointer any skill file or routine may reference. The authority itself: final say on conflicts, ambiguities, and escalations the team can't settle, and approval for anything outside a member's own mandate — the model lives in `magic-coordinator/TEAM-ORGANIZATION-VISION.md`, read there.
  - Define the real, invocable procedure used to actually contact the human-owner asynchronously when needed but not present in the current session.
- Doesn't:
  - Restate the authority model — "when the human-owner's involvement is actually needed" lives in `magic-coordinator/TEAM-ORGANIZATION-VISION.md`; this file doesn't duplicate it.
  - Hold actual contact details — installation-specific configuration (email, Trello handle, Slack `@myx`), lives at the sanctioned contacts file, not here.
  - Ever get "run"/invoked as a behavior — no auto-trigger exists, no dispatch path exists, none should exist.

# Terminology: none

No member-specific glossary terms for this member.

# Team-Member's (-specific) local procedures

Named procedure blocks. Steps below call them by name. Not separate routines - not visible outside this file.

## `reach-human-owner` - contact the real human-owner asynchronously when they're needed but not present in the current session

Distinct from the impersonation rule below: impersonation is about never speaking/acting *as* the human-owner; this procedure is about *communicating with* them (e.g. a spawned work instance needs a confirmation/answer and the human isn't in that session).

Steps:
1. Send via Slack to the human-owner's identity — `slack-human-owner` or `slack-magic-team`, judged by context — using the `--member-slack-send-message` operation, the same send path `routine-communication-sweep` uses. Never invent a separate send path, and never reference a credential directly.
2. Send promptly — the user's own framing was "send maybe straight away." Don't over-gate this with unnecessary confirmation steps before sending the question itself.
3. Register the topic/question as a `board-item` so it doesn't disappear — this is the same "questions addressed to them tracked and not left to disappear" requirement recorded in `TEAM-ORGANIZATION-VISION.md`'s "when the human-owner is actually needed" facet. File it as an `inquiry-*`/`approval-*` item in `board-blocked`, under the existing "human-owner decision" reason, carrying `source-slack-channel`/`source-slack-ts` once the Slack thread opens. The existing board-item mechanism, not a new file.
4. React to replies with a genuinely long timeout before treating the question as ignored — on the order of a week. Deliberately much longer than the aggressive stop-and-ask timeouts used elsewhere for synchronous tool/mechanism failures — those are about execution failing fast; this is async human response latency, a different timescale. Don't conflate the two.
   - No reply even after that long timeout: a genuinely open question, not decided here — don't invent an escalation or fallback action.

# Team-Member's (-specific) local rules

All statements apply at the same time, always. Any session reading or referencing this file is permitted and obliged to follow the `reach-human-owner` procedure exactly as written when it applies. This file's own rules — above all the impersonation-forbidden rule below — override any general team `.armed.md` rule a referencing session might otherwise apply, without exception.

- Never impersonate the human-owner. No exception, ever. This is the single hardest constraint in this folder — no maintainer edit may weaken it, qualify it, or add a carve-out to it.
- This file is never loaded to generate human-owner speech, replies, or actions — only ever a reference point for other files' own logic.
- No auto-trigger exists for this file. No dispatch path exists. None should exist.
- Actual contact details never live here — they live at the sanctioned, installation-specific contacts location.
- The authority model — when the human-owner's involvement is actually needed vs. the team deciding/recording on its own — lives in `magic-coordinator/TEAM-ORGANIZATION-VISION.md`. Do not re-derive or restate it here; read the source.
- A task seems to call for speaking or acting as the human-owner: it doesn't. Stop. Use `reach-human-owner` instead. Never guess an answer on their behalf.
- "Session technically open" is not the same as "human actually present/watching" — whether/how to account for this is a future joint `magic-librarian` + `magic-architect` investigation, not decided here.
- A maintainer-proposed change would soften or add an exception to the never-impersonate-the-human-owner rule: rejected, regardless of maintainer quorum agreement.

# Domain knowledge: none

No additional reference material beyond what's already in Goals/Scope.

# Team-Member's (-specific) tooling

Every `magic-tooling` operation this team-member uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-slack-send-message <team-member> <human-owner|magic-team> [text...]` — `reach-human-owner` step 1's send path. `<team-member>` is the session's own member, never `human-owner`. Target is `human-owner` for a direct ask, `magic-team` when the question belongs in front of the team; no other target applies here.

# Maintainer Notes

Used to check this files own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This file's rules exist to allow work-process to be smooth and running in proper direction.
- This file's instructions cover this skill's own activities and operations, as intended, without logical conflicts between rules.
- This file states the impersonation boundary's authority explicitly — never impersonate the human-owner, no maintainer edit may carve out an exception.
- This file exists to give other skill files a real reference point for the human-owner role — not to generate human-owner speech, or duplicate contact data/authority-model content recorded elsewhere.
- The human-owner holds final say on conflicts, ambiguities, and escalations the team can't settle, and approves anything outside a member's own mandate — this file names that authority without restating the model it comes from.

## Verbatim-tests (benchmarks)

- Readback of this file's contents still matches all `verbatim-intents` of this file.
- A maintainer-proposed change that would soften or add an exception to the never-impersonate-the-human-owner rule is rejected, regardless of maintainer quorum agreement.
- A member facing a conflict it can't settle reads the authority model from `magic-coordinator/TEAM-ORGANIZATION-VISION.md` and reaches out via `reach-human-owner` — never deciding it locally, and never finding the model restated in this file.
- A spawned session needing the human-owner's confirmation, with the human not present in that session, reaches out over `slack-human-owner` (contact identity resolved from the sanctioned contacts file, not hardcoded here) and registers the topic as an `inquiry-*`/`approval-*` board-item in `board-blocked`, under the existing "human-owner decision" reason, not a new tracking file.

## Librarian Comments

### Reference

- `human-owner.basic.md` — the canonical, unconditionally-loaded statement of the impersonation-forbidden rule and the "not a behavior to invoke" framing; stays live, not merged here.
- `magic-coordinator/TEAM-ORGANIZATION-VISION.md` — the authority-model source of truth ("when the human-owner is actually needed" facet).
- `board-blocked` — where open reach-out threads get tracked, as `inquiry-*`/`approval-*` board-items.
- `magic-team/magic-team.board.md` — the "human-owner decision" `board-blocked` reason category.
- `magic-team/magic-team.armed.md` — the board-item entity model (`source-slack-channel`/`source-slack-ts` field shape).
- `routine-communication-sweep` — the existing Slack mechanics `reach-human-owner` reuses rather than inventing a separate send path; also the source of the general impersonation rule this file's own boundary matches.

### Conventions

- The impersonation-forbidden rule must survive any edit completely intact, word-for-word in spirit, no softening, no exception carved out, ever — the single most safety-critical piece of content in this folder. If any edit to this file (or any of its source files) would weaken, qualify, or add a carve-out to that rule, stop and flag it rather than proceeding — not a normal editorial-judgment call.
