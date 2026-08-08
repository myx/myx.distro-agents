---
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# routine-prepare-session — the actual procedure

# Summary

Routine-prepare-session is a cheap, fast currency check confirming a routine/skill file about to be followed isn't stale or drifted, before a session acts on it.

## Goals

Give any about-to-run session (a structured routine, an ad-hoc activity, or a plain conversation that's about to lean on a specific skill/routine file) a cheap, fast confirmation that what it's about to follow is actually trustworthy — before it acts on a doc that might be stale or drifted, mirroring why `routine-close-session` exists as a shared step rather than N separate copies. This exists because running an entire session off a routine file already known to be wrong (or silently drifted from the team's actual current shape) wastes far more effort discovering that mid-session than a 30-second check up front would have cost.

## Scope

Does: cheap, fast currency check on the specific routine/skill file about to be followed. Called at the start of any structured routine, as part of `routine-session-start`'s own currency-check step, or callable standalone any time a session wants a quick check before relying on a file.
Doesn't do: deep audit — not a replacement for `magic-librarian`'s own full daily self-sufficiency audit.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **Confirm the routine protocol with librarian**: ask `magic-librarian` for a quick read of the specific routine file about to run (whichever `<owning-member>.<short-name>.routine.md` file this session is about to follow) as part of its team self-sufficiency audit — does this doc still reflect the team's current shape, is it internally consistent with its owning member's own `.armed.md`, the board, and `magic-team/magic-team.shared.md` and the other files it cross-references, and — the point that actually motivates this step — is everything the routine needs to run correctly written down in the file itself, not assumed from memory or a prior conversation a fresh instance wouldn't have. This is a fast read-only sanity check, not a full audit pass; if librarian flags a real gap or drift, surface it to the user before proceeding rather than running the routine off a doc already known to be wrong.
1a. **Process own inbox**: run `routine-process-inbox` on own inbox — inline execution (own identity). Not automatic just because this routine spawned — this explicit call is what actually guarantees it happens.

# Closure steps

This routine has no distinct closing phase of its own — it's a sub-procedure other routines call inline (folded into `routine-session-start` step 2), not a standalone session with its own lifecycle.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- Whichever `magic-team` member executes this routine is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- `executors: magic-team` is deliberately wide open here: this is a light session-prep check, it does not write to the board, and it carries no special mandate — there is no reason to restrict who can run it.
- Not wired into `routine-heartbeat`'s per-nudge cycle — that loop iterates far more often than the structured routines this step is meant for, so a librarian round-trip on every cycle would be disproportionate; its own doc still gets covered by librarian's daily sweep instead.
- This routine verifies only — it does not fix a gap it finds itself. It refuses to continue silently on a doc it knows is bad; the fix itself is someone else's step.
- The librarian's quick read finds something minor or cosmetic, not a real correctness gap: proceed — let the normal daily self-sufficiency audit pick it up later, don't block the calling session over it.
- Not sure if a finding is "real gap" or "minor": default to surfacing it — a note that turns out fine only costs a quick "that's fine, proceed"; a real gap left unsaid costs the whole session running on bad information.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- `magic-coordinator` can be the executor running this check, since several members may run this routine — when it is, the general `slack-event-track` activity-tracking obligation still applies for whatever session this check is part of. This step is usually too small for its own post, but a real gap it finds should feed into the calling routine's own tracking — don't let it get lost.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-slack-send-message <team-member> <target> [text...]` (Slack activity-tracking obligation)

## `--member-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

# Maintainer Notes

Used to check this files own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives any about-to-run session a cheap, fast confirmation that the doc it's about to follow is actually trustworthy — before acting on something stale or drifted.

## Verbatim-tests (benchmarks)

- If `magic-librarian` flags a real gap or drift during this check, it's surfaced to the user before proceeding — the routine never runs off a doc already known to be wrong.

## Librarian Comments

### Reference

- `routine-session-start` — folds this routine's currency check in as its own step, for coworking-like sessions.
- `routine-process-inbox` — own-inbox processing.
- `routine-close-session` — the shared-step design this routine's own existence mirrors.
- `routine-daily`, `routine-retro`, `routine-grooming`, `routine-one-on-one` — the structured routines that call this at their own start.
- `magic-team/magic-team.shared.md` — consistency-check target for the librarian read.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.
- The board — consistency-check target.

### Conventions

None currently known beyond this file's own Local rules.
