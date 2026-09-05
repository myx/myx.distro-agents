# Routine conventions — proposal and audit

Scope: the 18 `*.routine.md` files under `skillset/magic-team/`. Investigation only; no file edited.

Method: Part 1 built on the routine contract already in `magic-team.shared.md` § Routine and `templates/routine.contract.format.md`. Part 2: structural checks by script over all 18 files; semantic checks (trigger, goal, state, exit, the six properties, overlap) by three independent readers, six routines each; every cross-file claim in the table re-verified by grep before inclusion.

# Part 1 — Proposed convention list

Tag per item: [existing] already in `shared.md` § Routine · [sharpened] existing rule made checkable · [new].

## A. Identity and naming

1. File name is `<owning-member>.<short-name>.routine.md`; `<short-name>` names the outcome (`grooming`, `ingest-task`), is unique across the skillset, and never repeats the owner. [existing]
2. Title line is `# <owning-member>.<short-name>.routine — the actual procedure`, matching the filename exactly. [sharpened — `shared.md` and the template say `# routine-<name> — …`; all 18 files use the owner-dotted form. The files are the convention; the contract text is stale.]
3. One routine, one identity: no two routines state the same Goal sentence. Where scopes touch, `## Scope › Doesn't` names the routine that owns the excluded work. [new]

## B. Metadata (frontmatter)

4. Exactly `executors:`, `maintainers:`, and optionally `invitees:`. Values are comma-separated member identifiers only; conditions on who executes what go in `# Routine's local rules`, never in the frontmatter value. [sharpened]
5. One list syntax across template and files. Template uses `[a, b]`; all 18 files use bare `a, b`. Pick the bare form and fix the template. [new]
6. `human-owner` appears in `maintainers:` iff the routine states an owner-guaranteed rule. [existing rule, now checked per routine]

## C. Trigger

7. `# Summary` carries one `Trigger:` line before `## Goals` naming what starts the routine: a schedule, a phrase, a dispatch from a named routine/member, or a board state. A routine with two triggers lists both on that line. [new]

## D. Goal

8. `## Goals` opens with one sentence naming the single end state the routine leaves behind. Further goals bullet under it. [sharpened]
9. `## Scope` has `Does:` and `Doesn't:`; each `Doesn't` item that another routine handles names that routine. [existing + sharpened]

## E. Steps

10. Every root step is `<N>. **name**:`; names are unique in-file, verb-first, and describe effect not position. [existing]
11. Steps are referenced by name only — inside the file and from any other file. "Step 3" is a defect. [existing]
12. Nested lines use the `goal:` / `rule:` / `step:` grammar. [existing]
13. A step that invokes a local procedure or another routine names it and states what comes back — the handoff value the next step uses. [new]

## F. Context and state

14. `# Summary` carries a `State:` list naming what the routine carries between steps and across runs — lock, tracking document, transcript, session-context document, recheck-date — and where each lives on disk. [new]
15. State written by a step is read back before it is reported as done. [existing human-owner rule *Recheck before reporting*, applied]

## G. Tools

16. `# Routine-specific tooling` lists every `magic-tooling` operation Steps and local procedures use, and nothing else — not more, not less. Flags (`--wait`, `--thread`) are not operations. [existing]
17. Each operation's argument syntax appears once in its Operation Reference; steps use the name only. [existing]
18. Execution is via `mcp__myx_distro__execute` only. [existing]

## H. Exit conditions

19. `# Closure steps` is never empty: either named closing steps, or the sentence *"No closing tail of its own — closed by `<X>`."* [existing; made mandatory]
20. Success is stated as an observable end state — a file, a board move, a posted message — not "when done". [new]
21. Every step that can fail states its outcome: retry (how many times), escalate (to whom), or stop. Every wait or loop carries a bound — iterations, wall-clock, or a `recheck-date`. [new]

## I. Properties

22. **Deterministic** — every branch condition is an observable fact (a file exists, a field equals a value, a timestamp has passed). A branch on a judgment ("if the item is important") is a defect unless the judgment is delegated to a named procedure that returns a value. [new]
23. **Idempotent** — running twice on the same state produces the same end state. Every write is an upsert or is guarded by a stated "already done" check. [new]
24. **Bounded** — every loop, poll, and wait has a cap; the routine as a whole has a maximum duration or iteration count. [new]
25. **Observable** — every run leaves one durable record (transcript, board item, or event-track post) and every state-changing step says where it posts. [existing pattern, made mandatory]
26. **Composable** — a routine invoked from another is called by name with stated inputs and outputs; no routine reaches into another's `# Routine's local procedures`. [existing "not visible outside this file", plus inputs/outputs]
27. **Fail-safe** — a step that cannot run as written escalates or fails loud, never substitutes a tool or path; an aborted run leaves state consistent — lock released, tracking item updated, no half-written file. [existing "fail loud", plus cleanup]

## J. Maintainer sections

28. `## Verbatim-goals` and `## Verbatim-tests` each have at least one entry; every test is a scenario → outcome pair. [existing]
29. `### Reference` lists every file the routine reads or writes. [existing]

## K. Duplication

30. A step block that appears in more than one routine (`process-own-inbox` ×10, `session-start` ×5, `acquire-lock` ×4, `keep-tracking-item-current` ×2) is either a named procedure in one owning file invoked by name, or is deliberately duplicated and carries a `same as <routine>'s <step>` marker so the librarian's drift check can pair the copies. [new]

---

# Part 2 — Audit of the 18 routines

## 2.0 Headline numbers

| convention | routines failing | note |
|---|---|---|
| 7 Trigger line in Summary | **18 / 18** | trigger text exists somewhere in 7 files (Scope, Local rules) — never as a Summary line; contradictory callers in 4 |
| 8 Goals opens with an end state | **18 / 18** | every file opens Goals with purpose or rationale |
| 14 State list | **18 / 18** | no file names its carried state or where it lives on disk |
| 22 Deterministic branches | **18 / 18** | judgment branches in every file, 3-8 each |
| 21 / 24 Failure outcome + bounds | **17 / 18** | uncapped loops or waits in all but conventions-check |
| 23 Idempotent writes | **17 / 18** | unguarded creates/posts on rerun |
| 30 Shared step blocks marked | **17 / 18** | `process-own-inbox` ×10, `session-start` ×5, `acquire-lock` ×4, none marked |
| 16 Tooling not-more-not-less | **12 / 18** | see 2.1 |
| 19 Closure non-empty or canonical sentence | **7 / 18** | all seven use the same non-canonical form |
| 10 Every root step named | **7 / 18** | 19 unnamed root steps total |
| 2 Title matches contract | **contract** | 18/18 files agree with each other, disagree with `shared.md` and the template |
| 5 Frontmatter list syntax | **template** | template uses `[…]`, 18/18 files use bare lists |
| 4 Frontmatter values parseable | 1 / 18 | `process-inbox` `executors:` is a prose sentence |

## 2.1 Structural findings (script-verified)

