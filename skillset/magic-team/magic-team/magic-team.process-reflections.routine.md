---
executors: magic-librarian
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# magic-team.process-reflections.routine — the actual procedure

# Summary

Routine-process-reflections is the standing mechanism turning a session's learned-lesson memory file into durable team knowledge — a magic-team skillset md-files update, a routine-file correction, or a new inquiry.

## Goals

Give the team a real, standing mechanism for turning "Claude learned a lesson this session" (a `feedback_*.md`-style memory file) into actual, durable team knowledge — a skillset md-files update, a routine-file correction, a new inquiry if something's still genuinely unresolved — rather than letting these files accumulate indefinitely as an ever-growing pile nobody revisits. This closes a real structural gap: personal auto-memory is scoped per-project (personal Claude auto-memory is not a reliable cross-session store) and is exactly the kind of thing that's easy to write once, mid-incident, and then never look at again — this routine is the standing process that actually closes that loop.

## Scope

Does: close the loop on `feedback_*.md`-style memory files. Runs as part of `magic-librarian`'s own normal daily self-sufficiency audit, or on direct request — the human-owner or `magic-coordinator` asking for a sweep of accumulated feedback files in a specific project or workspace. **Distinct from `magic-team.process-inbox.routine`**: that routine processes board-adjacent inbox *items* (a member's own personal-inbox `.md` files — requests, hand-offs, `reflection-*` board-lifecycle items). This routine processes a different, separate category entirely — Claude's own per-session auto-memory `feedback_*.md`-style files (the personal, cross-conversation learned-lesson files referenced from `~/.claude/projects/<project>/memory/MEMORY.md`), which are not board items and not part of any member's inbox.
Doesn't do: let them accumulate indefinitely unreviewed.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **process-own-inbox**: run `magic-team.process-inbox.routine <executor>` (typically `magic-librarian`) — inline execution (own identity). `reflection-*` documents only, not the inbox generally — the in-inbox counterpart to the `feedback_*` auto-memory files **read-feedback-files** reads. Not automatic just because this routine spawned — this explicit call is what actually guarantees it happens.
2. **read-feedback-files**: read the accumulated `feedback_*`-style memory files for the project/workspace this session is operating in — these are Claude's own learned-lesson files, distinct from board-items and distinct from any member's personal inbox content.
3. **assess-each-lesson**: for each one — does this lesson already live somewhere durable (a section of the skillset md-files, a routine file, an existing standing rule), does it need to be newly incorporated, or does it describe something still genuinely unresolved?
   - **Already incorporated**: the memory file is redundant with real team knowledge — a candidate for retirement (see **retire-ingested-files**).
   - **Not yet incorporated, but clear**: **draft a proposal, don't edit yet** — write out the exact skillset md-files/routine-file section and wording this would change, as a proposal (`--member-inbox-note-upsert`), not a live edit. A settled understanding of what should change is not itself authorization to land the change — same "every pipeline step is its own separate authorization" discipline the team applies everywhere else.
   - **Still genuinely unresolved**: file it as a new `inquiry-*`/`reflection-*` board item rather than guessing at a resolution — same "don't guess, escalate a real open question" discipline as everywhere else in the team's process.
