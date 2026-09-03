---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
invitees: magic-team
---
# magic-coordinator.daily.routine — the actual procedure

# Summary

Routine-daily is the team's standing daily checkpoint: surface every member's state, assign the day's work in dependency order, run a supervised work session, and report honestly.

## Goals

- Give the team a standing, predictable daily checkpoint.
- Every permanent member's real state (backlog, blocks, ideas) gets surfaced and reconciled against the board at least once a day — nothing genuinely open silently rots between grooming passes.
- The day's work gets assigned in dependency-aware order via `check-process-board`'s own dependency recompute, not picked off an unordered list.
- A supervised work session actually happens — bounded and checked-in-on, not fire-and-forget — so problems surface the same day instead of at the next grooming.
- The human team gets a visible, honest trace of what happened, not a silent internal cycle.
- This is the team's primary rhythm-setting mechanism — what makes "the team is actually working, not just has a backlog" true on any given day.

## Scope

- Does:
  - Daily standup.
  - Dependency-ordered work assignment.
  - Supervised work-session fan-out.
  - Comms write-half.
  - Mechanical board moves, same as `magic-coordinator.advance.routine` (**run-check-process-board**).
  - Simple interview: open a new thread, or post a ready reply — no investigation.
  - Simple grooming-shaped decisions needing no spawn.
  - **Invocation**:
    - Manually: the human-owner (or a member, narrated) asks for a "daily meeting"/"standup".
    - Autonomously: via `magic-coordinator.heartbeat.routine`'s day-rhythm state (see that routine's "Day-rhythm state" section).
  - **Precondition**: none — every tool call this routine makes is its own direct `mcp__myx_distro__execute` call, per `magic-team/magic-team.armed.md`'s process-flow rule.
- Doesn't do:
  - Spawn a new dispatch — never calls `check-execute-board` (`magic-coordinator.advance.routine`, `magic-coordinator.advance.routine`-only: starts a never-yet-dispatched `board-pending` item, restarts/nudges `board-running` work). **fan-out-work-sessions**' own member fan-out is the one exception.
  - Backlog re-triage needing investigation/design — `magic-team.grooming.routine`'s job.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **acquire-lock**: Acquire this routine's own lock — a single `--magic-daily-lock-acquire` call, before anything else in this routine runs, **spawn-morning-review**'s spawn included. `ACQUIRED`, or a reclaim of a dead holder's lock, means go. Contention means another `magic-coordinator.daily.routine` is live: this pass does not start, and nothing below runs.
2. **spawn-morning-review**: first-today only — spawn `magic-librarian.morning-review.routine` as a full sub-session, and wait for it to complete.
   - Why: `magic-librarian` starts its workday earlier than `magic-coordinator.daily.routine` and does its own bookkeeping (inbox processing, board-state review) during that session; waiting ensures the standup/work-session below starts only after that bookkeeping pass is done, so probable inquiries and other incomings are already caught in a complete state.
   - Dispatch: a background `Agent` whose first action is `Skill(magic-librarian)`, default goal "run this workday's joint board-review session" (`magic-librarian.morning-review.routine`'s own Goals — state-shape drift and cross-file consistency, not ordinary content staleness).
   - **Wait for it to actually finish** before continuing to **reload-active-duty-context** — a real spawn-and-wait, not fire-and-forget; use `ScheduleWakeup` for the check-in, not polling.
   - **Autonomous invocation**: request this spawn from `main` via the `SPAWN-REQUEST` protocol instead of calling `Agent` directly — the goal, the wait, and the skip-on-same-day-rerun are unchanged.
   - That spawned sub-session is a full-featured coworking-like session per the session-type framework: it executes `magic-team.coworking.routine`'s Steps and, at the end, its Closure Steps.
   - Skip silently on a same-day re-run of `magic-coordinator.daily.routine` — once per workday, same first-today gating as **run-check-process-board**'s grooming counterpart.
   - **Hold the lock across this wait**: call `--magic-daily-lock-refresh` while waiting — waiting is not itself holding the lock, and a spawn-and-wait this long outlives a single acquire.
   - **Bounded wait, not indefinite**: sub-session hasn't reported back within roughly 30 minutes → flag it once (a `slack-magic-team` note plus a line in this session's own close-out report) and continue into **reload-active-duty-context** anyway — this meeting proceeds without morning-review's benefit rather than blocking the whole standup indefinitely.
