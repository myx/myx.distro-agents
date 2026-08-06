---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# routine-advance — the actual procedure

# Summary

Routine-advance is a lightweight, every-iteration mechanical reconciliation between the board's recorded state and reality — closes the gap between full daily/grooming cycles — plus the board's own dependency-ordering recompute (part of `check-process-board`), bounded to once a day or on direct request.

## Goals

The board isn't trustworthy between daily/grooming cycles — sessions die mid-work, dispatches go stale, approvals land continuously, not on a weekly schedule. This routine runs every main-loop iteration and executes only already-decided moves, never new judgment — what makes it safe to run unattended. Same logic covers stalled spawned work (nudge, report) and deferred actions (Slack reactions, Trello updates) once their conditions are actually met. One bounded exception, inside `check-process-board`'s own dependency-recompute step: recording a dependency edge is never a risky call, since an uncertain one is flagged rather than forced — reasoning worked out ad hoc in a chat reply would otherwise evaporate the moment the conversation moves on, with nowhere to live.

**Naming note**: "Advance" names what this routine actually does: bringing the board's *recorded* state back into alignment with what's *actually* true, not re-litigating priorities or scope.

## Scope

**In scope**, every invocation:
- `board-running` — every item, every pass, including its own in-place testing round; no separate `board/testing/` folder.
- `board-backlog` and `board-pending` — every item, every pass: mechanical `board-backlog`→`board-pending`→`board-running` moves, readiness-flagging only — not a full re-triage.
- `board-parked` and `board-blocked`, narrowly — only items carrying a `recheck-date` whose date has arrived (or, for `board-blocked`, an early-fire per `check-process-board`'s **board-reassess-parked-blocked**).
- `magic-coordinator`'s own inbox, narrowly — only `note-2026-08-05-pending-slack-reaction.md`/`note-2026-08-05-pending-trello-update.md`-shaped records (used in `check-pending-comms-actions`).
- Dependency-graph recomputation (`blocks:`/`blocked-by:` edges and ordering) — bounded, not every pass (`check-process-board`'s **board-recompute-dependencies**).

**`recheck-date`/`condition` convention**, on any item entering `board-parked`/`board-blocked`:
- set at the moment it's parked/blocked, by whoever does that triage
- extended by `check-process-board`'s **board-reassess-parked-blocked** whenever it spins off an inquiry job instead of resolving inline
- no `recheck-date` recorded → never triggers that step, falls to `routine-grooming`'s own slower cadence

**Explicitly out of scope** (left to `routine-grooming`'s own cadence):
- `board-blocked`/`board-parked`'s active-pursuit re-check — judgment-heavy, belongs to grooming's cadence. Actively resolving blockers stays excluded here. `check-execute-board`'s restart/nudge work IS in scope — not blocker-resolution, don't conflate the two.
- RICE scoring, any of it.
- Per-item triage verbs (keep/defer/reassign/split/drop) beyond "apply an already-decided move" and "redispatch an already-prescribed testing round".
- Board/file state-model drift hunting — `routine-librarian-morning-review`'s own job, once-per-workday.
- The actual "go" decision itself — `approved-by`/`approved-at`, or deciding human-owner-level approval is needed — is grooming's/the authority group's/the human-owner's call, never this routine's; this routine only acts once one of those two facts is already recorded (`check-process-board`'s **board-mechanical-moves**).
- Trello-board-content review/grooming (reading/assessing existing cards) — distinct from `check-pending-comms-actions`'s narrow, mechanical execution of an already-queued Trello write, which IS in scope.
- Google Drive/Sheets.

**No-blanket-defer rule for `board-running` follow-up**:
- "Judgment-heavy" exclusion applies to blocker-resolution triage (`board-blocked`/`board-parked`) only.
- It does not apply to `check-execute-board`'s own running-item continuation loop.
- Every `board-running` item must receive one concrete per-pass outcome, every pass: `nudged`, `respawned`, `redispatched`, `flagged-once`, or `no-action-with-explicit-reason`.
- A pass-level summary like "deferred for later" is invalid for `board-running` as a class.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

0. **advance-process-inbox**: Run `routine-process-inbox` on `routine-advance`'s own inbox, `magic-coordinator` as executor.
1. **advance-read-board-state**: Call the `--magic-advance-input-scan` operation.
2. **advance-run-process-board**: Run the `check-process-board` procedure (`magic-coordinator.armed.md`) against this pass's own read.
3. **advance-run-execute-board**: Run the `check-execute-board` procedure (below) against this pass's own read.
4. **advance-trigger-daily**: Trigger `routine-daily`'s later-today flow, once per workday, if due and not yet spawned.
   - condition: `today_stage` (from the `heartbeat-state-note`) indicates weekday + first-today `routine-grooming` already done + later-today flow not yet spawned today
   - action: spawn it as its own independent co-working session — `SPAWN-REQUEST`, fire-and-forget
   - never: inline-drive it step by step across multiple `next-iteration`s
   - never: re-spawn a duplicate for the same workday, or wait for it to report back
5. **advance-report**: Post `check-execute-board`'s own findings (redispatches performed, interview threads opened/continued) to `slack-event-track` via `--member-slack-send-message` (target `event-track`).

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines - not visible outside this file.

## `check-execute-board` procedure

All work on a board-item's own task — spawned or inline; continuation or initial launch. Callable only from `routine-advance`.

### Starting never-started `board-pending` items

Process all `board-pending` items each pass — some, all, or none started. Not a restart of already-dispatched work (below).

- Detect `board-pending` items that should start. Spawn, move to `board-running` — or it's an error. Never continue/restart an already-started dispatch.
- Candidate set: `board-pending`, approved, no active dispatch note.
  - Carries `restart-session:` → needs a coworking-session spawn: conflict gate + spawn steps below apply.
  - No `restart-session:` → basic task: start now, move to `board-running` via `--magic-advance-to-running`. No conflict gate, no spawn.
- Required header on a `restart-session:` candidate: `recheck-date`. Missing → set to now first.
- Conflict gate, any one dimension conflicting keeps the item in `board-pending`:
  - Package/topic overlap with a currently running job.
  - Resource contention: current MCP/machine load and concurrent complexity make a new start unsafe (no fixed max-job count; small non-intersecting no-console tasks pass).
  - Document-lock contention: documents the candidate needs are actively locked/edited by another live session.
- Handling:
  - Clear conflict evidence → keep in `board-pending`, note it, advance `recheck-date`.
  - Ambiguous evidence → ask via `AskUserQuestion` — conflict dimension, observed signal, two options (`treat as conflict` / `allow start now`).
- Start policy, non-conflicting `restart-session:` candidates:
  - Spawn at most one per pass, via `spawn-one-dispatch`, move exactly that one item to `board-running`.
  - Multiple equally ready → pick via `AskUserQuestion`, single choice list of candidate item names.
  - One item per spawned session; never batch multiple board-items into one spawned session.
  - Exception: `routine-daily`'s standing work-sessions take continuous task feed as each finishes.
- Repeated conflicts: item stays `board-pending`, re-checks on `recheck-date` indefinitely — no auto-escalation here.
- Before spawning: one last `AskUserQuestion` confirmation (`start this co-working session now?`), `yes`/`no`.
- **Autonomous invocation** (unattended, via `routine-heartbeat`): skip all three interactive prompts above. Ambiguous conflict evidence defaults to `treat as conflict`. No unattended coworking-session starts at all — leave every `restart-session:` candidate in `board-pending` for a human-present pass. Basic non-spawn tasks still start normally.
- Sole starter of never-started `board-pending` items: another place may call `spawn-one-dispatch` directly on its own instruction, but an unrequested pending dispatch only starts here.

### Continuing already-dispatched `board-running` items

Continue an already-dispatched `board-running` item. Never a first-time start (see above). Team-wide name for this mechanism: `check-restart` (see `magic-coordinator.armed.md` Terminology).

**General mechanism, every `board-running` item, every pass**:
- `session-id` set: a session is already working this item.
  - nudge it with this pass's own findings/updates, every time
  - never spawn a second session for this same item
  - failed nudge → treat as if `session-id` absent, continue below
- `session-id` absent:
  - `restart-session: <team-member> [<team-member>...]` present → spawn a coworking session (`magic-coordinator` + the named member(s)) via `spawn-one-dispatch`, passing the corresponding routine, document name, context
    - set `recheck-date` to now + 7min (jittered ±2min) and `session-id` to the new session's identifier, via `--magic-advance-to-running <team-member> <item-filename> --from-state:running --header:upsert:recheck-date:<value> --header:upsert:session-id:<value>` (same-state patch, existing content preserved)
  - `restart-session:` absent → execute the corresponding routine inline instead

**Per-pass completion requirement**:
- For each `board-running` item, finish the pass with one explicit outcome record from this procedure (`nudged` / `respawned` / `redispatched` / `flagged-once` / `no-action-with-explicit-reason`).
- "No action" is valid only with an explicit reason tied to current signals (e.g. `recheck-date` not due, unresolved-dispatch age below stale threshold, no relevant updates this pass).
- "Deferred" without one of these item-level outcomes is invalid.

**Staleness inputs feeding the mechanism above**:
- Console-session-backed work: for any in-scope item naming/depending on a `DistroAgentsTools` workspace console session, run `--list-consoles`, cross-reference. Console expected but gone → flag/report it; do not autonomously restart the console.
- Agent/Task-dispatch-backed work: for any `board-running` item recording an unresolved dispatch note, compute how long unresolved. Treat "unresolved past ~5 main-loop iterations or ~1 hour, whichever comes first" as the staleness signal.
  - Item's current state already prescribes a specific, safe, mechanical next step (e.g. a stale in-place testing round: dispatch a fresh `magic-tester` round): dispatch, record the new dispatch (id/time), report the redispatch once.
  - Otherwise: flag and report once. Escalate-once — don't re-flag the identical stale dispatch every pass; wait for a human/grooming response.
- For each `board-running` item confirmed alive above: check whether anything this pass did is relevant to that item.
  - Relevant → relay via that process's own live channel: `--send-console` (command-only) for console-session-backed work, `SendMessage` for Agent/Task-dispatch-backed work.
  - Not relevant → skip.

**Restart-session spawn concurrency**:
- At most two restart-session-driven coworking sessions per pass.
- Multiple qualifying items (`session-id` absent, `restart-session:` present) same pass → spawn up to two, leave the rest.
- Never batch multiple items into one spawned session.
- Selecting which ones:
  - Human present in `harness-session`-terminal → `AskUserQuestion`, single choice list of candidate item names; repeat once more if a second spawn is still available.
  - **Autonomous invocation**, no human present (`headless`-session): oldest `date`/`owner-session-since` first, then next-oldest, up to two — spawn without waiting (already `approved-by`/`approved-at`, no fresh judgment needed), then name what was started in this pass's own threaded human-owner DM (below), same thread as the per-type-checks report — never a second, separate post.

### Per-`board-running`-item task rules, by filename prefix

Apply these per-`board-running`-item task rules, by filename prefix. State-only half of the same prefixes: `check-process-board` (`magic-coordinator.armed.md`).

- `approval-*` / `approve-*`: not resolved, `recheck-date` due → re-ask via `source-slack-channel`/`source-slack-ts` or the `--member-slack-send-message` operation to human-owner; extend `recheck-date`.
- `interview-*` / `talk-*`: execute `routine-interview` on the board-item as context document — the routine owns all its own state changes, `recheck-date` setting, re-asking.
- `inquiry-*`: `recheck-date` due, no reply → re-ask via `source-slack-channel`/`source-slack-ts` or the `--member-slack-send-message` operation; extend `recheck-date`. Otherwise → no action this pass.
- `task-*` / `project-*` / `epic-*`: apply the console-session/Agent-dispatch stale-check above.
- `proposal-*`: `recheck-date` due → re-ask.
- `dispatch-*`: `session-id` set → nudge per the general mechanism above; append the report-back as a new dated log entry, rewrite via `--write-board-item running <item-filename>`.
- `change-*`: (placeholder) not yet defined.
- `warning-*`: (placeholder) not yet defined.
- `note-*` / `reflection-*` / `transcript-*`: not expected in `board-running` → flag for `routine-grooming`.

After all per-type checks: send one Slack DM to human-owner naming every item that stayed `board-running` with `recheck-date` untouched this pass (across this procedure's own pass and `check-process-board`'s already-run pass), plus any autonomous-invocation restart-session spawns from this same pass (above) — at most once per `routine-advance` run, not per item.

The same DM includes a compact `board-running` outcome count for this pass (`nudged`/`respawned`/`redispatched`/`flagged-once`/`no-action-with-explicit-reason`) so missing follow-up is visible immediately.

**Thread continuity**: read `human_owner_broadcast_thread_ts`/`human_owner_broadcast_thread_date` from the `heartbeat-state-note` first. Date matches today's real date → post this DM as a threaded reply, target `<channel>:<ts>` using that stored value, never the bare `human-owner` keyword. No match (absent, or a stale prior day) → post with the bare `human-owner` target as today's first such DM, capture `channel`/`ts` from this call's own JSON response, and write them back via `--magic-heartbeat-state-upsert` so every later `next-iteration` this same day threads into it instead of starting fresh.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-coordinator` (this routine's sole executor) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Every real file read/write and communications API call this routine makes (including `check-process-board`'s own `--react-slack` calls) is its own direct `lib/execShStdin` call — no Keep-Alive Console Session assumed or required, per `magic-team.armed.md`'s process-flow rule.
- Never resolves an open design/judgment question surfaced by an investigation subtask — flags it for `routine-grooming`/`magic-architect`.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal.
- `magic-coordinator` (this routine's sole executor) is obligated to keep `slack-event-track` activity tracking current as things are found, not batch it artificially.
- No separate close-out step. This routine is invoked inline, mid-iteration, from `routine-heartbeat`; that iteration's own session close closes the work.
- **advance-report** never repeats `check-process-board`'s own **board-report** — that step already covers this same pass's board-state findings.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-advance-input-scan <team-member>` (step 1: read the in-scope board state; also `check-process-board`'s own dependency-recompute step, on the same already-loaded read)
- `--magic-advance-to-running <team-member> <item-filename> --from-state:<state> [--header:...]...` (`check-execute-board`'s own never-started-`board-pending`-items step: basic-task start)
- `--member-slack-send-message <team-member> <target> [text...]` (step 5: post the `event-track` report trace; also `check-execute-board`'s own per-type re-ask rules)

## `--magic-advance-input-scan` operation reference

`DistroAgentsTools.fn.sh --magic-advance-input-scan <team-member>` — read-only scan giving all board job-state information relevant to this routine, every board-item type, every frontmatter field. `<team-member>` is the only argument; the scanned state list is fixed, with no caller-facing override.

## `--magic-advance-to-running` operation reference

`DistroAgentsTools.fn.sh --magic-advance-to-running <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]` — moves a board item into `board/running/` in one call, auto-stamping `started-at` (date-time). `--from-state:<state>` is required. `--header:*`/`--upsert-from-stdin`/`--edit-script-from-stdin`/`--edit-patch-from-stdin` pass straight through for whatever else the move also needs.

## `--member-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

# Maintainer Notes

Used to check this files own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine does the periodic board reconciliation process-flow needs to keep moving — without it, board state can drift from reality between full daily/grooming cycles.
- `check-process-board`'s own dependency-recompute step exists so task-ordering/dependency reasoning (what blocks what) is a standing, repeatable step recorded on the board itself — not a one-off answer that evaporates once the conversation moves on.

## Verbatim-tests (benchmarks)

- A `board-running` item whose own content already says it moved to `board-blocked`, but is still physically sitting in `board-running`, gets moved to match — without waiting for the next grooming pass.
- Dependency reasoning worked out ad hoc in a chat reply gets recorded on the Item files themselves — the next pass doesn't have to redo it from scratch.
- A high-RICE item blocked on a low-RICE one still records the gate plainly — never silently reordered to make the numbers look consistent.

## Librarian Comments

### Reference

- `routine-heartbeat` — the caller that invokes this routine every iteration, at the end of its loop.
- `routine-communication-sweep` — the Comms step this routine runs right after; also the source of `note-2026-08-05-pending-slack-reaction.md` records `check-pending-comms-actions` consumes.
- `routine-grooming` — deeper, once-daily, three-actor pass this routine's own findings feed into when they need real judgment; also reads `check-process-board`'s own recorded dependency ordering for its own cross-member reprioritization.
- `routine-librarian-morning-review` — the distinct, structural-drift-focused board session, not duplicated by this routine's own reconciliation pass.
- `routine-process-inbox` — this routine's own inbox processing (**advance-process-inbox**).
- `magic-coordinator/magic-coordinator.armed.md` — `check-process-board`'s own home, called from **advance-run-process-board**; `spawn-one-dispatch`, called from `check-execute-board`.
- `magic-team/magic-team.board.md` — the board's own state model, write-authority rule, `processed/`/`archived/` outcome-ambiguity note, `# Process-Flow, the board dynamics` section.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — Keep-Alive Workspace Console Session mechanics, `--list-consoles`, calling convention, `--react-slack`/`--send-console` mechanics.
- `magic-coordinator/RICE-SCORING.md` — the four normalized dimensions `check-process-board`'s own dependency-recompute step records alongside, never silently reconciled with.

### Conventions

None currently known beyond this file's own Local rules.
