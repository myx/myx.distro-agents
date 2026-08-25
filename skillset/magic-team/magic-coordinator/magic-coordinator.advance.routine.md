---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# magic-coordinator.advance.routine — the actual procedure

# Summary

Routine-advance is a lightweight, every-iteration mechanical reconciliation between the board's recorded state and reality — closes the gap between full daily/grooming cycles — plus the board's own dependency-ordering recompute (part of `check-process-board`), bounded to once a day or on direct request.

## Goals

The board isn't trustworthy between daily/grooming cycles — sessions die mid-work, dispatches go stale, approvals land continuously, not on a weekly schedule. This routine runs every main-loop iteration and executes only already-decided moves, never new judgment — what makes it safe to run unattended. Same logic covers stalled spawned work (nudge, report) and deferred actions (Slack reactions, Trello updates) once their conditions are actually met. One bounded exception, inside `check-process-board`'s own dependency-recompute step: recording a dependency edge is never a risky call, since an uncertain one is flagged rather than forced — reasoning worked out ad hoc in a chat reply would otherwise evaporate the moment the conversation moves on, with nowhere to live.

**Naming note**: "Advance" names what this routine actually does: bringing the board's *recorded* state back into alignment with what's *actually* true, not re-litigating priorities or scope.

## Scope

**In scope**, every invocation:
- All new incoming communication (email, Trello, Slack) — the full `magic-coordinator.communication-sweep.routine` pass (**check** + **process-each-message**, every found message, ascending timestamp order), not a narrow slice.
- `board-running` — every item, every pass, including its own in-place testing round; no separate `board/testing/` folder.
- `board-backlog` and `board-pending` — every item, every pass: mechanical `board-backlog`→`board-pending`→`board-running` moves, readiness-flagging only — not a full re-triage.
- `board-parked` and `board-blocked`, narrowly — only items carrying a `recheck-date` whose date has arrived (or, for `board-blocked`, an early-fire per `check-process-board`'s **board-reassess-parked-blocked**).
- `magic-coordinator`'s own inbox, narrowly — only `pending-slack-reaction` and `pending-trello-update` records (used in `check-pending-comms-actions`). One record per deferred action, not one standing record; the input-scan surfaces them, so no filename is written down or matched here.
- Dependency-graph recomputation (`blocks:`/`blocked-by:` edges and ordering) — bounded, not every pass (`check-process-board`'s **board-recompute-dependencies**).

**`recheck-date`/`condition` convention**, on any item entering `board-parked`/`board-blocked`:
- set at the moment it's parked/blocked, by whoever does that triage
- extended by `check-process-board`'s **board-reassess-parked-blocked** whenever it spins off an inquiry job instead of resolving inline
- no `recheck-date` recorded → never triggers that step, falls to `magic-team.grooming.routine`'s own slower cadence

**`recheck-date` computation (deterministic, not mental arithmetic)**: every `recheck-date` value this routine sets — whatever offset a step below states (`check-execute-board`'s `now + 7min (jittered ±2min)` restart-session spawn, its `now + 17 minutes` spawn-proxy-failure retry, or any other) — is computed by an actual shell `date` command, run via `mcp__myx_distro__execute`, never worked out as LLM mental arithmetic. A step's stated offset (`now + 7min`, `now + 17 minutes`) names the target only; this is how it's actually produced. Required output shape: full `date-time` per `magic-team.armed.md`'s Terminology (`YYYY-MM-DD HH:MM ±HHMM`, e.g. `2026-08-13 15:20 +0000`) — never a bare date, never dropping the UTC offset. Where a jitter window is stated (e.g. `±2min`), the jitter itself is also produced by that same shell call — a randomized offset folded into the base minutes before formatting — not eyeballed or approximated.

**Explicitly out of scope** (left to `magic-team.grooming.routine`'s own cadence):
- `board-blocked`/`board-parked`'s active-pursuit re-check — judgment-heavy, belongs to grooming's cadence. Actively resolving blockers stays excluded here. `check-execute-board`'s restart/nudge work IS in scope — not blocker-resolution, don't conflate the two.
- RICE scoring, any of it.
- Per-item triage verbs (keep/defer/reassign/split/drop) beyond "apply an already-decided move" and "redispatch an already-prescribed testing round".
- Board/file state-model drift hunting — `magic-librarian.morning-review.routine`'s own job, once-per-workday.
- The actual "go" decision itself — `approved-by`/`approved-at`, or deciding human-owner-level approval is needed — is grooming's/the authority group's/the human-owner's call, never this routine's; this routine only acts once one of those two facts is already recorded (`check-process-board`'s **board-mechanical-moves**).
- Trello-board-content review/grooming (reading/assessing existing cards) — distinct from `check-pending-comms-actions`'s narrow, mechanical execution of an already-queued Trello write, which IS in scope.
- Google Drive/Sheets.

**No-blanket-defer rule for `board-running` follow-up**:
- "Judgment-heavy" exclusion applies to blocker-resolution triage (`board-blocked`/`board-parked`) only.
- It does not apply to `check-execute-board`'s own running-item continuation loop.
- An item whose `recheck-date` is genuinely still in the future (checked against the real current date, never asserted) is skipped entirely this pass: no write, no outcome record, not touched in any way.
- Every other `board-running` item must receive one concrete per-pass outcome, every pass: `nudged`, `respawned`, `redispatched`, `flagged-once`, or — only for an item whose prefix matches no per-type rule at all, or a temporary error this pass — `no-action`.
- A pass-level summary like "deferred for later" is invalid for `board-running` as a class.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **advance-acquire-lock**: Acquire this routine's own lock — a single `--magic-advance-lock-acquire` call, before anything else in this routine runs. `ACQUIRED`, or a reclaim of a dead holder's lock, means go. Contention means another `magic-coordinator.advance.routine` is live: this pass does not start, and nothing below runs.
2. **advance-process-inbox**: run `magic-team.process-inbox.routine magic-coordinator` — the whole inbox, not `check-pending-comms-actions`'s narrow slice. New items get handled this pass, not only already-decided moves (a landed approval, a finished or stalled dispatch).
3. **advance-read-board-state**: Call the `--magic-advance-input-scan` operation.
   - This routine's own `state-and-lock` note comes back with that scan, as part of this routine's own input. It is this pass's tracking document — the tactical status, and whatever the next iteration needs to continue. Reference `TEAM-DATA` rather than copying it, to keep it compact. Write it via the `--magic-advance-state-and-lock-upsert` operation, keeping it current as the pass proceeds rather than only at close. Holding the lock across a long pass is a separate obligation: call `--magic-advance-lock-refresh` periodically — writing content does not itself hold the lock.
4. **advance-process-comms**: run `magic-coordinator.communication-sweep.routine`'s own Steps in full, inline, this same pass, against this pass's own board read from **advance-read-board-state** — messages can't be assessed without the current process-flow state, so this step never runs before the board is loaded. **check** (`--magic-sweep-input-scan`, every live platform, board-tracked threads plus every open thread) then **process-each-message** (every found message, one at a time, ascending timestamp order, cross-referenced against this pass's own board state, including the mandatory `conversations.replies` check on every open thread) — reused by reference, not duplicated logic.
5. **advance-run-process-board**: Run the `check-process-board` procedure (`magic-coordinator.armed.md`) against this pass's own read.
6. **advance-run-execute-board**: Run the `check-execute-board` procedure (below) against this pass's own read.

# Closure steps

1. **advance-report**: Post `check-execute-board`'s own findings (redispatches performed, interview threads opened/continued) to `slack-event-track` via `--member-comms-slack-send-message` (target `event-track`).
2. **advance-close-state-and-unlock**: Write the pass's closing status into the `state-and-lock` note via `--magic-advance-state-and-lock-upsert`, then release the lock via `--magic-advance-close-state-and-unlock`. That order is required: the release is what sets `state: advance-finished`, and a content write after it would put the note back to running. Until the release lands, the next iteration sees this pass as still running.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines - not visible outside this file.

## `check-execute-board` procedure

All work on a board-item's own task — spawned or inline; continuation or initial launch. Callable only from `magic-coordinator.advance.routine`.

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
- Contention-evidence rule: "was dispatched earlier today" or "liveness unknown" alone is never conflict evidence. Resource contention here needs a live signal from this pass (active lock/channel or a successful same-pass nudge/heartbeat).
- Handling:
  - Clear conflict evidence → keep in `board-pending`, note it, advance `recheck-date`.
  - Ambiguous evidence → ask via `AskUserQuestion` — conflict dimension, observed signal, two options (`treat as conflict` / `allow start now`).
- Start policy, non-conflicting `restart-session:` candidates:
  - Spawn at most one per pass, via `spawn-one-dispatch`, move exactly that one item to `board-running`.
  - Multiple equally ready → pick via `AskUserQuestion`, single choice list of candidate item names.
  - One item per spawned session; never batch multiple board-items into one spawned session.
  - Exception: `magic-coordinator.daily.routine`'s standing work-sessions take continuous task feed as each finishes.
- Repeated conflicts: item stays `board-pending`, re-checks on `recheck-date` indefinitely — no auto-escalation here.
- Before spawning: one last `AskUserQuestion` confirmation (`start this co-working session now?`), `yes`/`no`.
- **Autonomous invocation** (unattended, via `magic-coordinator.heartbeat.routine`): skip all three interactive prompts above. Ambiguous conflict evidence defaults to `treat as conflict`. Default non-remote process-flow spawn sessions MUST first try normal harness tool; use `--magic-heartbeat-spawn-proxy` only as fallback (no direct `Agent` tool). Proxy success in the same pass is required to move the item to `board-running`, verified this way for the async (non-`--wait`) proxy call: after launch, wait a few seconds, then read the resulting `output.log` — an immediate launch-failure signature (e.g. a `⛔ ERROR:` line at the very start, before any real work output) counts as failure; its absence counts as success. "Success" here means "launched without an immediate failure signature," not "task completed" — this check stays bounded (seconds, not indefinite) and never blocks the pass waiting for the spawned session to finish. Failure keeps or moves the item to `board-parked` in the same pass via `--magic-advance-to-parked` with all of:
  - `condition: spawn required, proxy execution failed in this pass`
  - `handoff-action: human-present harness-session retry required`
  - `recheck-date: now + 17 minutes`
  - `execution-receipt: <proxy-receipt-id-or-failure-marker>`
  and posts one `event-track` notification for this attempt. On each later recheck pass, retry once; success moves back to `board-running`, failure stays in `board-parked`, updates `recheck-date` to now + 17 minutes, and posts again.
- Sole starter of never-started `board-pending` items: another place may call `spawn-one-dispatch` directly on its own instruction, but an unrequested pending dispatch only starts here.

### How to actually work an item -- a real decision tree (the missing procedure, applies before any per-type rule below decides an outcome)

Decision node: **what does this item's own gap actually require?**
- **The gap is: nothing left to decide, just do it** (the next action is unambiguous) → branch A:
  1. Identify the single concrete action (send a message, write a file, run a check) -- not "review it."
  2. Execute it now, this pass, via the real tooling call it requires.
  3. Verify it actually happened -- not assumed from having attempted it.
  4. Record the outcome citing what was actually done, not a restatement of the goal.
- **The gap is: a real choice between options exists** (which approach, which owner, proceed or park) → branch B:
  1. Enumerate the actual options -- not one assumed path.
  2. For each, state the real outcome/risk if chosen -- evaluate before choosing, not after.
  3. Select one, with the reasoning recorded on the item, not just the pick.
  4. Execute the selected option per branch A above.
- **The gap is: missing information, not a missing decision** → branch C:
  1. State exactly what's missing and where it would come from.
  2. Get it this pass if it's a single tooling call away; otherwise flag it once, naming the specific missing fact, not a vague "needs more info."

A per-type rule below that reduces to "post a status/flag it" without walking one of these branches first is not doing the work, only describing that work exists.

### Continuing already-dispatched `board-running` items

Continue an already-dispatched `board-running` item. Never a first-time start (see above). Team-wide name for this mechanism: `check-restart` (see `magic-coordinator.armed.md` Terminology).

**General mechanism, every `board-running` item, every pass**:
- `session-id` set: a session is already working this item.
  - nudge it with this pass's own findings/updates, every time
  - never spawn a second session for this same item
  - failed nudge → treat as if `session-id` absent, continue below
  - nudge delivered, but `started-at` is past the same "~5 main-loop iterations or ~1 hour" staleness threshold used below, with no state change across nudges this pass or the last → treat identically to a failed nudge: `session-id` absent, continue below (eligible for `restart-session:` respawn using this item's own already-recorded participant list, if present)
- liveness unknown and no nudge path available from this pass alone → treat as if `session-id` absent (do not convert this into a pass-level blanket defer)
- `session-id` absent:
  - `interview-*`/`talk-*` prefix already tracking a Slack thread — `communication-channel-id` in the three-part `slack:<channel>:<ts>` shape → apply this item's `interview-*`/`talk-*` per-type rule (below), this same pass — a bounded resume-review + re-assess round over the existing Slack thread — never fall through to the `restart-session:` branch below for this case, even when `restart-session:` is also present.
  - `interview-*`/`talk-*` prefix not tracking a Slack thread — no `communication-channel-id` at all, or one that is not a three-part `slack:<channel>:<ts>` value (a bare `slack:<channel>` tracks no thread) → apply this item's `interview-*`/`talk-*` per-type rule (below), this same pass, posting to a fresh Slack thread via `--member-comms-slack-send-message` (target `human-owner`) instead of a reply into an existing one — same bounded resume-review + re-assess round as above, never a separate pre-round message — never fall through to the `restart-session:` branch below for this case either, even when `restart-session:` is also present.
    - Compose the returned `channel`/`ts` into one `slack:<channel>:<ts>` value and write it back as `communication-channel-id` via `--magic-advance-to-running <team-member> <item-filename> --from-state:running --header:upsert:communication-channel-id:<value>` (one header, same-state patch, existing content preserved), so the item is Slack-thread-backed from the next pass onward.
    - Post succeeded but write-back failed this pass → `flagged-once` (report the orphaned `channel:ts` via `slack-event-track`), never re-post a second backfill thread next pass.
  - `restart-session: <team-member> [<team-member>...]` present → spawn a coworking session (`magic-coordinator` + the named member(s)) via `spawn-one-dispatch`, passing the corresponding routine, document name, context
    - set `recheck-date` to now + 7min (jittered ±2min) and `session-id` to the new session's identifier, via `--magic-advance-to-running <team-member> <item-filename> --from-state:running --header:upsert:recheck-date:<value> --header:upsert:session-id:<value>` (same-state patch, existing content preserved)
  - `restart-session:` absent, no per-type rule matches this item's prefix → post to `slack-event-track` via `--member-comms-slack-send-message` (target `event-track`) — "active `board-running` document with no handler: `<filename>`" — flag for `magic-team.grooming.routine`, outcome `no-action` (`no-action:no-handler-for-prefix`). Never execute anything inline for an unhandled prefix. This, and a temporary-error reason (below), are the only two valid reasons for `no-action` — see **Per-pass completion requirement**.

- before continuing to check-restart the next `board-running` item whose handling above actually spawned/nudged/posted (a genuinely side-effecting call): execute the `--magic-advance-sleep-run` operation. A pure bookkeeping-only outcome recorded via `--magic-advance-batch-outcome` (below) needs no sleep-run at all — pacing exists to rate-limit real side effects, not frontmatter writes.

**Work order**: rank by real coverage of the item's own actual goal, not a sub-task count -- sub-task count is gameable (many trivial sub-tasks can inflate a finished-ratio while covering almost none of the real scope) and is never used as the measure. Judge coverage against what the item is actually asking for; then by age.

No pass-wide blanket defer is allowed for `board-running` restart work. Apply this mechanism item-by-item within the existing per-pass concurrency caps.

**Definition of done (a shared, explicit standard for "complete", not left to individual judgment)**: an outcome record alone does not mean an item is done -- it is done only when the outcome reflects real, verifiable state (a message actually sent, a session actually spawned, a real per-type round actually executed). A recorded outcome with no underlying action behind it is a false completion, not a valid one.

**Per-pass completion requirement**:
- An item whose `recheck-date` is genuinely still in the future, or whose staleness clock hasn't yet passed the threshold, is skipped entirely this pass: no write, no outcome record of any kind, not touched. This is not "no action" — it's "nothing due," and gets no record at all.
- For every other `board-running` item, finish the pass with one explicit outcome record from this procedure (`nudged` / `respawned` / `redispatched` / `parked-spawn-failed` / `flagged-once` / `no-action`).
- Every outcome record includes `execution-receipt`: spawn receipt id for spawn-proxy paths, dispatch/session id for redispatch/nudge paths, or explicit `inline:<timestamp>` / `no-action:<reason-code>` markers for non-spawn paths. **These shapes are exhaustive for this procedure's own `board-running` continuation outcomes** (`nudged`/`respawned`/`redispatched`/`flagged-once`/`no-action`) — no other string (an invented marker such as `no-new-signal-<date>`, or any other ad hoc receipt text) is a valid `execution-receipt` for any item, any such outcome; a conventions-check that finds anything outside these four shapes on a continuation outcome fails on sight. The separate `board-pending`→`board-parked` spawn-proxy-failure case (above, `parked-spawn-failed`) uses its own `<proxy-receipt-id-or-failure-marker>` shape instead — not one of these four, and not governed by this exhaustiveness claim.
- **`no-action` means "no action" plus an explicit REASON — and exactly two reasons qualify, nothing else**: (1) no per-type rule matches this item's prefix at all (the unhandled-prefix case above), or (2) a temporary error occurred this pass that itself prevented the item's real handling step from running (a reason to retry next pass, never a reason to stop trying). "Not due yet," "below staleness threshold," and "no relevant updates" are not valid reasons for this outcome — those items are skipped untouched per the bullet above instead. An item whose prefix has a matching per-type rule and is actually due/stale this pass always gets a real outcome from executing that rule's steps — never `no-action` in place of executing them.
- "Deferred" without one of these item-level outcomes is invalid.
- **`interview-*`/`talk-*`/`proposal-*` pooled-batch-call exclusion**, rules:
  - Unconditional, no exception: these items never enter the pooled batch call.
  - Each carries its own per-type-specific deep-check requirement, required by the per-type rule below — the **resume-review** + **reassess-before-next-message** round for `interview-*`/`talk-*`, a full `magic-team.discuss.routine` pass over the item's own framed decision for `proposal-*`.
  - Because of that requirement, none of the three ever qualify as "bookkeeping-only" the way the **At scale** note below allows for other prefixes.
  - Every `interview-*`/`talk-*`/`proposal-*` outcome this pass — `nudged`/`redispatched`/`flagged-once`/`no-action` alike — is recorded as a direct consequence of actually executing that item's own per-type rule this same pass, never folded into a `--magic-advance-batch-outcome` call alongside other items' bookkeeping.
  - Recording one of these outcomes via the pooled batch call is itself the defect this rule closes — never a valid path for these prefixes, whether or not the round genuinely ran standalone earlier in the pass.
- **At scale** (many `board-running` items in one pass), rules:
  - A genuine spawn/respawn/redispatch/park still goes through its own dedicated single-item op (`--magic-advance-to-running`/`--magic-advance-to-parked`), one call each, paced by `--magic-advance-sleep-run` as above.
  - Every item whose outcome this pass is bookkeeping-only (`nudged`, `flagged-once`, `no-action`, or recording that a respawn/redispatch already happened via its own call) is recorded through one `--magic-advance-batch-outcome` call covering the whole set, instead of one sequential call per item.
  - Exception: `interview-*`/`talk-*`/`proposal-*` items are excluded from this pooling entirely, no matter how many are in scope this pass — per the rule directly above.

**Staleness inputs feeding the mechanism above**:
- Console-session-backed work: for any in-scope item naming/depending on a `DistroAgentsTools` workspace console session, run `--console-list`, cross-reference. Console expected but gone → flag/report it; do not autonomously restart the console.
- Agent/Task-dispatch-backed work: for any `board-running` item recording an unresolved dispatch note, compute how long unresolved. Treat "unresolved past ~5 main-loop iterations or ~1 hour, whichever comes first" as the staleness signal.
  - Item's current state already prescribes a specific, safe, mechanical next step (e.g. a stale in-place testing round: dispatch a fresh `magic-tester` round): dispatch, record the new dispatch (id/time), report the redispatch once.
  - Otherwise: flag and report once. Escalate-once — don't re-flag the identical stale dispatch every pass; wait for a human/grooming response.
- Never-dispatched work: a `board-running` item, any prefix, carrying `approved-by`/`approved-at` but none of `session-id`, `restart-session:`, an active console session, or an unresolved dispatch note — no dispatch was ever actually made, whatever moved it into `board-running`. Compute elapsed time since `started-at`; the same "~5 main-loop iterations or ~1 hour, whichever comes first" threshold applies.
  - Past threshold: dispatch a coworking session via `spawn-one-dispatch`, naming this item's own `participants` record if present, else its `owner:` header alone (mechanically read, never inferred from prose) — same shape as dispatching a prescribed mechanical next step above. Record `session-id`/`recheck-date` via `--magic-advance-to-running --from-state:running`, outcome `respawned`, report the dispatch once.
  - Not yet past threshold: skip this item entirely this pass — no write, no outcome record; nothing is due yet.
- For each `board-running` item confirmed alive above: check whether anything this pass did is relevant to that item.
  - Relevant → relay via that process's own live channel: `--console-send` (command-only) for console-session-backed work, `SendMessage` for Agent/Task-dispatch-backed work.
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

Each item here is a tracking document. Where a rule below spawns or restarts work on one, it spawns the group that item's `participants` record names, and hands each member the goal, the task, the document itself, and that prefix's own rule below. A prefix may also have a routine assigned — run it in the situations that prefix calls for. A `(placeholder) not yet defined` entry is a real deferral: complete it when that type is settled, never improvise a rule per item.

- `approval-*` / `approve-*`: not resolved, `recheck-date` due → re-ask into the thread its `communication-channel-id` tracks, or via the `--member-comms-slack-send-message` operation to human-owner; extend `recheck-date` to now + 17min (jittered ±2min), per **`recheck-date` computation** above. Re-ask leads with the `NEEDS REPLY:` marker; report `waiting on human-owner` only while that marker's occurrence stays unanswered.
- `interview-*` / `talk-*`: run exactly one round — `magic-team.interview.routine`'s own **resume-review** + **reassess-before-next-message** — per that routine's own explicit non-blocking design, for real, over this item's own tracked thread.
  - rule: a tracked thread (`communication-channel-id` in the three-part `slack:<channel>:<ts>` shape) always gets this round actually executed this pass before any outcome is recorded for it — never skipped in favor of a bulk/bookkeeping record (see **Per-pass completion requirement**'s `interview-*`/`talk-*` pooling exclusion above); this round's outcome is always recorded directly, never via `--magic-advance-batch-outcome`.
  - rule: never attempt to run the interview to completion inline.
  - rule: any re-ask/notification is drafted fresh from this round's own current read of context, the board (including relevant updates on other board-items/threads this topic depends on — items load and change independently, and this round is what surfaces that), and the thread itself — never a repeated, now-irrelevant question.
  - rule: an update, an open question, or a wait that has gone on too long each require this round to produce real activity (a fresh question, a notice of what changed, or an explicit close-out) — not a static restatement of a stale prior message.
  - rule: report `waiting on human-owner` only while a real, still-relevant open question stays unanswered.
  - step: that round's own content already states every open question resolved and this pass raises no new one → flag it once via `slack-event-track` for `magic-team.grooming.routine`'s own `board-processed` closure (no `board-processed`-move operation is granted to this routine, so the move itself waits for grooming) — escalate-once, same as other stale-dispatch flags above, never re-flag the identical resolved item every pass.
- `inquiry-*`: `recheck-date` due, no reply → re-ask into the thread its `communication-channel-id` tracks, or via the `--member-comms-slack-send-message` operation; extend `recheck-date` to now + 17min (jittered ±2min), per **`recheck-date` computation** above. Otherwise → no action this pass.
- `task-*` / `project-*` / `epic-*`: apply the console-session/Agent-dispatch/never-dispatched-work stale-checks above.
- `proposal-*`: `recheck-date` due → run `magic-team.discuss.routine` over this item's own framed decision, this same pass, per that routine's own Steps, rules:
  - `magic-team.discuss.routine` owns all state changes for this item (see `check-process-board`'s Note on proposal items).
  - That routine's own **record-the-outcome** step performs the resulting move itself — approved/promoted → `board-processed` plus the same unblock sweep `approval-*`/`approve-*` items use; rejected/dropped → `board-archived`.
  - Never a bare re-ask outside that routine's own Steps.
- `dispatch-*`: `session-id` set → nudge per the general mechanism above; append the report-back as a new dated log entry via `--magic-advance-to-running --from-state:running` — the item stays in `board-running`. `session-id` absent → apply the never-dispatched-work stale-check above, same as any other prefix.
  - rule: every participant is written into the `dispatch-*` document at creation, before it is approved
  - rule: approval adds or removes names on that list
- `change-*`: `recheck-date` due → re-verify whether the underlying change has actually landed (the condition it was tracking); landed → move to `board-processed`, still pending → re-ask/extend `recheck-date` to now + 17min, same as `inquiry-*`.
- `warning-*`: `recheck-date` due, condition still true → re-escalate once via `slack-event-track` (not a silent re-flag) and extend `recheck-date`; condition no longer true → move to `board-processed`. No `recheck-date` set → set one now, same as any item entering this loop without it.
- `session-*`: the spawn includes every member the item's `participants` record names.
- `note-*` / `reflection-*` / `transcript-*`: not expected in `board-running` → flag for `magic-team.grooming.routine`.
- **base restart**: a named participant cannot be spawned, steps:
  - move the item to `board-parked` via `--magic-advance-to-parked`
  - set `condition` naming the participant that could not be spawned, via `--header:upsert:condition:<value>`
  - set `recheck-date`, via `--header:upsert:recheck-date:<value>`
  - report it in **advance-report**

After all per-type checks: send one Slack DM to human-owner naming every item that stayed `board-running` with `recheck-date` untouched this pass (across this procedure's own pass and `check-process-board`'s already-run pass), plus any autonomous-invocation restart-session spawns from this same pass (above) — at most once per `magic-coordinator.advance.routine` run, not per item.

The same DM includes a compact `board-running` outcome count for this pass (`nudged`/`respawned`/`redispatched`/`flagged-once`/`no-action`) so missing follow-up is visible immediately.

**Thread continuity**: read `human_owner_broadcast_thread_ts`/`human_owner_broadcast_thread_date` from the `heartbeat-state-note` first. Date matches today's real date → post this DM as a threaded reply, target `<channel>:<ts>` using that stored value, never the bare `human-owner` keyword. No match (absent, or a stale prior day) → post with the bare `human-owner` target as today's first such DM, capture `channel`/`ts` from this call's own JSON response, and write them back via `--magic-heartbeat-state-upsert` so every later `next-iteration` this same day threads into it instead of starting fresh.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-coordinator` (this routine's sole executor) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- This routine is an extension of `magic-team.coworking.routine` — it inherits that routine's own instructions and follows them wherever they apply; on any conflict, this file's rules override the parent's.
- Overrides the inherited coworking thread anchor: this routine's session thread lives in `slack-event-track`, not `slack-magic-team`. Genuinely important items still go separately to the human-owner DM and `slack-magic-team`.
- Does not run **fold-in-learned-lessons** — that step works a small, recent, unresolved reflection set, and this routine's every-iteration cadence would grind the whole accumulated pile each pass.
- Not wired into `magic-team.coworking.routine`'s Steps/Closure Steps as separate calls — this routine runs unattended every main-loop iteration and its trace is debug-level. **advance-report** is that inherited closing obligation, discharged into `slack-event-track`.
- Every real file read/write and communications API call this routine makes (including `check-process-board`'s own `--member-comms-slack-react` calls) is its own direct `mcp__myx_distro__execute` call — no Keep-Alive Console Session assumed or required, per `magic-team.armed.md`'s process-flow rule.
- Never resolves an open design/judgment question surfaced by an investigation subtask — flags it for `magic-team.grooming.routine`/`magic-architect`.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal.
- `magic-coordinator` (this routine's sole executor) is obligated to keep `slack-event-track` activity tracking current as things are found, not batch it artificially.
- No separate close-out step beyond `# Closure steps` below. This routine is invoked inline, mid-iteration, from `magic-coordinator.heartbeat.routine`; that iteration's own session close closes the work.
- **advance-report** never repeats `check-process-board`'s own **board-report** — that step already covers this same pass's board-state findings.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-advance-input-scan <team-member>` (**advance-read-board-state**: read the in-scope board state; also `check-process-board`'s own **board-recompute-dependencies**, on the same already-loaded read)
- `--magic-advance-to-running <team-member> <item-filename> --from-state:<state> [--header:...]...` (`check-execute-board`'s own never-started-`board-pending`-items step: basic-task start)
- `--magic-advance-to-parked <team-member> <item-filename> --from-state:<state> [--header:...]...` (`check-execute-board` fallback when spawn is required but cannot execute in this pass)
- `--magic-advance-lock-acquire <team-member> <owner-label>` (**advance-acquire-lock**: take this routine's lock before anything else runs)
- `--magic-advance-lock-refresh <team-member>` (hold the lock across a long pass)
- `--magic-advance-close-state-and-unlock <team-member>` (**advance-close-state-and-unlock**: release, setting `state: advance-finished`)
- `--magic-advance-lock-status <team-member>` (ask who holds the lock; never a gate)
- `--magic-advance-state-and-lock-upsert <team-member> [--header:...]... [--from-file <path>|--edit-patch-from-stdin]` (**advance-read-board-state**'s own session tracking document, kept current as the pass proceeds; **advance-close-state-and-unlock**'s closing content write)
- `--magic-advance-sleep-run` (`check-restart`: executed before continuing to the next `board-running` item, side-effecting outcomes only)
- `--magic-advance-batch-outcome <team-member> --items:<item-filename>:<outcome>:<execution-receipt>[,...]` (**Per-pass completion requirement**, at scale: records bookkeeping-only outcomes for several `board-running` items in one call)
- `--magic-heartbeat-spawn-proxy <team-member> [--from-board <board-item-name> [--board-state <state>]...] [--from-vault <vault-item-name>] [--from-audit <audit-item-name>] [--wait]` (`check-execute-board` autonomous spawn relay with execution receipt)
- `--magic-heartbeat-state-upsert <team-member> [--from-file <path>]` (per-type checks' closing human-owner DM: **Thread continuity** write-back of `human_owner_broadcast_thread_ts`/`human_owner_broadcast_thread_date`)
- `--member-comms-slack-send-message <team-member> <target> [text...]` (**advance-report**: post the `event-track` report trace; also `check-execute-board`'s own per-type re-ask rules)

## `--magic-advance-sleep-run` operation reference

`DistroAgentsTools.fn.sh --magic-advance-sleep-run` — read-only, no arguments: a fixed-duration pacing operation in `magic-coordinator.advance.routine`'s operation group. Required only after a genuinely side-effecting per-item call (spawn/nudge/redispatch/park); not required after `--magic-advance-batch-outcome`.

## `--magic-advance-batch-outcome` operation reference

`DistroAgentsTools.fn.sh --magic-advance-batch-outcome <team-member> --items:<item-filename>:<outcome>:<execution-receipt>[,<item-filename>:<outcome>:<execution-receipt>]...` — records a per-pass outcome (`nudged`/`respawned`/`redispatched`/`flagged-once`/`no-action`) plus `execution-receipt` for several `board-running` items in one call, same-state (`running`→`running`), existing content preserved. Bookkeeping only — never moves state, never spawns; a genuine spawn/respawn/redispatch/park still goes through `--magic-advance-to-running`/`--magic-advance-to-parked`. `execution-receipt` is everything after an entry's second colon, so colon-shaped values (`inline:<timestamp>`, `no-action:<reason-code>`) pass through intact; must not contain a comma. Never `slack:<channel>:<ts>` — that shape is an item's own `communication-channel-id` header value, not an `execution-receipt`; `interview-*`/`talk-*` outcomes are recorded directly, never via this call (see **Per-pass completion requirement**'s pooling exclusion), and still use the same exhaustive four `execution-receipt` shapes as everything else. One malformed/failing entry is reported inline without aborting the rest of the batch; any failures make the whole call exit non-zero.

## `--magic-advance-input-scan` operation reference

`DistroAgentsTools.fn.sh --magic-advance-input-scan <team-member>` — read-only scan giving all board job-state information relevant to this routine, plus this routine's own `state-and-lock` note as part of the same prepared input. `<team-member>` is the only argument; the scan's shape is fixed.

## `--magic-advance-lock-acquire` / `--magic-advance-lock-refresh` / `--magic-advance-close-state-and-unlock` / `--magic-advance-lock-status` operation reference

`DistroAgentsTools.fn.sh --magic-advance-lock-acquire <team-member> <owner-label>` / `--magic-advance-lock-refresh <team-member>` / `--magic-advance-close-state-and-unlock <team-member>` / `--magic-advance-lock-status <team-member>` — the single-instance lock this routine owns, one holder at a time. `acquire` prints `ACQUIRED` on a fresh take, or `RECLAIMED_STALE:...` when a dead holder's lock is taken over, both returning 0; on contention it prints `ACTIVE:...` and returns 1, which means this pass does not start. `<owner-label>` identifies the actual running agent/process by a fixed, discoverable name, not an ephemeral session id — distinct from `<team-member>`, the calling member's own identity. `refresh` prints `REFRESHED` and is what holds the lock across a long pass. `close-state-and-unlock` prints `RELEASED` and sets `state: advance-finished`. `status` is a question, not a gate: it prints current lock metadata, or `NO_LOCK` when free, and always returns 0.

## `--magic-advance-state-and-lock-upsert` operation reference

`DistroAgentsTools.fn.sh --magic-advance-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--edit-patch-from-stdin]` — writes this routine's own `state-and-lock` note: the pass's session tracking content. Body content via `--from-file` or `--edit-patch-from-stdin`. Every call stamps `state: advance-running` and renews `recheck-date` itself — the caller never supplies `recheck-date`, and never names the note.

## `--magic-advance-to-parked` operation reference

`DistroAgentsTools.fn.sh --magic-advance-to-parked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]` — moves a board item into `board-parked` in one call, and/or patches its frontmatter. It stamps nothing: the calling step supplies `condition`/`handoff-action`/`recheck-date`/`execution-receipt` itself via `--header:*`.

## `--magic-advance-to-running` operation reference

`DistroAgentsTools.fn.sh --magic-advance-to-running <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]` — moves a board item into `board/running/` in one call, auto-stamping `started-at` (date-time). `--from-state:<state>` is required. `--header:*`/`--upsert-from-stdin`/`--edit-script-from-stdin`/`--edit-patch-from-stdin` pass straight through for whatever else the move also needs.

## `--magic-heartbeat-state-upsert` operation reference

`DistroAgentsTools.fn.sh --magic-heartbeat-state-upsert <team-member> [--from-file <path>]` — writes (creates or overwrites) `magic-coordinator.heartbeat.routine`'s own day-rhythm state record, plus `magic-coordinator.communication-sweep.routine`'s per-platform mechanical sweep state. Content via stdin by default, or `--from-file <path>`. Always a whole-record overwrite, never an append; empty content is refused rather than written — so a write-back of individual fields supplies the whole record, not just the changed pair.

## `--member-comms-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine does the periodic board reconciliation process-flow needs to keep moving — without it, board state can drift from reality between full daily/grooming cycles.
- `check-process-board`'s own dependency-recompute step exists so task-ordering/dependency reasoning (what blocks what) is a standing, repeatable step recorded on the board itself — not a one-off answer that evaporates once the conversation moves on.

## Verbatim-tests (benchmarks)

- A `board-running` item whose own content already says it moved to `board-blocked`, but is still physically sitting in `board-running`, gets moved to match — without waiting for the next grooming pass.
- Dependency reasoning worked out ad hoc in a chat reply gets recorded on the Item files themselves — the next pass doesn't have to redo it from scratch.
- An approved `board-running` item carrying none of `session-id`, `restart-session:`, an active console session, or an unresolved dispatch note, sitting past the staleness threshold, gets a real dispatch this pass — never a blanket `no-action` stamp with nothing actually tried.
- A `session-id`-set item that keeps getting nudged with zero observed state change past the staleness threshold is treated as if the nudge failed — not renudged indefinitely as "still working."
- A high-RICE item blocked on a low-RICE one still records the gate plainly — never silently reordered to make the numbers look consistent.

## Librarian Comments

### Reference

- `magic-coordinator.heartbeat.routine` — the caller that invokes this routine every iteration, at the end of its loop.
- `magic-coordinator.communication-sweep.routine` — the Comms step this routine runs right after; also the source of the `pending-slack-reaction` records `check-pending-comms-actions` consumes.
- `magic-team.grooming.routine` — deeper, once-daily, three-actor pass this routine's own findings feed into when they need real judgment; also reads `check-process-board`'s own recorded dependency ordering for its own cross-member reprioritization.
- `magic-librarian.morning-review.routine` — the distinct, structural-drift-focused board session, not duplicated by this routine's own reconciliation pass.
- `magic-team.process-inbox.routine` — full own-inbox read (**advance-process-inbox**), distinct from `check-pending-comms-actions`'s narrow deferred-action slice.
- `magic-coordinator/magic-coordinator.armed.md` — `check-process-board`'s own home, called from **advance-run-process-board**; `spawn-one-dispatch`, called from `check-execute-board`.
- `magic-team/magic-team.board.md` — the board's own state model, write-authority rule, `processed/`/`archived/` outcome-ambiguity note, `# Process-Flow, the board dynamics` section.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — Keep-Alive Workspace Console Session mechanics, `--console-list`, calling convention, `--member-comms-slack-react`/`--console-send` mechanics.
- `magic-coordinator/RICE-SCORING.md` — the four normalized dimensions `check-process-board`'s own dependency-recompute step records alongside, never silently reconciled with.

### Conventions

None currently known beyond this file's own Local rules.