3. **reload-active-duty-context**: (re-)load this routine's own active-duty context now, in full — reading the distributed typed files directly.
   - Deliberately *after* **spawn-morning-review**'s spawn-and-wait, so this session picks up anything the morning-review session may have changed in this member's own instruction files or inbox state.
   - Skip only if this exact session has already loaded it earlier in the same continuous run.
4. **session-start**:
   - goal: this routine's own `state-and-lock` note is this pass's tracking document — the tactical status, and whatever the next pass needs to pick up from here.
   - rule: reference `TEAM-DATA` rather than copying it, to keep it compact.
   - rule: holding the lock across a long pass is a separate obligation — call `--magic-daily-lock-refresh` periodically; writing content does not itself hold the lock.
   - step: write it via the `--magic-daily-state-and-lock-upsert` operation, keeping it current as the pass proceeds rather than only at close.
   - step: execute `magic-team.coworking.routine`'s **session-start** group:
     - **declare-session-type**: declares this as a coworking-like/structured-multi-member session.
     - **fold-in-learned-lessons**: invokes `magic-team.process-reflections.routine` for this project/workspace.
     - **collect-reflections-output**: processes own inbox.
     - **post-opening-broadcast**: posts an opening broadcast to `slack-magic-team`/Trello (coworking-only, applies here).