| routine | convention | what is wrong | change needed |
|---|---|---|---|
| all 18 | 2 | Title is `# <owner>.<short>.routine — the actual procedure`; `shared.md` § Routine and the template say `# routine-<name> — …` | Update `shared.md` line "`# routine-<name> — the actual procedure`" and the template to the owner-dotted form the files use |
| all 18 | 5 | Frontmatter values are bare lists; template shows `[a, b]` | Change the template to bare lists |
| process-inbox | 4 | `executors: any acting member (for its own inbox); magic-coordinator (for non-acting-owner content, …)` — prose, unparseable | `executors: magic-team, magic-coordinator`; move the conditions to `# Routine's local rules` |
| bootstrap | 10 | 5 of 12 root steps unnamed | Name them |
| grooming | 10 | 6 of 8 root steps unnamed | Name them |
| daily | 10 | 3 of 15 unnamed | Name them |
| ingest-task, one-on-one, retro, conventions-check | 10 | 1 unnamed each | Name it |
| communication-sweep | 11 | one "step N" reference | Replace with the step name |
| advance | 16 | declared, unused: `--magic-advance-lock-status` | Remove or use |
| communication-sweep | 16 | declared, unused: `--member-comms-email-check/-mark-seen/-send`, `--member-comms-slack-send-message`, `--member-comms-trello-check` (5) | Remove, or add the steps that use them — the email/Trello branches exist in prose but no step names the op |
| daily | 16 | declared, unused: `--magic-daily-lock-status` | Remove or use |
| heartbeat | 16 | declared, unused: `--magic-heartbeat-lock-refresh/-status`, `--magic-heartbeat-sleep-run`; used, undeclared: `--board-state` | Reconcile |
| retro | 16 | declared, unused: `--magic-retro-lock-status`, `--member-comms-slack-send-message`, `--member-inbox-note-upsert` | Reconcile |
| grooming | 16 | declared, unused: `--magic-grooming-create-running`, `--magic-grooming-lock-status`, `--magic-grooming-to-running`, `--member-work-session-input-scan`, `--help` | Reconcile; `--help` is not a routine operation |
| coworking | 16 | used, undeclared: `--member-comms-slack-react`, `--member-inbox-note-upsert`, `--member-inbox-reflection-upsert` | Declare them |
| ext-inbox-loop, ingest-task, one-on-one, morning-review, brainstorm, discuss | 16 | `--member-comms-slack-send-message` declared, never named in a step (and morning-review also `--member-upsert-member-inquiry`) | Either name the op in the step that sends, or remove |
| ext-inbox-loop, ingest-task, conventions-check, brainstorm, discuss, process-inbox, process-reflections | 19 | Closure is *"Invoked inline: nothing. Run as its own session: execute coworking's Closure Steps."* or *"Execute coworking's Closure Steps."* — neither named steps nor the canonical sentence | Replace with `No closing tail of its own — closed by \`magic-team.coworking.routine\`'s **close-session**.` |

## 2.2 Semantic findings, per routine

Rows from the three readers, merged. One row retracted after verification (`daily` 13 — `ping-stale-interviews` does exist as a step).

### magic-coordinator — advance, bootstrap, communication-sweep, daily, external-inbox-handle-loop, heartbeat

