---
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# routine-session-start — the actual procedure

# Summary

Routine-session-start is the symmetric opening counterpart to `routine-close-session` — currency check, learned-lesson memory fold-in, own-inbox processing, for every kind of session.

## Goals

Symmetric opening counterpart to `routine-close-session`: one consistent place, for every kind of session (structured routine or ad-hoc/IDE-chat alike), to do the start-of-work things every session needs — a currency check on the routine file about to run, folding in this member's own accumulated learned-lesson memory, and processing its own inbox.

## Scope

Does: session-type detection (coworking-like vs ad-hoc), shared by both session-start and session-close. Runs at the start of every structured routine (`routine-daily`, `routine-retro`, `routine-grooming`, `routine-one-on-one`, `routine-coworking`, `routine-librarian-morning-review`) — replacing what used to be a bare `routine-prepare-session` call at that same position, its own step 2 below still runs that check — and is also directly callable from a plain IDE-chat session or any other dynamic activity starting up.
Doesn't do: external broadcast itself (`routine-close-session`'s own job).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **Declare this session's type**, per the taxonomy in this file's own Local rules — state plainly, up front (same discipline as `routine-coworking`'s own goal-framing step), which of the two types this session is. Every subsequent step in this routine, and every session-type-gated step in `routine-close-session`, keys off this one declaration — don't re-derive it separately at each gated step.
1a. **If session type is coworking-like, assign `session_transcript_name` now** — required context key, one `transcript-*.md` filename for this session, set once and stable for the whole session; transcript appends are blocked when this key is absent.
1b. **Post to `slack-magic-team` now — this routine's first externally-visible action.** Every activity posts as it happens, no exemptions, any session type; this opening post specifically happens here, immediately after steps 1/1a's declarations — before step 2's currency check, step 3's reflections pass, or step 3a's inbox processing, no exceptions. Content may be minimal at this point (session type + participants known so far + goal if already framed) — completeness is never a reason to delay; a short immediate post beats a complete late one. Any member posts directly via the `--member-slack-send-message` operation.

**Coworking-like sessions only**: this same step also carries the opening Trello update naming participants and the shared goal (already framed by step 1 above, or about to be framed by the calling routine's own step 1), mirroring `routine-close-session`'s closing Trello update. A calling routine may inline the actual posting into whatever early-session dispatch it already makes, rather than treating this as a separately-invoked generic call every time — an opening post happening is what's mandatory, not the exact mechanism used to make it happen.
2. **Run `routine-prepare-session`'s existing steps** — the librarian currency check on the specific routine file this session is about to follow, plus that routine's own inbox processing. Folded in here rather than run as a separate call, so a caller that switches from invoking `routine-prepare-session` directly to invoking this routine loses nothing.
3. **Mandatory: invoke `Skill(routine-process-reflections)` for this session's own project/workspace.** Moved here from `routine-close-session` — human-owner's own words, direct: "This file WILL BE NOT PERSISTENT - Must be encoded in your skill - that is the only part I sync between instances." Running this at session *start* rather than close means a member begins its actual work having already folded in whatever this project/workspace's accumulated `feedback_*.md` lessons say, rather than only catching up on them on the way out — and closes the redundancy this also flagged (this call, `routine-close-session`'s own former continuity check, and its reflect-on-incidents step all overlapping the same "make sure a lesson isn't lost" ground from three different angles).
3a. **Process own inbox**: `routine-process-inbox`(`routine-session-start`'s own inbox, the executor running it) — inline execution (own identity). Not automatic just because this routine spawned — this explicit call is what actually guarantees it happens.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- Whichever `magic-team` member executes this routine is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- `executors: magic-team` is deliberately wide open here — same open posture as `routine-prepare-session`/`routine-close-session`: opening cleanly is a universal need, not something to gate behind a specific role.
- **Session-type taxonomy — defined here, referenced (not re-defined) by `routine-close-session`.** Every session invoking either this routine or `routine-close-session` is one of exactly two types:
  - **Coworking-like / structured-multi-member**: the session is one of the team's named structured routines with a defined participant set and an existing external-reporting obligation — `routine-daily`, `routine-retro`, `routine-grooming`, `routine-one-on-one`, `routine-coworking`, `routine-librarian-morning-review` — or, more generally, several members genuinely working the *same* shared task together (not each on its own separate assignment, which is `routine-daily`'s work-session fan-out — still "coworking-like" for this purpose since it's part of a structured routine, but see `routine-coworking`'s own Goals for the narrower "same task together" sense of the term).
  - **Ad-hoc / solo / IDE-chat**: a single-member dispatch working its own assigned item, a plain IDE-chat UI conversation, or any other dynamic one-off activity that isn't one of the named structured routines above.
- Genuinely unsure which type a session is: default to **ad-hoc** — the same call this makes for context compaction (only meaningful for ad-hoc/IDE-chat sessions). A session that isn't clearly one of the six named structured/coworking routines above is treated as ad-hoc rather than assumed to have a team-visible participant set it doesn't actually have.
- **Standing rule**: every invocation of one of the six named coworking-like routines above is always a proper (sub-)spawned session with its own full `routine-session-start`/`routine-close-session` lifecycle — never an ambiguous "just a step vs. a real spawn" judgment call. It's always a real spawn, it declares its own session type, and it runs session-start/close-session in full.
- **Scope boundary on that standing rule**: it does NOT extend to every invocation of every named `routine-*` skill — only to the six coworking-like routines listed above. Utility/mechanical routines keep their existing, deliberately lightweight execution modes exactly as already documented: `routine-process-inbox` keeps its own explicit inline-(own identity)/spawned-(representing another identity) execution-mode split; `routine-camunda-diagram-sync` keeps its own "skip silently if nothing changed; don't dispatch an agent just to find that out" cheap mtime check.
- **Co-working transcript context rule**: for coworking-like sessions, `session_transcript_name` is mandatory session context. Assign it once at session start (transcript-* filename, stable for the session) and keep it unchanged through close; transcript-append calls are blocked when this context value is missing.
- Not wired into `routine-heartbeat`'s own per-nudge cycle — that loop iterates far more often than the structured routines this routine is meant for.
- `routine-process-reflections` (step 3) turns up nothing to fold in: still run it — do not skip on the assumption "probably nothing new." Same "still run every step" discipline `routine-close-session`'s own Local rules apply to its steps.
- Genuinely nothing to announce (step 1b), because the session's shared goal isn't framed yet: post a short "starting: <participants>, goal TBD" line, rather than skipping the post — same "silence is what created the original visibility gap" reasoning `routine-close-session`'s Local rules apply to its own broadcast step.
- **DistroAgentsTools trust policy**: `DistroAgentsTools.fn.sh` is the team's own tool. Trust it by default day to day — no defensive re-verification of its own correctness on every call. Propose interface changes through the normal idea → interview → proposal → approval pipeline, never as an inline bypass. Re-check a specific call site only when a real incident actually traces back to it.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- When `magic-coordinator` specifically is the executor running this open-out (one of several members who may run this routine), it is obligated to keep `slack-event-track` activity tracking current, same as any other routine where it is a possible executor.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-slack-send-message <team-member> <target> [text...]` (step 1b: opening `slack-magic-team` post; Slack activity-tracking obligation)

## `--member-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

# Maintainer Notes

Used to check this files own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives every session type — structured routine or ad-hoc alike — one consistent place to do start-of-work things, mirroring `routine-close-session` at the opposite end of a session's life.

## Verbatim-tests (benchmarks)

- A session that isn't clearly one of the six named structured/coworking routines defaults to ad-hoc, rather than being assumed to have a team-visible participant set it doesn't actually have.

## Librarian Comments

### Reference

- `routine-close-session` — the symmetric counterpart at the opposite end of a session's life; references this routine's own session-type definition rather than redefining it.
- `routine-prepare-session` — folded in as this routine's own step 2.
- `routine-process-reflections` — invoked mandatorily at step 3, moved here from `routine-close-session`.
- `routine-process-inbox` — this routine's own inbox processing (step 3a).
- `routine-daily`, `routine-retro`, `routine-grooming`, `routine-one-on-one`, `routine-coworking`, `routine-librarian-morning-review` — the six coworking-like routines this routine's own standing "always (sub-)spawned" rule applies to.
- `routine-communication-sweep` — the broadcast-mechanics section step 4's mechanics mirror.
- `routine-camunda-diagram-sync`, `routine-process-inbox` — utility/mechanical routines explicitly out of scope for the "always full spawn" rule.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — `DistroAgentsTools.fn.sh --member-slack-send-message`, the bot-credential mechanism.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.

### Conventions

- This routine owns the session-type definition (coworking-like vs. ad-hoc) that `routine-close-session` references rather than redefines — preserve the full definition, the six named routines list, the "always (sub-)spawned" standing rule, and its scope-check exclusions (`routine-process-inbox`, `routine-camunda-diagram-sync`) precisely. A future edit blurring this into a vague "some sessions are bigger than others" would break `routine-close-session`'s own gating logic, which depends on this exact definition.
- Step 1b's opening broadcast may be inlined into an existing early dispatch, not a rigid separate call — don't let it collapse into "the opening post is optional."
