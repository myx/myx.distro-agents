---
executors: magic-librarian
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-team.process-reflections.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Steps
- Closure steps
- Routine's local procedures
- Routine's local rules
- Routine-specific tooling
  - DistroAgentsTools magic-tooling operations
  - `--member-inbox-note-upsert` operation reference
  - `--librarian-inbox-to-processed` operation reference
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions

# Summary

Routine-process-reflections is the standing mechanism turning a session's own accumulated `reflection-*` inbox notes into durable team knowledge — a magic-team skillset md-files update, a routine-file correction, or a new inquiry.

## Goals

Give the team a real, standing mechanism for turning "Claude learned a lesson this session" (a `reflection-*` inbox note) into actual, durable team knowledge — a skillset md-files update, a routine-file correction, a new inquiry if something's still genuinely unresolved — rather than letting these notes accumulate indefinitely as an ever-growing pile nobody revisits. Genuinely local, machine-only state stays in that project's own `MEMORY.md`/`.local/agents` — never Claude Code's per-project auto-memory, which this routine does not read and does not depend on.

## Scope

Does: close the loop on accumulated `reflection-*` inbox notes. Runs as part of `magic-librarian`'s own normal daily self-sufficiency audit, or on direct request — the human-owner or `magic-coordinator` asking for a sweep of accumulated reflections in a specific project or workspace. **Distinct from `magic-team.process-inbox.routine`**: that routine does the general per-item triage/routing pass, any item type. This routine is the deeper, dedicated pipeline specifically for `reflection-*` items — assess, propose, batch-approve, land in the skillset, retire — not a general inbox pass.
Doesn't do: let them accumulate indefinitely unreviewed.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **process-own-inbox**: run `magic-team.process-inbox.routine <executor>` (typically `magic-librarian`) — inline execution (own identity). `reflection-*` documents only, not the inbox generally — this collects the accumulated reflection notes this routine turns into durable knowledge. Bound "accumulated" against `--librarian-list-team-files-dates` when a specific since-last-pass window is needed, rather than reading the whole pile unbounded every time. Not automatic just because this routine spawned — this explicit call is what actually guarantees it happens.
2. **assess-each-lesson**: for each `reflection-*` item collected above — does this lesson already live somewhere durable (a section of the skillset md-files, a routine file, an existing standing rule), does it need to be newly incorporated, or does it describe something still genuinely unresolved? A matter squarely in `magic-librarian`'s own authoring/conventions territory routes to it directly — file an `inquiry-*` to `magic-librarian`'s own inbox, or call `magic-librarian.conventions-check.routine` — rather than being decided here alone.
   - **Already incorporated**: the reflection is redundant with real team knowledge — a candidate for retirement (see **retire-ingested-files**).
   - **Not yet incorporated, but clear**: **draft a proposal, don't edit yet** — write out the exact skillset md-files/routine-file section and wording this would change, as a proposal (`--member-inbox-note-upsert`), not a live edit. A settled understanding of what should change is not itself authorization to land the change — same "every pipeline step is its own separate authorization" discipline the team applies everywhere else.
   - **Still genuinely unresolved**: file it as a new `inquiry-*`/`reflection-*` board item rather than guessing at a resolution — same "don't guess, escalate a real open question" discipline as everywhere else in the team's process.