| routine | conv # | what is missing or wrong | specific change |
|---|---|---|---|
| advance | 7 | No `Trigger:` line. Triggers scattered and contradictory: Summary "runs every main-loop iteration… or on direct request"; Local rules "invoked inline, mid-iteration, from heartbeat"; heartbeat says a *separate spawned session via background `Agent`*; daily's **run-advance-dispatch** is a third caller. | `Trigger: spawned by heartbeat's Board-advance sub-step every next-iteration; called in full by daily's run-advance-dispatch; direct request.` Delete the "invoked inline" Local rule or fix heartbeat — pick one. |
| advance | 8 | `## Goals` opens with rationale ("The board isn't trustworthy between daily/grooming cycles…"), not an end state. | Open with: "At pass end every board item's folder matches its recorded state, every due `board-running` item carries one outcome record with `execution-receipt`, and `state-and-lock` reads `advance-finished`." |
| advance | 9 | Out-of-scope items with no owner named: "RICE scoring, any of it.", "Google Drive/Sheets.", "Trello-board-content review/grooming". `check-pending-comms-actions` cited ×5 as this routine's step; no such step exists (verified). | Name `magic-team.grooming.routine` on all three. Add a `check-pending-comms-actions` step consuming sweep's `pending-*` records, or delete every reference. |
| advance | 13 | **advance-process-inbox**, **advance-process-comms**, **advance-run-process-board** state no handoff value. | State per step what returns and which step consumes it. |
| advance | 14 | No `State:` list; carried: own lock, `state-and-lock` note, per-item `recheck-date`/`session-id`, sweep's `pending-*` records, heartbeat's `heartbeat-state-note` — none with a location. | Add `State:` with paths; mark `heartbeat-state-note` as *borrowed from heartbeat*. |
| advance | 21 | Explicitly unbounded: "re-checks on `recheck-date` indefinitely — no auto-escalation here" (verified); spawn-proxy retry every 17 min forever; `approval-*`/`inquiry-*`/`change-*` re-asks with no cap. No failure outcome for **advance-process-inbox**, **advance-read-board-state**, **advance-report**. | Add `attempts:` header and cap (3 → park + escalate); add "fails → release lock, post `event-alert`, stop" to the three steps. |
| advance | 22 | Judgment branches: conflict gate "current MCP/machine load… make a new start unsafe (no fixed max-job count)"; "Package/topic overlap"; "Ambiguous evidence"; "**what does this item's own gap actually require?**" A/B/C tree; "Judge coverage"; "a wait that has gone on too long". | Observable tests (overlap = shared `package:` value; contention = `--console-list` count ≥ N; "too long" = `recheck-date` passed) or a named procedure returning `conflict\|clear`. Drop the A/B/C tree from an "already-decided moves only" routine. |
| advance | 23 | Orphan-thread backfill: "never re-post a second backfill thread next pass" — nothing on disk records the post, so next pass posts again. "Escalate-once" names no on-item marker. | Write `channel:ts` and `flagged-at:` header before posting; gate every "once" on it. |
| advance | 24 | No pass duration cap; lock refresh "periodically" (no interval); "waiting a few seconds"; per-item loops uncapped while caller respawns every 30s–2min. | Pass cap (10 min), refresh ≤ N calls, fixed verify wait, "past cap → `no-action:pass-timeout`, close-and-unlock". |
| advance | 26 | Runs sweep's **check** + **process-each-message** only — never **update-context**, so `last_swept_ts` never advances from an advance pass. Reads/writes heartbeat's `heartbeat-state-note` via whole-record overwrite. | Call sweep in full with stated input/output; give heartbeat a field-level state op and call that. |
| advance | 27 | Tool substitution endorsed: "spawn sessions MUST first try the normal harness tool; use `--magic-heartbeat-spawn-proxy` only as fallback". No abort path between `spawn-one-dispatch` and the `session-id` write. | One spawn path per invocation mode, no fallback. Write `session-id` before confirming spawn, or park on any spawn error. |
| advance | 30 | **advance-acquire-lock** / **advance-read-board-state** / **advance-close-state-and-unlock** = daily's and heartbeat's lock block; **advance-process-inbox** = `process-own-inbox`. No markers. | Add `same as` markers or invoke a shared procedure. |
| bootstrap | 3 / 8 | Two identities: Goals/Steps are a Slack-identity bootstrap; Scope line 35 says "stands a team up in a new place — a full custom-team setup". Goals has no opening end state. | Delete line 35 or split. Open with "`magic-coordinator` can post as `Magic Vane` to the four channels with `message.user == user_id`, reported `READY`." |
| bootstrap | 7 | No `Trigger:` line; "one-time (and re-runable)" names no starter. | `Trigger: human-owner request, or harness bootstrap state before mode selection.` |
| bootstrap | 13 | **escalate-to-human-owner** and **checkpoint-ask-user** are numbered Steps invoked as procedures from steps 1-4, 8; return value unmapped. | Move to local procedures; return `{answer, re-run: <step-name>}` with a blocker→step table. |
| bootstrap | 14 | No `State:`; step 9 "Record currently required scopes" and step 6 "queue fix" name no location. | Add `State:` with scope-matrix file path and fix-queue destination. |
| bootstrap | 20 / 25 | **report-compact-outcome** "Produce one short matrix" — no destination, no durable record. | Post to `event-track`, write to a named file; success = that post plus `READY`. |
| bootstrap | 22 | "If API read is unavailable or ambiguous"; "current intended image is present and correct"; "Status line: present, role-aligned, short". | Expected image = stored hash/URL; status line = exact string; target = configured `SLACK_CHANNEL_*`. |
| bootstrap | 23 | **check-send-path** posts a probe to four channels on every run; no "already verified" guard. | Guard on stored `last_verified` + `user_id`; re-run only the failed target. |
| bootstrap | 24 | **wait-for-reply** capped, but escalate → re-run → escalate cycle has no overall cap. | Cap total escalation rounds; then stop `NOT READY`. |
| bootstrap | 27 | **checkpoint-ask-user** substitutes paths by design (AskUserQuestion → Slack IM → channels). Step 6 continues past a step that cannot run. | Branch once on attended/unattended, one path per mode; hard-fail → stop `NOT READY`. |
| comm-sweep | 3 | Scope names daily and heartbeat as callers; heartbeat has no comms step; advance is the real caller. Daily calls "read half"/"write half" this file never defines (verified: 0 definitions). | Name advance as the per-iteration caller; define `read-half`/`write-half` or delete daily's split. |
| comm-sweep | 7 | No `Trigger:` line. | `Trigger: called in full by advance's advance-process-comms; by daily's sweep-comms-read/-write; direct request.` |
| comm-sweep | 8 | Goals opens with rationale. | Open with "Every message with ts > `last_swept_ts` on every live platform has been read, reacted, acted or routed, and `last_swept_ts` equals the last fully-processed ts." |
| comm-sweep | 9 | "Google (Drive/Sheets) — extended procedure" names no routine. | "— `magic-team.grooming.routine`'s job." |
| comm-sweep | 13 / 26 | **act**: "note for the next daily", "propose a one-on-one session" name no write. Hands deferred reactions to "advance's pending-reaction-lookup step" — does not exist (verified). **process-own-inbox** no return. | Specify the note write op and filename; name the real consuming step once it exists. |
| comm-sweep | 14 | No `State:`; `sweep-state-note`, `roster-note`, `pending-*` records, own-status Trello card, session root ts all unlocated ("storage is the operation's own concern"). | Add `State:` naming each and its op/path. |
| comm-sweep | 21 | **check** "errors or ambiguous → go deliberate" — undefined; email "get human confirmation" no bound; per-message send/react failure no outcome. | Define `deliberate` procedure (1 retry, then `event-alert`, skip platform); bound the wait; error → `pending-*` and continue. |
| comm-sweep | 22 | "Approved, simple, obvious → inline / Bigger, questionable → note"; "borderline… conservative bucket"; "genuinely blocked"; "Negative outcome… assessed per case". | Size test = message names a board item with `approved-by`; fix emoji per outcome. |
| comm-sweep | 23 | Reply sent, then react/watermark fails → next pass re-replies; the file forbids using own later reply as evidence. | Use the `:ok_hand:` reaction as the already-replied guard before any send. |
| comm-sweep | 24 | **process-each-message** uncapped ("can take minutes") while caller respawns every 30s–2min. | Cap messages per pass and wall-clock; `last_swept_ts` handles resumption. |
| comm-sweep | 27 | Rule "never impersonate" vs declared op's own "retries once under the other identity". | Forbid the auto-retry for this routine, or remove the rule. |
| comm-sweep | 30 | **process-own-inbox** ×10 copy, no marker. | Add marker. |
| daily | 3 / 9 | Doesn't: "never calls `check-execute-board`" — Closure **run-advance-dispatch** runs advance in full, which runs it. **librarian-updates-context** is a no-op step. | Rewrite Doesn't to what is true; delete the no-op step. |
| daily | 7 | No `Trigger:` line; invocation in Scope. | `Trigger: "daily meeting"/"standup" request; heartbeat later-today branch.` |
| daily | 8 | Six bullets, no end state. | Open with "Every permanent member has today's assignment on the board, one supervised session per member has run to its timebox, `state-and-lock` reads `daily-finished`." |
| daily | 13 | **update-todos** (step 9) consumes **run-check-process-board**'s (step 10) output — order inverted. **sync-camunda-diagrams** invokes an unnamed partner routine. **sweep-comms-read/-write** invoke undefined halves. Four steps state no return. | Swap 9/10; name the partner routine; define the halves or call sweep in full; state returns. |
| daily | 14 | No `State:`: lock, note, `TodoWrite`, `roster-note`, ScheduleWakeup marks, SPAWN-REQUEST receipts, first-today gate. | Add `State:`; name the field carrying "morning-review already ran today". |
| daily | 21 | No failure outcome for **librarian-confirms-roster**, SPAWN-REQUEST via `main`, **sync-camunda-diagrams**; unresponsive fan-out agent at timebox unhandled. | "no reply within N min → flag once, continue"; "unresponsive → item stays `board-running`, noted". |
| daily | 22 | "needs real discussion"; "needs a real decision… genuine doubt"; "Truly unsure… default to escalation". | Observable tests (no `approved-by`; `owner:` ≠ member) or a procedure returning `inline\|escalate`. |
| daily | 23 | Same-day rerun: **post-opening-broadcast** posts a second root; **fan-out-work-sessions** re-spawns (writes no `session-id`). | Store root ts in the note and reuse; write `session-id` on each fanned-out item. |
| daily | 24 | No total duration; lock refresh "periodically". | Total cap (90 min); refresh ≤ 5 min. |
| daily | 26 | Sweep halves not exposed; partner routine unnamed. | Define halves or call in full; name the routine. |
| daily | 27 | No abort rule; two closing paths described (`--header:upsert:state:daily-finished` vs unlock op). | "on abort: post live agent ids, close with `daily-aborted`"; keep one closing path. |
| daily | 30 | **acquire-lock**/**session-start**/**close-state-and-unlock** = lock block; **sort-incoming** = `process-own-inbox`. No markers. | Add markers or shared procedure. |
| ext-inbox-loop | 7 | No `Trigger:`; Scope names "heartbeat's post-sweep inbox-processing step" — heartbeat has no sweep before it. | `Trigger: heartbeat's Inbox-processing sub-step every next-iteration; direct request.` |
| ext-inbox-loop | 8 | Rationale paragraph, no end state. | Open with "Every inbox item with a non-acting `owner:` carries a dated log entry naming this pass's action, or is resolved." |
| ext-inbox-loop | 13 / 26 | Item set undefined (how a non-acting-owner item is identified); "Retry through the same channel"/"Switch channels" name no op; only Slack send declared. | Input = items with `owner: human-owner\|external:*`; declare email/Trello ops; output = per-item action. |
| ext-inbox-loop | 14 | No `State:`; "logged back onto the item" names no op or path. | `State:` = the item file, written via `--member-inbox-note-upsert --edit-patch-from-stdin` with `last-attempt-at`/`attempts`. |
| ext-inbox-loop | 19 | Non-canonical closure. | Canonical sentence + a named **close-standalone** step. |
| ext-inbox-loop | 20 / 25 | No success state; durable record only for escalations. | Success = each item's log updated; one `event-track` line per pass. |
| ext-inbox-loop | 21 / 24 | "Retry" no count; "after reasonable attempts" no number; "'Reasonable time' is a judgment call… not a fixed threshold" (verified); DM failure no outcome; no cap. | retry ≤ 2, remind after 24 h, switch after 2, escalate after 3; DM failure → `event-alert`. |
| ext-inbox-loop | 22 | "judgment call from the item's own urgency"; "err toward one more attempt"; "will naturally get addressed"; "channel genuinely appears dead". | `last-attempt-at` + fixed intervals + `urgent:` header; dead = N consecutive send errors. |
| ext-inbox-loop | 23 | Caller runs every 30s–2min; no "already sent since X" guard. | Gate every action on `last-attempt-at` + minimum interval. |
| ext-inbox-loop | 30 | **process-own-inbox** copy, unmarked; heartbeat already ran process-inbox immediately before. | Mark, or drop step 1 when invoked from heartbeat. |
| heartbeat | 3 / 9 | Doesn't: "doesn't read, scan, or write any board item" (verified) — steps run `--magic-heartbeat-input-scan` (verified ×4), create `warning-*`, trash `processed/`, run process-inbox and ext-inbox-loop inline. Reference and Test-email cite a Comms sub-step that does not exist. | Rewrite Doesn't to what is true; delete the Comms references or add the step; name `main-loop-mode`'s owner. |
| heartbeat | 7 | Trigger in Scope, phrase only; each `next-iteration` is started by the main-loop iterator. | `Trigger: "Magic, do/start main loop" starts the iterator; each next-iteration is spawned by main-loop-mode.` |
| heartbeat | 8 | Bullet list, no end state. | Open with "At end of each next-iteration everything due per `heartbeat-state-note` is dispatched with a receipt, the note reflects this iteration, and the `event-track` thread carries ✅." |
| heartbeat | 13 | Returns unstated for process-inbox, ext-inbox-loop, grooming/daily dispatch, and the `Agent`-spawned advance (no receipt, unlike **spawn-proxy**). | State each; give the `Agent` advance a receipt or use **spawn-proxy**. |
| heartbeat | 14 | `day-rhythm-state` fields listed but no `State:`, no disk location, thread ts carried by nothing named. Ownership contradicts: "whichever session executes next-iteration" vs Reference "librarian-owned". | Add `State:` (note path, lock, thread ts); pick one owner. |
| heartbeat | 21 | No failure outcome for **open-event-track-thread**, grooming/daily **spawn-proxy** failure (`today_stage`?), GC's "type-dependent retention threshold" (undefined). | thread fails → `event-alert`, skip; dispatch fails → `today_stage` unchanged, escalate once; define retention per prefix. |
| heartbeat | 22 | "looks stale (age-based…)" no number; "Anything worth a permanent record"; weekend "genuine ad-hoc human-owner activity"; "roughly 5+ consecutive… or ~1 hour". | stale = age > 24 h; thresholds exact; weekend override = explicit header. |
| heartbeat | 23 | `grooming_done` set on `STATUS=started` or on completion — unstated; crash between dispatch and note write re-dispatches. | Write `today_stage: grooming_dispatched` + receipt immediately; `grooming_done` only on receipt success. |
| heartbeat | 24 | "one bounded pass" with no wall-clock cap; refresh "periodically"; between-sub-step message check unbounded. | Cap next-iteration (15 min); refresh ≤ 5 min; one check per sub-step. |
| heartbeat | 26 | Advance interface contradicts advance's own text. `heartbeat-state-note` declared file-local yet whole-record-overwritten by advance — lost-update race. | Promote to a shared record in `armed.md` with field-level upsert; align advance's calling mode. |
| heartbeat | 27 | **spawn-proxy** procedure says `--from-file` "is not the documented path" (verified) while this file's op reference declares only `[--from-file <path>\|--wait]` (verified ×6) — step cannot run against its own tooling. Note update ordered after dispatch. | Align op reference with advance's (`--from-board …`); move the header write to right after each dispatch. |
| heartbeat | 30 | `single-instance-lock` is the de-facto owning lock block but declared file-local; "Inbox processing" is another `process-own-inbox` copy. | Move `single-instance-lock` to `armed.md`/`shared.md` and have daily/advance invoke it, or add `same as` markers. |

