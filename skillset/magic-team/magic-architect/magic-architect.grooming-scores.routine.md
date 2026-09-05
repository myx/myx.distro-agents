---
executors: magic-architect
maintainers: magic-coordinator, magic-librarian, magic-architect
invitees: none
---
# routine-grooming-scores — the actual procedure

Normative contract: `magic-team/magic-team.shared.md`'s "Armed & Routine contracts" → Routine. This file is a derived skeleton; where the two disagree, `magic-team/magic-team.shared.md` wins.

# Summary

`magic-architect`'s idle-run routine that sets/refines RICE-style scores on open backlog items falling in this skill's own architecture-level domain of judgment.

## Goals

- Review the open backlog items in `board-backlog` and `board-running` (and `board-blocked`/`board-parked` where relevant) and, for items in this skill's own domain of judgment — architecture-level concerns: complexity, blast radius, what systems/patterns get touched, risk — set or refine a RICE-style score per `magic-coordinator/RICE-SCORING.md`'s formula. A scoring-only pass, keeping scores current so grooming works from real numbers rather than stale ones.

## Scope

- Does:
  - Set or refine RICE-style scores on architecture-domain items, recording the reasoning directly on each item.
- Doesn't:
  - Reassign, split, or drop items — that is `magic-team/magic-team.grooming.routine`'s job. This is a scoring-only pass, not a full triage.
  - Create a separate scoring record — the score lives on the board item's own file.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **review-open-items**: Review the open backlog items under `board-backlog` and `board-running` (and `board-blocked`/`board-parked` where relevant) that fall in this skill's own domain of judgment — the board is the sole live backlog source.
2. **score-in-domain**: For each such item, set or refine a RICE-style score per `magic-coordinator/RICE-SCORING.md`'s formula. For a structural score (risk, coupling, blast radius):
   - rule: that scenario + sensitivity point IS the one line of reasoning recorded on the item — not the score alone.
   - step: name the concrete scenario this item affects (what breaks, under what condition) — not "this is risky," the actual failure mode.
   - step: identify the sensitivity point — which single design choice, if changed, most affects that scenario's outcome.
3. **refresh-stale-scores**: A score set weeks ago may no longer reflect what is actually true now. If refining one depends on something outside this skill's own direct knowledge — e.g. how much a domain area has actually changed since the score was last set — consult the domain-owning member (or other relevant skills/current context) rather than guessing.
4. **record-on-item**: Record the score directly on the board item's own file (frontmatter or a dated note), per `magic-coordinator/RICE-SCORING.md`'s "official scores" convention — never a separate scoring record.

# Closure steps

1. **report-scored**: Report back the items scored or changed, the new/refined score, and the reasoning. Then run this member's own post-activity reflection, per `magic-architect.armed.md`.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor (`magic-architect`) is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- Scoring-only: never reassign, split, or drop items here — that is grooming's job.
- Idle-run scheduling (weight, min-interval, scope) is not set here — it lives in `magic-architect.armed.md`'s `## Idle-Tasks` section, which the `grooming-scores-review` selection procedure reads.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-inbox-note-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]` (**report-scored**: file findings to this member's own inbox where a durable record is warranted)

## `--member-inbox-note-upsert` Operation Reference

`DistroAgentsTools.fn.sh --member-inbox-note-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]` — writes (creates or overwrites) a note into `<member>`'s own inbox. Content via stdin by default, or `--from-file <path>`. `<item-filename>` is a bare filename, no path separators. (The board-item scoring itself is written on each item's own file; the actual board-write op is `magic-coordinator`'s, so a score change this routine cannot write directly is handed back through `magic-coordinator`.)

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- A scoring-only pass: scores and their one-line reasoning are kept current, never a triage that reassigns/splits/drops.
- The reasoning recorded is the concrete failure scenario plus its sensitivity point, not the bare score.

## Verbatim-tests (benchmarks)

- No open item in this skill's domain needs a score change: a valid, reportable "scores current" outcome.

## Librarian Comments

### Reference

- `magic-architect.armed.md`'s `## Idle-Tasks` section — the scheduling policy governing when this routine fires.
- `magic-coordinator/RICE-SCORING.md` — the four-dimension scoring model.
- Migrated to routine form in the 2026-09 idle-task-to-routine refactor.

### Conventions

- None currently known beyond this file's own Local rules.
