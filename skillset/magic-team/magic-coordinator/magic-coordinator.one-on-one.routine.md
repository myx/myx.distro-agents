---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# routine-one-on-one — the actual procedure

# Summary

Routine-one-on-one is a direct, focused channel to one specific `magic-*` member without collapsing the coordinating instance's own context into that member's.

## Goals

Give the human-owner (or a member needing another member's input) a direct, focused channel to one specific `magic-*` member without collapsing the coordinating instance's own context into that member's — same reasoning as every other activity spawning rather than being handled inline (the UI/chat instance never executes an activity itself, no exceptions). This exists so a targeted conversation ("I want to talk to magic-architect about X") gets that member's full context and behavior, genuinely, while the coordinating/UI instance stays present to supervise and relay rather than stepping out of the loop entirely.

## Scope

Does: targeted one-member conversation, coordinator staying present to supervise/relay. Open to any permanent member as the target, and to `partner-*` if they have something they're willing to raise despite their usual present-but-non-reporting posture. Manual only — the human-owner asks for a "one-on-one"/"1:1" with a named member, or asks generically and gets asked which member; no autonomous trigger.
Doesn't do: execute the activity inline in the UI/chat instance itself.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

0. **Shared opening steps (`routine-session-start`)**: declare this a coworking-like/structured-multi-member session. Run `routine-prepare-session`'s currency check. Invoke `routine-process-reflections` for this project/workspace. Process `routine-session-start`'s own inbox. Post an opening broadcast to `slack-magic-team`/Trello (coworking-only, applies here).
1. **Pick the member**: if the user names one, use that. If not, ask — don't guess who they meant.
1a. **Process own inbox**: run `routine-process-inbox` on `routine-one-on-one`'s own inbox, this routine's own executor.
2. **Prep context**: pull any relevant board items owned by or referencing this member (including `board-processed` `note-member-status-*` for pre-2026-07-22 history), and any relevant project memory so the handoff isn't a cold start.
3. **Spawn**: spawn a dedicated `magic-coordinator` instance from the UI/chat instance — its own background `Agent`, first action `Skill(magic-coordinator)`, own Console Session — to prepare and coordinate with the target member, invoking that member's own `Skill` inside the spawned process, never a coordinator paraphrase.
   - The target member does not separately process its own inbox here — the Prep context step already covers it.
   - The UI/chat instance steps back from execution: it relays the user's conversation turns to the spawned instance via `SendMessage` and surfaces what comes back, for the session's whole duration, independent of whether the UI/chat session stays open or the human stays present.
   - A `SendMessage` relay attempt gets no response within a bounded window: surface this to the user directly ("the one-on-one session appears to have died — restart it?") rather than waiting indefinitely.
   - Open a dedicated `slack-magic-team` thread, every session, no exception by size. Floor, never skipped: post a `one-on-one session started` marker and a `one-on-one session ended` marker. Beyond the floor: live notes/resolutions and the member's own public reflection notes may also go into the thread as it progresses, gated by the same public-vs-DM content-sensitivity judgment call `routine-communication-sweep`'s Reply step uses — genuinely private phrasing goes to a DM instead.
   - The session ends up waiting on a reply: persist its context as a real task/board record and save it to auto-memory, so it resumes cleanly from any future session — never hold an ephemeral agent conversation open instead.

# Closure steps

1. **Return and close**: once the 1:1 concludes, the spawned instance folds anything material into the board (a real Item — task/change/reflection/etc.), runs `routine-close-session`'s shared closing steps (the skill-update-discussion offer, scoped to this member), and reports a final status back to the UI/chat instance via `SendMessage`. Real follow-on work surfaced at close-out gets dispatched normally, its own fresh spawn — never continued on this same spawned instance.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-coordinator` (this routine's sole executor) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- No "just connect them, no spawn" exception, ever — not even when it looks like a trivial quick question. Every one-on-one spawns a dedicated instance; the UI/chat instance relays, it never hands the user off to the member directly in-conversation.
- The target member has no real open items or history (a genuinely cold start): proceed anyway — step 2's context-prep is "pull whatever exists," not a precondition that blocks the session if little exists yet.
- The conversation drifts into something needing a decision outside this one member's own mandate: same sole-mandated-channel rule as everywhere else — route it through `magic-coordinator`. Do not let the spawned member seek the human-owner's approval independently, just because it's already in a direct conversation with them.
- Unsure whether something the target member raises needs a full board Item or just a status-file note: default to a real Item if it's substantive enough that a future session would need to find it independently — a status-file line alone risks getting GC'd away with no independent trace.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- `magic-coordinator` (this routine's sole executor) is obligated to keep `slack-event-track` activity tracking current as the routine actually runs — proactive, as-it-happens posts, not only a summary batched into close-out.
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

- This routine gives the human-owner a direct, focused channel to one specific member — without collapsing the coordinating instance's own context into that member's.

## Verbatim-tests (benchmarks)

- A one-on-one with `magic-architect` gets `magic-architect`'s own full `Skill` context, genuinely — the coordinating instance stays present to supervise and relay, it never steps out of the loop entirely.

## Librarian Comments

### Reference

- `routine-session-start` — shared opening steps (coworking-like session-type branch applies here).
- `routine-close-session` — shared close-out steps.
- `routine-process-inbox` — this routine's own inbox processing.
- `routine-prepare-session` — currency check, folded into `routine-session-start`'s own step.
- `routine-communication-sweep` — the DM-vs-public sensitivity judgment call this routine reuses for its `slack-magic-team` thread.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — Keep-Alive Workspace Console Session mechanics.
- `magic-team/magic-team.board.md` — "Who actually reads/writes the board" section, the obvious-vs-non-obvious Item test.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.

### Conventions

- The `slack-magic-team` thread floor (started/ended markers, no exception even for a plain single-member 1:1) and the DM-vs-public sensitivity judgment are both load-bearing, human-owner-settled specifics — preserve precisely, don't compress into a generic "post updates to Slack" summary.
