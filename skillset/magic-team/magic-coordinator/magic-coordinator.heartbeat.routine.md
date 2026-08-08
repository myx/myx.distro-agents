---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# routine-heartbeat — the actual procedure

# Summary

Routine-heartbeat is the team's continuous, self-driven operating rhythm — comms, inbox processing, once-daily grooming, and the daily meeting's work-session fan-out — so the team acts without a human re-triggering each step.

## Goals

- Continuous, self-driven operating rhythm — not gated on a human re-triggering each step:
  - comms checked and replied to promptly
  - inboxes processed
  - backlog groomed once a day
  - daily meeting's work-session fan-out actually happens
- Self-driven via `ScheduleWakeup`/`SendMessage` nudges — the team's own operating cadence doesn't depend on continuous human observation.
- Defines the team's whole 7-day operating rhythm.

## Scope

- Does:
  - Thin orchestration layer — calls `routine-grooming`/`routine-daily`/`routine-communication-sweep`/`routine-advance` unchanged, no core-logic rewrite of any of them.
  - Runs `routine-advance` every `next-iteration`, at the end of the loop.
  - Triggered only by **"Magic, do main loop"**/**"Magic, start main loop"** — starts the `main-loop` iterator (`main-loop-mode`), which spawns a fresh `next-iteration` every cycle.
    - Ongoing resource commitment (30s-2min-ish cadence, potentially hours) — the iterator is never started implicitly just because this routine exists.
- Doesn't do:
  - Self-schedule or idle-wait for anything — one bounded pass per `next-iteration`, then exits.
  - Isn't one of "the four" (daily-meeting/retro/grooming/one-on-one) — the daily meeting remains where bigger, human-supervised decisions get made.
  - Doesn't currently call `routine-retro` from any default branch (only grooming and daily-meeting are called) — `routine-retro`'s own "Autonomous invocation" addendum exists for consistency, not because the current design invokes it.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud. Each step below runs once per `next-iteration`, in sequence — one bounded pass, not a continuous loop of its own.

0. **Check required config** — `--magic-heartbeat-config-check` operation.
   - Message whatever session spawned this `next-iteration` (`SendMessage`) with the outcome — each missing key's line already carries its own exact fix command.
   - **On failure**: `sleep 15`, then exit — no further steps run this cycle, nothing else touched.
   - **On success**: continue.
1. **Acquire the lock** — `single-instance-lock` procedure, `--magic-heartbeat-lock-acquire` operation.
   - Message whatever session spawned this `next-iteration` (`SendMessage`) with the outcome.
   - **On failure**: `sleep 15`, then exit — no further steps run this cycle, nothing else touched.
   - **On success**: continue.
   - **An anomaly here (an undocumented lock state, an unexpected owner/meta) is assess→investigate work**: governed by `magic-coordinator.harness.md`'s `harness-session-rules`, not restated here.
2. **Direct tooling calls, no console session** — this `next-iteration`'s own execution model, per `magic-team.armed.md`'s process-flow rule: no Keep-Alive Console Session opens, none is assumed.
   - Every command from here on (`DistroAgentsTools.fn.sh` or any other shell check) goes through `mcp__myx_common__lib_execShStdin` — never Bash, Python, or any other tool that runs a process directly.
   - Every `heartbeat-state-note` update goes through `--magic-heartbeat-state-upsert` via `lib/execShStdin` — never the Edit/Write tools, never a raw shell redirect, never a raw Bash call.
   - That record is rewritten every `next-iteration`; a permission prompt on it halts this whole unattended loop until a human clicks it.
3. **Start a Slack thread in `slack-event-track`** — `--member-slack-send-message` operation, literal target argument `event-track` (no `slack-` prefix), a short opening line for this `next-iteration`.
   - Not `slack-magic-team` — that's the human-facing channel; this thread is this routine's own execution log for this run.
4. **Read the `heartbeat-state-note`**, branch per the `day-rhythm-state` procedure — weekend / first-today / later-today.
5. Run one bounded step for that branch — not everything at once; each sub-step's own calls are direct per step 2, no shared session to carry between them.
   - After each sub-step: post a short progress report into the thread opened in step 3.
   - Between each sub-step: check for incoming console messages and messages from sub-spawned and parent sessions — same think/spawn/relay pattern `magic-coordinator.armed.md`'s shared loop-body rule uses for the outer cycle, applied here to this `next-iteration`'s own internal sub-steps.
   - Sub-steps, in order:
     - **Heartbeat board scan** (first, every `next-iteration`): call the `--magic-heartbeat-input-scan` operation to load this routine's own board-scan input before Comms/Board-advance execution.
     - **Comms** (every `next-iteration`, any day): one full `routine-communication-sweep` iteration, all six of its steps.
       - Includes the mandatory `conversations.replies` check on every open thread — a `conversations.history`-only check misses replies already sitting in open threads.
     - **Inbox processing, immediately after Comms**:
       - Run `routine-process-inbox magic-coordinator` — inline execution, own identity. This loop is that routine's regular caller, not its only invocation path (see `routine-process-inbox` for standalone/ad hoc invocation and the morning self-review).
       - Items owned by a non-acting owner (human-owner, external contacts): run `routine-external-inbox-handle-loop` — their content lives inside `magic-coordinator`'s own inbox too, since they have no skill folder of their own.
       - Items owned by an acting member: leave for the next `routine-daily`/`routine-grooming` pass to fold into that member's properly-registered assignment, unless there's a specific reason to invoke `routine-process-inbox` standalone for that member right now.
         - **Automatic nudge**: content that looks stale (age-based, same light check this sub-step already does across acting members' inboxes) gets a `warning-*` board-item in `board-blocked` instead of silently waiting — `recheck-date` set to today, `condition: <member> hasn't processed inbox item <item-filename> yet`, referencing the stale item. Already one open for this item: refresh `recheck-date` only, don't duplicate.
       - **GC**, generalized across every `processed/` folder in the tree, not just the board's own, same pass:
         - Check whether any `board-processed` item, has passed its (type-dependent) retention threshold.
         - If so, remove it — not a direct delete, `rm` needs explicit permission granted separately by the human-owner — except, checked in this order:
           1. `archive: true` on the item diverts it to `archived/` instead (see the board's own `archived/` entry) — checked first, always wins. Applies the same to `board-processed` items and per-member `<member>/processed/` log entries.
           2. Failing that, **`board-processed` items only** — a per-member log entry carries no `references:` field at all (the board's own "Per-member `<member>/processed/` file shape" note: no `references`/`owner` fields, this isn't the board's own `board-item` model — so this check never fires for one): an item still referenced by another live board-item diverts it to `board-retained` instead (see the board's own `retained/` entry). A qualifying reference:
              - originates from an active state (`board-backlog`/`board-pending`/`board-running`/`board-blocked`/`board-parked`) or from `board-archived` itself — one from another `board-processed`/`board-retained` item, or from an already-removed item, never qualifies, which is what stops two mutually-referencing concluded items from retaining each other forever.
              - is also structurally load-bearing — something else's own resolution genuinely depends on this item remaining resolvable, not merely any incidental passing mention (`references:` is documented elsewhere as informational/soft, and an unrestricted reading risks `board-retained` slowly absorbing most of `board-processed` over time).
         - `archived/` and `retained/` are diversions from the default removal path; only one ever applies, `archive: true` taking precedence when both would otherwise fire.
         - For `board-processed` items specifically, removal means calling the `--magic-heartbeat-board-item-trash` operation. Per-member `<member>/processed/` log entries aren't board-items and have no tooling op yet backing their own removal — flagged as a real gap, not silently invented a mechanism for here.
         - GC is not a separate routine, it's folded in here — this generalization is what makes every member's own `processed/` folder a maintained, bounded log rather than an ever-growing pile with no external steward.
     - **Test email report** (hourly cadence, testing only): a conditional, date/context-based step, not a separate routine — happens after the Comms step above, not every `next-iteration`.
       - This is the still-undesigned evening day-wrap-up email report, run **hourly instead of once-daily purely for closer testing convenience** — a literal frequency change, not a timescale/ratio compression of the eventual real cadence.
       - Two intended cadences exist in the eventual design (hourly-during-the-day, and one evening wrap-up), neither fully specified yet — this step exists only to exercise the send mechanism while real cadence/content design waits on the human-owner seeing real hourly test reports in practice.
       - Independent of the day-rhythm state machine's own checks — the two never get coupled; this step runs (or doesn't, per the hourly check) regardless of which of the weekend/first-today/later-today branches this `next-iteration` is in.
       - Content: the plain-text placeholder must be a real, readable, multi-section structure, not one line:
         - **Board statistics** — one line per board state (`board-backlog`, `board-pending`, `board-running`, `board-blocked`, `board-parked`, `board-processed`, `board-archived`, `board-retained`) with its count, computed live at send time via `magic-tooling` (`find`/`wc` per `board-<state>` folder) — never cached or persisted as standing state.
         - **Active processes** — one line per active/blocked item naming it and its state (in-work/blocked/etc.), not just a number.
         - Shape: an iteration/timestamp header line, then the Board statistics section, then the Active processes section.
       - Full HTML/multipart layout redesign stays deferred (the text-vs-HTML question is still open) — this is a content/structure floor, not the eventual full design.
       - Sent via the same sanctioned bot-credential mechanism `routine-close-session`'s broadcast step already uses — never a session's own personal mail connector.
       - Cadence check: track `last_test_email_sent` in the `heartbeat-state-note` and check "has an hour passed" the same mechanical way the day-rhythm check works — not fired every single `next-iteration` regardless of the fast-tier's 30s-2min cadence.
     - **First-today only**: a small `routine-grooming` pass plus librarian context prep, plus a batched `magic-librarian` own-inbox processing pass — collect all pending doc-fix notes, apply together in one multi-update run (`magic-librarian`'s own "Own inbox: collect and batch, don't fix ad hoc" standard).
     - **Later-today**: `routine-daily`'s flow, watching for planned work-sessions.
     - **`heartbeat-state-note` update**: a small, mostly-static state record, not a running history — updated every single `next-iteration`, not just narrative-notable ones.
       - The structured header block (`last_iteration_date`/`last_iteration_timestamp`/`today_stage`/`active_project`) is refreshed to this `next-iteration`'s own values each time, never left at an earlier `next-iteration`'s values — a stale header is indistinguishable from a stopped loop to anyone checking it.
       - The file's "Last iteration" section is overwritten each `next-iteration`, not appended to — one short paragraph replacing the previous one, not a growing tail.
       - Anything worth a permanent record does not accumulate here — it goes to one of two places: this `next-iteration`'s own `slack-event-track` thread (step 3), for anything about this run specifically; or a `magic-coordinator/inbox/` reflection memo, for anything that should outlive this single run.
     - **Stale-flag escalation**:
       - Trigger: the same open decision-point already flagged in a prior `next-iteration`'s `active_project` field or `slack-magic-team` trace (matched by its own recorded wording, not a brand-new occurrence), still carried forward unresolved across roughly 5+ consecutive `next-iteration`s or ~1 hour of elapsed time, whichever comes first.
       - Action: escalate it **exactly once** — a direct, focused `slack-magic-team` post naming the specific decision needed, not another repeat of the flag — instead of continuing to silently re-flag it every subsequent iteration with no one ever actually asking.
       - Does **not** authorize deciding the flagged question itself — still `main`/the human-owner's call, unchanged. It only converts "flagged repeatedly, never asked plainly" into "asked once, clearly," consistent with the standing "batch human-hands-on items, don't drip them" posture, applied here to stale decision-flags rather than physical actions.
       - Once escalated: record `escalated: <timestamp>` alongside the flag in the `heartbeat-state-note`'s `active_project` field, and don't re-escalate the same flag on later `next-iteration`s unless the human-owner's response itself calls for a follow-up.
     - **Board advance, end of loop, every `next-iteration`**: one `routine-advance` pass. Every pass, no first-today/later-today gate.

# Closure steps

1. **Release the lock**, per the `single-instance-lock` procedure, using the `--magic-heartbeat-lock-release` operation.
2. **Conclude the `slack-event-track` thread opened in step 3** via the `--comms-slack-react` operation, reacting ✅ on that thread — a direct `lib/execShStdin` call, same as every other call this `next-iteration` makes.
3. **Report status** to whatever session spawned this `next-iteration`, via `SendMessage`, then exit.
   - `SendMessage(to:"main", ...)` always reaches the true root, never a mid-tree ancestor — if the actual spawner is `main-loop-mode`'s own iterator rather than root, report to `"main"` instead and let it relay down.
   - Repeating, if it happens at all, is entirely up to whatever spawned this `next-iteration` — never this routine itself.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines - not visible outside this file.

## `day-rhythm-state` procedure

- Persistent record: the `heartbeat-state-note` — read via the `--magic-heartbeat-state-read` operation, written via `--magic-heartbeat-state-upsert`.
- Owned/written by whichever session actually executes this routine's own `next-iteration` (in practice, `magic-coordinator`).
- Minimum fields: `last_iteration_date`, `last_iteration_timestamp`, `today_stage` (`not_started` → `grooming_done` → `daily_done` → steady-state cycling), `last_test_email_sent` (see step 5's Test email report sub-step), `human_owner_broadcast_thread_ts` / `human_owner_broadcast_thread_date` (the captured `channel:ts` of today's first human-owner-facing status broadcast, e.g. `routine-advance`'s `check-execute-board` DM — treated as stale/cleared whenever `human_owner_broadcast_thread_date` != today's real date, same "recompute per real date" convention as the weekend/first-today checks above; consumed by `magic-coordinator.advance.routine.md`'s own `check-execute-board` procedure to thread same-day human-owner DMs together instead of posting each as a fresh top-level message), and a light pointer to whichever active project a dispatched work-session belongs to — just enough to satisfy the "all dispatched work sits within a project" constraint; the project schema itself stays out of scope here.
- Created lazily on first real run.

- **First-iteration-today test**: compare `last_iteration_date` to today's real date.
  - Mismatch or file absent → this is the first `next-iteration` today: run `routine-grooming` after `magic-librarian` preps context, then move into `routine-daily`'s flow.
  - Match → resume from `today_stage`.
- **Weekend detection** (recompute weekday from real system date every `next-iteration`; Sat/Sun triggers this):
  - ALLOW: comms sweep. Reactive admin (todo/record updates), only in direct response to an actual incoming request.
  - DENY by default: dispatching grooming/daily-meeting/work-sessions; advancing `today_stage` past comms.
  - RULE: coordinator dispatches normal work only if tied to a genuine ad-hoc human-owner activity, firsthand-confirmed by a `magic-coordinator` instance in live contact with the human-owner — trusted per `magic-team`'s own delegated-authority rule, same as any other coordinator report; no separate anchor required.
  - Unmet → DENY stands.

## `single-instance-lock` procedure

- This routine's own concern — it protects itself, since only a real filesystem lock works across separate OS processes anyway.
- Implemented as a `--magic-heartbeat-lock-*` option group in `DistroAgentsTools.fn.sh` (`myx.distro-agents/sh-scripts/`, body in `sh-lib/AgentsTools.MagicHeartbeat.include`) — don't hand-roll the mkdir/heartbeat logic inline, call these ops via `mcp__myx_common__lib_execShStdin`, the same way as every other `DistroAgentsTools.fn.sh` call, never raw Bash.
- The lock directory's parent is pre-created by the tool so the `mkdir` on the final lock-directory path component stays a single atomic call — storage location itself is resolved and owned by the tool internally (the same board-location config the sibling `--magic-heartbeat-state-*`/`--magic-sweep-state-*` ops use), never a path this doc states or a caller supplies.

- The `--magic-heartbeat-lock-acquire` operation attempts the `mkdir`. Prints `ACQUIRED` and returns 0 on success. On failure it checks the existing lock's heartbeat age: stale (>15 min) reclaims it (`RECLAIMED_STALE:...`, returns 0, treating it as a crashed prior owner); fresh prints `ACTIVE:owner=...:since=...:heartbeat_age=...` and returns 1.
- The `--magic-heartbeat-lock-heartbeat` operation refreshes the heartbeat timestamp; call periodically if a single run's own work (e.g. a first-today grooming + daily-meeting fan-out) runs long, so a concurrent check doesn't mistake a slow-but-alive run for a stale one.
- The `--magic-heartbeat-lock-release` operation removes the lock; called as this routine's own last step, every time.
- The `--magic-heartbeat-lock-status` operation prints current lock metadata; what anyone deciding whether to start a new run should check first.

## `spawn-proxy` procedure

This routine executes spawn requests itself via `DistroAgentsTools.fn.sh --magic-heartbeat-spawn-proxy`.

- **Protocol shape is mandatory**: every spawn attempt must carry a structured prompt packet and produce a structured receipt packet.

### Prompt packet (required)

```text
SPAWN-REQUEST: <short label, e.g. "librarian-morning-review">
GOAL: <one-line description -- same as Agent's own description field>
CONTEXT: <self-contained prompt body>
NAME: <fixed name to spawn under, or omit for one-shot>
WAIT: <yes|no>
```

Exact formatted example:

```text
SPAWN-REQUEST: librarian-morning-review
GOAL: Run routine-librarian-morning-review for board state-shape drift check
CONTEXT: Review magic-team board files and report only actual drift findings.
NAME: routine-librarian-morning-review
WAIT: no
```

- Field rules:
  - `SPAWN-REQUEST` required.
  - `GOAL` required.
  - `CONTEXT` required.
  - `NAME` optional.
  - `WAIT` required (`yes` or `no`).
- Source rules:
  - Prompt packet comes from stdin by default, or from one explicit selector:
    - `--from-board <board-item-name> [--board-state <state>]...`
    - `--from-vault <audit-item-name>`
    - `--from-audit <vault-item-name>`
  - Compatibility path `--from-file` may exist for legacy callers but is not the documented path for routine usage.

### Receipt packet (required)

```text
RECEIPT_ID=<id>
RECEIPT_FILE=<path>
STATUS=<started|succeeded|failed>
PID=<pid-if-async>
EXIT_CODE=<code-if-wait>
OUTPUT_FILE=<path>
```

Exact formatted example:

```text
RECEIPT_ID=heartbeat-20260806T095318Z-9f3a1c2e
RECEIPT_FILE=/runtime/md/heartbeats/receipts/heartbeat-20260806T095318Z-9f3a1c2e.receipt
STATUS=started
PID=48217
EXIT_CODE=
OUTPUT_FILE=/runtime/md/heartbeats/receipts/heartbeat-20260806T095318Z-9f3a1c2e.output
```

- `RECEIPT_ID` and `RECEIPT_FILE` are mandatory outputs on every call.
- This routine's caller records receipt evidence on the related board item as `execution-receipt`.
- `WAIT: no` is default path (async, `STATUS=started`); `WAIT: yes` is for explicit blocking cases.
- Any spawn-required branch that cannot produce a successful proxy call in the same pass is a hard execution failure and must follow `routine-advance` parked fallback (never silent defer).

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-coordinator` (this routine's sole executor) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- This routine is a scheduler tick — each `next-iteration` checks what's due against `magic-team`'s own calendar/full-sprint routine (comms cadence, once-daily grooming, the daily meeting) and acts on exactly what's due this pass, nothing more.
- **Per-platform pacing, not one interval for everything**:
  - **Fast tier** (Slack, email, Trello's notification-stream check) — check roughly every 30s-2min, since these are where a human is most likely waiting on a timely reply.
    - Trello belongs here, not slow tier — its `GET /1/members/me/notifications?since=...` check (`routine-communication-sweep` documents it) is exactly as cheap as an email/Slack check, so it runs on the same cadence, not a reduced one.
  - **Slow tier** (reading/grooming/analyzing full Trello board content, plus Google Drive/Sheets, Confluence, and any similar deep-content platform that joins later) — check every few cycles of the fast tier, or only from `routine-grooming`, instead of every single one; genuinely heavier and less time-sensitive than "is there anything new."
  - Google Drive/Sheets is out of this loop's fast tier entirely (per `routine-communication-sweep`'s Scope section) — it's an extended procedure for grooming/search, living in the slow tier above alongside deep Trello board work, not polled on its own schedule.
  - Exact cadence is a runtime parameter based on actual API limits and real activity levels, not fixed here.
- **Guardrail: acting alone doesn't mean acting unsupervised in spirit.** Running unattended is exactly the situation where the existing caution rules matter most, not least — the "no unilateral epics" rule, the standing send/confirm rules per platform, and "don't manufacture work when there's nothing real to do" all apply at full strength inside every sweep and every sub-routine this routine runs, not a relaxed version of them.
- **No inline invention during a real `next-iteration`**:
  - A real (non-testing, non-investigation) `next-iteration` follows existing instructions and existing precoded tooling as written — one plain tool call at a time, never a hand-built multi-step script or a novel command sequence invented on the spot.
  - A genuinely better/novel approach occurring mid-`next-iteration` is not built or run inline — it files an idea/proposal as an initial task (the idea → interview → proposal → approval pipeline) and keeps working the current `next-iteration` on existing, already-approved instructions/tooling in the meantime.
  - The invented approach only becomes usable once it's actually been interviewed and approved through that pipeline and applied for real — never adopted unilaterally inside a `next-iteration` just because it seemed like a good idea in the moment.
  - Exception: testing/investigation/verification sessions (e.g. a `magic-tester` dispatch, a build/design coworking session) — hand-constructed commands and exploratory scripting are normal and expected there; this rule is scoped to a real production `next-iteration`'s own execution specifically.
  - Governs *invention* — don't hand-roll a new command sequence when a plain DistroAgentsTools op already exists.
  - Distinct, companion concern to how much to trust/re-verify a DistroAgentsTools call that's already being made correctly: default-trust it blindly day to day, re-check a specific call site only when a real incident actually traces back to it.
- **Routing discipline covers *all* new work, not just novel/hand-rolled ideas.**
  - Sharper than the invention guardrail above in two ways: it isn't scoped to *novel* approaches that occur mid-`next-iteration` — it covers ordinary task intake generally, any real change work of any kind, wherever it originates; and it applies to daily-meeting too — a daily-meeting work-session dispatch executes against already-approved instructions/tooling the same way a `next-iteration` does, it doesn't get to skip the queue just because a human happens to be present for that routine.
  - New work (a fix, a change, an improvement someone notices) always gets filed into the relevant inbox or a queued board state first; `main-loop-mode` (or whichever routine is actually running) is the mechanism designed to pick it up from there, not something to route around because it's convenient in the moment.
  - A live, explicit, real-time override from the human-owner in direct response to an active blocker (e.g. "build this specific thing right now") is still the one recognized exception to "always queue" — a generalizable idea noticed while working is not.
- **Relationship to `main-loop-mode`**:
  - Before `main` decides whether to relay into an already-running `main-loop` or spawn a fresh one, it checks the lock status via the `--magic-heartbeat-lock-status` operation. Held means a `main-loop` is presumed already running; free means it isn't.
    - Reliable-enough signal in practice: each `next-iteration` holds the lock for its own real execution time, normally longer than the gap between cycles, so status reads "held" far more often than "free" while a healthy iterator is alive.
  - While running, the iterator (`main-loop`) is an ordinary root, coexisting normally with any other root.
  - `main` stays interactive, relaying status and forwarding any new ask to `main-loop` via `SendMessage` rather than executing cycle steps itself.
  - To stop, `main-loop` lets its current `next-iteration` sub-session finish (its own Closure steps release the lock as the first of those), sends a final status update to `main`, and ends without spawning another cycle.
  - Per-cycle lock reporting: each `next-iteration` messages `main-loop` (`SendMessage`) with the lock outcome for that run — acquired-and-completed, or acquire-failed-and-exited-early (step 1).
    - `main-loop` uses this to know whether real work happened this cycle; it never calls the lock ops itself.
  - Runtime cap: `main-loop` doesn't stop on its own — it keeps cycling until the user says stop or a soft safety cap of roughly 8 hours total runtime is reached.
    - Approaching the cap: let the current `next-iteration` finish (its own Closure steps release the lock), leave a clear note, then stop rather than hard-cutting mid-iteration.
- A permission prompt appears mid-`next-iteration`: a direct `lib/execShStdin` call should never trigger one — it's a sign a call bypassed the mandated tooling channel, or a real config/auth gap. Stop and fix it, don't click through and continue as if it were normal.
- A day's real activity level doesn't match the assumed weekend/weekday branch: still follow the branch logic as written — the day-rhythm state machine is date-driven, not activity-driven, so low activity is not a signal to skip steps, only genuinely being a weekend is.
- **DistroAgentsTools trust policy**: `DistroAgentsTools.fn.sh` is the team's own tool.
  - Trust it by default day to day — no defensive re-verification of its own correctness on every call.
  - Propose interface changes through the normal idea → interview → proposal → approval pipeline — never as an inline bypass.
  - Re-check a specific call site only when a real incident actually traces back to it.
- **Goal-directedness**: when a goal is set for this session, actively work to move the process toward that goal.
  - Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-slack-send-message <team-member> <target> [text...]` (step 3: open the `event-track` thread)
- `--comms-slack-react <channel>:<ts> <emoji-name>` (Closure steps: close the `event-track` thread with a checkmark)
- `--magic-heartbeat-config-check` (step 0: check magic-coordinator config upfront, before anything else runs)
- `--magic-heartbeat-input-scan <team-member>` (step 5: load heartbeat board-scan input)
- `--magic-heartbeat-lock-acquire <team-member> <owner-label>` (step 1: acquire the single-instance lock)
- `--magic-heartbeat-lock-heartbeat <team-member>` (refresh the heartbeat during a long-running `next-iteration`)
- `--magic-heartbeat-lock-release <team-member>` (Closure steps: release the lock)
- `--magic-heartbeat-lock-status <team-member>` (check lock state before starting a new run)
- `--magic-heartbeat-state-read <team-member>` (step 4: read the `heartbeat-state-note`)
- `--magic-heartbeat-state-upsert <team-member> [--from-file <path>]` (steps 2 and 5: rewrite the `heartbeat-state-note`)
- `--magic-heartbeat-board-item-trash <team-member> <board-state> <item-name>` (GC step: relocate a terminal board-item to `trash/`)
- `--magic-heartbeat-spawn-proxy <team-member> [--from-file <path>|--wait]` (spawn relay used by unattended heartbeat/advance execution paths)

## `--member-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

## `--comms-slack-react` operation reference

`DistroAgentsTools.fn.sh --comms-slack-react <channel>:<ts> <emoji-name>` — posts one Slack reaction (`reactions.add`) to a specific message. `<channel>:<ts>` only, no `magic-team`/`human-owner` shortcut, since a reaction always targets one exact message, not a channel. `<emoji-name>` has no colons (e.g. `white_check_mark`, not `:white_check_mark:`). An `already_reacted` error is treated as a harmless no-op, not a failure. This routine's own Closure-steps usage: `event-track:<thread-ts> white_check_mark`.

## `--magic-heartbeat-config-check` operation reference

`DistroAgentsTools.fn.sh --magic-heartbeat-config-check` — takes no arguments, always checks magic-coordinator's own config. Prints one `<KEY>: OK`/`<KEY>: FAIL` line per key (name only, never the value) for `TEAM_DATA_DIRECTORY`, `SLACK_BOT_TOKEN`, `SLACK_CHANNEL_EVENT_TRACK`, `SLACK_CHANNEL_MAGIC_TEAM`, `SLACK_CHANNEL_HUMAN_OWNER`, `EMAIL_IMAP_HOST`, `EMAIL_USER`, `EMAIL_APP_PASSWORD`, `TRELLO_KEY`, `TRELLO_TOKEN`, each FAIL with its own exact fix command. Only `TEAM_DATA_DIRECTORY` gates the exit code (1 if missing); the rest are informational — a FAIL there returns 0 regardless.

## `--magic-heartbeat-input-scan` operation reference

`DistroAgentsTools.fn.sh --magic-heartbeat-input-scan <team-member>` — read-only: this routine's own board scan (name deliberately doesn't echo this routine's own name). Always `--all-types`. Always scans `backlog/pending/running/blocked/parked`, always every frontmatter field — no caller-facing `--state`/`--header` override. An interim default (a broad "pulse of the whole active board" reading), not yet tied to one specific consuming step's own verified text the way sibling ops' defaults are.

## `--magic-heartbeat-lock-acquire` operation reference

`DistroAgentsTools.fn.sh --magic-heartbeat-lock-acquire <team-member> <owner-label>` — `mkdir`-based mutex on a lock directory the tool resolves and manages internally (see this routine's own `single-instance-lock` procedure above; storage is never a path this doc states or a caller supplies), 900s stale threshold. `<owner-label>` should identify the actual running agent/process by a fixed, discoverable name (e.g. `"main-loop"`), not an ephemeral chat/conversation-session id — distinct from `<team-member>`, which is the calling team-member's own identity. Prints `ACQUIRED` and returns 0 on a fresh acquire; `RECLAIMED_STALE:prev_owner=...:age=...s` and returns 0 if the existing lock's heartbeat is older than 900s (treated as a crashed prior owner); `ACTIVE:owner=...:since=...:heartbeat_age=...s` and returns 1 if a fresh lock is genuinely held by someone else. This routine's own step 1 usage: `<team-member> "<owner-label>"`.

## `--magic-heartbeat-lock-heartbeat` operation reference

`DistroAgentsTools.fn.sh --magic-heartbeat-lock-heartbeat <team-member>` — refreshes the lock's heartbeat timestamp so a long-running holder doesn't get mistaken for a stale/crashed one by a concurrent `--magic-heartbeat-lock-acquire`. Prints `HEARTBEAT_OK` and returns 0 if a lock is held; `NO_LOCK_HELD` and returns 1 otherwise.

## `--magic-heartbeat-lock-release` operation reference

`DistroAgentsTools.fn.sh --magic-heartbeat-lock-release <team-member>` — removes the lock directory (`rm -rf`, not `rmdir` — it holds a real `meta` file, not just an empty marker). Always prints `RELEASED` and returns 0.

## `--magic-heartbeat-lock-status` operation reference

`DistroAgentsTools.fn.sh --magic-heartbeat-lock-status <team-member>` — read-only, always returns 0. Prints the lock's raw `meta` file contents (`owner=`/`pid=`/`start=`/`heartbeat=`) if held, or `NO_LOCK` if not.

## `--magic-heartbeat-state-read` operation reference

`DistroAgentsTools.fn.sh --magic-heartbeat-state-read <team-member>` — read-only: prints the whole `heartbeat-state-note` on stdout, verbatim. Prints `NO_STATE` and returns 0 when nothing is stored yet — a normal first-run outcome, not an error, the same "absent is not a failure" contract as `--magic-heartbeat-lock-status`'s own `NO_LOCK`. `<team-member>` is the only argument.

## `--magic-heartbeat-state-upsert` operation reference

`DistroAgentsTools.fn.sh --magic-heartbeat-state-upsert <team-member> [--from-file <path>]` — writes (creates or overwrites) the `heartbeat-state-note`. Content comes via stdin by default, or via `--from-file <path>` (never a bare `--file`). Every call replaces the whole record; it never appends. Empty content is refused rather than written, since an erased record reads back as "no state yet" and would re-run a day's grooming. Takes no filename or path argument — storage is the operation's own concern, which is what keeps ordinary iteration from ever rewriting a skillset file.

## `--magic-heartbeat-board-item-trash` operation reference

`DistroAgentsTools.fn.sh --magic-heartbeat-board-item-trash <team-member> <board-state> <item-name>` — relocates one terminal board-item out of the board entirely, for this routine's own GC step. `<board-state>` is the item's current real board state (`backlog/pending/running/blocked/parked/processed/archived/retained`); `<item-name>` is a bare filename. Thin wrapper, always trashes, never restores — restoring is a separate, internal-only capability, not exposed through this op.

## `--magic-heartbeat-spawn-proxy` operation reference

`DistroAgentsTools.fn.sh --magic-heartbeat-spawn-proxy <team-member> [--from-file <path>|--wait]` — executes a spawn prompt through `DistroAgentsConsole.sh` and writes a runtime receipt (`RECEIPT_ID`/`RECEIPT_FILE`, plus `OUTPUT_FILE`) for per-item execution accounting. Body source is exactly one of stdin (default) or `--from-file <path>`; empty body is rejected. Default mode is async (`STATUS=started` + `PID`), while `--wait` blocks for completion and returns non-zero on failure.

# Maintainer Notes

Used to check this files own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- `routine-heartbeat` is a thin orchestration layer over `routine-grooming`/`routine-daily` — it feeds the daily meeting better material, it doesn't replace human-supervised decisions.
- New work always files into the relevant inbox or board queue first — never routed around because it's convenient in the moment.
- Give the team a real, continuous operating rhythm instead of only ever doing work when a human happens to be present asking for it.

## Verbatim-tests (benchmarks)

- New work discovered mid-loop files into the relevant inbox or board queue rather than `main-loop` routing around it inline because it's convenient.
- If this routine is already running (holding its own lock) and gets invoked again from anywhere, the second invocation's own lock-acquire fails and it exits without duplicating any work.

## Librarian Comments

### Reference

- `routine-communication-sweep` — the Comms sub-step, every iteration.
- `routine-advance` — the Board-advance sub-step, every iteration, end of loop.
- `routine-process-inbox` — inbox-processing sub-step: one call per pass on `magic-coordinator`'s own inbox, this loop being that routine's regular caller.
- `routine-external-inbox-handle-loop` — non-acting-owner inbox variant, folded into the same sub-step.
- `routine-grooming` — first-today-only sub-step (autonomous-invocation mode).
- `routine-daily` — later-today sub-step.
- `routine-retro` — carries an "Autonomous invocation" addendum for consistency, not currently called by any default branch.
- `heartbeat-state-note` — day-rhythm persistent state, librarian-owned.
- `magic-team/magic-team.armed.md`'s "Execution mechanisms" section — the process-flow direct-tooling-call rule this routine's own step 2 follows; its "Team-Member's (-specific) tooling" section for calling convention and the permission-prompt diagnostic.
- `magic-team/magic-team.armed.md` — delegated-authority rule the weekend-detection branch relies on.
- `magic-coordinator/TEAM-ORGANIZATION-VISION.md` — the main-loop-elevation facets and architect-resolution addendum.
- `magic-librarian/magic-librarian.armed.md`'s `own-inbox-batch-processing` procedure — "Own inbox: collect and batch, don't fix ad hoc" standard, applied by the first-today-only sub-step.
- `magic-team/magic-team.board.md` — `archived/`/`retained/` diversion entries, per-member `processed/` file shape, used by the GC sub-step.
- Trigger mechanics live in `magic-coordinator.armed.md`'s `main-loop-mode` mechanics instead, not here.

### Conventions

- This is the largest/densest routine folder in the team — preserve the single-instance lock mechanics, the day-rhythm state machine, the per-run bounded-iteration shape, the stale-flag escalation rule, and the "process-flow runs as direct tooling calls, no console session" rule precisely. Summarizing any of these away risks silently reintroducing the failure modes each one exists to prevent.
