---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
invitees: magic-team
---
# magic-team.coworking.routine — the actual procedure

# Summary

Routine-coworking is the named shape for genuine multi-member collaborative work on one shared task in one conversation/thread, `magic-coordinator` participating directly.

## Goals

Give the team a real, named shape for genuine multi-member collaborative work sessions — several members actually working the same task together in the same conversation/thread, not one member dispatched solo and reporting back afterward. This is distinct from a normal dispatch (one member, one assignment, reports at the end) and distinct from `magic-coordinator.daily.routine`'s work-session fan-out (several members, but each working their *own* separate assignment in parallel, not the same shared task together). `magic-coordinator` participating directly and orchestrating — keeping the session's own goal on track, not just spawning and stepping back — is what makes this genuinely coworking rather than several independent dispatches that happen to run at the same time.

## Scope

Does: orchestrated shared-task collaboration, `magic-coordinator` staying on-task not just spawning and stepping back. Manual, no autonomous or scheduled trigger — the human-owner, or `magic-coordinator` itself, recognizes a task genuinely needs several members working it together in the same session, though a spawned session can also recognize this partway through. Explicitly non-exhaustive — not the only valid coworking shape.
Doesn't do: solo dispatch-and-report-back, `magic-coordinator.daily.routine`'s per-member parallel-but-separate fan-out.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **session-start**: the shared opening group. Every session executes it — coworking-like and ad-hoc/solo alike. A session that is not this routine references this group by name and executes it alike, rather than invoking this routine as a whole, steps:
   - **declare-session-type**: declare this session's type, per the taxonomy in this routine's own Local rules — state plainly, up front, which of the two types this session is. Every later step here, and every session-type-gated step in **close-session**, keys off this one declaration — don't re-derive it separately at each gated step.
   - **assign-transcript-name**: if session type is coworking-like, assign `session_transcript_name` now — required context key, one `transcript-*.md` filename for this session, set once and stable for the whole session. Transcript appends are blocked while this key is absent; do not proceed with them.
   - **post-opening-broadcast**: post to `slack-magic-team` now — this group's first externally-visible action. Every activity posts as it happens, no exemptions, any session type; this opening post happens here, before **fold-in-learned-lessons** or **collect-reflections-output**, no exceptions. Content may be minimal at this point (session type + participants known so far + goal if already framed) — completeness is never a reason to delay; a short immediate post beats a complete late one. Any member posts directly via the `--member-comms-slack-send-message` operation.
     - **Coworking-like sessions only**: this same step also carries the opening Trello update naming participants and the shared goal (already framed, or about to be framed at **frame-the-shared-goal**), mirroring **close-session**'s closing Trello update. A calling routine may inline the actual posting into whatever early-session dispatch it already makes — an opening post happening is what's mandatory, not the exact mechanism used to make it happen.
     - **Thread continuity — every session, both types**: capture `channel`/`ts` from this opening post's own `--member-comms-slack-send-message` JSON response as this session's own `session_thread_ts` — plain in-context session state, no persistence needed. Every later `slack-magic-team` post this session makes targets `<channel>:<session_thread_ts>` once captured, never a fresh bare `magic-team` post — one continued activity, one thread. This is ad-hoc/solo work's own minimal floor: an open post and a close post in one visible thread, nothing heavier — mid-session progress narration stays each member's own judgment call, not mandatory for ad-hoc the way it is for genuinely shared coworking.
   - **fold-in-learned-lessons**: mandatory — run `magic-team.process-reflections.routine` for this session's own project/workspace, so the session starts with this project's accumulated `feedback_*` lessons already folded in rather than catching up on them on the way out. **all participants**: the executor commands each member in turn to fold in its own project/workspace lessons, and announces each in the session thread.
   - **collect-reflections-output**: run `magic-team.process-inbox.routine <executor>` — inline execution (own identity). Positioned after **fold-in-learned-lessons** deliberately: that step files new drafted proposals and `inquiry-*`/`reflection-*` items into this executor's own inbox, and this is the pass that picks them up. **all participants**: it collects what that same member's own **fold-in-learned-lessons** just filed into that member's own inbox, so the executor commands each member it just ran that step for, and announces it. Not automatic just because this routine spawned — this explicit call is what actually guarantees it happens.
