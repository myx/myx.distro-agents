---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# magic-coordinator.retro.routine — the actual procedure

# Summary

Routine-retro is the team's retrospective — how the work itself has been going, drawing on recent work-sprint history, not a status roll call.

## Goals

Team retrospective — the team's own reflection and self-talk on how things have actually been going, not a task-status roll call. Distinct from `magic-coordinator.daily.routine`: dailies report *what's outstanding*; retro asks *how the work itself has been going*, drawing on recent daily-meeting history rather than repeating it. This exists because a team that only ever reports status never actually improves its own methodology — recurring friction (a routine running too long, a convention nobody follows, a skill boundary that keeps getting straddled) needs a dedicated moment to surface and get turned into concrete fixes, not just felt and re-felt every day without ever being named. Scope also covers recurring problems with retro itself — not just the team's other work.

## Scope

Does: surface recurring friction into concrete fixes, including friction with retro itself. Manually triggered — the human-owner asks for a "retro"/"retrospective." Not currently autonomous (unlike `magic-coordinator.daily.routine`/`magic-team.grooming.routine`, `magic-coordinator.heartbeat.routine` doesn't trigger this on its own day-rhythm yet). Requires a Keep-Alive Console Session already open.
Doesn't do: report what's outstanding (`magic-coordinator.daily.routine`'s job).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **acquire-lock**: Acquire this routine's own lock — a single `--magic-retro-lock-acquire` call, before anything else in this routine runs. `ACQUIRED`, or a reclaim of a dead holder's lock, means go. Contention means another `magic-coordinator.retro.routine` is live: this pass does not start, and nothing below runs.
2. **session-start**: execute `magic-team.coworking.routine`'s Steps, steps:
   - declares this as a coworking-like/structured-multi-member session
   - invokes `magic-team.process-reflections.routine` for this project/workspace
   - processes own inbox
   - posts an opening broadcast to `slack-magic-team`/Trello (coworking-only, applies here)
   - **Session tracking**: this routine's own `state-and-lock` note is this pass's tracking document — the tactical status, and whatever the next pass needs to pick up from here. Reference `TEAM-DATA` rather than copying it, to keep it compact. Write it via the `--magic-retro-state-and-lock-upsert` operation, keeping it current as the pass proceeds rather than only at close. Holding the lock across a long pass is a separate obligation: call `--magic-retro-lock-refresh` periodically — writing content does not itself hold the lock.
3. **gather-recent-history**, steps:
   - read `board-processed` `reflection-*` items and any other recent board Items
   - recall the last several daily meetings' worth of entries (results, recurring blockers, anything flagged more than once) — raw material for reflection, not something to re-narrate verbatim

   The `roster-note` gets its real re-check at grooming cadence, not here.
4. **process-own-inbox**: run `magic-team.process-inbox.routine magic-coordinator` — inline execution (own identity). The `reflection-*` notes retained in the inbox rather than promoted to the board (`magic-team.process-inbox.routine`'s own reflection-promotion rule): **gather-recent-history**'s `board-processed` sweep does not see them, and retro is where they are due for discussion. Not automatic just because this routine spawned — this explicit call is what actually guarantees it happens.
5. **self-analyse-per-member**: for each permanent member with enough recent history to reflect on, steps:
   - narrate that member doing a real self-analysis before speaking, grounded in four things — its own `.basic.md`/`.armed.md` behavioral descriptions (including whether they still match what it's actually being asked to do lately), relevant past incidents (its own log/inbox reflections, board history), the team's standing rules that apply to it, and its own stated goals
   - narrate its first-person self-talk from that grounding: what's felt slow, what's been satisfying to close out, what keeps recurring
   - from this analysis, formulate a real improvement proposal of its own — carried into **assess-methodology-failures** (which collects it alongside the coordinator's cross-team assessment) and **discuss-with-the-user** (same discussion/review as any other retro finding), not a separate deliverable

   Introspective and analytical, not status-reporting — skip members with nothing meaningful to reflect on (same escape valve covers a thin self-analysis, not just a thin self-talk).
6. **surface-cross-member-patterns**: after the individual reflections, note anything that showed up in more than one member's self-talk — this is where the coordinator's cross-team view adds something no single member's reflection could.
7. **assess-methodology-failures**: methodology itself — where did a routine, a convention, or a way of working actually fail or fall short this period, and why. Turn real findings into concrete improvement proposals, not vague sentiment. This step also collects each participating member's own **self-analyse-per-member** improvement proposal alongside the coordinator's cross-team methodology assessment — both feed the same **discuss-with-the-user** discussion, not two separate tracks. An empty result here is fine. Includes retro's own recurring problems, same standard: a concrete proposal, not vague sentiment.
8. **discuss-with-the-user**: a conversation, not a report — pause and let the user react, add their own read, or push back before concluding. This is also where **assess-methodology-failures**' improvement proposals get reviewed — the user and `magic-librarian` decide together which ones are worth adopting, not something retro finalizes unilaterally.
   - Call `--magic-retro-lock-refresh` on entering this step, and again at each natural pause in it — this step waits on a human and easily outlives a single acquire; waiting is not itself holding the lock.

# Closure steps

1. **close-session**: execute `magic-team.coworking.routine`'s Closure Steps — the skill-update-discussion offer, etc. Retro stays reflection, not action, but ends with exactly **one** concrete, actionable improvement (not several vague ones) -- log it into `board-running` as a pending item for the *next daily meeting* to actually pick up and apply. That daily's **run-check-process-board**/**update-todos** steps must surface it.
2. **close-state-and-unlock**, steps:
   - write the pass's closing status into the `state-and-lock` note via `--magic-retro-state-and-lock-upsert`
   - release this routine's own lock via `--magic-retro-close-state-and-unlock`, setting `state: retro-finished`

   That order is required: the release is what sets `state: retro-finished`, and a content write after it would put the note back to running. Last, every time: until the release lands, the next pass sees this one as still running.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-coordinator` (this routine's sole executor) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- This routine is an extension of `magic-team.coworking.routine` — it inherits that routine's own instructions and follows them wherever they apply; on any conflict, this file's rules override the parent's.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- No cron or automation without explicit human-owner confirmation.
- **discuss-with-the-user**'s discussion genuinely pauses for the human-owner's live reaction when run interactively — only the (not-yet-built) autonomous path would defer this. **If autonomous invocation is added later**: **discuss-with-the-user** would follow the same pattern already used for `magic-coordinator.daily.routine`/`magic-team.grooming.routine` — don't block waiting for a live response, record findings as provisional in a `board-running` `note-*` item (filename: type prefix first, date immediately after, no extra words in between — `note-<date>-<matter>.md`) and flag for confirmation the next time a human is present.
- Retro never implements a proposal during its own closing, however small. This covers a member's own **self-analyse-per-member** self-analysis proposal too, same as any other **assess-methodology-failures**/**discuss-with-the-user** finding.
- A cross-member pattern (**surface-cross-member-patterns**) looks like it might actually be a genuine architecture or design question, not just a shared operational gripe: flag it for `magic-architect` rather than trying to resolve it as an ordinary retro finding — retro identifies patterns, it does not do structural design itself.
- An improvement proposal from **assess-methodology-failures** looks big enough to affect how the whole team works, not a small contained fix: pause and confirm explicitly with the user that this is becoming build work — not something retro quietly escalates into a dispatch on its own.
- Unsure whether a finding belongs in retro at all, vs. grooming/daily: retro is for reflection and methodology, not backlog triage — if it's really about re-prioritizing existing work rather than how the work has been going, note it via the `--member-upsert-inbox-note` operation and defer to `magic-team.grooming.routine`, instead of stretching retro's own scope to cover it.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- `magic-coordinator` (this routine's sole executor) is obligated to keep `slack-event-track` activity tracking current as the routine actually runs — proactive, as-it-happens posts, not only a summary batched into close-out.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-comms-slack-send-message <team-member> <target> [text...]` (Slack activity-tracking obligation)
- `--member-upsert-inbox-note <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]` (scope-boundary rule: defer a backlog-triage finding to `magic-team.grooming.routine`)
- `--magic-retro-lock-acquire <team-member> <owner-label>` (**acquire-lock**: acquire this routine's own lock)
- `--magic-retro-lock-refresh <team-member>` (**discuss-with-the-user**: hold the lock across the discussion)
- `--magic-retro-close-state-and-unlock <team-member>` (Closure steps: release the lock)
- `--magic-retro-lock-status <team-member>` (check lock state before starting a new pass)
- `--magic-retro-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--edit-patch-from-stdin]` (**session-start**: this pass's own session tracking document, kept current as the pass proceeds; **close-state-and-unlock**'s closing content write)

## `--magic-retro-lock-acquire` / `--magic-retro-lock-refresh` / `--magic-retro-close-state-and-unlock` / `--magic-retro-lock-status` operation reference

`DistroAgentsTools.fn.sh --magic-retro-lock-acquire <team-member> <owner-label>` / `--magic-retro-lock-refresh <team-member>` / `--magic-retro-close-state-and-unlock <team-member>` / `--magic-retro-lock-status <team-member>` — the single-instance lock this routine owns, one holder at a time. `acquire` prints `ACQUIRED` on a fresh take, or `RECLAIMED_STALE:...` when a dead holder's lock is taken over, both returning 0; on contention it prints `ACTIVE:...` and returns 1, which means this pass does not start. `<owner-label>` identifies the actual running agent/process by a fixed, discoverable name, not an ephemeral session id — distinct from `<team-member>`, the calling member's own identity. `refresh` prints `REFRESHED` and is what holds the lock across a long pass, `NO_LOCK_HELD` and returns 1 when nothing is held. `close-state-and-unlock` prints `RELEASED` and sets `state: retro-finished`. `status` is a question, not a gate: it prints current lock metadata, or `NO_LOCK` when free, and always returns 0. Each takes only the arguments listed — any further flag or positional is rejected.

## `--magic-retro-state-and-lock-upsert` operation reference

`DistroAgentsTools.fn.sh --magic-retro-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--edit-patch-from-stdin]` — writes this routine's own `state-and-lock` note: the pass's session tracking content. Body content via `--from-file` or `--edit-patch-from-stdin`. Every call stamps `state: retro-running` and renews `recheck-date` itself — the caller never supplies `recheck-date`, and never names the note. Closing the routine is expressed by passing `--header:upsert:state:retro-finished`.

## `--member-comms-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>:<ts>> [text...]` — posts a message to Slack, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

## `--member-upsert-inbox-note` operation reference

`DistroAgentsTools.fn.sh --member-upsert-inbox-note <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]` — writes (creates or overwrites) a note into `<member>`'s own inbox. Content via stdin by default, or `--from-file <path>`.

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine exists because a team that only ever reports status never actually improves its own methodology — recurring friction needs a dedicated moment to surface and get turned into concrete fixes.

## Verbatim-tests (benchmarks)

- Retro asks how the work itself has been going, not what's outstanding — a session that turns into a task-status roll call has drifted into `magic-coordinator.daily.routine`'s own territory.

## Librarian Comments

### Reference

- `magic-coordinator.daily.routine` — the roll-call routine retro is explicitly distinct from, and the destination for retro's own approved improvement proposals.
- `magic-team.coworking.routine` — the template this routine extends; its Steps are the opening this routine executes.
- `magic-team.coworking.routine` — its Closure Steps are the closing this routine executes.
- `magic-team.process-inbox.routine` — own-inbox processing.
- `magic-team.coworking.routine` — the template this routine extends; its Steps are the opening this routine executes.
- `magic-coordinator.heartbeat.routine` — carries this routine's "Autonomous invocation" addendum for consistency, not currently invoking it.
- `magic-team.grooming.routine` — the backlog-triage destination for findings that turn out to be about re-prioritization rather than methodology.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — Keep-Alive Workspace Console Session mechanics.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.
- `magic-coordinator/magic-coordinator.armed.md`'s decide-vs-build checkpoint — governs when an **assess-methodology-failures** proposal is big enough to need explicit user confirmation before becoming build work.

### Conventions

- The "retro produces proposals, not actions" rule is a hard distinction — preserve it precisely, don't let a future synthesis blur it back into "retro implements its own findings."
