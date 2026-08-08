---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# routine-retro — the actual procedure

# Summary

Routine-retro is the team's retrospective — how the work itself has been going, drawing on recent work-sprint history, not a status roll call.

## Goals

Team retrospective — the team's own reflection and self-talk on how things have actually been going, not a task-status roll call. Distinct from `routine-daily`: dailies report *what's outstanding*; retro asks *how the work itself has been going*, drawing on recent daily-meeting history rather than repeating it. This exists because a team that only ever reports status never actually improves its own methodology — recurring friction (a routine running too long, a convention nobody follows, a skill boundary that keeps getting straddled) needs a dedicated moment to surface and get turned into concrete fixes, not just felt and re-felt every day without ever being named. Scope also covers recurring problems with retro itself — not just the team's other work.

## Scope

Does: surface recurring friction into concrete fixes, including friction with retro itself. Manually triggered — the human-owner asks for a "retro"/"retrospective." Not currently autonomous (unlike `routine-daily`/`routine-grooming`, `routine-heartbeat` doesn't trigger this on its own day-rhythm yet). Requires a Keep-Alive Console Session already open.
Doesn't do: report what's outstanding (`routine-daily`'s job).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

0. **run-shared-opening-steps**: `routine-session-start` — declares this as a coworking-like/structured-multi-member session, runs its own step 2 currency check (**check-file-currency**), invokes `routine-process-reflections` for this project/workspace, processes own inbox, and posts an opening broadcast to `slack-magic-team`/Trello (coworking-only, applies here).
1. **gather-recent-history**: read `board-processed` `reflection-*` items and any other recent board Items, and recall the last several daily meetings' worth of entries (results, recurring blockers, anything flagged more than once) — raw material for reflection, not something to re-narrate verbatim. The `roster-note` gets its real re-check at grooming cadence, not here.
1a. **process-own-inbox**: run `routine-process-inbox magic-coordinator` — inline execution (own identity). The `reflection-*` notes retained in the inbox rather than promoted to the board (`routine-process-inbox`'s own reflection-promotion rule): step 1's (**gather-recent-history**) `board-processed` sweep does not see them, and retro is where they are due for discussion. Not automatic just because this routine spawned — this explicit call is what actually guarantees it happens.
2. **self-analyse-per-member**: for each permanent member with enough recent history to reflect on, narrate that member doing a real self-analysis before speaking, grounded in four things — its own `.basic.md`/`.armed.md` behavioral descriptions (including whether they still match what it's actually being asked to do lately), relevant past incidents (its own log/inbox reflections, board history), the team's standing rules that apply to it, and its own stated goals — then narrate its first-person self-talk from that grounding: what's felt slow, what's been satisfying to close out, what keeps recurring. From this analysis each member formulates a real improvement proposal of its own — carried into step 4 (which collects it alongside the coordinator's cross-team assessment) and step 5 (same discussion/review as any other retro finding), not a separate deliverable. Introspective and analytical, not status-reporting — skip members with nothing meaningful to reflect on (same escape valve covers a thin self-analysis, not just a thin self-talk).
3. **surface-cross-member-patterns**: after the individual reflections, note anything that showed up in more than one member's self-talk — this is where the coordinator's cross-team view adds something no single member's reflection could.
4. **assess-methodology-failures**: methodology itself — where did a routine, a convention, or a way of working actually fail or fall short this period, and why. Turn real findings into concrete improvement proposals, not vague sentiment. This step also collects each participating member's own step-2 improvement proposal alongside the coordinator's cross-team methodology assessment — both feed the same step-5 discussion, not two separate tracks. An empty result here is fine. Includes retro's own recurring problems, same standard: a concrete proposal, not vague sentiment.
5. **discuss-with-the-user**: a conversation, not a report — pause and let the user react, add their own read, or push back before concluding. This is also where step 4's improvement proposals get reviewed — the user and `magic-librarian` decide together which ones are worth adopting, not something retro finalizes unilaterally.

# Closure steps

1. **Close out**: run `routine-close-session`'s shared closing steps — the skill-update-discussion offer, etc. Retro stays reflection, not action: log step 5's approved improvement proposals into `board-running` as pending items for the *next daily meeting* to actually pick up and apply — members may reflect on a proposal here, but implementation waits for a daily.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-coordinator` (this routine's sole executor) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- No cron or automation without explicit human-owner confirmation.
- Step 5's discussion genuinely pauses for the human-owner's live reaction when run interactively — only the (not-yet-built) autonomous path would defer this. **If autonomous invocation is added later**: step 5 (Discuss with the user) would follow the same pattern already used for `routine-daily`/`routine-grooming` — don't block waiting for a live response, record findings as provisional in a `board-running` `note-*` item (filename: type prefix first, date immediately after, no extra words in between — `note-<date>-<matter>.md`) and flag for confirmation the next time a human is present.
- Retro never implements a proposal during its own closing, however small — a standing, previously-corrected mistake. This covers a member's own step-2 self-analysis proposal too, same as any other step 4/5 finding.
- A cross-member pattern (step 3) looks like it might actually be a genuine architecture or design question, not just a shared operational gripe: flag it for `magic-architect` rather than trying to resolve it as an ordinary retro finding — retro identifies patterns, it does not do structural design itself.
- An improvement proposal from step 4 looks big enough to affect how the whole team works, not a small contained fix: pause and confirm explicitly with the user that this is becoming build work — not something retro quietly escalates into a dispatch on its own.
- Unsure whether a finding belongs in retro at all, vs. grooming/daily: retro is for reflection and methodology, not backlog triage — if it's really about re-prioritizing existing work rather than how the work has been going, note it via the `--member-upsert-inbox-note` operation and defer to `routine-grooming`, instead of stretching retro's own scope to cover it.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- `magic-coordinator` (this routine's sole executor) is obligated to keep `slack-event-track` activity tracking current as the routine actually runs — proactive, as-it-happens posts, not only a summary batched into close-out.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-slack-send-message <team-member> <target> [text...]` (Slack activity-tracking obligation)
- `--member-upsert-inbox-note <member> <item-filename>` (scope-boundary rule: defer a backlog-triage finding to `routine-grooming`)

## `--member-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

## `--member-upsert-inbox-note` operation reference

`DistroAgentsTools.fn.sh --member-upsert-inbox-note <member> <item-filename> [--from-file <path>]` — writes (creates or overwrites) a note into `<member>`'s own inbox. Content via stdin by default, or `--from-file <path>`.

# Maintainer Notes

Used to check this files own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine exists because a team that only ever reports status never actually improves its own methodology — recurring friction needs a dedicated moment to surface and get turned into concrete fixes.

## Verbatim-tests (benchmarks)

- Retro asks how the work itself has been going, not what's outstanding — a session that turns into a task-status roll call has drifted into `routine-daily`'s own territory.

## Librarian Comments

### Reference

- `routine-daily` — the roll-call routine retro is explicitly distinct from, and the destination for retro's own approved improvement proposals.
- `routine-session-start` — shared opening steps (coworking-like session-type branch applies here).
- `routine-close-session` — shared close-out steps.
- `routine-process-inbox` — own-inbox processing.
- `routine-session-start` — its step 2 (**check-file-currency**) is the currency check this routine's own step 0 runs.
- `routine-heartbeat` — carries this routine's "Autonomous invocation" addendum for consistency, not currently invoking it.
- `routine-grooming` — the backlog-triage destination for findings that turn out to be about re-prioritization rather than methodology.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — Keep-Alive Workspace Console Session mechanics.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.
- `magic-coordinator/magic-coordinator.armed.md`'s decide-vs-build checkpoint — governs when a step-4 proposal is big enough to need explicit user confirmation before becoming build work.

### Conventions

- The "retro produces proposals, not actions" rule is a standing, previously-corrected mistake — preserve this distinction precisely, don't let a future synthesis blur it back into "retro implements its own findings."
