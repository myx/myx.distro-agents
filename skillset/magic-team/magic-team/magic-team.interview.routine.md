---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# routine-interview — the actual procedure

# Summary

Routine-interview is the dedicated place to precisely understand another party's vision or inquiry before trying to converge on anything.

## Goals

Give the team a real, dedicated place to precisely understand another party's vision or inquiry — the human-owner's own design thinking, an external contact's actual need — *before* trying to converge on anything. This is deliberately not about reaching agreement (that's `routine-discuss`'s job) — it exists because collection and convergence are genuinely different modes: rushing to agree before the other party's actual intent is fully captured risks building the wrong thing precisely, or worse, quietly deciding things on their behalf that were never actually settled.

## Scope

Does: collection, minimal-assumption questioning, one topic per thread. Manual-trigger only — the human-owner or a member asks for an interview with a specific party about a specific topic; no autonomous or scheduled trigger. One concrete, recurring trigger: `magic-coordinator/magic-coordinator.armed.md`'s `missing-tool-option-escalation` local procedure — an unresolved, non-simple tooling gap escalates here rather than staying stuck or getting built inline.
Doesn't do: reach agreement (`routine-discuss`'s job).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

0. **Process own inbox**: `routine-process-inbox`(`routine-interview`'s own inbox, the executor running it) — inline execution (own identity). Genuinely load-bearing here, not boilerplate: `routine-interview` is manual-trigger-only with no daily/autonomous invocation anywhere else, so this explicit call is the *only* thing that ever guarantees its own inbox gets read.
1. **Establish the channel, and create the tracking board Item in this same step, not later**: Slack thread (via the `--member-slack-send-message` operation) is the primary channel for an interview session; email (via the `--send-email-message` operation) is the failover for slow-moving or unusually complex matters where a thread's back-and-forth pace doesn't fit. **One topic, one thread — fork, don't absorb**: if an unrelated topic surfaces mid-interview, don't let it bleed into the current thread. Fork it into its own new Slack thread and keep the original thread strictly on its own subject. **The `inquiry-*` board Item (see step 5) gets created right here, at channel-open time — not deferred to "eventually" or to whenever step 5 gets reached.** This step is never deferrable. **When the interview is being opened or resumed by a genuinely live-interactive session**, set `owner-session: interactive` and `owner-session-since: <now>` on the tracking Item's frontmatter at this same moment — refreshed as a heartbeat each time step 1b's resume-review runs under that same live session, so a long-running real conversation never drifts into looking stale mid-way through.
1a. **When more than one interview's tracking Item is open at once, name the specific one when resuming
   it.** A bare "continue"/"next round" with no name is ambiguous and must be treated as a genuine
   assumption gap (conversation-mechanics rule 5a) — ask which interview, propose options, don't guess.

1b. **Resume-review**, whenever this interview is picked up or continued — standing, repeatable, every pickup, not just the first, run before any new question:
   - Review the interview's accumulated board-item and transcript content for sub-pieces already settled but not yet dispatched.
   - Formulate each as a concrete dispatch, get it approved this same continuation, execute it, shrink remaining scope to what's still open — same propose→approve→dispatch cycle as step 3a/3b, same compaction shape as step 3.
   - Runs regardless of what triggered the pickup: this routine's own resumption, a `routine-grooming` pass, `magic-coordinator`'s `coordination-session` closing its `goal-gap-toward-empty`, or an in-progress `routine-advance` pass reaching this item. Never blocks the triggering pass — Slack is the async channel, pickup is round-based.
   - **Concurrency**: whichever entry point picks it up first marks the tracking Item ("resume-review in progress this pass") so a second entry point doesn't collide.
1c. **Re-assess, on every pickup, before writing the next message.**
   - Stick to this interview's own tracking Item only — don't mix in another interview's content.
   - Re-check board/session state fresh each round; never assume last round's read is still current —
     staleness risk scales with how many parallel sessions are active.
   - First: update state if possible (board changes included); check incoming harness/agent messages; check
     any new message in this thread against the current gathered state. Conflict -> resolve it first, don't
     collect yet. No conflict and it's an approval -> act on it, close this round. No conflict and it's new
     content -> collect it.
   - Gather together: the initial ask; approved parts so far (some, not necessarily all); collected info
     (summary so far, still revisable; verbatim-intents; verbatim-benchmarks; interview notes); session
     state (goal, scope, open questions, open conflicts); transcript if needed.
   - Check this gathered material for conflicts within itself, even with no new message — time passing
     between rounds can make it drift out of sync with itself.
   - Conflict found -> resolve it, don't draft yet.
   - No conflict -> draft: built fresh each round from the above, not necessarily saved, and allowed to have
     gaps — that's normal. Where exact wording matters, generate several candidate phrasings and compare
     them directly, same method as conversation-mechanics rule 10b.
   - Before using or showing the draft, check it keeps every verbatim-intent, verbatim-benchmark, and
     stated goal collected so far — nothing dropped, nothing contradicted.
   - When presenting a corrected draft mid-cycle, show what changed against the prior version, not just the
     new text alone — makes it easy to verify nothing else shifted.
   - Showing the whole draft for approval is one option, not the default — usually take small steps that
     gather more exact wording bit by bit. Channel and expected message length matter too — a small task can
     just be one line asking for approval.

1d. **Inherits the team's own `check-restart` procedure** (runs on any resume, separate from
    1b/1c's own content re-assessment). The restated gist, if a nudge is warranted, is the current open
    topic (per that same procedure's own presentation-gist rule).

2. **Collect, don't converge**: ask small, iterative, minimal-assumption questions, confirmed one at a time — never bundle several decisions into one proposal. The goal is capturing the other party's perspective as precisely as possible, not steering it toward a particular answer. **Unless something is already clear and agreed upon — go further.** This pacing discipline is a floor against guessing ahead of real understanding, not a mandate to keep the interview crawling once a point is genuinely settled. **In an interactive UI chat session, default to small, structured UI questions** — one topic each, the `AskUserQuestion`-style mechanism — over plain-text paragraphs if harness method is not available. This session worked better once that became the default. **Switch from asking to proposing only once a piece is verified settled** — a plain one-line restatement the human-owner didn't correct — never because enough turns have passed or the shape merely seems obvious. **A piece not yet verified settled stays in full live context, not summarized**; only a settled-and-dispatched point gets compacted, per step 3's own compaction shape below.
2a. **Rephrase and confirm before acting, every time — this is what actually closes assumption gaps** (human-owner-stated directly, 2026-07-23, after a real misread: a correction that only meant "the value `idle` is wrong" got acted on as "remove the field entirely"). Before doing anything on the back of what the other party just said — fixing something, changing a value, dispatching work — state back, in one line, what you understood them to mean, and only proceed once that's confirmed (or immediately act if the confirmation is itself trivially obvious and low-stakes — this is a floor against silently guessing on anything that isn't). This applies generally, not just inside a formally-named `routine-interview` session — any live back-and-forth with the human-owner or another party benefits from the same discipline whenever a real, actionable correction just came in.
2b. **Work the nearest job to approval next, not the smallest job.** When several open pieces are live at once, prioritize whichever currently has the smallest remaining assumption gap and the highest chance of approval — regardless of that piece's actual size or scope. A large-but-nearly-settled piece outranks a small-but-still-foggy one.
2c. **Before any dispatch/spawn execution, run a strict pre-dispatch confirmation gate with verbatim fidelity**: post a `STATE` block first with these exact fields: `session goal`, `session transcript`, `session members`, `session scope`, `session constraints`, `expected outputs`, `board usage` (explicitly `NO` unless directly authorized). Then post a `DISPATCH PAYLOAD` block containing the exact payload text to be executed, verbatim (no paraphrase, no normalization, no omitted clauses). Execute nothing until the human-owner explicitly responds `APPROVE`; if response is `NO`, do not dispatch and do not execute. For risky/irreversible/detail-sensitive actions, require an explicit member-side confirmation line (`member confirms dangerous/detail action`) in the pre-dispatch readback before requesting approval.
2d. **Filing follows the same gate as dispatch**: don't file a board item unilaterally mid-interview — propose it (what piece, what type, what goal) and wait for confirmation, unless the human-owner explicitly asked for that specific filing.
2e. **Live `GOOD INTERVIEW`/`BAD INTERVIEW` (or pinned `ASSESSMENT`) quality-marker — triggers an immediate
    self-edit of this file.** When the human-owner states `GOOD INTERVIEW`/`BAD INTERVIEW`, or `GOOD
    ASSESSMENT`/`BAD ASSESSMENT` pinned to a specific quoted prior statement of the interviewer's, read back
    the understood rule and check magic-librarian's own conventions (its `.armed.md`/writing-mode
    guidance) before writing, then make a small edit to this file adding a reinforcing (`GOOD`) or corrective
    (`BAD`) rule that captures what just happened, plain and undated. Confirm in the same reply what was
    added. Interview-specific: stays inside this file, not the team's general conversation-mechanics — this
    routine's own instructions already take precedence over that file's general conventions within interview
    scope.
