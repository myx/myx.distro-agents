---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect
invitees: magic-team
---
# routine-coworking — the actual procedure

# Summary

Routine-coworking is the named shape for genuine multi-member collaborative work on one shared task in one conversation/thread, `magic-coordinator` participating directly.

## Goals

Give the team a real, named shape for genuine multi-member collaborative work sessions — several members actually working the same task together in the same conversation/thread, not one member dispatched solo and reporting back afterward. This is distinct from a normal dispatch (one member, one assignment, reports at the end) and distinct from `routine-daily`'s work-session fan-out (several members, but each working their *own* separate assignment in parallel, not the same shared task together). `magic-coordinator` participating directly and orchestrating — keeping the session's own goal on track, not just spawning and stepping back — is what makes this genuinely coworking rather than several independent dispatches that happen to run at the same time.

## Scope

Does: orchestrated shared-task collaboration, `magic-coordinator` staying on-task not just spawning and stepping back. Manual, no autonomous or scheduled trigger — the human-owner, or `magic-coordinator` itself, recognizes a task genuinely needs several members working it together in the same session, though a spawned session can also recognize this partway through. Explicitly non-exhaustive — not the only valid coworking shape.
Doesn't do: solo dispatch-and-report-back, `routine-daily`'s per-member parallel-but-separate fan-out.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

0a. **Run `routine-session-start`'s shared opening steps** — `routine-coworking` is always coworking-like/structured-multi-member for `routine-session-start`'s own session-type branching purposes, so its coworking-only opening broadcast (announcing the session to `slack-magic-team`/Trello, symmetric to this routine's own closing report in the closure step below) applies here, along with its mandatory `routine-process-reflections` call and its folded-in `routine-prepare-session` currency check.
   - **Thread continuity**: reuses `session_thread_ts`, already captured from that opening broadcast per `routine-session-start`'s own thread-continuity rule — no separate capture here. Every further post this routine makes to `slack-magic-team` for the rest of this session (step 2's Inviting/confirmation lines, step 4b's progress narration, step 5's final report) targets `<channel>:<session_thread_ts>`, never the bare `magic-team` keyword.
