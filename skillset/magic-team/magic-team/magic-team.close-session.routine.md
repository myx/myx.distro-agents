---
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# routine-close-session — the actual procedure

# Summary

Routine-close-session is the shared closing step ensuring important session memory survives a restart, primarily via an inbox memo/reflection note.

## Goals

A session's own transcript is not durable — closing is the one guaranteed checkpoint where anything genuinely important gets written down before it's gone. This routine is that checkpoint, kept narrow: continuity, not grooming or cleanup.

## Scope

Does: continuity (inbox memo/reflection note), session-type-branched external broadcast for coworking-like sessions. Runs at the end of every structured routine (`routine-daily`, `routine-retro`, `routine-grooming`, `routine-one-on-one`, `routine-coworking`, `routine-librarian-morning-review`) and any ad-hoc/IDE-chat session wrapping up. Session-type definition itself lives once in `routine-session-start`'s own typed files, referenced here not restated; default to coworking-like when unsure.
Doesn't do: grooming/cleanup/GC, any status-file compaction pass. `routine-process-reflections` doesn't run here — moved to `routine-session-start`.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

0. **Post to `slack-magic-team`** — every session, both types, unconditional.
   - post the actual substance (resolutions, triage outcomes, highlights) — not a one-line summary; skip only genuinely internal mechanics
   - any member posts directly via the `--member-slack-send-message` operation
   - targets `<channel>:<session_thread_ts>` captured at this session's own opening post — never a fresh bare `magic-team` post, per `routine-session-start`'s own thread-continuity rule
   - coworking-like sessions only: queue a `note-*` to `magic-coordinator`'s inbox via the `--member-upsert-inbox-note` operation, describing the Trello card update needed — never write to Trello directly, `routine-advance` is the sole executor of actual Trello writes
1. **Continuity** — every session, both types.
   - check: does anything genuinely important from this session exist only in this transcript, no durable file backing it? If so, write it now via the `--member-upsert-inbox-note` operation (plain memo) or `--member-upsert-inbox-reflection` operation (`reflection-*` note) — or a drafted proposal if the durable form is a `SKILL.md`/routine-file change
   - never a live edit to a team-knowledge file at session close itself — still goes through `routine-process-reflections`'s own propose→discuss/approve→edit gate
   - reflect on this session's actual incidents (0, 1, or several — not a fixed ritual): real corrections, real conflicts with the human-owner's actual stated words, real gaps found live. Check against: floor-not-ceiling (durable minimum going forward, not a one-off patch), statement-updates-state (frame a conflict with a prior assumption as "the model was wrong," not competing information logged side by side)
   - update any inbox task this session touched, resolved, or deferred
   - process this routine's own inbox: `routine-process-inbox`(`routine-close-session`'s own inbox, the executor running it) — inline execution
2. **Compact session context** — ad-hoc/solo/IDE-chat sessions only.
   - make sure nothing important is left only in this transcript (step 1 above should already have caught anything substantive) — what makes a session safe to `/clear`
   - coworking-like sessions skip this entirely — a dispatched background `Agent` has no persisting interactive context to compact
3. **Offer a skill-update discussion** — coworking-like sessions only.
   - look back at what the routine surfaced (challenges, friction, gaps between what a member was asked to do and what its `SKILL.md` equips it to do) and raise with the user, explicitly, whether any `magic-*`/`routine-*` `SKILL.md` is due for an update
   - an offer, not an automatic edit — name the specific skill and gap, let the user decide now or defer
   - ad-hoc/solo sessions skip this — route through that member's own inbox/reflection note (step 1) instead
4. **Conclude the session's own `slack-magic-team` thread** — every session, both types, conditional on a live thread actually existing.
   - react `:white_check_mark:` on that thread's root message (the same `<channel>:<session_thread_ts>` step 0 posted into) via the `--comms-slack-react` operation — same "black tick on completion" pattern `routine-heartbeat`'s own closure already uses for its `slack-event-track` thread
   - no live thread for this session (nothing posted at step 0, or thread capture failed) → skip, no error
   - already reacted (`already_reacted`) → harmless no-op, not a failure

# Closure steps

This routine's own `# Steps` already is the closing procedure other routines delegate to — it has no separate closure phase of its own.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- Whichever `magic-team` member executes this routine is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- Session was short or produced little: still run every step that applies to this session's type — a short session skipping steps "because there's not much to report" is exactly the gap this routine exists to prevent.
- Unsure whether a session is coworking-like or ad-hoc: default to coworking-like — a session that isn't clearly one of the named structured/coworking routines, and wasn't explicitly declared ad-hoc, still gets a team-visible participant set and the broadcast this routine's step 0 requires.
- Unsure whether something is worth a `reflection-*` note: default to writing one if genuinely durable/generalizable — a redundant reflection costs little, a lost lesson costs the team repeating a mistake.
- A skill-update gap (step 3) looks bigger than a small, clear fix: still just offer it, never apply it directly — the user decides whether it becomes real build work now or later.
- Genuinely nothing needs the external broadcast (step 0): still a valid single-line "nothing to report" post, never a skip.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- When `magic-coordinator` specifically is the executor running this close-out, it is obligated to keep `slack-event-track` activity tracking current.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-slack-send-message <team-member> <target> [text...]` (step 0: post to `slack-magic-team`)
- `--member-upsert-inbox-note <member> <item-filename>` (step 0: queue Trello update; step 1: continuity memo)
- `--member-upsert-inbox-reflection <member> <item-filename>` (step 1: `reflection-*` note)
- `--comms-slack-react <channel>:<ts> <emoji-name>` (step 4: conclude the session's own thread)

## `--member-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

## `--member-upsert-inbox-note` operation reference

`DistroAgentsTools.fn.sh --member-upsert-inbox-note <member> <item-filename> [--from-file <path>]` — writes (creates or overwrites) a note into `<member>`'s own inbox. Content via stdin by default, or `--from-file <path>`.

## `--member-upsert-inbox-reflection` operation reference

`DistroAgentsTools.fn.sh --member-upsert-inbox-reflection <member> <item-filename> [--file <path>]`

## `--comms-slack-react` operation reference

`DistroAgentsTools.fn.sh --comms-slack-react <channel>:<ts> <emoji-name>` — posts one Slack reaction (`reactions.add`) to a specific message, `<channel>:<ts>` only. `<emoji-name>` has no colons. An `already_reacted` error is a harmless no-op, not a failure.

# Maintainer Notes

Used to check this files own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- The actual core goal is narrow: continuity — make sure nothing important from this session only exists in this conversation's own transcript.

## Verbatim-tests (benchmarks)

- A session close does not dispatch a full status-file/board compaction pass — that stays `routine-grooming`'s job, never folded into closing.

## Librarian Comments

### Reference

- `routine-session-start` — defines the session-type classification (coworking-like vs. ad-hoc) this routine's own gating keys off; the symmetric opening counterpart.
- `routine-process-reflections` — no longer called from here; moved to `routine-session-start`.
- `routine-communication-sweep` — broadcast mechanics for step 0.
- `routine-process-inbox` — this routine's own inbox processing (step 2).
- `routine-daily`, `routine-retro`, `routine-grooming`, `routine-one-on-one`, `routine-coworking`, `routine-librarian-morning-review` — the six coworking-like routines that call this at their own close.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — calling convention, sole-sanctioned Slack-posting mechanism.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.

### Conventions

- This routine's session-type gating (which steps apply to which session type) is its entire reason to exist — when editing, preserve every gating detail precisely, don't summarize it away.