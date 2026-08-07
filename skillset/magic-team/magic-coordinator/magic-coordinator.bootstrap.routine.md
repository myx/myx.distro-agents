---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-devops
invitees: human-owner
---
# routine-bootstrap-magic-vane - the actual procedure

# Summary

Routine-bootstrap-magic-vane is the one-time (and re-runable) coordinator bootstrap for Magic Vane's real operating identity: confirm identity, configure credentials, verify delivery semantics, confirm Slack profile shape, and fail loud with a human-owner handoff when any step cannot be completed autonomously.

# Goals

- Ensure Magic Vane operates under the intended identity (`magic-coordinator` / `Magic Vane` / `dispatchr`) rather than accidental myx/app-only impersonation.
- Ensure message delivery checks reflect real usable behavior (native-user expectations and attribution reality) instead of `ok:true` false confidence.
- Ensure watched communication targets are reachable and joined where applicable.
- Ensure Slack profile basics are correct and visibly aligned with the role.
- Produce a compact, explicit missing-items report when blocked.

# Scope

Does:
- Bootstrap and validate `SLACK_USER_TOKEN` for `magic-coordinator`.
- Verify target channel reachability and join state for `magic-team`, `event-track`, `event-alert`, and `human-owner` alias target.
- Verify send-path behavior with current policy checks.
- Verify Slack profile essentials: picture, display name, handle, and status line.
- Escalate to human-owner with exact step-by-step asks when a step cannot be completed by coordinator tooling.

Doesn't do:
- Change unrelated skill files.
- Auto-link this file from SKILLSET indexes.
- Rework broad team policy outside coordinator bootstrap scope.

# Preconditions

- Workspace root available with `source/myx/myx.distro-agents`.
- `DistroAgentsTools.fn.sh` available and executable.
- Coordinator member key exists: `magic-coordinator`.
- Human-owner reachable for escalations when required.

# Steps

Exact instructions. Execute in order, every step, literally as written.

1. **Load identity and targets**
- Read member token and configured targets:
  - `--member-config-option magic-coordinator --select SLACK_USER_TOKEN`
  - `--agents-config-option magic-coordinator --select SLACK_CHANNEL_MAGIC_TEAM`
  - `--agents-config-option magic-coordinator --select SLACK_CHANNEL_HUMAN_OWNER`
  - `--agents-config-option magic-coordinator --select SLACK_CHANNEL_EVENT_TRACK`
  - `--agents-config-option magic-coordinator --select SLACK_CHANNEL_EVENT_ALERT`
- Missing any required value: stop and escalate using the human-owner script in step 10.

2. **Auth identity check**
- Call `auth.test` using `SLACK_USER_TOKEN`.
- Expected minimum:
  - `ok:true`
  - `user == magic-coordinator`
  - stable `user_id` present
- If auth fails or identity mismatch: stop and escalate (step 10).

3. **Membership and join check (public channels)**
- For `magic-team`, `event-track`, `event-alert`:
  - Call `conversations.join` with current user token.
  - Accept `ok:true` as joined/already-joined success.
- If `missing_scope` appears:
  - Record missing scope exactly as returned (for example `channels:write`).
  - Escalate with one clear add-scope request (step 10).

4. **Send-path reality check**
- Send probe message to each target (`magic-team`, `event-track`, `event-alert`, `human-owner`) with timestamp marker.
- Capture full API response payload for each attempt.
- Distinguish outcomes:
  - transport success (`ok:true`)
  - attribution shape (`message.user`, `app_id`, `bot_id`, `bot_profile`)
  - target accessibility errors (`channel_not_found`, `not_in_channel`, etc.)

5. **Native identity policy gate**
- Treat send as valid operational success only when all are true:
  - `ok:true`
  - `message.user` equals authenticated `user_id` from step 2
  - target is expected and reachable for that alias
- Presence of `app_id`/`bot_id`/`bot_profile` is a policy warning, not a standalone transport failure.
- If local code currently hard-fails on marker presence alone, record as tooling-rule mismatch and queue fix.

6. **Alias target validity check (`human-owner`)**
- If `human-owner` send fails with `channel_not_found`:
  - mark alias mapping unresolved for current identity.
  - require human-owner to provide a reachable DM/channel id for Magic Vane.
- Do not silently swap to a guessed target.

7. **Slack profile setup check (now and every bootstrap re-run)**
- Validate these profile fields for Magic Vane:
  - Picture/avatar: current intended image is present and correct.
  - Display name: `Magic Vane`.
  - Handle/alias: `dispatchr`.
  - Status line: present, role-aligned, short.