3. **batch-approve-with-human-owner**: discuss/approve batched, on a real cadence — bring the accumulated batch of **assess-each-lesson** proposals — not one at a time — to the human-owner for a genuine discussion/approval pass before any of them land. Same batch-then-test floor `magic-team.coworking.routine` already established for magic-team knowledge changes. **Cadence/owner, so this batch doesn't itself become a second unattended backlog**: surfaced at the next `magic-team.grooming.routine` pass, reusing that routine's own existing "human-action-required items" consolidation-and-send mechanism (**gather-the-backlog**'s batch-and-fire-directly pattern, not a filed note hoping some other routine notices) — or sooner, inline, whenever the human-owner is already live in the session processing this routine. **Proportionality carve-out**: an obviously-trivial, self-evidently-correct fix (a typo, a restatement of something already explicitly agreed elsewhere) can get a quick single inline confirm rather than waiting for the next full grooming batch — but never skips confirmation entirely; only a real interface/behavior change needs the full batched discussion. Only an explicitly approved proposal proceeds to **apply-approved-edit**; anything not approved goes back to **assess-each-lesson** (revise the proposal, or reclassify as still unresolved).
4. **apply-approved-edit**: only after **batch-approve-with-human-owner**'s explicit approval — apply the approved change to the real skillset md-files/routine file, exactly as approved (or as amended live during that discussion). This is the only point in this routine where the skillset md-files' content actually changes.
5. **reassess-against-new-cases**: reassess against new live case scenarios as they come up — a reflection that looked fully incorporated at one point may turn out to need refinement once a new real situation actually tests it; this is an ongoing recheck, not a one-time sweep. Applies equally to a proposal still sitting at **batch-approve-with-human-owner** awaiting approval, not just an already-landed **apply-approved-edit**.
6. **retire-ingested-files**: once a `reflection-*` item's lesson is confirmed durably captured elsewhere — meaning **apply-approved-edit** has actually landed, not merely proposed or approved — and reassessed against real cases without turning up any gap, move it to processed via `--librarian-inbox-to-processed` rather than leaving it to sit indefinitely in the live inbox.
7. **merge-across-the-batch**: merge/sort/reassess across the accumulated set as a whole — **process-own-inbox** through **retire-ingested-files** above process one item at a time; this step looks at the currently-accumulated batch together, not just per-item, and is where the actual generalization work this routine exists for happens:
   - **Merge**: several items that turn out to describe the same underlying lesson from different incidents get folded into one replacement (re-)reflection or a single consolidated skillset md-files/routine update, rather than each being separately incorporated/retired in isolation — same "merge, don't duplicate" discipline the board's own board-item model already applies.
   - **Sort**: rank the remaining set by what's actually actionable now (clear, ready to fold in) vs. still genuinely open (needs a new inquiry) vs. stale/superseded by a later item — surface this ordering rather than working strictly in file-creation order.
   - **Reassess as a set, not just individually**: a lesson that looked fully resolved in isolation (**reassess-against-new-cases**) can turn out incomplete or even contradicted once read alongside another item in the same batch — a cross-item view that step's own per-item reassessment can't catch on its own.
   - **Generate whatever the batch-level finding actually calls for**: a single replacement `reflection-*`/`inquiry-*` item consolidating several originals, or a log entry recording what was resolved (so the resolution history survives even after the source items retire) — neither is gated, since neither is a skillset md-files edit. Any actual skillset md-files/routine-file content this step's batch-level finding would produce goes through the same **batch-approve-with-human-owner**/**apply-approved-edit** gate as any other proposal — folded into the same batch, never landed directly from this step.

**No grandfathering — the gate applies unconditionally, to every backlog, including one already substantially processed elsewhere.** The first time this routine touches a backlog — this project's own, or any other project's — **assess-each-lesson**/**batch-approve-with-human-owner**/**apply-approved-edit** apply in full.

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
- Never invents skillset content solely to close out a reflection item: an incorporation has to actually land in a real source file (skillset md-files/routine) — same "fix the source, not just the symptom" discipline as everything else this team does.
- Unsure whether a lesson is truly already captured elsewhere, or only superficially similar: err toward checking the actual current source file content directly, rather than trusting a reflection item's own self-description of what it says — a stale reflection item might describe an incorporation that never actually happened, or happened differently than remembered.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- The Slack activity-tracking obligation (general executor guidance wherever `magic-coordinator` is an executor) does not apply here — this routine's sole executor is `magic-librarian`, not `magic-coordinator`.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-inbox-note-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]` (**assess-each-lesson**: draft a not-yet-approved skillset md-files/routine-file change proposal)
- `--librarian-inbox-to-processed <team-member> <item-filename> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]` (**retire-ingested-files**: move a fully-incorporated `reflection-*` item to processed)

## `--member-inbox-note-upsert` operation reference

Writes (creates or overwrites) a note into any member's own personal inbox — inbox write access is not exclusive to one member; any member may post into any other member's inbox (the standard cross-member handoff mechanism).

## `--librarian-inbox-to-processed` operation reference

Moves one item out of a member's own live inbox into that inbox's processed-items area. Full syntax: `magic-librarian.armed.md`'s own Tooling section.

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine turns a session's own accumulated `reflection-*` inbox notes into actual, durable team knowledge — rather than letting them accumulate indefinitely as an ever-growing pile nobody revisits.

## Verbatim-tests (benchmarks)

- A `reflection-*` item whose lesson already lives durably somewhere else (a section of the skillset md-files, a standing rule) becomes a candidate for retirement, not left sitting alongside its now-redundant duplicate.

## Librarian Comments

### Reference

- `magic-team.process-inbox.routine` — the distinct, general per-item triage/routing operation this routine is explicitly NOT (this routine is the deeper assess/propose/approve/land pipeline, scoped to `reflection-*` items only).
- `magic-team/magic-team.board.md` — the "merge, don't duplicate" board-item-model discipline this routine's own merge step mirrors.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.
- `magic-librarian.conventions-check.routine` — where **assess-each-lesson** routes a lesson needing a conventions ruling.

### Conventions

- This routine's executor scope is `magic-librarian` only — narrower than most routines' open `magic-team`/`*` scope. Preserve this exactly during any edit; do not widen it to `magic-coordinator` or `magic-team/*` even if a future edit elsewhere in the team's docs seems to imply broader involvement — this narrowness is deliberate (folding a lesson into a source file is `magic-librarian`'s own established authoring territory).
- The distinction from `magic-team.process-inbox.routine` (a dedicated assess/propose/approve/land pipeline, not a general inbox pass) is easy to blur in a compressed summary — preserve it explicitly.