### magic-coordinator — ingest-task, one-on-one, retro · magic-librarian — conventions-check, morning-review · magic-team — process-inbox

| routine | conv # | what is missing or wrong | specific change |
|---|---|---|---|
| ingest-task | 7 | Trigger in Scope prose: "Any natural-language phrasing expressing 'I need you to ingest/settle…'". | `Trigger: phrase — requester asks to ingest/settle/turn an idea into a task.` |
| ingest-task | 8 | 100+-word "why" sentence, no end state. | "End state: one settled task-description exists as a note in exactly one member inbox (or a dispatch made under live authorization)." |
| ingest-task | 9 | Doesn't lists anti-behaviours ("guess at unstated intent"), not excluded work; the real exclusions sit in step **relationship-to-grooming**. | Doesn't: "triage/RICE (`magic-team.grooming.routine`); execute the task (owning routine)". Fold the step into that line. |
| ingest-task | 13 | **process-own-inbox** no return; output (b) "Dispatch straight to execution via `magic-coordinator`" names no routine. | State return; name the dispatch routine and its input. |
| ingest-task | 14 | No `State:`. | `State: inbox note <member>/inbox/<item-filename>; no cross-run state.` |
| ingest-task | 19 | Non-canonical closure. | Canonical sentence. |
| ingest-task | 20 | Success = "once settled" — judgment. | Note exists with a `settled:` marker or an explicit `ambiguous:` list. |
| ingest-task | 21 / 24 | **gather-and-agree** loops "until the content is actually settled" — no cap; upsert failure no outcome. | Cap rounds; fallback = write with `ambiguous:` list; upsert failure → fail loud. |
| ingest-task | 22 | "actually settled"; "depending on content"; "only within `magic-coordinator`'s own mandate". | `settledness-check` procedure returning a value; inbox choice = addressed member else coordinator; (b) = requester wrote "execute inline". |
| ingest-task | 23 | `<item-filename>` derivation unstated — two runs, two notes. | Filename rule `inquiry-<date>-<slug>.md`; edit-patch if exists. |
| ingest-task | 26 | (b) dispatches "via `magic-coordinator`" — a member, not a routine. | Name routine, input, output. |
| ingest-task | 30 | **process-own-inbox** copy with a differing tail, unmarked. | Bare invocation + marker. |
| one-on-one | 7 | Trigger in Scope: "Manual only — the human-owner asks for a 'one-on-one'/'1:1'". | `Trigger: phrase — human-owner (or a member) asks for a one-on-one; no schedule.` |
| one-on-one | 8 | Capability + rationale, no end state. | "End state: `one-on-one session ended` marker posted in a dedicated thread and every material outcome folded into a board item." |
| one-on-one | 9 | Doesn't is a rule; real exclusions unnamed (target-member inbox → process-inbox; follow-on dispatch). | Name the owners. |
| one-on-one | 13 | **session-start** and **spawn-and-relay** state no return. | coworking → session declared + broadcast ts; spawn → Console Session id + final status. |
| one-on-one | 14 | No `State:`; board record, auto-memory, thread, Console Session scattered. | Add `State:` with locations. |
| one-on-one | 20 | Success = "once the 1:1 concludes". | Ended marker posted + final status received + board item present. |
| one-on-one | 21 | "no response within a bounded window" — window unnamed; spawn failure no outcome. | Name the window; spawn failure → fail loud, no thread. |
| one-on-one | 22 | "public-vs-DM content-sensitivity judgment call"; "anything material"; "substantive enough". | Procedure returning `public\|dm`; material = decision/ask/proposal stated. |
| one-on-one | 23 | Two runs for the same member → two threads, two spawns. | Guard: look up open board record/thread for this member; resume. |
| one-on-one | 24 | Relay "for the session's whole duration, independent of whether… the human stays present" — unbounded. | Session cap / idle timeout → **return-and-close** with `recheck-date`. |
| one-on-one | 27 | Spawned instance dies → ended marker never posted; board record persisted only "when waiting on a reply". | On relay timeout, post marker and upsert `state: interrupted`. |
| one-on-one | 30 | **session-start** restates coworking's Steps (variant 1 of 3); duplicated inbox bullet; unmarked. | Bare invocation; drop duplicate; marker. |
| retro | 7 | Trigger in Scope: "Manually triggered — the human-owner asks for a 'retro'". | `Trigger: phrase — human-owner asks for a retro; no schedule.` |
| retro | 8 | Description, no end state. | "End state: exactly one improvement item in `board-running` for the next daily, `state-and-lock` at `retro-finished`." |
| retro | 13 | **session-start** no return. | State it. |
| retro | 14 | No `State:` despite lock, note with `recheck-date`, improvement item; note path never named. | Add `State:`. |
| retro | 21 | **discuss-with-the-user** "easily outlives a single acquire" — no bound; `NO_LOCK_HELD` mid-pass no outcome; autonomous fallback "not-yet-built". | Bound (N hours → provisional findings, `retro-paused`); `NO_LOCK_HELD` → stop, fail loud. |
| retro | 22 | "enough recent history"; "nothing meaningful"; "looks like… a genuine architecture question"; "big enough to affect the whole team". | ≥1 item touched since last retro; delegate size/architecture calls to a procedure or the user. |
| retro | 23 | **close-session** "log it into `board-running`" — no op, no filename → second run, second item. | Name the write and filename (`note-<date>-retro-improvement.md`). |
| retro | 24 | No pass cap. | Tie to lock stale threshold. |
| retro | 30 | **session-start** variant 2 of 3; **process-own-inbox** tail verbatim in morning-review and process-reflections; **acquire-lock** ×4; no markers. | Markers or bare invocations. |
| conventions-check | 7 | Trigger stated, but in Local rules ("**Trigger**: any armed-mode team member may invoke…"; "**A change is the only trigger — never a run.**"). | Move to a Summary `Trigger:` line. |
| conventions-check | 8 | Describes inputs, no end state. | "End state: every finding classified (violation / judgment-call / clean) with file/line and, for wording, a best replacement; the change blocked or cleared." |
| conventions-check | 9 | Doesn't is a rule; real exclusions (cosmetic → librarian daily audit; verification → `magic-tester`) missing. | Add them. |
| conventions-check | 13 | **recheck-the-fix** self-invokes with no input/return; tester dispatch no return. | State both. |
| conventions-check | 14 | No `State:`; round counter ("Capped at 3 rounds") held nowhere; findings location unnamed. | Add `State:`. |
| conventions-check | 19 | Non-canonical closure. | Canonical sentence. |
| conventions-check | 20 / 25 | Success not observable; findings have no posting target. | Name where findings land; blocked changes carry `blocked-by-conventions-check`. |
| conventions-check | 21 | No analog → no outcome; tester dispatch no bound. | "no analog" is a finding; dispatch → bound + escalation. |
| conventions-check | 22 | Classification is judgment: "judged from context"; "clearly and easily understandable"; "cosmetic/minor never blocks"; "Unsure… default to surfacing". | **classify-each-finding** as a procedure with stated criteria returning one value; cosmetic = no intent/benchmark dropped, no behaviour word. |
| conventions-check | 26 | Tester dispatched with no routine name/inputs/outputs; self-invocation has no call shape. | Name both. |
| morning-review | 7 | Trigger in Scope. | `Trigger: dispatch from daily's spawn-morning-review, first daily of the day.` |
| morning-review | 8 | Context, no end state; **check-state-shape-drift** folds in a second goal (content-hygiene rewrite of skill files) that its own Verbatim-test forbids ("exactly one responsibility"). | Open with the report end state; move the hygiene pass out. |
| morning-review | 9 | Exclusions live in a step and a local rule, not Doesn't; Doesn't names a procedure not a routine. | Add: "delete processed items (heartbeat GC); blocked/parked transitions (grooming)". |
| morning-review | 13 | **session-start** no return; `heartbeat-state-note` read op unnamed; local rule invokes `post-inquiry` but local procedures says "None currently defined" (verified). | State returns; name the op; define `post-inquiry` or use `--member-upsert-member-inquiry`. |
| morning-review | 14 | No `State:`; "since the last pass" marker lives nowhere. | Add `State:`. |
| morning-review | 20 | "simply exits once its report is sent" — shape and destination unnamed. | "report returned to daily as <message/board note>". |
| morning-review | 21 / 24 | No failure outcomes ("stop-and-ask" names no one); hygiene rewrite over an open-ended set; no session cap. | Name escalation target; cap files or move the pass out; session cap. |
| morning-review | 22 | "looks like it should already be gone"; "looks like it may have changed, but isn't certain"; "isn't board-specific". | age > retention threshold; referenced blocker's state changed; board-specific = under `board-*`. |
| morning-review | 23 | Skill-file rewrite with no already-done guard; "fix the model gap itself" board write unguarded; inquiry filename rule absent. | Guards; deterministic filename. |
| morning-review | 25 | Flags from three steps have no posting target. | Name the write per flag. |
| morning-review | 26 | Reaches into coordinator's tooling for the state-note read; calls undefined `post-inquiry`. | Named routine/procedure with stated output, or list the op for the coordinator executor. |
| morning-review | 27 | Skill-file rewrite mid-session with no abort cleanup → half-rewritten rule file. | Remove the rewrite or make it proposal-only per process-reflections. |
| morning-review | 30 | **session-start** variant 3 of 3; tail duplicated from retro; no markers. | Markers or bare invocations. |
| process-inbox | 7 | Trigger in a local rule; names "the morning self-review" — not a routine. | `Trigger: explicit call from any routine's Steps; heartbeat every cycle; member's first spawn of the day.` Name or drop "morning self-review". |
| process-inbox | 8 | Capability, no end state. | "End state: every item in `<member>`'s inbox is replied, routed, resolved, or retained with a reason." |
| process-inbox | 9 | Doesn't names a member; exclusions (non-acting-owner content → ext-inbox-loop; GC → heartbeat) only in local rules. | Add them to Doesn't. |
| process-inbox | 13 | **run-gc-in-heartbeat** no return; **act-lightweight** "route to another member" names no op (only Slack send declared). | State return; name the routing write and declare it. |
| process-inbox | 14 | No `State:`; inbox path unnamed; no per-item processed marker. | `State: <member>/inbox/ (path); per-item processed marker.` |
| process-inbox | 19 | Non-canonical closure. | Canonical sentence. |
| process-inbox | 20 | No observable "processed" condition. | "no item lacks a processed marker". |
| process-inbox | 21 / 24 | No failure outcomes; no items-per-pass cap. | Cap with carry-over; failed route → retry once, leave unmarked, report. |
| process-inbox | 22 | "genuinely simple/obvious"; "classify by what it actually says"; "significant enough". | Classify by filename prefix; "simple" via an explicit criteria procedure. |
| process-inbox | 23 | No processed marker → rerun re-sends **reply-on-cross-member-handoff**. | Marker; guard the send. |
| process-inbox | 25 | Non-coordinator executors leave no durable record ("Self-writes… don't need one"). | Processed marker is the record, every executor. |
| process-inbox | 26 | Contract contradicts itself: executor = inbox owner only, yet **Spawned** mode is "representing an inbox it doesn't itself own". | One contract: `<team-member>` is always the owner; the spawned case belongs to ext-inbox-loop. |