2f. **Live scope-steering trigger keywords — add a topic to this interview's own plan mid-round.** Each
    keyword below runs the same readback-and-confirm step as 2a before the addition counts as settled, and
    before the interview proceeds to its next iteration:
    - `detour:` — places the topic at the TOP of this interview's own plan (highest priority, handled next).
    - `later:` — places the topic at the END of this interview's own plan (lowest priority).
    - `next:` — inserts the topic as the CURRENTLY RUNNING item (immediate focus, ahead of whatever was
      already in progress).
    - `fork:` — same readback-and-confirm step, but the topic does not join this interview's own scope: file
      it as its own new `interview-*` board Item instead, then add the topic to that new Item's own
      scope/goals at the top of its plan once confirmed.
2g. **Inherits the team's own topic/queue/question mechanics.** Both presentation modes
    (next-question and topics-to-choose) are available; use whichever fits the round.

3. **Dispatch settled points as you go, don't just note them.** The moment a piece genuinely settles mid-interview — not the whole topic, just that piece — it goes straight to wherever it actually belongs (a board task/change/note item, `magic-coordinator`'s inbox, a direct doc/code edit if it's that concrete) *right then*, not held until the interview as a whole wraps up. **Then compact the interview's own tracking context**: drop or condense what's now settled-and-dispatched, keep the record focused on what's still genuinely open.

   **Compaction shape, precisely**: once a piece is reassessed, approved, and dispatched, fold it into **one present-tense block** — a plain, current-state statement of what was settled. Not a transcript of the back-and-forth (no "first I asked X, then Y, then corrected to Z") — just the resulting rule/fact/decision, stated directly. Keep every distinct settled point; strip only the question-and-answer framing. Reorganise and reorder for better readability. Good rule doesn't need examples and references.

   The compacted wording itself must be simple and hard to misinterpret, and must not drop any intent,
   detail, or benchmark the original had — same bar as any other proposed formulation.

   Remove dispatched pieces from the interview's own open scope — the tracking record narrows to what's still unresolved. This doesn't mean a dispatched point is never touched again: if context changes, revisiting it is normal. The point is shrinking the *pending* backlog, piece by piece, so the interview actually progresses and eventually concludes empty — not staying open re-litigating settled ground. Reassess, move to the next open question.

   **Compaction keeps distinct categories separate, never flattened into one blob**: plan/queue, verbatim-intents, verbatim-benchmarks, corrections, settled facts, and any decomposed sub-parts of a bigger topic each stay their own section. Compacting means shrinking within each category, not merging categories together.

   **Reducing working context is itself an active goal, not only a side effect of dispatch timing.** Don't wait for a piece to happen to get dispatched before compacting it — periodically check the accumulated transcript for anything already resolved that hasn't been compacted yet, and fold it, same as above. A long-running interview that lets its own working context grow unboundedly between dispatches is a failure of this goal, independent of whether any single piece is individually mishandled.
