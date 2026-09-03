---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-coordinator.external-inbox-handle-loop.routine — the actual procedure

# Summary

Routine-external-inbox-handle-loop gives non-acting owners (human-owner, external contacts) the same working-mailbox continuity acting members get, despite having no skill folder of their own.

## Goals

Give non-acting owners (the human-owner, external contacts) the same real, working "mailbox" continuity that acting members get from `magic-team.process-inbox.routine`, despite having no skill folder of their own to host one — so an outstanding ask/reminder/status to a non-acting owner doesn't just silently sit unaddressed because there's no natural "their own inbox" for a normal pass to check. Without this, the team's inbox model would have a structural blind spot exactly where it matters most (the human-owner's own outstanding items, or an external partner's pending response).


## Scope

Does: outstanding-ask/reminder/status tracking for non-acting owners. Invoked from `magic-coordinator.heartbeat.routine`'s own post-sweep inbox-processing step (its regular caller), or standalone any time there's reason to check on a specific non-acting owner sooner than the next regular cycle. `magic-coordinator` only — non-acting owners' content lives inside its own inbox by construction, so it is structurally the only one positioned to run this; there is no "the owner processes it themselves" path here, the way `magic-team.process-inbox.routine` has for acting members.
Doesn't do: anything `magic-team.process-inbox.routine` already covers for acting members. Both its steps read `magic-coordinator`'s own inbox, but handle different content there: **process-own-inbox** handles `magic-coordinator`'s own mail; **work-the-loop** handles the non-acting-owner content that lives in that same inbox by construction (see Goals).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **process-own-inbox**: run `magic-team.process-inbox.routine magic-coordinator` — `magic-coordinator`'s own mail only; the non-acting-owner content sitting in that same inbox is **work-the-loop**'s job, not this step's.
2. **work-the-loop**: pick one of five actions per item, by its own real history — not a fixed rotation.
   - **Retry**: the prior attempt may not have landed — try again through the same channel.
   - **Communicate**: send a fresh status/update even without a specific blocker, to keep the item visibly alive.
   - **Remind**: a gentle nudge on something already sent, not yet answered.
   - **Switch channels**: the current channel isn't working after reasonable attempts — try a different one this owner is known to use.
   - **Escalate**: last resort. DM the human-owner directly to report the item (`magic-coordinator`'s own "sole mandated channel" rule — reports the outcome, doesn't skip that channel for external parties).
   - "Reasonable time" is a judgment call from the item's own urgency/history (references, prior reply timestamps) — not a fixed threshold.

# Closure steps

Invoked inline: nothing. Run as its own session: execute `magic-team.coworking.routine`'s Closure Steps.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-coordinator` (this routine's sole executor) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- Whatever's decided gets logged back onto the item itself (a reply/reaction round); a retry/reminder/channel-switch just logs the attempt and leaves the item where it was, typically still pending.
- Does not move an item to `board-processed` on anything short of genuine resolution.
- Escalate is always the last resort, not the default.
- Unsure whether "reasonable time" has actually elapsed: err toward one more attempt before escalating, unless the item is explicitly time-sensitive.
- An external contact's channel genuinely appears dead: that itself is escalation-worthy — report it, rather than silently retrying a channel known not to work.
- A human-owner item sits unanswered but looks like something that will naturally get addressed when they're next in Slack: weigh against unnecessarily nagging — a routine "communicate a fresh update" can substitute for an urgent-feeling remind or escalate, when genuinely not time-critical.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- `magic-coordinator` (this routine's sole executor) is obligated to keep `slack-event-track` activity tracking current — an escalation in particular should be visible as it happens, not just discoverable later from the item's own log.
- `# Steps`/`# Closure steps` sequencing follows `magic-team/magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-comms-slack-send-message <team-member> <target> [text...]` (**work-the-loop**: escalation DM; Slack activity-tracking obligation)

## `--member-comms-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>:<ts>> [text...]` — posts a message to Slack, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives non-acting owners (human-owner, external contacts) the same working mailbox continuity acting members get from `magic-team.process-inbox.routine`, despite having no skill folder of their own.

## Verbatim-tests (benchmarks)

- An external-contact item that gets no response within a reasonable time escalates to a direct DM to the human-owner, never resolved by skipping that channel.

## Librarian Comments

### Reference

- `magic-team.process-inbox.routine` — the general operation this routine is the non-acting-owner variant of.
- `magic-coordinator.heartbeat.routine` — the regular caller (post-sweep inbox-processing step).
- `magic-coordinator` — sole-mandated-channel-to-human-owner rule; batch-human-hands-on-items standing rule.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.

### Conventions

None currently known beyond this file's own Local rules.
