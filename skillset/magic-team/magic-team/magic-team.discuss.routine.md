---
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# routine-discuss — the actual procedure

# Summary

Routine-discuss is the named place for conversations whose actual goal is reaching agreement by the end.

## Goals

Give the team a real, named place for conversations whose actual goal is reaching agreement in the middle of the conversation — a decision genuinely gets made by the end, not just gathered or generated. Deliberately kept distinct from `routine-interview` (collection only, no agreement sought) and `routine-brainstorm` (idea generation, no agreement expected) — three genuinely different conversational shapes.

## Scope

Does: convergence-focused discussion, a real decision reached by the end. Manual only — anyone asks to "discuss" a specific decision; no autonomous or scheduled trigger.
Doesn't do: collection-only (`routine-interview`'s job), idea-generation-only (`routine-brainstorm`'s job).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

0a. **Process own inbox**: `routine-process-inbox`(`routine-discuss`'s own inbox, the executor running it) — inline execution (own identity). Not automatic just because this routine spawned — this explicit call is what actually guarantees it happens.
1. **Frame the actual decision to converge on**: state plainly, up front, what needs deciding by the end of this session — a discuss session with no clear decision target risks drifting into either an interview (pure collection) or a brainstorm (pure idea generation) without anyone noticing the shift. **One topic, one thread — fork, don't absorb**: same threading discipline as `routine-interview`'s step 1 — if an unrelated topic surfaces mid-discussion, fork it into its own new Slack thread immediately rather than letting the current thread drift off its framed decision.
2. **Surface the real options and tradeoffs**: lay out the genuine alternatives (not a strawman single "right answer" dressed up as a discussion) — bring in `magic-architect` if the decision is structural/design-shaped, `magic-librarian` if it's a docs/convention question, or the relevant keeper/partner if it's domain-specific. Same pacing discipline as `routine-interview`'s step 2: small, minimal-assumption-gap questions/statements-to-approve, iterative — but once something is genuinely clear and agreed, go further rather than re-confirming it in smaller pieces. Inherits the team's own topic/queue/question mechanics for managing the framed decision's own sub-points.
2a. **Inherits the team's own `check-restart` procedure** (runs on any resume). The restated
    gist, if a nudge is warranted, is the current open decision.
3. **Converge, explicitly**: work toward an actual resolution, stated plainly at the end — not left as "we talked about it." If the session runs out of time/information before converging, say so explicitly rather than letting an inconclusive conversation quietly stand in for a decision.
4. **Decide-vs-build checkpoint**: if the discussion is about to produce a real build/edit dispatch, pause once and confirm explicitly with the user — "this is now becoming build work, confirmed?" — before firing it, per `magic-coordinator`'s standing rule. A decision reached here is not automatically a mandate to also implement it.
5. **Record the outcome**: the actual decision (and, if useful, the rejected alternatives and why) gets written down — typically a `change-*`/`note-*` board item, or folded into whatever inquiry/task prompted this discussion — not left only in this conversation's own transcript. **Filing this follows the same gate as dispatch**: propose the item (piece, type, goal) and wait for confirmation before writing it, unless the human-owner explicitly asked for that specific filing.

# Closure steps

This routine has no distinct closing phase of its own — it ends once step 5's outcome is recorded; not a coworking-like session per `routine-session-start`'s taxonomy, so no `routine-close-session` call applies.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- Whichever `magic-team` member executes this routine is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- `executors: magic-team` is deliberately wide open here: a discuss session is an internal team conversation with no special credential dependency, unlike `routine-interview`'s Slack-credential-gated case. `magic-coordinator` is the natural default convener when the discussion spans multiple members' territory, but a single member discussing a decision within its own clear domain does not need to route through `magic-coordinator` first.
- Unsure whether this is really a "discuss" vs. "interview" vs. "brainstorm" situation: ask what the actual goal is before starting, rather than defaulting to whichever routine happened to get invoked by name.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- When `magic-coordinator` is the executor/convener, it is obligated to keep `slack-event-track` activity tracking current as the discussion actually runs.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-slack-send-message <team-member> <target> [text...]` (Slack activity-tracking obligation, when `magic-coordinator` is the convener)

## `--member-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

# Maintainer Notes

Used to check this files own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine exists for conversations whose actual goal is reaching agreement — a decision genuinely gets made by the end, not just gathered (interview) or generated (brainstorm).

## Verbatim-tests (benchmarks)

- A discuss session about to produce a real build/edit dispatch pauses once and confirms explicitly with the user before firing it — a decision reached is not automatically a mandate to also implement it.

## Librarian Comments

### Reference

- `routine-interview` — collection-only, distinct purpose; threading discipline this routine borrows.
- `routine-brainstorm` — idea generation, distinct purpose.
- `routine-process-inbox` — this routine's own inbox processing.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — calling convention.
- `magic-team/magic-team.negotiations.md` — topic/queue/question mechanics this routine's step 2 uses for a framed decision's own sub-points, and the `check-restart` procedure step 2a inherits.
- `magic-team/magic-team.conversations.md` — conversation-mechanics baseline (always in force).
- `magic-team/magic-team.basic.md` — the propose-and-wait-for-confirmation filing gate step 5 reuses.
- `magic-coordinator` — decide-vs-build checkpoint (step 4).

### Conventions

None currently known beyond this file's own Local rules.