2. **frame-the-shared-goal**: state plainly, up front, what the coworking session is actually trying to accomplish together — same discipline as `magic-team.discuss.routine`'s framing step, since a coworking session without a clear shared goal risks becoming an unfocused free-for-all. (**post-opening-broadcast** may run before or after this framing.) Once the goal names specific board-item(s), call the `--routine-coworking-session-input-scan` operation for those item(s) before the session works from them, and re-read any inbox item naming the same board-item(s) so the participants invited next start from them.
3. **invite-participants-visibly**: invoke each participant's real Skill, visibly, as each one is actually dispatched — including any member pulled into duty later, mid-session, not only those named when the session started. Every member actually collaborating loads its own full `Skill`, not a paraphrase — same standard as any other dispatch, just multiple members present in the same working session rather than one. For each one, at the moment its dispatch begins, post `Inviting <member's own Alias, per its own Public Information>...` into this session's `slack-magic-team` thread via the `--member-comms-slack-send-message` operation, target `<channel>:<session_thread_ts>` per **post-opening-broadcast**'s Thread continuity capture, never the bare `magic-team` keyword; once that member has loaded its Skill and is ready, that member posts its own confirmation into the same thread under its own alias, same threaded target (illustrative shape only: `@<alias>: Hi there! Armed and ready!` — each member's actual wording is its own voice, not a fixed script). This reply is not decorative — it's the actual mechanism that confirms the member is armed, replacing a silent assumption of dispatch success with a visible, checkable confirmation. Applies identically to a member added mid-session — no quieter/implicit path for a late arrival. **Confirmation never arrives**: `magic-coordinator` re-invites once (re-post the `Inviting...` line); still nothing, flag it in this session's own `slack-magic-team` thread and either proceed without that member if the shared task still works without them, or pause and ask the human-owner if it can't.
4. **orchestrate-as-participant**: `magic-coordinator` participates directly and orchestrates — not a passive observer — actively keeps the session's own goal on track, redirects when the work's shape drifts, and makes the real-time judgment calls a solo dispatch would otherwise leave to whichever single member was assigned.
5. **work-the-shared-task**: however the actual collaboration shape needs to happen for this specific goal — sequential handoffs, parallel sub-pieces reconciled at the end, live back-and-forth — this step is deliberately not prescriptive about the *mechanics* of collaborating, since that's genuinely task-dependent.
6. **batch-then-test-knowledge-changes**: batch-then-test floor, specifically for magic-team knowledge changes (routines/skills/rules/process-flow files — `SKILL.md` and its typed siblings, shared team docs; not a ceiling on how a session may work, a minimum for this specific kind of change): accumulate a batch of related knowledge changes first, rather than treating every single minor edit mid-session as its own tested unit. Between batches: close out any sub-spawned sessions from the finishing batch, make sure the actual knowledge files are fully updated (not left half-edited), then spawn a fresh session whose only job is to test the batch's changes together as a whole (not mixed with authoring new changes), reload the now-current knowledge into this coworking session itself once that test session confirms things hold, and only then spawn the next co-working batch. This is the standing floor for this shape of session. **The test session's own completion report is the real signal** — a background `Agent` dispatch reports back on completion the same way any other spawned sub-session does, so the coworking session isn't guessing whether the batch is clean. **The report comes back failing, not passing**: fix the real problems it found and re-test within that same test/fix cycle — never reload an unconfirmed batch into this coworking session; only a batch the test session has actually confirmed clean gets reloaded.
7. **narrate-progress-in-thread**: narrate real progress into the same thread as it happens, not only at the final report — as the shared goal's scope changes, or a participant begins applying a piece of work, post a short line to that effect (illustrative shape: `updated session scope: ...`, `applying ...`). This makes `magic-coordinator`'s own general message-by-message relay obligation concrete for this routine. Additive to, not a replacement for: the existing `slack-event-track` activity-tracking obligation in this routine's own Local rules (different channel, technical purpose) and **report-out-with-transcripts**'s own end-of-session substantive report.
8. **ask-before-investigating**: default to a short clarification question over a broad investigation when something is unclear mid-task — same ask-first discipline as conversation mechanics rule 6 (single-hypothesis, closed-form) and the team's own gap-surfacing convention (ask what's wanted; investigate only facts, never intent). Escalate into a real investigation — file reads, cross-file search, dispatching a member to go look — only once one of two concrete thresholds is actually met: the same gap has gone through two clarification rounds without resolving (that same rule's own stall definition), or the gap is a fact nobody present already holds (what a file/system actually contains or does, never what's wanted). Investigating "to be sure" before either threshold is met is scope creep on this step, not a safer default.
9. **report-out-with-transcripts**: report out to `slack-magic-team` via the `--member-comms-slack-send-message` operation, including transcripts — unlike an ordinary dispatch's compact status trace, a coworking session's report includes enough of the actual working transcript/substance that the broader team can see not just the outcome but how it was reached — this is a deliberate transparency choice for genuinely collaborative work, distinct from **post-closing-broadcast**'s more compact broadcast. Same threaded target as **invite-participants-visibly**/**narrate-progress-in-thread**: `<channel>:<session_thread_ts>`, never a fresh bare `magic-team` post.

# Closure steps

1. **close-session**: the shared closing group. Every session executes it — coworking-like and ad-hoc/solo alike. A session that is not this routine references this group by name and executes it alike, rather than invoking this routine as a whole. `magic-team.process-reflections.routine` does not run here — it already ran at **fold-in-learned-lessons**, steps:
   - **post-closing-broadcast**: post to `slack-magic-team` — every session, both types, unconditional.
     - post the actual substance (resolutions, triage outcomes, highlights) — not a one-line summary; skip only genuinely internal mechanics
     - any member posts directly via the `--member-comms-slack-send-message` operation
     - targets `<channel>:<session_thread_ts>` captured at **post-opening-broadcast** — never a fresh bare `magic-team` post
     - coworking-like sessions only: queue a `note-*` to `magic-coordinator`'s inbox via the `--member-upsert-inbox-note` operation, describing the Trello card update needed — never write to Trello directly, `magic-coordinator.advance.routine` is the sole executor of actual Trello writes
     - in a full coworking session this is the compact counterpart to **report-out-with-transcripts**, which carries the working transcript itself
   - **secure-continuity**: every session, both types. **all participants**: the executor commands each member to check its own transcript, reflect on its own incidents, and write into its own inbox, and announces the round.
     - check: does anything genuinely important from this session exist only in this transcript, no durable file backing it? If so, write it now via the `--member-upsert-inbox-note` operation (plain memo) or `--member-upsert-inbox-reflection` operation (`reflection-*` note) — or a drafted proposal if the durable form is an `.armed.md`/routine-file change
     - never a live edit to a team-knowledge file at session close itself — still goes through `magic-team.process-reflections.routine`'s own propose→discuss/approve→edit gate
     - reflect on this session's actual incidents (0, 1, or several — not a fixed ritual): real corrections, real conflicts with the human-owner's actual stated words, real gaps found live. Check against: floor-not-ceiling (durable minimum going forward, not a one-off patch), statement-updates-state (frame a conflict with a prior assumption as "the model was wrong," not competing information logged side by side)
     - update any inbox task this session touched, resolved, or deferred
     - process own inbox: run `magic-team.process-inbox.routine <executor>` — inline execution. Closes out this step's own writes: the `note-*`/`reflection-*` just filed above, plus any inbox item this session touched, resolved, or deferred.
   - **compact-session-context**: ad-hoc/solo/IDE-chat sessions only.
     - make sure nothing important is left only in this transcript (**secure-continuity** should already have caught anything substantive) — what makes a session safe to `/clear`
     - coworking-like sessions skip this entirely — a dispatched background `Agent` has no persisting interactive context to compact
   - **offer-skill-update-discussion**: coworking-like sessions only.
     - look back at what the routine surfaced (challenges, friction, gaps between what a member was asked to do and what its own `.armed.md` equips it to do) and raise with the user, explicitly, whether any `magic-*` member's `.armed.md` or any `routine-*` file is due for an update
     - an offer, not an automatic edit — name the specific skill and gap, let the user decide now or defer
     - ad-hoc/solo sessions skip this — route through that member's own inbox/reflection note (**secure-continuity**) instead
   - **conclude-session-thread**: conclude the session's own `slack-magic-team` thread — every session, both types, conditional on a live thread actually existing.
     - react `:white_check_mark:` on that thread's root message (the same `<channel>:<session_thread_ts>` **post-closing-broadcast** posted into) via the `--member-comms-slack-react` operation — same "black tick on completion" pattern `magic-coordinator.heartbeat.routine`'s own closure already uses for its `slack-event-track` thread
     - no live thread for this session (nothing posted at **post-opening-broadcast**, or thread capture failed) → skip, no error
     - already reacted (`already_reacted`) → harmless no-op, not a failure

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-coordinator` (this routine's sole executor) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- **Two senses of "coworking", kept apart.** This routine's `# Summary`/`## Goals` govern the *narrow* sense — several members working the same shared task together, `magic-coordinator` participating directly. The taxonomy below governs the *general* session-type distinction every session passes through. A session can be coworking-like in the general sense without being a full coworking session in the narrow one. Both live in this file now; do not collapse them into each other.
- **Every step here is the executor's.** A step naming participants is a script for the executor to orchestrate and command, announced in the session transcript as it happens — never members quietly doing it on their own. **fold-in-learned-lessons**, **collect-reflections-output** and **secure-continuity** are the steps the executor runs *per participant*, commanding each in turn; every other step it performs directly.
- **A member joining mid-session does not replay the steps it missed.** On arrival it loads its own Skill, is announced into the session thread, and picks up the shared task from the current state — the executor decides whether any earlier step needs re-running for that member and commands it explicitly if so. Nothing re-fires automatically.
- **`session-start` and `close-session` are open to every member — `executors: magic-coordinator` in this file's frontmatter governs a full coworking session, not those two groups.** Opening and closing cleanly is a universal need, not something to gate behind a specific role: any member, and any ad-hoc/solo or IDE-chat session, executes both groups alike under its own identity. The frontmatter is deliberately not widened — it is right for the narrow sense, and this rule is what carries the open posture the groups had as their own routines.
- **Session-type taxonomy — defined here, in the template that owns the opening and closing steps.** Every session executing this routine's Steps or Closure Steps is one of exactly two types:
  - **Coworking-like / structured-multi-member**: a routine extending this template with a defined participant set and an existing external-reporting obligation — `magic-coordinator.daily.routine`, `magic-coordinator.retro.routine`, `magic-team.grooming.routine`, `magic-coordinator.one-on-one.routine`, `magic-librarian.morning-review.routine`, and this routine itself — or, more generally, several members genuinely working the *same* shared task together (not each on its own separate assignment, which is `magic-coordinator.daily.routine`'s work-session fan-out — still coworking-like, since it is part of a structured routine).
  - **Ad-hoc / solo / IDE-chat**: a single-member dispatch working its own assigned item, a plain IDE-chat UI conversation, or any other dynamic one-off activity that isn't one of the structured routines above. It executes these Steps and Closure Steps alike, in simplified form, following what applies.
  - `magic-coordinator.advance.routine` and `magic-coordinator.heartbeat.routine` extend this template too, but override the groups heavily (their own `slack-event-track` lifecycle, no **fold-in-learned-lessons**) — see their own Local rules.
- Genuinely unsure which type a session is: default to **coworking-like**, not ad-hoc — full participant declaration, opening broadcast, and the coworking-gated closing steps — unless the session explicitly declares itself ad-hoc. Ad-hoc is an explicit declaration, never an assumed fallback.
- **Standing rule**: every invocation of one of the structured routines named above is always a proper (sub-)spawned session executing these Steps and Closure Steps in full — never an ambiguous "just a step vs. a real spawn" judgment call.
- **Scope boundary on that standing rule**: it does NOT extend to every named `routine-*`. Utility/mechanical routines keep their deliberately lightweight execution modes exactly as documented: `magic-team.process-inbox.routine` keeps its inline-(own identity)/spawned-(representing another identity) split; `partner-ndm-camunda.camunda-diagram-sync.routine` keeps its "skip silently if nothing changed" cheap mtime check.
- **Co-working transcript context rule**: for coworking-like sessions, `session_transcript_name` is mandatory session context. Assign it once at **assign-transcript-name** and keep it unchanged through close; transcript-append calls are blocked when it is missing.
- **Session thread-continuity rule**: every session captures `session_thread_ts` at **post-opening-broadcast** and reuses it for every later `slack-magic-team` post, including **post-closing-broadcast** — one continued activity, one thread, ad-hoc/solo sessions included.
- Explicitly non-exhaustive scope — human-owner's own framing when introducing this routine: "not limiting - trying to open unblock you vision." Don't read the shape described here as the only valid form a coworking session can take; widen it as real cases surface, through the normal maintainer-quorum process, not silently in the moment.
- Every participant in this routine — `magic-coordinator` included — counts as not genuinely live-interactive for the `Edit`-vs-`magic-tooling` fallback rule, regardless of any parallel live session `magic-coordinator` may also be holding elsewhere.
- **Workspace boundary: in coworking, work on an explicitly different workspace must run in a console session for that target workspace.** Same rule as `magic-team.armed.md`'s "Execution mechanisms" section, restated here so a coworking session doesn't have to cross-reference `magic-coordinator.harness.md` to find it.
- No default attendee roster: `magic-coordinator` convenes and calls in whichever members the shared task actually needs — nobody is required to attend by default.
- `magic-coordinator`'s participation is not optional or passive: a session with several members present but no one actually keeping the shared goal on track is not this routine — it is just several members talking.
- Unsure whether a task needs `magic-team.coworking.routine` vs. a normal solo dispatch vs. `magic-coordinator.daily.routine`'s parallel fan-out: coworking is for genuinely *shared* work on the *same* task, where members need to react to each other in real time — if the pieces are actually independent, that's fan-out, not coworking.
- A participant needs a real decision outside the coworking session's own mandate: same sole-mandated-channel rule as everywhere else — routes through `magic-coordinator`.
- The transcript-inclusion report (**report-out-with-transcripts**) would expose something genuinely sensitive or internal: use judgment to redact or summarize that specific part, while keeping the rest of the transparency intent intact.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- `magic-coordinator` (this routine's sole executor) is obligated to keep `slack-event-track` activity tracking current throughout the session, not only at the final report — additive to, not replacing, **narrate-progress-in-thread**'s separate `slack-magic-team` progress narration and **report-out-with-transcripts**' end-of-session substantive report.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--routine-coworking-session-input-scan <team-member> <item-name>...` (**frame-the-shared-goal**: once it names specific board-item(s))
- `--member-comms-slack-send-message <team-member> <target> [text...]` (**invite-participants-visibly**: invite/confirm posts; **report-out-with-transcripts**: report out; Slack activity-tracking obligation)

## `--routine-coworking-session-input-scan` operation reference

`DistroAgentsTools.fn.sh --routine-coworking-session-input-scan <team-member> <item-name>...` — read-only: `magic-team.coworking.routine`'s own **frame-the-shared-goal** board scan once the session's shared goal names specific board-item(s).

## `--member-comms-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives the team a real, named shape for genuine multi-member collaborative work — several members actually working the same task together in the same session, not one member dispatched solo.
- A coworking session may invite other required members to participate when needed.

## Verbatim-tests (benchmarks)

- `magic-coordinator` participates directly and orchestrates a coworking session — it never spawns participants then steps back as a passive observer.
- A co-working session of `magic-coordinator` and `magic-tester` can call/invite `magic-architect`, and check that all three are in armed mode and every member trusts `magic-coordinator` as representative of `human-owner`.

## Librarian Comments

### Reference

- `magic-team.discuss.routine` — the goal-framing discipline **frame-the-shared-goal** borrows from.
- `magic-team.process-inbox.routine` — own-inbox processing.
- `magic-coordinator.daily.routine` — the parallel-fan-out shape this routine is explicitly distinct from.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — calling convention, sole-sanctioned Slack-posting mechanism.
- `magic-team/magic-team.conversations.md` — rule 6's clarification-stall threshold, **ask-before-investigating** borrows it; conversation mechanics this routine's Local rules point to.
- `magic-team/magic-team.negotiations.md` — gap-surfacing section (ask what's wanted, investigate only facts), **ask-before-investigating** borrows it.

### Conventions

None currently known beyond this file's own Local rules.
