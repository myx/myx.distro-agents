---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-devops, human-owner
invitees: human-owner
---
# magic-coordinator.bootstrap.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Steps
- Closure steps
- Routine's local procedures
- Routine's local rules
- Routine-specific tooling
  - DistroAgentsTools magic-tooling operations
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions

# Summary

`magic-coordinator.bootstrap.routine` sets up and verifies Magic Vane's working identity and channels, and hands the human-owner an exact list of what is missing. It can be re-run at any time.

## Goals

- Magic Vane works under her own identity (`magic-coordinator`, Magic Vane, `dispatchr`), never by accident under the human-owner's or a bare app identity.
- Delivery checks reflect real, usable behaviour, never a transport success alone.
- Every watched team conversation is reachable, and her Slack profile matches her role.

## Scope

- Does: readiness checks, probe sends, profile checks, and one concrete ask to the human-owner for each blocker. Runs when a team is set up in a new place, or on request.
- Doesn't: change other skill files, or rework team policy.
- Open: whether app-attribution markers are acceptable when the message reads as Magic Vane — the human-owner's policy call, asked at **checkpoint-ask-user**. Tooling that hard-fails on the marker alone is a recorded mismatch to fix.
- Open: checking channel membership and joining public team channels, once an operation covers it.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **check-readiness**: Run `--owner-setup-slack --check` and `--magic-heartbeat-config-check`. Every missing or failing item becomes a blocker for **checkpoint-ask-user**.
2. **check-send-path**: Send a probe, carrying a timestamp marker, to `magic-team`, `event-track`, `event-alert` and `human-owner` (`--member-comms-slack-send-message`). Read each back (`--member-comms-slack-read`). A probe counts only when it arrived where expected and reads as sent by Magic Vane. Delivered under another identity, or not found, is a blocker. App attribution alongside her own identity is a warning, not a failure.
3. **check-alias-target**: A failed `human-owner` send leaves that target unresolved. Ask the human-owner for a reachable conversation; never guess a substitute.
4. **check-slack-profile**: Read the profile (`--member-comms-slack-profile-get magic-coordinator`) and compare it with `magic-coordinator.basic.md`: picture, display name Magic Vane, handle `dispatchr`, and a short role-aligned status line (baseline: "Dispatch and prioritization lead for magic-*"). A mismatch is set (`--member-comms-slack-profile-set`) after the human-owner's go. A facet that could not be read is asked about, never assumed.
5. **checkpoint-ask-user**: For each blocker, ask the human-owner for exactly the next action, one question at a time (`AskUserQuestion`), and wait for the answer (`magic-team.armed.md`'s **wait-never-quit**). After each answer, apply only the affected fix and re-run only the affected step.

# Closure steps

1. **report-compact-outcome**: One short table: target, send status, identity status, missing items. A final line `READY` only when every target passed **check-send-path**; otherwise `NOT READY` with the numbered missing actions.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- Fail loud on ambiguity. Transport success alone never reads as "working".
- No guessed targets, no guessed scopes, no fallback identity.
- Every blocker maps to one concrete ask, and every `NOT READY` passes through **checkpoint-ask-user**.
- Reports are compact: facts first.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--owner-setup-slack --check`
- `--magic-heartbeat-config-check`
- `--member-comms-slack-send-message <team-member> <target> [text...]`
- `--member-comms-slack-read <team-member> <channel>:<ts>`
- `--member-comms-slack-profile-get <team-member>`
- `--member-comms-slack-profile-set <team-member> {--display-name <v>|--status-text <v>|--avatar <path>|...}`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- Magic Vane operates under the intended identity (`magic-coordinator` / `Magic Vane` / `dispatchr`), never under accidental myx or app-only impersonation.
- Message-delivery checks reflect real usable behavior — native-user expectations and actual attribution — never the false confidence of a bare `ok:true`.

## Verbatim-tests (benchmarks)

- A probe send returns `ok:true` but `message.user` does not match **check-auth-identity**'s authenticated `user_id`: reported `NOT READY` with a numbered missing action, never counted as working.
- A `human-owner` send fails with `channel_not_found`: the alias stays unresolved and produces a concrete human-owner ask, never a guessed substitute target.

## Librarian Comments

### Reference

- `magic-coordinator.basic.md` — the identity the profile is checked against.

### Conventions

- Keep transport success, identity success and policy success apart.
- One question per ask, each actionable.