- Preferred status line baseline:
  - `Dispatch and prioritization lead for magic-*`
- If API scope allows (`users.profile:read`), fetch and verify via API.
- If API read is unavailable or ambiguous, request visual confirmation from human-owner (step 10).

8. **Minimum scope matrix capture**
- Record currently required scopes by operation family:
  - Auth: token validity (`auth.test`).
  - Channel joins (public): `channels:write`.
  - Channel history/replies reads: conversation read scopes used by `--check-slack`.
  - Reactions: scopes for `reactions.add` used by `--react-slack`.
  - Message send: scopes for `chat.postMessage`.
- When any call returns `missing_scope`, record exact `needed` and `provided` fields verbatim.

9. **Compact outcome report**
- Produce one short matrix:
  - Target -> join status -> send status -> identity status -> missing items.
- Include explicit final line:
  - `READY` only if all required targets are operational per step 5.
  - otherwise `NOT READY` plus numbered missing actions.

9a. **AskUserQuestion checkpoint (mandatory when `NOT READY`)**
- Ask the human-owner for exactly the next missing action, one question at a time.
- Preferred path: AskUserQuestion in-session (single focused question, explicit expected answer format).
- Failover path: if AskUserQuestion is unavailable, unanswered, or the session is unattended, send the same question to Slack IM target (`human-owner`) via `--member-slack-send-message`.
- Slack IM failover failure (`channel_not_found` or equivalent): immediately fall back to posting the question in `magic-team` plus a short `event-alert` blocker note.
- After each answer, apply only the directly affected fix and re-run only the impacted bootstrap step(s).

10. **Human-owner escalation script (step-by-step, mandatory when blocked)**
- Use this exact ask sequence, one step per message:
  1. Confirm I should continue bootstrap for `magic-coordinator` under `Magic Vane` identity.
  2. Confirm/update `SLACK_USER_TOKEN` for Magic Vane.
  3. Add missing Slack scope(s) exactly as reported (example: `channels:write`).
  4. Reinstall/re-authorize app/token if Slack requires it after scope changes.
  5. Provide/confirm reachable `human-owner` DM or channel id for this identity.
  6. Confirm Slack profile values:
     - picture correct,
     - name `Magic Vane`,
     - handle `dispatchr`,
     - status line text.
  7. Confirm whether app-attribution markers are acceptable for this workspace policy when `message.user` matches Magic Vane.
  8. Approve rerun of full bootstrap verification sweep.
- After each human-owner response, re-run only the directly affected step(s), then continue sequence.

# Routine's local rules

- Fail loud on ambiguity; never report "working" from transport success alone.
- No guessed target ids, no guessed scope names, no silent fallback identities.
- Every blocker must map to one concrete ask for human-owner.
- Every `NOT READY` state must pass through step 9a: one concrete AskUserQuestion before continuing.
- Keep reports compact and operational: facts first, no narrative padding.
- Never link this routine file into SKILLSET automatically.

# Routine-specific tooling

## DistroAgentsTools magic-tooling operations

- `--member-config-option <member> --select <KEY>`
- `--agents-config-option <member> --select <KEY>`
- `--member-slack-send-message <member> <target> [text...]`
- `--check-slack <target> [--oldest <ts>] [--raw]`
- `--react-slack <channel>:<ts> <emoji-name>`

## AskUserQuestion operation

- `vscode_askQuestions` (or equivalent AskUserQuestion channel in the active harness) is the primary interactive blocker-resolution mechanism for step 9a.
- Ask one concrete question at a time. Do not batch unrelated blockers into one prompt.

## Direct Slack API checks used by this routine

- `auth.test`
- `conversations.join`
- `chat.postMessage`
- Optional profile read when available: `users.profile.get`

# Maintainer Notes

Used only when maintaining this routine file.

## Compact conventions

- Keep step order stable; add new checks as append-only unless a reorder is required by dependency.
- Preserve the split between transport success, identity success, and policy success.
- Keep escalation text actionable and one-question-at-a-time.

## Session-grounded baseline captured here

- `channels:write` was required to auto-join public targets.
- `human-owner` alias target can fail with `channel_not_found` for Magic Vane unless explicitly mapped.
- Slack may return `ok:true` with app/bot attribution markers while `message.user` still matches Magic Vane.
- Bootstrap reporting must separate "delivered" from "accepted by native-identity policy".
