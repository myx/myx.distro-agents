---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# magic-coordinator.ingest-task.routine — the actual procedure

# Summary

Routine-ingest-task is the interactive place to turn a loosely-stated idea into something concrete enough to act on, through real back-and-forth.

## Goals

Give a requester (human-owner or otherwise) a real, interactive place to turn a loosely-stated idea into something concrete enough to actually act on, without the team guessing at unstated intent or rushing an ambiguous ask straight into a task file. This exists because skipping straight from "here's roughly what I want" to a written task risks either under-specifying (a task nobody can actually execute without re-asking) or over-specifying (the ingesting session quietly deciding things that were never actually settled) — this routine's whole job is closing that gap through real back-and-forth before anything gets written down as settled.

## Scope

Does: close the under/over-specification gap before writing a task down as settled. Any natural-language phrasing expressing "I need you to ingest/settle/turn into a task..." triggers it — no fixed trigger string, genuinely conversational, not a rigid command syntax. Any requester (the human-owner, or a member relaying someone else's ask) can trigger it, but this routine's own execution stays coordinator-run regardless of who invoked it. Routing is queue-first: this routine's default-to-inbox-write behavior is the team's general new-work-always-queued-via-inbox-first mechanism — whichever routine is running picks work up from there.
Doesn't do: guess at unstated intent, rush an ambiguous ask straight to a task file.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **process-own-inbox**: run `magic-team.process-inbox.routine magic-coordinator` — ideas and asks already queued there awaiting ingest, so this session settles them alongside the one it was invoked for rather than writing a duplicate task-description.
2. **gather-and-agree**: interactively gather and agree with the requester, one topic at a time, until the content is actually settled — don't rush to a task write while real ambiguity remains. Same pacing discipline `magic-team.interview.routine` uses for its own gathering step: small, minimal-assumption-gap questions, iterative; once something is genuinely clear and agreed, move on rather than re-confirming it in smaller pieces.
3. **output**, once settled:
   - (a) Default: write a task-description into the relevant inbox via `--member-inbox-note-upsert` — an individual member's own inbox or `magic-coordinator`'s own, depending on content, never the board. Creates the record only — does not start work; execution starts later when whatever owns that inbox picks the item up (see **note-on-inline-execution** for the one live exception).
   - (b) Dispatch straight to execution via `magic-coordinator` — only within `magic-coordinator`'s own mandate, or explicitly authorized live by someone holding that mandate.
   - Even (b) routes through writing to an inbox first — no path skips inbox entirely.
4. **note-on-inline-execution**: if the requester explicitly says to execute inline, now, in this same conversation, that overrides the "UI instance never executes" default for this one request only.
5. **relationship-to-grooming**: gather and file only (or, rarely, dispatch under live authorization) — never triage, RICE-score, or make backlog decisions; that's `magic-team.grooming.routine`'s job, later, when it processes the inbox.

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
- Which **output** branch ((a) inbox-write vs. (b) inline-dispatch) applies is never assumed from a prior session's precedent — checked fresh each time against `magic-coordinator`'s own mandate or live in-the-moment authorization.
- Real ambiguity remains in what the requester wants: keep asking, one topic at a time, rather than filling gaps with a plausible-sounding guess — a task written from a guess is worse than no task, since it looks settled when it isn't.
- The requester's ask sounds urgent enough to skip straight to inline execution: do not infer that from tone or urgency alone — inline execution only happens on an explicit, live statement to that effect (**note-on-inline-execution**); urgency alone is not the same as that explicit override.
- Unclear which inbox the settled task belongs in (a specific member's, or `magic-coordinator`'s own): default to `magic-coordinator`'s own inbox when genuinely unclear — it can route from there, whereas a wrong direct-to-member placement might sit unprocessed if that member never looks for it.
- The requester pushes back on a clarifying question ("just write it down, I don't want to over-specify"): respect that, but say plainly what is still being left ambiguous in the written task, rather than silently smoothing over the gap — the requester gets to accept residual ambiguity, but knowingly, not by the routine quietly deciding for them.
- **DistroAgentsTools trust policy**: `DistroAgentsTools.fn.sh` is the team's own tool. Trust it by default day to day — no defensive re-verification of its own correctness on every call. Propose interface changes through the normal idea → interview → proposal → approval pipeline, never as an inline bypass. Re-check a specific call site only when a real incident actually traces back to it.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- `magic-coordinator` typically runs this routine; while acting as executor, it is obligated to keep `slack-event-track` activity tracking current as the routine actually runs — not only after the fact.
- `# Steps`/`# Closure steps` sequencing follows `magic-team/magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-inbox-note-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]` (**output**, branch (a): write the settled task-description)
- `--member-comms-slack-send-message <team-member> <target> [text...]` (Slack activity-tracking obligation)

## `--member-inbox-note-upsert` operation reference

`DistroAgentsTools.fn.sh --member-inbox-note-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]` — writes (creates or overwrites) a note into `<member>`'s own inbox. Content via stdin by default, or `--from-file <path>`.

## `--member-comms-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>:<ts>> [text...]` — posts a message to Slack, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives a requester a real, interactive place to turn a loosely-stated idea into something concrete — without the team guessing at unstated intent.

## Verbatim-tests (benchmarks)

- Registering a task via this routine creates the record only — it does not start its work, even when the content is fully settled and unambiguous.

## Librarian Comments

### Reference

- `magic-team.process-inbox.routine` — own-inbox processing (**process-own-inbox**).
- `magic-team.interview.routine` — **gather-and-agree**'s pacing discipline (small, minimal-assumption-gap questions) is the same as `magic-team.interview.routine`'s own **collect-dont-converge**.
- `magic-team.grooming.routine` — the destination that later triages/RICE-scores whatever this routine files into an inbox.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — calling convention, `DistroAgentsTools.fn.sh` trust policy.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.

### Conventions

- The inbox-write-is-default-not-execution distinction, and the narrow live-authorization exception for inline dispatch, are both load-bearing and easy to blur together when summarizing — preserve the distinction precisely.