### magic-team — brainstorm, coworking, discuss, grooming, interview, process-reflections

| routine | conv # | what is missing or wrong | specific change |
|---|---|---|---|
| brainstorm | 7 | Trigger in Local rules: "Manual only — anyone asks to 'brainstorm' a topic." | `Trigger: phrase "brainstorm <topic>" from any member or the human-owner.` |
| brainstorm | 8 | Purpose paragraph; the tracking document is never named. | "End state: one named tracking document listing every idea with its light-assessment verdict." |
| brainstorm | 9 | "deep feasibility review (light assessment only)" names no owner. | Name grooming's task-creation lifecycle or interview's **run-bigger-mechanism-cycle**. |
| brainstorm | 13 | **process-own-inbox**, **hand-off-promising-ideas**, and the closure state no return/input. | State per invocation. |
| brainstorm | 14 | No `State:`. | `State: tracking document; session_thread_ts; filed items pending confirmation.` |
| brainstorm | 19 | "Execute coworking's Closure Steps." — not the canonical sentence. | Canonical sentence. |
| brainstorm | 20 | A run can end with no artifact ("nothing promising" valid). | Success = tracking document lists every idea with a verdict, posted — even at zero filed. |
| brainstorm | 21 | **gate-filing-on-confirmation** "wait for confirmation" — no bound; generation has no stop. | No confirmation this session → record proposals, stop; idea cap or time-box. |
| brainstorm | 22 | "genuinely promising"; "if it needs a real decision… if it's heading toward being built"; "One idea starts dominating… gently redirect". | Key on the recorded verdict field; route by item type; drop or delegate the rest. |
| brainstorm | 23 | Files new `idea-*`/`note-*` with no exists-check. | Skip if same name exists; else upsert. |
| brainstorm | 24 | No cap or duration. | Routine-level bound. |
| brainstorm | 25 | Durable-record obligation applies only when coordinator executes. | Tracking write and closing post unconditional. |
| brainstorm | 26 | Closure consumes `session_thread_ts` from **session-start**, which brainstorm never runs. | Run **session-start** as step 1, or declare "closure inputs: ad-hoc, no thread". |
| brainstorm | 27 | Abort between proposal and confirmation leaves proposals in transcript only. | On abort, write un-confirmed proposals to the tracking document. |
| brainstorm | 30 | **process-own-inbox** unmarked; **gate-filing-on-confirmation** duplicates discuss's and interview's gate. | Markers, or move the gate to one owner. |
| coworking | 7 | Scope: "recognizes a task genuinely needs several members" — a judgment; **session-start**/**close-session** entry from other sessions is a second trigger not listed. | `Trigger: phrase "cowork on <item>"; session-start/close-session entered by name from any session.` |
| coworking | 8 | Purpose, not end state. | "End state: tracking document updated, report-with-transcript posted in the session thread, root reacted ✅." |
| coworking | 9 | "solo dispatch-and-report-back" names no routine. | Name advance's `check-execute-board`. |
| coworking | 13 | **frame-the-shared-goal** calls `--routine-coworking-session-input-scan` without stating what returns or who consumes it. | "returns the closed set of board items; **work-the-shared-task** uses it." |
| coworking | 14 | No `State:` despite defining the most: `session_transcript_name` (directory unstated), `session_thread_ts`, session type, tracking documents, knowledge batch. | Add `State:` with locations. |
| coworking | 21 | **invite-participants-visibly** "Confirmation never arrives" — no wait time; **batch-then-test-knowledge-changes** fix/re-test uncapped; **work-the-shared-task** unbounded. | Wait bound; cap cycle (2 → escalate); session max. |
| coworking | 22 | "proceed without that member if the shared task still works"; "redirects when the work's shape drifts"; "anything genuinely important"; "genuinely sensitive… use judgment to redact". | Observable (member in `participants` → pause) or delegate. |
| coworking | 23 | **post-opening-broadcast** and invites post with no already-posted check (closure's `already_reacted` guard is good). | "if `session_thread_ts` set, reuse." |
| coworking | 24 | No session max; loops uncapped. | Routine bound + per-batch cap. |
| coworking | 26 | **session-start**/**close-session** invoked from five files yet live in `# Steps`, not declared procedures; inputs/outputs undeclared. | Export both with an explicit interface. |
| coworking | 27 | Abort leaves thread unclosed and transcript half-written. | "on abort: post abort line, react, flush **secure-continuity**." |
| coworking | 30 | "process own inbox" appears twice in-file (**collect-reflections-output**, **secure-continuity**) unlinked. | `same as **collect-reflections-output**`. |
| discuss | 7 | Two triggers scattered in Scope (phrase; dispatch from advance over `proposal-*`). | One `Trigger:` line listing both. |
| discuss | 8 | Purpose; "in the middle of the conversation" contradicts Summary's "by the end". | "End state: recorded decision item and, for a `proposal-*`, that item moved to processed/archived." |
| discuss | 13 | **record-the-outcome** "hands the resolved outcome to `magic-coordinator`" — mechanism and return unstated; closure inputs missing. | Name the handoff write and return. |
| discuss | 14 | No `State:`. | Add. |
| discuss | 19 | Non-canonical closure. | Canonical sentence. |
| discuss | 20 | Inconclusive run's end state unstated. | "inconclusive → `# Context Detail` 'open: …' + `recheck-date`". |
| discuss | 21 | "runs out of time" no bound; two confirmation waits unbounded. | Session bound; "no confirmation → pending, stop". |
| discuss | 22 | "bring in `magic-architect` if structural/design-shaped…"; "if an unrelated topic surfaces"; "about to produce a real build/edit dispatch". | Key on item type/frontmatter; checkpoint before any `--magic-board-*`/dispatch call. |
| discuss | 23 | Creates `change-*`/`note-*` with no guard; move on already-moved item unstated. | Upsert by deterministic name; skip if in target state. |
| discuss | 24 | No bound; iterative loop uncapped. | Round/time cap. |
| discuss | 25 | Event-track only when coordinator convenes; state-changing steps don't name posts. | Name post target per step. |
| discuss | 26 | Dispatched "over" a `proposal-*` with no declared input/output. | `Inputs: <proposal-item>; Outputs: decision recorded, item state.` |
| discuss | 27 | Abort mid-**keep-tracking-item-current** leaves partial `# Context Detail`. | "on abort: write 'discussion aborted, open: …'". |
| discuss | 30 | **process-own-inbox** unmarked; **keep-tracking-item-current** declared a copy of interview's but lacks the marker form; filing gate = third copy. | Markers. |
| grooming | 7 | Triggers scattered: Goals, Local rules, Reference (heartbeat's first-iteration branch). | One `Trigger:` line. |
| grooming | 8 | "Backlog grooming: review, triage, and reprioritize…" — activity, not end state. | "End state: every open item carries this pass's triage verb and RICE score, `state-and-lock` reads `grooming-finished`, summary posted." |
| grooming | 13 | **session-start** no return; roster recheck dispatches `magic-tester` with no return. | State both. |
| grooming | 14 | No `State:` despite lock, note, `roster-note`, provisional findings, thread ts. | Add. |
| grooming | 21 | Lock refresh "periodically"; "Time-boxed per item" no number; **review-with-the-user** unbounded; Trello/Google API calls no failure outcome; tester dispatch no outcome. | Interval; per-item box; review bound with provisional fallback; API failure → skip, note, continue. |
| grooming | 22 | **triage-per-item**: "stale/no longer worth doing?"; "too big"; "wrong member"; "case-by-case judgment call"; "never had real substance — judgment call"; "already warrants treating it as approved"; "genuinely needs live confirmation". | Observable checks primary; wrap the rest in a `triage-decision` procedure returning one verb. |
| grooming | 23 | Every `--magic-grooming-create-*` is "the item's first write" with no exists-guard; batch Slack send no already-sent guard. | Skip create if filename exists; record send in `state-and-lock`. |
| grooming | 24 | No pass duration; per-item box unnumbered. | Pass bound with carry-over. |
| grooming | 26 | **session-start** executes coworking's *entire* Steps (incl. **work-the-shared-task**, **report-out-with-transcripts**); reaches into "the interview/communication-sweep Slack mechanism"; calls interview's **resume-review** with no input. | Invoke only **session-start**; call **resume-review** with `<item>`; name the Slack op. |
| grooming | 27 | Abort leaves `grooming-running` and lock held until stale-reclaim. | "on abort: close with `grooming-aborted` and items reached." |
| grooming | 30 | **acquire-lock** ×4, **process-own-inbox** ×10, unmarked. | Markers. |
| interview | 7 | Triggers scattered: manual ask, `missing-tool-option-escalation`, four resume entry points inside **resume-review**. | One `Trigger:` line for start and resume triggers. |
| interview | 8 | Purpose. | "End state: tracking item's 'still open' section empty, verbatim-intents/benchmarks recorded, every settled piece dispatched." |
| interview | 13 | **process-own-inbox** no return. | State it. |
| interview | 14 | No `State:`. Tracking item named `inquiry-*` at **open-channel-and-create-item** but `interview-*` at the `fork:` rule and in grooming (verified both). | Add `State:`; resolve the naming. |
| interview | 20 | "isn't 'done' until there's nothing left to focus on" — terminal board move unstated. | State the terminal move. |
| interview | 21 | "doesn't report back within a bounded window" — window unspecified; cycles uncapped; `APPROVE` wait unbounded; conflict-resolve loop uncapped. | Values for each; "no `APPROVE` → piece stays open, stop." |
| interview | 22 | "email is the failover for slow-moving or unusually complex"; "unrelated topic surfaces"; "trivially obvious and low-stakes"; "clearly wants to decide"; minimal-vs-bigger split. | Failover on no reply in N h; cycle choice on single-file vs multi-file; drop or delegate the rest. |
| interview | 23 | **open-channel-and-create-item** creates the tracking item on every pickup with no exists-guard. | "if exists, refresh `owner-session*` only." |
| interview | 24 | No round or duration cap. | Per-pickup cap + routine bound. |
| interview | 26 | **run-bigger-mechanism-cycle** spawns "a coworking-*style* dispatch" — not a by-name call; **resume-review** is an entry point for three routines but not a declared procedure. | Call coworking by name with inputs/outputs; declare **resume-review**'s interface. |
| interview | 27 | "resume-review in progress" marker has no cleanup on abort — blocks every later entry. `GOOD/BAD INTERVIEW` rule "triggers an immediate self-edit of this file" — live edit contradicting coworking and process-reflections. | Clear marker on abort; route the self-edit through process-reflections as a proposal. |
| interview | 30 | **process-own-inbox** unmarked; filing gate = one of three copies. | Markers. |
| process-reflections | 7 | Triggers in Scope; the dispatch from coworking's **fold-in-learned-lessons** is not mentioned. | `Trigger: dispatch from coworking's fold-in-learned-lessons; librarian daily audit; request.` |
| process-reflections | 8 | Purpose. | "End state: every `feedback_*.md` retired, covered by an approved edit, or represented by a filed item." |
| process-reflections | 9 | Doesn't is a negated goal; the real exclusion (inbox items → process-inbox) sits in Does. | Rewrite Doesn't. |
| process-reflections | 13 | **batch-approve-with-human-owner** hands to grooming with no return; closure no inputs. | "returns approval status per proposal, read at next run". |
| process-reflections | 14 | No `State:`; "which proposals are awaiting approval" has no home. | `State: feedback_* path; pending proposals as note-* in librarian's inbox; resolution log.` |
| process-reflections | 19 | Non-canonical closure. | Canonical sentence. |
| process-reflections | 20 | "flag it as eligible for deletion" — where unstated. | Name the flag location. |
| process-reflections | 21 | Batch wait has no `recheck-date`; **reassess-against-new-cases** "an ongoing recheck" — a standing loop inside a step. | `recheck-date` on pending; per-run check, not standing. |
| process-reflections | 22 | Three-way "already incorporated / clear / genuinely unresolved"; "obviously-trivial, self-evidently-correct"; "the same underlying lesson". | Anchor on verbatim search hit; trivial = single-line no behaviour word; delegate merge. |
| process-reflections | 23 | Proposal note filename not deterministic — rerun files a second proposal. | `note-reflection-<feedback-file-stem>`. |
| process-reflections | 24 | No per-run file cap; recheck unbounded. | Cap + carry-over. |
| process-reflections | 25 | Opts out of event-track; inline closure "nothing"; no-op run leaves no record; log entry optional. | Mandatory log entry per run. |
| process-reflections | 26 | Invoked with input "this session's project/workspace" but declares no inputs/outputs; reaches into grooming's **gather-the-backlog**. | Declare I/O; call grooming by name with the batch. |
| process-reflections | 27 | **apply-approved-edit** edits a live file with no atomic-write/read-back. | "write, re-read, diff against approved text before marking applied". |
| process-reflections | 30 | **process-own-inbox** unmarked. | Marker. |


---

# Part 3 — Overlap map (convention 3)

**Board driving — heartbeat / advance / daily.** Intended: heartbeat decides what is due and dispatches; advance executes already-decided moves; daily assigns and supervises. Actual: heartbeat's `Doesn't` says *"doesn't read, scan, or write any board item"* while its steps run `--magic-heartbeat-input-scan`, create `warning-*` items and trash `processed/`; daily's `Doesn't` says *"never calls check-execute-board"* while its Closure runs advance in full; daily's fan-out writes no `session-id`, so advance's never-dispatched check respawns fanned-out items. Two callers of advance describe it differently (heartbeat: background `Agent` spawn; advance: *"invoked inline"*).

**Comms sweep — three claimed callers, one real.** Sweep's Scope names daily and heartbeat; heartbeat has no comms step (its Reference still cites one); advance is the real per-iteration caller and runs only **check** + **process-each-message**, never **update-context**, so `last_swept_ts` only advances when daily runs. Daily calls a *"read half"* / *"write half"* sweep never defines. Sweep hands deferred reactions to *"advance's pending-reaction-lookup step"*; advance calls it `check-pending-comms-actions`; neither exists (verified: 0 definitions).

**Own inbox — up to three passes per heartbeat iteration** (heartbeat → process-inbox; ext-inbox-loop step 1 → process-inbox; spawned advance → process-inbox), none marked as the same block.

**Shared state with no owner.** `heartbeat-state-note`: whole-record-overwritten by heartbeat every iteration and by the concurrent advance session; called *"librarian-owned"* in one place and *"owned by whichever session executes next-iteration"* in another; declared *"not visible outside this file"* yet read and written by advance. Lost-update race on `today_stage`.

**Structured conversations — brainstorm / discuss / interview.** Same skeleton, boundaries stated as intentions. Interview's `Doesn't: reach agreement` is false as written — **run-minimal-step-cycle** approves and dispatches, **run-bigger-mechanism-cycle** applies plan pieces directly. Tracking-item naming diverges: interview creates `inquiry-*`, its fork rule and grooming's `check-backlog-promote` expect `interview-*` (verified: both present).

**Coworking session-start / close-session.** Invoked by name from five files but live in `# Steps`, not as declared procedures with inputs/outputs. Brainstorm, discuss, process-reflections invoke the *Closure* without the *Steps*, so `session_thread_ts` / transcript name are never set and the closure degrades silently. Grooming runs coworking's *entire* Steps, including **work-the-shared-task** and **report-out-with-transcripts**.

**Reflections pipeline — process-reflections / coworking / retro / grooming.** Coworking's **fold-in-learned-lessons** runs process-reflections for every participant at every session; process-reflections' Scope says librarian's daily audit or direct request only, executor `magic-librarian` alone. Retro and process-reflections both claim inbox `reflection-*` notes. Approval batch delegated to grooming; "pending approval" state has no home.

**Skill-file edits by three rules.** conventions-check: review before landing. process-reflections: propose → approve → apply. morning-review **check-state-shape-drift** and interview's `GOOD/BAD INTERVIEW` rule: edit in place, now. Two of the three bypass the other two.

---

# Part 4 — What to fix first

Ordered by number of routines unblocked per edit.

1. **Contract text** (2 edits, 18 routines): `shared.md` § Routine title line → owner-dotted form; template list syntax → bare. Then 18/18 pass conventions 2 and 5 without touching a routine.
2. **Add three lines to the template** — `Trigger:`, `State:`, and a Goals opener *"End state: …"* — so every routine touched from now on gains 7, 8, 14 on its next edit (the contract's own *"applied as each routine file is next touched"* rule).
3. **One canonical closure sentence** (7 routines, same string): mechanical replace.
4. **Coworking exports `session-start` / `close-session`** as declared procedures with inputs/outputs. Fixes 26 for six callers and the silent closure degradation in three.
5. **Delete the four dangling cross-references** (`check-pending-comms-actions` ×5, `pending-reaction-lookup` ×2, sweep *"read half"* ×2, morning-review `post-inquiry`) or add what they name.
6. **Declare `heartbeat-state-note` as a shared record** with one owner and field-level upsert — the only lost-update race found.
7. **Then** the per-routine work in 2.2: bounds, idempotency guards, judgment → observable, in that order, one routine at a time.