3a. **For a doable *minimal* step specifically, the dispatch has a concrete shape**: the cycle, inline and iterative, not deferred to a separate session: (1) assess the agreed step with `magic-architect`, live, while the interview continues; (2) turn that into a real proposal; (3) present the proposal back to the human-owner *in this same interview* and ask for approval — not a separate approval routine; (4) once approved, dispatch it to `board-backlog`; (5) apply step 3's context-compaction. Repeat per newly-agreed step. **The interview isn't "done" until there's nothing left to focus on**. This is the accelerated, inline path for something small enough to actually decide and dispatch within the interview itself.
3b. **For something bigger than step 3a's minimal step — a real mechanism/design, not a one-line change — the cycle is dispatch → test → apply → queue, still driven by this same interviewing session, not handed off and forgotten.** Once the interview settles a mechanism's actual shape, (1) spawn a dedicated multi-member sub-session (a `routine-coworking`-style dispatch — e.g. `magic-librarian` + `magic-architect` + `magic-tester` together, not `magic-architect` alone as in step 3a's lighter cycle) to produce a concrete, **tested** work-plan grounded in real files, not assumptions; (2) the *same* interviewing session collects that plan — it doesn't hand off to yet another separate session to apply it; (3) apply the plan's own concrete pieces directly, continuing the interview's own established discipline — small, minimal-assumption questions where something is genuinely still ambiguous; otherwise keep applying and refocusing on the next open bit without pausing for confirmation between every piece; (4) queue whatever's left over — anything the plan itself intentionally deferred — as its own real board item(s), not silently dropped; the same multi-member group step 3b just spawned to design the plan is who it'll take to execute it, so set `restart-session: <the same members>` on the new item(s) at creation, same step. Same completion test as 3a: keep cycling until there's nothing left to focus on. **The spawned sub-session doesn't report back within a bounded window**: this isn't silently dropped — log it as a still-open piece on the interview's own tracking board Item (not compacted away), and if the interview itself wraps up before it resolves, flag it explicitly in the closing-reflection closure step. Step 1b's resume-review picks it back up automatically the next time this interview is continued, same as any other genuinely-settled-but-not-yet-dispatched piece.
4. **Two distinct kinds of verbatim record — not one undifferentiated "test predicate" bucket:**
   - **Verbatim-benchmarks**: concrete scenario -> expected-outcome pairs ("if X happens, the solution should do Y"). Collect as a growing, non-exhaustive checklist — "the proper solution will have/allow: ..." — never a vague "there may be more like this" note. Keep them verbatim, no re-phrasing.
   - **Verbatim-intents**: structural/purpose statements and architectural invariants ("this exists so that...", "the point is to keep X thin/relay-only"). Collect separately from benchmarks — these describe *why*/*what shape*, not a scenario/outcome pair, and don't belong folded into the same checklist. Keep them verbatim, no re-phrasing.
   - **Default framing for both kinds**: what's given is a floor, not a ceiling — a minimum the solution must satisfy, extensible, never a closed/limiting set — unless the other party states an explicit ceiling (a hard number, an explicit "no more than X"). Use bullet points for either list, never a bare numbered list.
   - **A session's own rephrasing of either kind is always a clearly-labeled derivative**, tagged as such wherever recorded — it never overwrites or gets confused with the human-owner's own original verbatim wording, which stays the permanent controlling record for that point. When step 3's compaction folds a settled piece into a present-tense block, the original verbatim benchmark/intent text it derived from stays retrievable (session transcript or original message), not discarded once the compacted rephrase exists.
5. **Keep the tracking board Item current while the interview stays active** (created at step 1, not here) — update its "settled so far" / "still open" sections as step 3's compaction narrows the remaining scope, so the Item itself stays an accurate live snapshot rather than a stale artifact from the moment it was created.

# Closure steps

1. **Closing reflection**: at the end, reflect on how the interview session itself went (process/quality, not just content) and check memory notes. Also check whether this interview surfaced a real behavior/pattern not yet backed by a written rule — a finding for this reflection too, not just wording polish.
2. **Hand off, don't build — except steps 1b/3a/3b's own inline cycles**: once the other party's vision is genuinely captured, the interview's own job is done for anything bigger than what 3a/3b already cover inline — that goes through the normal task-creation lifecycle.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-coordinator` (this routine's sole executor) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- A member with a genuine domain-specific interview need routes that request through `magic-coordinator`, rather than running this routine independently — unless, and until, a real case justifies widening this.
- One documented mechanism failing once is a stop-and-ask signal, not a puzzle to solve alone.
- A small, stable understanding is reached mid-interview: apply and record it inline immediately.
- A bigger understanding emerges mid-interview but isn't yet concrete enough to be step 3a's minimal step or step 3b's settled mechanism: file it as an inbox task referencing the live interview, for `magic-coordinator` to decompose into proper subtasks later — don't decide it on the spot just because the interview surfaced it.
- The other party starts pushing toward a decision or agreement, not just describing their vision: gently keep the session in collection mode if there's more to capture, but don't fight a natural convergence if the other party clearly wants to decide something right now — note explicitly that the mode shifted.
- Unsure whether something the other party said is a firm requirement or just a passing thought: treat it as a real requirement (add to the growing checklist), unless the other party explicitly says otherwise.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- `magic-coordinator` (this routine's sole executor) is obligated to keep `slack-event-track` activity tracking current as the interview actually runs, via the `--member-slack-send-message` operation.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-slack-send-message <team-member> <target> [text...]` (step 1: establish/continue the Slack-thread channel; Slack activity-tracking obligation)
- `--send-email-message <email@address>... -- <subject> -- <body...>` (step 1: email failover channel)

## `--member-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

## `--send-email-message` operation reference

`DistroAgentsTools.fn.sh --send-email-message <email@address>... -- <subject> -- <body...>` (or `-- --from-stdin` / `-- --file <path>` in place of the trailing body) — real standalone SMTP send via curl. Multiple recipients accepted before the first `--`; subject is everything between the two `--` separators; everything after the second becomes the body. Exactly one body source required — giving more than one of trailing-body-argv/`--from-stdin`/`--file` together is an error.

# Maintainer Notes

Used to check this files own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine exists to precisely understand another party's vision or inquiry before trying to converge on anything — collection and convergence are genuinely different modes.

## Verbatim-tests (benchmarks)

- A bare "continue"/"next round" with no interview named, when more than one interview's tracking Item is open, is treated as a genuine assumption gap — it asks which interview rather than guessing.

## Librarian Comments

### Reference

- `routine-discuss` — convergence/decision-oriented, distinct from this routine's collection-only purpose.
- `routine-brainstorm` — idea generation, no agreement expected.
- `routine-coworking` — the multi-member dispatch shape step 3b spawns for a bigger-than-minimal mechanism.
- `routine-process-inbox` — this routine's own inbox processing.
- `magic-coordinator/magic-coordinator.armed.md`'s `missing-tool-option-escalation` local procedure — the tooling-escalation ladder that's one concrete trigger for this routine.
- `magic-coordinator/magic-coordinator.armed.md` — the `coordination-session`/`goal-gap-toward-empty` description step 1b's third entry point refers to.
- `magic-team/magic-team.board.md` — the general item lifecycle, `inquiry-*` item shape, `board-backlog`'s drop-point shape.
- `magic-team/magic-team.conversations.md` — rules 5a/10b this routine's steps borrow, and the general conversation-mechanics baseline this routine's Local rules point to.
- `magic-team/magic-team.negotiations.md` — the `check-restart` procedure and topic/queue/question mechanics steps 1d/2g inherit.
- `magic-team/magic-team.basic.md` — the propose-and-wait-for-confirmation filing gate step 2d reuses.

### Conventions

None currently known beyond this file's own Local rules.