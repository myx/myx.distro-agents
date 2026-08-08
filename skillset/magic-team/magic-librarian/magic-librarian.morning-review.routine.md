---
executors: magic-coordinator, magic-librarian
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# routine-librarian-morning-review — the actual procedure

# Summary

Routine-librarian-morning-review is the once-per-workday joint `magic-coordinator`+`magic-librarian` checkpoint catching board state-model drift, not ordinary content staleness.

## Goals

`magic-coordinator` owns and modifies the board continuously, all day, on its own authority. This session is the one deliberate checkpoint where `magic-librarian` joins it — jointly, coordinator leading — rather than coordinator working the board alone all week with nobody else's eyes on it. Its real purpose isn't re-confirming ordinary content staleness (that's `magic-librarian`'s own daily self-sufficiency audit) — it's catching a more structural class of problem: does the board's own *state model* still match what it's supposed to represent, and do claims made in one file actually still hold against another file's real current content. Not a separate audit `magic-librarian` runs solo against the board; if librarian finds something worth changing outside this session, that's still coordinator's call to fold in or defer, same as any other dispatch.

## Scope

Does: catch board *state-model* drift and cross-file consistency gaps — not ordinary content staleness. Spawned as a full sub-session from `routine-daily`'s own step 0, first-today only — a background `Agent` dispatch (`Skill(magic-librarian)` first, default goal = this routine's own Goals), waited on to completion, running its own `routine-session-start`/`routine-close-session` per the session-type framework.
Doesn't do: the deep team self-sufficiency audit `magic-librarian`'s own `magic-librarian.armed.md` (`team-self-sufficiency-audit` procedure) already runs as a normal daily task across every `magic-*` skill directory's formal docs — that's broader (currency/consistency/self-sufficiency/clarity across the whole team, unconditional, every day) and doesn't specifically center on the board.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