4. **batch-approve-with-human-owner**: discuss/approve batched, on a real cadence — bring the accumulated batch of **assess-each-lesson** proposals — not one at a time — to the human-owner for a genuine discussion/approval pass before any of them land. Same batch-then-test floor `magic-team.coworking.routine` already established for magic-team knowledge changes. **Cadence/owner, so this batch doesn't itself become a second unattended backlog**: surfaced at the next `magic-team.grooming.routine` pass, reusing that routine's own existing "human-action-required items" consolidation-and-send mechanism (**gather-the-backlog**'s batch-and-fire-directly pattern, not a filed note hoping some other routine notices) — or sooner, inline, whenever the human-owner is already live in the session processing this routine. **Proportionality carve-out**: an obviously-trivial, self-evidently-correct fix (a typo, a restatement of something already explicitly agreed elsewhere) can get a quick single inline confirm rather than waiting for the next full grooming batch — but never skips confirmation entirely; only a real interface/behavior change needs the full batched discussion. Only an explicitly approved proposal proceeds to **apply-approved-edit**; anything not approved goes back to **assess-each-lesson** (revise the proposal, or reclassify as still unresolved).
5. **apply-approved-edit**: only after **batch-approve-with-human-owner**'s explicit approval — apply the approved change to the real skillset md-files/routine file, exactly as approved (or as amended live during that discussion). This is the only point in this routine where the skillset md-files' content actually changes.
6. **reassess-against-new-cases**: reassess against new live case scenarios as they come up — a feedback file that looked fully incorporated at one point may turn out to need refinement once a new real situation actually tests it; this is an ongoing recheck, not a one-time sweep. Applies equally to a proposal still sitting at **batch-approve-with-human-owner** awaiting approval, not just an already-landed **apply-approved-edit**.
7. **retire-ingested-files**: once a `feedback_*.md` file's lesson is confirmed durably captured elsewhere — meaning **apply-approved-edit** has actually landed, not merely proposed or approved — and reassessed against real cases without turning up any gap, it becomes obsolete — flag it as eligible for deletion (actual `rm` still needs whatever permission convention applies) rather than leaving it to sit indefinitely as a standalone file nobody revisits.
8. **merge-across-the-batch**: merge/sort/reassess across the accumulated set as a whole — **read-feedback-files** through **retire-ingested-files** above process one file at a time; this step looks at the currently-accumulated batch together, not just per-file, and is where the actual generalization work this routine exists for happens:
   - **Merge**: several files that turn out to describe the same underlying lesson from different incidents get folded into one replacement (re-)reflection or a single consolidated skillset md-files/routine update, rather than each being separately incorporated/retired in isolation — same "merge, don't duplicate" discipline the board's own board-item model already applies.
   - **Sort**: rank the remaining set by what's actually actionable now (clear, ready to fold in) vs. still genuinely open (needs a new inquiry) vs. stale/superseded by a later file — surface this ordering rather than working strictly in file-creation order.
   - **Reassess as a set, not just individually**: a lesson that looked fully resolved in isolation (**reassess-against-new-cases**) can turn out incomplete or even contradicted once read alongside another file in the same batch — a cross-file view that step's own per-file reassessment can't catch on its own.
   - **Generate whatever the batch-level finding actually calls for**: a single replacement `reflection-*`/`inquiry-*` file consolidating several originals, or a log entry recording what was resolved (so the resolution history survives even after the source files retire) — neither is gated, since neither is a skillset md-files edit. Any actual skillset md-files/routine-file content this step's batch-level finding would produce goes through the same **batch-approve-with-human-owner**/**apply-approved-edit** gate as any other proposal — folded into the same batch, never landed directly from this step.

**No grandfathering — the gate applies unconditionally, including to backlogs already substantially processed under the old process elsewhere.** A feedback backlog that was mid-way through direct-edit incorporation when this gate was introduced does not get to finish under the old rules; the first time this routine touches it going forward (this project's own backlog, or any other project's), **assess-each-lesson**/**batch-approve-with-human-owner**/**apply-approved-edit** apply in full.

# Closure steps

Invoked inline: nothing. Run as its own session: execute `magic-team.coworking.routine`'s Closure Steps.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-librarian` (this routine's sole executor) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- Never invents skillset content solely to close out a memory file: an incorporation has to actually land in a real source file (skillset md-files/routine) — same "fix the source, not just the symptom" discipline as everything else this team does.
- Unsure whether a lesson is truly already captured elsewhere, or only superficially similar: err toward checking the actual current source file content directly, rather than trusting a memory file's own self-description of what it says — a stale memory file might describe an incorporation that never actually happened, or happened differently than remembered.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- The Slack activity-tracking obligation (general executor guidance wherever `magic-coordinator` is an executor) does not apply here — this routine's sole executor is `magic-librarian`, not `magic-coordinator`.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-inbox-note-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]` (**assess-each-lesson**: draft a not-yet-approved skillset md-files/routine-file change proposal)

## `--member-inbox-note-upsert` operation reference

Writes (creates or overwrites) a note into any member's own personal inbox — inbox write access is not exclusive to one member; any member may post into any other member's inbox (the standard cross-member handoff mechanism).

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine turns a session's own learned-lesson memory files into actual, durable team knowledge — rather than letting them accumulate indefinitely as an ever-growing pile nobody revisits.

## Verbatim-tests (benchmarks)

- A feedback file whose lesson already lives durably somewhere else (a section of the skillset md-files, a standing rule) becomes a candidate for retirement, not left sitting alongside its now-redundant duplicate.

## Librarian Comments

### Reference

- `magic-team.process-inbox.routine` — the distinct, board-adjacent inbox-item operation this routine is explicitly NOT (different input category: `feedback_*.md` auto-memory files vs. inbox items).- `magic-team/magic-team.board.md` — the "merge, don't duplicate" board-item-model discipline this routine's own merge step mirrors.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.
- `~/.claude/projects/<project>/memory/MEMORY.md` — the index referencing the `feedback_*.md` files this routine processes.

### Conventions

- This routine's executor scope is `magic-librarian` only — narrower than most `routine-*` folders' open `magic-team`/`*` scope. Preserve this exactly during any edit; do not widen it to `magic-coordinator` or `magic-team/*` even if a future edit elsewhere in the team's docs seems to imply broader involvement — this narrowness is deliberate (folding a lesson into a source file is `magic-librarian`'s own established authoring territory).
- The distinction from `magic-team.process-inbox.routine` (different input category entirely — auto-memory `feedback_*.md` files, not board-adjacent inbox items) is easy to blur in a compressed summary — preserve it explicitly.
