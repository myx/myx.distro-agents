---
executors: any acting member (for its own inbox); magic-coordinator (for non-acting-owner content, board-formal-state writes, and the main-loop GC sub-step)
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# routine-process-inbox — the actual procedure

# Summary

Routine-process-inbox is the real, working mailbox for every acting team member, so cross-member handoffs and routed requests land and get worked without relaying through `magic-coordinator` first.

## Goals

Give every acting team member a real, working mailbox so cross-member handoffs, routed requests, and self-notes have somewhere reliable to land and get worked — without requiring every interaction to be relayed through `magic-coordinator` first. This exists because a team with no inbox mechanism either loses async handoffs entirely (nobody's watching for them) or over-centralizes on the coordinator as a bottleneck for every small cross-member exchange. Splitting "reading/replying/routing within one's own inbox" (any member, freely) from "writing the board's *formal* state" (`magic-coordinator`-exclusive) keeps both goals intact: real member autonomy for ordinary mail, and a single source of truth for the team's formal work-tracking.

## Scope

Does: member-owned read/reply/route within one's own inbox. Also separately runnable by any acting member for its own inbox, any time.
Doesn't do: write the board's formal state (`magic-coordinator`-exclusive).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **read-and-classify**: a status/block report, a request/question, a routine handoff, a reflection, something else. Not an exhaustive list — classify by what it actually says.
2. **act-lightweight**: reply, route to another member or to `magic-coordinator`, or resolve inline if it's genuinely simple/obvious and within this member's own duties. Needs a formal board change and this isn't `magic-coordinator` running the pass: route to `magic-coordinator` rather than attempting the write.
3. **reply-on-cross-member-handoff**: a reply/route/handoff touching another member (including routing to `magic-coordinator`) sends an immediate reply to `slack-magic-team` via the `--member-slack-send-message` operation — compact, who + what it relates to. `magic-coordinator` sends it even when it isn't the one who performed the underlying write. Self-writes to one's own inbox don't need one.
4. **run-gc-in-heartbeat**: when `magic-coordinator` runs this for its own inbox as part of `routine-heartbeat`, run `routine-heartbeat`'s own GC sub-step — full mechanics live there, not restated here.

**Not automatic just because a spawn happened**: a spawned session processes the executing member's own inbox only when its `.routine.md` Steps sequence contains an explicit `routine-process-inbox <that member>` call — a real step each routine's own file is responsible for including, same as any acting member's duties include reading its mail. A routine whose own Steps never contain this explicit call gives no guarantee its executor's inbox is ever read, no matter how routine its invocation looks.

**Execution mode is decided by identity match, not by which routine is calling**: this routine is invoked as `routine-process-inbox <team-member>` — one mandatory argument. It always works on that member's inbox; there is no second parameter.
- **Inline**, in the same process/session — when `member` is processing its **own** inbox/identity. This is the common case: any acting member processing its own inbox.
- **Spawned**, as a separate background `Agent` — when `member` is representing an inbox/identity it doesn't itself own, on behalf of someone else. Same shape as `routine-external-inbox-handle-loop`'s non-acting-owner pattern (`magic-coordinator` spawned to act for the human-owner/external contacts, since they have no inbox folder of their own).

# Closure steps

This routine has no distinct closing phase of its own — it's invoked inline by other routines' own steps to process one inbox, not a standalone session with its own lifecycle.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- Whichever member is named as the executor for a given call — any acting member for its own inbox, `magic-coordinator` for non-acting-owner content/board-formal-state writes/the main-loop GC sub-step — is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- Every acting member gets a personal inbox — created lazily, first use. Separate from the board (`magic-coordinator`'s own formal-state tool, not a mailbox).
- Any member (or `routine-communication-sweep`, `routine-ingest-task`) can write into someone's inbox; only that folder's own owner processes what's inside it.
- Non-acting owners (human-owner, external contacts) have no inbox folder of their own — their content lives inside `magic-coordinator`'s inbox, processed for them via `routine-external-inbox-handle-loop`.
- Only `magic-coordinator` may post `assignment-*` items into another member's inbox — any member may post `inquiry-*` to anyone's inbox (the general default), but a real work dispatch is coordinator-exclusive.
- Only `magic-coordinator` may update board-tracking metadata (already-triaged, already-referenced) on an item sitting in another member's inbox — even when writing there for another allowed reason.
- First spawn of the day (or a genuinely fresh session): reads its own inbox — including saved `reflection-*` self-notes — as part of loading context, before anything else. Member-initiated, not coordinator-triggered.
- Invoked from: `routine-heartbeat`'s inbox-processing sub-step (immediately after comms-sweep, `magic-coordinator` processes its own inbox every cycle), standalone on a member's own initiative, and the morning self-review.
- `routine-heartbeat`'s own inbox-processing sub-step also does a light staleness check across acting members' inboxes (age-based, not exhaustive re-reading) — stale content folds into that member's next dispatch, or gets a direct nudge if time-sensitive.
- **reflection-promotion**: A member's in-the-moment reflection about running an activity lands in its own inbox. From there it either moves to the board as an `inquiry-*` addressed to `magic-coordinator`, or stays in that same inbox — compacted and cleaned up along with the other reflection items there — until it forms into a proposal, is discussed at `routine-retro`, or is discarded. It is never moved into another inbox.
- Unsure whether an item is simple/obvious enough to resolve inline vs. route onward: same bar as `magic-coordinator`'s own Dispatch section ("approved, simple, obvious, within this member's own duties") — fails that bar, route it.
- An item needs a formal board change but this isn't `magic-coordinator` running the pass: always route, even if the fix looks small — not a case-by-case judgment call.
- Unsure whether a cross-member touch is significant enough for an immediate reply to `slack-magic-team`: default to sending one.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- When `magic-coordinator` is the executor (own inbox, non-acting-owner content, or a board-formal-state write), it is obligated to keep `slack-event-track` activity tracking current — extends to the pass's broader progress, not just individual handoffs already covered by step 3.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-slack-send-message <team-member> <target> [text...]` (step 3: cross-member handoff immediate reply; Slack activity-tracking obligation)

## `--member-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

# Maintainer Notes

Used to check this files own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine ensures every acting member's own inbox actually gets processed — not left to sit unread just because nothing automatically triggers it.

## Verbatim-tests (benchmarks)

- Any member can write directly into another member's inbox folder, but only that folder's own owner processes what's inside it — same as real email.

## Librarian Comments

### Reference

- `routine-external-inbox-handle-loop` — the non-acting-owner variant/pattern this routine's spawned-execution mode mirrors.
- `routine-heartbeat` — the regular caller for `magic-coordinator`'s own inbox, every cycle.
- `routine-communication-sweep`, `routine-ingest-task` — other writers into a member's inbox.
- `routine-retro` — where a retained reflection gets discussed, one of reflection-promotion's own outcomes.
- Every other `.routine.md` — each must contain its own explicit `routine-process-inbox <team-member>` call in its Steps for the executing member's inbox to actually get processed; this routine does not guarantee that on its own.
- The board — the formal-state target, `magic-coordinator`-exclusive to write.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.

### Conventions

- The mandatory-`<team-member>` call shape is this routine's single most load-bearing property — preserve `routine-process-inbox <team-member>` exactly (always a member, always that member's inbox, no other parameters), the "not automatic just because a spawn occurred" correction, and the inline-vs-spawned execution split by identity match precisely. Don't let a future synthesis pass reintroduce a false-automatic framing where every spawn is assumed to process the executing member's inbox without an explicit Steps-section call.
- The two-authorities split (own-inbox actions vs. board-formal-state writes, `magic-coordinator`-exclusive for the latter) is equally load-bearing — preserve exactly, don't blur the two into one permission tier.