0a. **Run `routine-session-start`'s shared opening steps**: declares itself coworking-like/structured-multi-member (`magic-coordinator` + `magic-librarian` jointly), runs `routine-prepare-session`'s currency check, invokes `routine-process-reflections` for this session's own project/workspace, processes own inbox, and posts an opening broadcast to `slack-magic-team`/Trello.
1. **Read the board's current shape** — `board-running`/`board-blocked`/`board-parked`/`board-processed`/`board-archived`/`board-retained`, plus the `heartbeat-state-note`, read via the `--magic-heartbeat-state-read` operation, for comms-platform state not yet reflected there.
1a. **Process own inbox**: run `routine-process-inbox magic-coordinator` (the confirmed default executor for this joint-executor routine) — inline execution (own identity). Board-state notes filed there since the last pass — the claims step 2 checks the board's own state model against. Not automatic just because this routine spawned — this explicit call is what actually guarantees it happens.
2. **Check for state-shape drift**, not just content drift — e.g. `blocked/` and `parked/` being silently collapsed into `running/`/`archived/`, losing the distinction between "stalled on something external" and "deliberately deferred by choice." Not just "is this file's *content* current" but "does the *model itself* still match what it's supposed to represent."

   **Content-hygiene pass, folded into this same step**: any skill-folder file that defines a routine, machinery, team dynamic, or process flow — `SKILL.md` and its typed siblings, shared team docs — touched during this session gets checked for accreted dated/historical narration ("Added on DATE," "CORRECTED —," incident-quote framing standing in for a plain rule). Where found: analyze and load the actual current context, verify nothing actually-active is lost, then rewrite as firm, present-tense current content — not a history of edits. Log files (a keeper's own `processed/` entries, board Items, inbox items, the `heartbeat-state-note`) are exempt — their whole point is being a dated record. Full statement of this standard: `magic-librarian`'s own "Skill-folder content hygiene" content.
3. **Re-check `blocked/` and `parked/` items specifically** for whether their condition has changed — per the board's own definitions, this doesn't have to happen at every grooming pass, but this session is a good light-touch moment for it.
4. **Cross-file consistency**, not just in-file cleanup — a status claim in one file against the actual current content of another. Budget explicit attention for this, not just a same-file dedupe pass.
5. **GC-adjacent, but not GC itself** — `board-processed` retention/GC is folded into `routine-heartbeat`'s post-sweep inbox-processing sub-step, not this session's job. This session can flag a `processed/` item that looks like it should already be gone, but doesn't do the deletion itself.

# Closure steps

1. **Close via `routine-close-session`'s shared steps** — this is a coworking-like session (see step 0a above), so its continuity step, `slack-magic-team`/Trello closing broadcast, and skill-update-discussion offer all apply; context compaction does not (a spawned sub-session has no persisting interactive context to compact — it simply exits once its report is sent, back to `routine-daily`). `routine-process-reflections` already ran at step 0a's opening, not here.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-coordinator` and `magic-librarian` (this routine's joint executors) are permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- Never inspect the credential store directly — only through `DistroAgentsTools.fn.sh`'s own config resolution.
- One documented mechanism failing once is a stop-and-ask signal, not a puzzle to solve alone.
- A state-shape drift is found (for example, two states silently collapsed into one): treat this as higher priority than ordinary content staleness — fix the model gap itself, not just the one instance of it, since a model-level gap likely produced more than one misclassified item.
- A cross-file inconsistency is found, where it's unclear which file is actually correct: do not silently pick a winner — surface the conflict and resolve it explicitly.
- A `blocked/`/`parked/` item's condition looks like it may have changed, but isn't certain: a light-touch re-check is enough here — flag it for a real decision at the next `routine-grooming` pass, rather than resolving the transition unilaterally in this session.
- Something surfaces that isn't board-specific: pass it to `magic-librarian` via the `post-inquiry` procedure, for its own regular daily audit, rather than fixing it inline here.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- `magic-coordinator` is part of this routine's joint executor set — while acting as executor here, it is obligated to keep `slack-event-track` activity tracking current as the session actually runs, not only via the closure step's close-out.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-heartbeat-state-read <team-member>` (step 1: read the `heartbeat-state-note`'s comms-platform state)
- `--member-slack-send-message <team-member> <target> [text...]` (Slack activity-tracking obligation)
- `--member-upsert-member-inquiry <member> <item-filename>` (non-board-specific findings, passed to `magic-librarian`'s own daily audit)

## `--magic-heartbeat-state-read` operation reference

`DistroAgentsTools.fn.sh --magic-heartbeat-state-read <team-member>` — read-only: prints the whole `heartbeat-state-note` on stdout, verbatim. Prints `NO_STATE` and returns 0 when nothing is stored yet — a normal outcome, not an error. `<team-member>` is the only argument.

## `--member-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

## `--member-upsert-member-inquiry` operation reference

Passes an inquiry along to a specific named member's own inbox — same argument shape and file-writing mechanics as the `--member-upsert-inbox-note` operation (in fact self-recurses directly into it), kept as its own distinctly-named op because the two represent semantically distinct fallback cases ("note it for later" vs. "pass it to another member") even though they currently resolve to the identical mechanism.

# Maintainer Notes

Used to check this files own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This session's real purpose is catching structural drift — does the board's own state model still match what it's supposed to represent, and do claims in one file still hold against another file's real current content.

## Verbatim-tests (benchmarks)

- This session has exactly one responsibility — the board-review session described in its own Goals section, not two.

## Librarian Comments

### Reference

- `routine-daily` — the caller that spawns this routine at its own step 0.
- `routine-session-start` / `routine-close-session` — shared opening/closing steps.
- `routine-process-inbox` — own-inbox processing.
- `magic-team/magic-team.board.md` — the board's own state model this routine checks for drift.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — Keep-Alive Workspace Console Session mechanics, calling convention, sole-sanctioned Slack-posting mechanism.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.

### Conventions

None currently known beyond this file's own Local rules.