5. **librarian-confirms-roster**, in parallel with **sweep-comms-read**: dispatch `magic-librarian` to confirm the `roster-note` and `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section are current (roster/domain and workspace/tooling facts, read as trusted day-to-day, not re-derived here).
   - Refresh the `roster-note` via the `--member-upsert-inbox-note` operation if it drifted.
   - Per-member backlog itself lives on the board (coordinator-exclusive write authority).
6. **sort-incoming**, in parallel with **librarian-confirms-roster** and **sweep-comms-read**: run `magic-team.process-inbox.routine magic-coordinator` — inline execution (own identity). A genuine second pass, not a repeat of **collect-reflections-output**: that one picks up what **fold-in-learned-lessons** just filed, this one is the sorting read across everyone's `inquiry-*`/`reflection-*`/status reports and reactions accumulated since the last daily, so **roll-call** speaks to what actually came in.
   - Not automatic just because this routine spawned — this explicit call is what actually guarantees it happens.
7. **sweep-comms-read**, in parallel with **librarian-confirms-roster**: run the read half of `magic-coordinator.communication-sweep.routine` — not Trello-specific, covers every live platform under `the credential store`.
   - Fold anything relevant into the roll call narration in **roll-call**.
   - Don't act on it unilaterally.
8. **roll-call**: not a status meeting -- narrating status without adapting the plan is the failure mode this step must avoid; **update-todos** immediately after must actually change the plan, not just record what was said. random order — pick a random order over the permanent members (every skill except `magic-coordinator` itself).
   - Fixed question order: what happened since last time, what's planned next, what's blocking -- in that order, for each member, steps:
     - call the `--member-work-session-input-scan` operation
     - use its board-items section only — the inbox section stays unread, each member reads its own inbox itself at session start
     - narrate that member's status/blocks/ideas/leftovers for today from it plus whatever's visible in `TodoWrite`/project memory
   - All invitees (including `partner-*`s) still get a turn — most days that's "nothing to report," but they can flag a recommendation if another member's item touches infra/CDCI/service code.
   - A narrated pass, not a full agent spawn per member — that comes later.
   - **Compact that member's reflections, same round, limited scope**:
     - rule: not a retro-scale proposal pass; this is what keeps **fold-in-learned-lessons**' input a small, recent, unresolved set.
     - step: recap the `reflection-*` items accumulated in its own inbox since the last daily.
     - step: where several say the same thing, replace them with one or two current ones — retire what is resolved, promote what has formed into an `inquiry-*`/proposal.
   - Anything a member's status raises that needs real discussion doesn't get resolved inline here — flag it for **questions-then-conclude** or the backlog instead.
9. **update-todos**: reflect what the roll call surfaced in the current session's `TodoWrite` (today's working list) for the members about to get a work session.
   - **Held until further notice — a temporary hold, not a removal; only the human-owner lifts it.** No idle task is assigned while the hold stands. Held instruction: member with nothing assigned but an idle-task menu of more than one file, steps:
     - randomly pick one `idle-tasks/*.idle.md` file now
     - put *that specific file* in the todo — don't leave "run the idle menu" as a vague item
   - Every member — acting members and `routine-*` virtual members alike — always has one more idle-task candidate available beyond whatever `idle-tasks/*.idle.md` files it happens to have.
     - That candidate: a short, iterative "research the web a bit on a topic of this member's own duties, detect good proposals to assess at the next `magic-team.grooming.routine`" pass.
10. **run-check-process-board**: run the `check-process-board` procedure (`magic-coordinator.armed.md`) directly. Never `magic-coordinator.advance.routine`.
11. **librarian-updates-context**: today's new task details already live on the board directly (via **run-check-process-board**'s pass and **fan-out-work-sessions**' dispatched agents' own board moves) — no separate write-back step exists.
12. **sync-camunda-diagrams**: run the owning `partner-*`'s own diagram-sync routine — mtime check on the `temp-magic-team` BPMN diagrams against team definition files, redeploy handoff to that routine's own owning `partner-*` if stale.
   - Skip silently if nothing changed — don't dispatch an agent just to find that out, the mtime comparison is cheap enough to do inline.
13. **questions-then-conclude**: let the user (or a member, narrated) ask anything before closing the standup portion.
   - **Autonomous invocation**: doesn't block waiting for a live response — post any open questions to `slack-magic-team` via the `--member-comms-slack-send-message` operation (and, if it needs to persist as real backlog rather than just a conversational trace, a `board-running` `note-*` item) for later human review, then continue to **fan-out-work-sessions**. The next daily's **sort-incoming** step checks for a reply before treating the question as open.
14. **fan-out-work-sessions**: for every permanent member that has something to do today — **except `partner-*`** (present-but-non-reporting members don't get a work session either) — spawn one background `Agent` per member.
   - This is where this routine's own **participants** (see this file's own Local rules for the executor-vs-participant definition) actually get sub-spawned, one at a time as their own real background `Agent`, not merely referenced/notified.
   - **Autonomous invocation**: route each spawn through `main` via the `SPAWN-REQUEST` protocol instead, same as **spawn-morning-review**; wait for `main`'s relayed result before treating the work-session as started.
   - Each agent's first action must be invoking that member's own Skill (via the `Skill` tool), so it actually operates under that skill's full content, not a paraphrase.
     - Then it works its assigned item(s) for roughly 20-30 minutes, within the participant scope defined in this file's Local rules.
   - **Board consultation is a coordinator-level concern, not each agent's own**: **update-todos** is where any relevant board item already gets folded into a properly-scoped assignment before this fan-out happens.
     - The spawned agent just works its assigned item normally — no separate "check the board" behavior needed.
   - **`board-running`→`board-blocked` trigger**: per the board's own refined state-model definition, a `board-running` item is one the next work-session iteration is expected to pick up and continue — so if an agent gets here and genuinely can't make progress, that's exactly when the item was "supposed to be running" and wasn't.
     - Move it to `board-blocked` as part of this same work session (note *why*, including a `blocked-by` pointer if it's blocked on another item), rather than leaving it sitting in `board-running` looking active, or silently deferring the discovery to the next grooming pass.
   - **Claimed-completion trigger**: if instead an agent finishes its assigned `board-running` item's implementation this session — nothing left to do, not stuck — that's a claimed completion, not a finished item yet.
     - Note the claim in place (item stays `board-running`); the actual verification happens per the board's own `board-running` entry, dispatching `magic-tester`, not inline in this same work session unless `magic-tester` itself is one of today's dispatched agents.
   - If the assigned item is the randomly-picked idle-task file from **update-todos**, tell the agent explicitly which `idle-tasks/*.idle.md` file to load and execute.
   - Use `ScheduleWakeup` at that mark as the check-in signal rather than polling.
   - Call `--magic-daily-lock-refresh` at each check-in — a fan-out this long outlives a single acquire, and a concurrent check must not mistake a slow-but-alive pass for a crashed one.
   - While these run, stay in the main conversation talking with the user about live progress — that's supervision, not silence.
   - A milestone landing or a new blocker surfacing mid-session gets posted to `slack-magic-team` right then, not batched until the close-out.
   - If a working agent surfaces or receives a new, unrelated ask mid-session, it notes it (its own inbox, or a board note naming the item it concerns in body prose) for the next communication sweep / grooming triage rather than switching focus.
15. **sweep-comms-write**: run the write half of `magic-coordinator.communication-sweep.routine` — update the own-status card to reflect today's actual state, and reply/comment anywhere else warranted across whatever platforms are live.

# Closure steps

1. **run-advance-dispatch**: run `magic-coordinator.advance.routine`, in full, before anything else here — it is the routine that actually dispatches and respawns; the main sequence deliberately doesn't.
   - goal: everything is decided by now. While the main steps are still running, what gets dispatched — in what form, in what order — is still open to reassessment. Dispatching only once the board is updated means work goes out without corrections chasing it, and without hitting blockers a later step would have resolved.
   - rule: this does not re-dispatch **fan-out-work-sessions**' own work sessions — `check-execute-board`'s standing "`magic-coordinator.daily.routine`'s standing work-sessions take continuous task feed as each finishes" exception already excludes them.
   - rule: `magic-coordinator.advance.routine`'s **advance-run-process-board** repeats the `check-process-board` pass **run-check-process-board** already ran. That is a deliberate second reconciliation over a board the main sequence has since changed, not an accident — `check-process-board` executes only already-decided moves, so re-running it is safe.
2. **close-out**: once agents finish (or are wrapped up at the timebox), compact what happened into a short summary for the user. Execute `magic-team.coworking.routine`'s Closure Steps in full — this is a coworking-like session, so its continuity step, `slack-magic-team`/status-card broadcast, and skill-update-discussion offer all apply; context compaction does not. `magic-team.process-reflections.routine` already ran at **fold-in-learned-lessons**, not here. Meeting finished.
3. **close-state-and-unlock**:
   - rule: that order is required — the release is what sets `state: daily-finished`, and a content write after it would put the note back to running; last, every time — until the release lands, the next pass sees this one as still running.
   - step: write the pass's closing status into the `state-and-lock` note via `--magic-daily-state-and-lock-upsert`.
   - step: release this routine's own lock via `--magic-daily-close-state-and-unlock`, setting `state: daily-finished`.

# Routine's local procedures

None — every procedure this routine invokes belongs to another routine, referenced here by name only (`magic-team.coworking.routine`, `magic-coordinator.communication-sweep.routine`, `magic-coordinator.advance.routine`, the owning `partner-*`'s own diagram-sync routine, `magic-librarian.morning-review.routine`, `magic-team.process-inbox.routine`, `magic-team.interview.routine`, `magic-team.process-reflections.routine`) — see Librarian Comments → Reference.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-coordinator` (this routine's sole executor) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- This routine is an extension of `magic-team.coworking.routine` — it inherits that routine's own instructions and follows them wherever they apply; on any conflict, this file's rules override the parent's.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- **Executor vs. participant role, defined explicitly** (resolving this routine's own version of the "always (sub-)spawned" standing rule): `magic-coordinator.daily.routine` has one **executor** (`magic-coordinator`) and, at its work-session fan-out step (**fan-out-work-sessions**), several **participants** — every member that step actually dispatches. This is `magic-coordinator.daily.routine`'s own version of the same executor/participant distinction `magic-team.coworking.routine` already draws explicitly ("other members are participants, not executors"), just shaped around this routine's own "fan-out" collaboration mode (each participant works its *own* separate assignment) rather than several people on one shared task.
  - **The executor's (`magic-coordinator`'s) scope**:
    - Frames what today's work actually is: roll call, todo assignment, dependency ordering.
    - Supervises the participants' work session in real time: check-ins via `ScheduleWakeup`, redirecting if something drifts.
    - Does the board consultation/state-transition judgment calls that aren't any one participant's own to make.
    - Owns the session's actual close-out.
    - Board writes stay exclusively the executor's, even when a participant's own work surfaces the need.
  - **A participant's scope**: work the specific item(s) already assigned — nothing broader.
    - Does *not* independently consult the board for other work.
    - *Does* make the two board-state-transition calls that are genuinely its own to make about its *own* assigned item, as they arise mid-session: `board-running`→`board-blocked` if genuinely stuck, a claimed-completion note in place if done.
    - Reports status when checked in on.
    - Routes anything non-goal-directed it notices back to the executor's own triage, rather than acting on it solo.
    - Genuinely sub-spawned — a real background `Agent`, `Skill(<member>)` first, not merely "notified/referenced" — for the duration of its own assigned work, then reports back and exits.
    - Same "creates its own context, does its work, exits cleanly" shape as `magic-librarian.morning-review.routine`'s own sub-session, just without that routine's own full Steps/Closure Steps lifecycle layered on top — a single-member work-session slot is an ad-hoc/solo dispatch per `magic-team.coworking.routine`'s own session-type definition, not one of the structured coworking-like routines itself, deliberate, not an oversight.
- No cron: this routine is never automated onto its own schedule — confirm explicitly with the human-owner before ever proposing that.
- the board is the cross-workspace, cross-day source of truth for per-member backlog — `TodoWrite` alone can't serve this role since it resets every session.
- `magic-coordinator` holds exclusive write authority over the board.
- A member's status is ambiguous, or the roll call can't tell what they need (**roll-call**): don't guess a work assignment from a thin signal — flag it for **questions-then-conclude**, or leave it for the backlog.
- Nothing-to-report is a normal, valid outcome for a member.
- A member has more than one plausible idle-task file and no assigned work (**update-todos**): the random pick is held until further notice — a temporary hold, not a removal, lifted only by the human-owner. Held instruction: pick one at random and name it explicitly.
- Do not let "figure out priorities among idle tasks" become its own mid-routine investigation — that is out of scope for a daily roll call.
- A dispatched agent (**fan-out-work-sessions**) reports something ambiguous — not clearly stuck, not clearly done: default to treating it as still `board-running` (no state change) rather than guessing.
- Ask the agent directly for a clearer status if there's time left in the work-session window.
- A wrong move here creates board noise `magic-team.grooming.routine` then has to untangle.
- Board writes during the fan-out (**fan-out-work-sessions**) stay `magic-coordinator`-exclusive: a dispatched agent that discovers a block or completion only flags it — `magic-coordinator` performs the actual `board-running`→`board-blocked` move, or notes a claimed completion in place.
- Something surfaces that needs a real decision outside this routine's own mandate (a design question, a resource commitment, genuine doubt): route it through `magic-coordinator` as the sole mandated channel to the human-owner — never resolved inline as an ordinary judgment call, and never a dispatched member seeking approval independently.
- Truly unsure whether something is a small in-routine call or a real decision needing escalation: default to escalation — an unnecessary escalation costs a short question, an inline wrong guess costs rework and board noise later.
- A step's stated precondition looks unmet (the `roster-note`/`magic-team/magic-team.armed.md` tooling section looking stale beyond what **librarian-confirms-roster** caught): stop and fix the precondition before proceeding, rather than continuing on the assumption it sorts itself out later.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal.
- Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- `magic-coordinator` (this routine's sole executor) is obligated to keep `slack-event-track` activity tracking current as the routine actually runs — proactive, as-it-happens posts, not only a summary batched into **sweep-comms-write**/**close-out**.
- `# Steps`/`# Closure steps` sequencing follows `magic-team/magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-comms-slack-send-message <team-member> <target> [text...]` (**ping-stale-interviews**: interview-thread nudge/re-engagement messages; **questions-then-conclude**'s autonomous invocation: post open questions to `magic-team`; Slack activity-tracking obligation)
- `--member-work-session-input-scan <team-member>` (**roll-call**: per-member status read)
- `--member-upsert-inbox-note <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]` (**librarian-confirms-roster**: refresh the `roster-note` if it drifted)
- `--magic-daily-lock-acquire <team-member> <owner-label>` (**acquire-lock**: acquire this routine's own lock)
- `--magic-daily-lock-refresh <team-member>` (**spawn-morning-review** and **fan-out-work-sessions**: hold the lock across this routine's long-running waits)
- `--magic-daily-close-state-and-unlock <team-member>` (Closure steps: release the lock)
- `--magic-daily-lock-status <team-member>` (check lock state before starting a new pass)
- `--magic-daily-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--edit-patch-from-stdin]` (**session-start**: this pass's own session tracking document, kept current as the pass proceeds; **close-state-and-unlock**'s closing content write)

## `--magic-daily-lock-acquire` / `--magic-daily-lock-refresh` / `--magic-daily-close-state-and-unlock` / `--magic-daily-lock-status` operation reference

`DistroAgentsTools.fn.sh --magic-daily-lock-acquire <team-member> <owner-label>` / `--magic-daily-lock-refresh <team-member>` / `--magic-daily-close-state-and-unlock <team-member>` / `--magic-daily-lock-status <team-member>` — the single-instance lock this routine owns, one holder at a time. `acquire` prints `ACQUIRED` on a fresh take, or `RECLAIMED_STALE:...` when a dead holder's lock is taken over, both returning 0; on contention it prints `ACTIVE:...` and returns 1, which means this pass does not start. `<owner-label>` identifies the actual running agent/process by a fixed, discoverable name, not an ephemeral session id — distinct from `<team-member>`, the calling member's own identity. `refresh` prints `REFRESHED` and is what holds the lock across a long pass, `NO_LOCK_HELD` and returns 1 when nothing is held. `close-state-and-unlock` prints `RELEASED` and sets `state: daily-finished`. `status` is a question, not a gate: it prints current lock metadata, or `NO_LOCK` when free, and always returns 0. Each takes only the arguments listed — any further flag or positional is rejected.

## `--magic-daily-state-and-lock-upsert` operation reference

`DistroAgentsTools.fn.sh --magic-daily-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--edit-patch-from-stdin]` — writes this routine's own `state-and-lock` note: the pass's session tracking content. Body content via `--from-file` or `--edit-patch-from-stdin`. Every call stamps `state: daily-running` and renews `recheck-date` itself — the caller never supplies `recheck-date`, and never names the note. Closing the routine is expressed by passing `--header:upsert:state:daily-finished`.

## `--member-comms-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>:<ts>> [text...]` — posts a message to Slack, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

## `--member-work-session-input-scan` operation reference

`DistroAgentsTools.fn.sh --member-work-session-input-scan <team-member>` — read-only: one member's own current work-session input — personal, not routine-dictated (every armed member runs this against its own name as it becomes armed, regardless of which routine triggered the arming).
## `--member-upsert-inbox-note` operation reference

`DistroAgentsTools.fn.sh --member-upsert-inbox-note <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]` — writes (creates or overwrites) a note into any member's own personal inbox; content via stdin. The `roster-note` is one continuously-updated note under a fixed filename.

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- `magic-coordinator.daily.routine` exists to give the team a regular cadence that turns backlog into actively-supervised, coordinated work — not a check-in ritual with no real dispatch behind it.
- The executor/participant split exists so supervision and cross-cutting judgment calls stay in one place, while each participant stays focused purely on its own assigned work.
- This is the team's primary rhythm-setting mechanism — the thing that makes "the team is actually working, not just has a backlog" true on any given day.
- A supervised work session actually happens — bounded, checked-in-on, not a fire-and-forget dispatch — so problems (a member stuck, an item quietly done) surface the same day instead of at the next grooming.

## Verbatim-tests (benchmarks)

- A participant's own work surfaces a board-state need outside its assigned item; it reports the need back to `magic-coordinator` rather than writing to the board itself.
- An agent that gets genuinely stuck mid-work-session moves its item from `board-running` to `board-blocked` within that same session, rather than leaving it looking active until the next grooming pass.

## Librarian Comments

### Reference

- `magic-team.coworking.routine` — the template this routine extends; its Steps are the opening this routine executes.
- `magic-team.coworking.routine` — its Closure Steps are the closing this routine executes.
- `check-process-board` (`magic-coordinator.armed.md`) — dependency-ordering recompute, **run-check-process-board**; called directly, not via `magic-coordinator.advance.routine`.
- `magic-coordinator.advance.routine` — run in full at the first closure step (**run-advance-dispatch**), as this routine's own dispatch/respawn pass; never called from the main sequence.
- the owning `partner-*`'s own diagram-sync routine — BPMN diagram staleness check, **sync-camunda-diagrams**.
- `magic-coordinator.communication-sweep.routine` — read half (**sweep-comms-read**) and write half (**sweep-comms-write**).
- `magic-team.process-inbox.routine` — the sorting pass over own inbox, **sort-incoming**; see its own "Execution mode is decided by identity match" section for why this explicit call is required.
- `magic-team/magic-team.armed.md`'s "Execution mechanisms" section — the process-flow direct-tooling-call rule this routine follows; its "Team-Member's (-specific) tooling" section for calling convention and the sole-sanctioned Slack-posting mechanism.
- `magic-team/magic-team.board.md` — the board's own state-model definition (`board-running`→`board-blocked` trigger, `board-running` entry verification) **fan-out-work-sessions** relies on.
- `magic-coordinator/magic-coordinator.armed.md`'s "Team-Member's (-specific) local rules" section — the executor's own standing operating rules this routine runs under, including the "How to hand off"/"What to hand off" dispatch rules **fan-out-work-sessions** follows.

### Conventions

None currently known beyond this file's own Local rules.