0b. **Confirm co-working transcript context is assigned** — this session must have one stable `session_transcript_name` value (transcript-* filename) from session start; do not proceed with transcript appends when this key is missing.
1. **Frame the shared goal**: state plainly, up front, what the coworking session is actually trying to accomplish together — same discipline as `routine-discuss`'s framing step, since a coworking session without a clear shared goal risks becoming an unfocused free-for-all. (Step 0a's opening broadcast may run before or after this framing.) Once the goal names specific board-item(s), call the `--routine-coworking-session-input-scan` operation for those item(s) before the session works from them.
1a. **Process own inbox**: `routine-process-inbox`(`routine-coworking`'s own inbox, `magic-coordinator` as the executor — confirmed default, since it's the one that participates/orchestrates per this routine's own Goals) — inline execution (own identity). Not automatic just because this routine spawned — this explicit call is what actually guarantees it happens.
2. **Invoke each participant's real Skill, visibly, as each one is actually dispatched** — including any member pulled into duty later, mid-session, not only those named when the session started. Every member actually collaborating loads its own full `Skill`, not a paraphrase — same standard as any other dispatch, just multiple members present in the same working session rather than one. For each one, at the moment its dispatch begins, post `Inviting <member's own Alias, per its own Public Information>...` into this session's `slack-magic-team` thread via the `--member-slack-send-message` operation, target `<channel>:<session_thread_ts>` per step 0a's Thread continuity capture, never the bare `magic-team` keyword; once that member has loaded its Skill and is ready, that member posts its own confirmation into the same thread under its own alias, same threaded target (illustrative shape only: `@<alias>: Hi there! Armed and ready!` — each member's actual wording is its own voice, not a fixed script). This reply is not decorative — it's the actual mechanism that confirms the member is armed, replacing a silent assumption of dispatch success with a visible, checkable confirmation. Applies identically to a member added mid-session — no quieter/implicit path for a late arrival. **Confirmation never arrives**: `magic-coordinator` re-invites once (re-post the `Inviting...` line); still nothing, flag it in this session's own `slack-magic-team` thread and either proceed without that member if the shared task still works without them, or pause and ask the human-owner if it can't.
3. **`magic-coordinator` participates directly and orchestrates**: not a passive observer — actively keeps the session's own goal on track, redirects when the work's shape drifts, and makes the real-time judgment calls a solo dispatch would otherwise leave to whichever single member was assigned.
4. **Work the shared task together**: however the actual collaboration shape needs to happen for this specific goal — sequential handoffs, parallel sub-pieces reconciled at the end, live back-and-forth — this step is deliberately not prescriptive about the *mechanics* of collaborating, since that's genuinely task-dependent.
4a. **Batch-then-test floor, specifically for magic-team knowledge changes** (routines/skills/rules/process-flow files — `SKILL.md` and its typed siblings, shared team docs; not a ceiling on how a session may work, a minimum for this specific kind of change): accumulate a batch of related knowledge changes first, rather than treating every single minor edit mid-session as its own tested unit. Between batches: close out any sub-spawned sessions from the finishing batch, make sure the actual knowledge files are fully updated (not left half-edited), then spawn a fresh session whose only job is to test the batch's changes together as a whole (not mixed with authoring new changes), reload the now-current knowledge into this coworking session itself once that test session confirms things hold, and only then spawn the next co-working batch. This is the standing floor for this shape of session. **The test session's own completion report is the real signal** — a background `Agent` dispatch reports back on completion the same way any other spawned sub-session does, so the coworking session isn't guessing whether the batch is clean. **The report comes back failing, not passing**: fix the real problems it found and re-test within that same test/fix cycle — never reload an unconfirmed batch into this coworking session; only a batch the test session has actually confirmed clean gets reloaded.
4b. **Narrate real progress into the same thread as it happens, not only at the final report**: as the shared goal's scope changes, or a participant begins applying a piece of work, post a short line to that effect (illustrative shape: `updated session scope: ...`, `applying ...`). This makes `magic-coordinator`'s own general message-by-message relay obligation concrete for this routine. Additive to, not a replacement for: the existing `slack-event-track` activity-tracking obligation in this routine's own Local rules (different channel, technical purpose) and step 5's own end-of-session substantive report.
4c. **Default to a short clarification question over a broad investigation when something is unclear mid-task**: same ask-first discipline as conversation mechanics rule 6 (single-hypothesis, closed-form) and the team's own gap-surfacing convention (ask what's wanted; investigate only facts, never intent). Escalate into a real investigation — file reads, cross-file search, dispatching a member to go look — only once one of two concrete thresholds is actually met: the same gap has gone through two clarification rounds without resolving (that same rule's own stall definition), or the gap is a fact nobody present already holds (what a file/system actually contains or does, never what's wanted). Investigating "to be sure" before either threshold is met is scope creep on this step, not a safer default.
5. **Report out to `slack-magic-team` via the `--member-slack-send-message` operation, including transcripts**: unlike an ordinary dispatch's compact status trace, a coworking session's report includes enough of the actual working transcript/substance that the broader team can see not just the outcome but how it was reached — this is a deliberate transparency choice for genuinely collaborative work, distinct from `routine-close-session`'s more compact broadcast step. Same threaded target as steps 2/4b: `<channel>:<session_thread_ts>`, never a fresh bare `magic-team` post.

# Closure steps

1. **Close via `routine-close-session`**: same shared closing steps as any other coworking-like/structured activity — continuity (transcript check, reflect-on-incidents, inbox-task updates), external broadcast, and the skill-update offer — scoped to what this coworking session actually surfaced. **Context compaction does not apply here**: a dispatched coworking session has no persisting interactive context to compact the way a plain IDE-chat session does. `routine-process-reflections` also does not run here — it already ran at this session's own start, via step 0a above.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-coordinator` (this routine's sole executor) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- Explicitly non-exhaustive scope — human-owner's own framing when introducing this routine: "not limiting - trying to open unblock you vision." Don't read the shape described here as the only valid form a coworking session can take; widen it as real cases surface, through the normal maintainer-quorum process, not silently in the moment.
- Every participant in this routine — `magic-coordinator` included — counts as not genuinely live-interactive for the `Edit`-vs-`magic-tooling` fallback rule, regardless of any parallel live session `magic-coordinator` may also be holding elsewhere.
- **Workspace boundary: in coworking, work on an explicitly different workspace must run in a console session for that target workspace.** Same rule as `magic-team.armed.md`'s "Execution mechanisms" section, restated here so a coworking session doesn't have to cross-reference `magic-coordinator.harness.md` to find it.
- No default attendee roster: `magic-coordinator` convenes and calls in whichever members the shared task actually needs — nobody is required to attend by default.
- `magic-coordinator`'s participation is not optional or passive: a session with several members present but no one actually keeping the shared goal on track is not this routine — it is just several members talking.
- Unsure whether a task needs `routine-coworking` vs. a normal solo dispatch vs. `routine-daily`'s parallel fan-out: coworking is for genuinely *shared* work on the *same* task, where members need to react to each other in real time — if the pieces are actually independent, that's fan-out, not coworking.
- A participant needs a real decision outside the coworking session's own mandate: same sole-mandated-channel rule as everywhere else — routes through `magic-coordinator`.
- The transcript-inclusion report (step 5) would expose something genuinely sensitive or internal: use judgment to redact or summarize that specific part, while keeping the rest of the transparency intent intact.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- `magic-coordinator` (this routine's sole executor) is obligated to keep `slack-event-track` activity tracking current throughout the session, not only at the final report — additive to, not replacing, step 4b's separate `slack-magic-team` progress narration and step 5's end-of-session substantive report.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--routine-coworking-session-input-scan <item-name>...` (step 1: Frame the shared goal, once it names specific board-item(s))
- `--member-slack-send-message <team-member> <target> [text...]` (step 2: invite/confirm posts; step 5: report out; Slack activity-tracking obligation)

## `--routine-coworking-session-input-scan` operation reference

`DistroAgentsTools.fn.sh --routine-coworking-session-input-scan <item-name>...` — read-only: `routine-coworking`'s own step-1 board scan once the session's shared goal names specific board-item(s).

## `--member-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

# Maintainer Notes

Used to check this files own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives the team a real, named shape for genuine multi-member collaborative work — several members actually working the same task together in the same session, not one member dispatched solo.
- A coworking session may invite other required members to participate when needed.

## Verbatim-tests (benchmarks)

- `magic-coordinator` participates directly and orchestrates a coworking session — it never spawns participants then steps back as a passive observer.
- A co-working session of `magic-coordinator` and `magic-tester` can call/invite `magic-architect`, and check that all three are in armed mode and every member trusts `magic-coordinator` as representative of `human-owner`.

## Librarian Comments

### Reference

- `routine-session-start` — opening steps this routine runs at its own step 0a.
- `routine-close-session` — closing steps this routine runs at its own closure step.
- `routine-discuss` — the goal-framing discipline step 1 borrows from.
- `routine-process-inbox` — this routine's own inbox processing.
- `routine-daily` — the parallel-fan-out shape this routine is explicitly distinct from.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — calling convention, sole-sanctioned Slack-posting mechanism.
- `magic-team/magic-team.conversations.md` — rule 6's clarification-stall threshold, step 4c borrows it; conversation mechanics this routine's Local rules point to.
- `magic-team/magic-team.negotiations.md` — gap-surfacing section (ask what's wanted, investigate only facts), step 4c borrows it.

### Conventions

None currently known beyond this file's own Local rules.
