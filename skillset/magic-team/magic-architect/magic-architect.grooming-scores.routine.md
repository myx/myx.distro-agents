---
executors: magic-architect
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
invitees: none
---
# magic-architect.grooming-scores.routine — the actual procedure

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
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions

# Summary

`magic-architect`'s idle-run routine that sets or refines RICE scores on open board items in its architecture-level domain.

## Goals

- Keep architecture-level scores current, so grooming works from real numbers: complexity, blast radius, systems touched, risk.

## Scope

- Does:
  - Propose scores, each with its one line of reasoning, to `magic-coordinator`, who records them on the items.
- Doesn't:
  - Reassign, split or drop items — grooming's job.
  - Write the board.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **review-open-items**: Take the open item names the dispatch lists. With none listed, ask the session's `magic-coordinator` for the open items in this domain. Read each with `--member-board-item-read`.
2. **score-in-domain**: For each item, set or refine a score per `magic-team.grooming.routine`'s `rice-scoring` block. For a structural score (risk, coupling, blast radius):
   - rule: the scenario and its sensitivity point are the one line of reasoning carried with the score.
   - step: name the concrete scenario the item affects — what breaks, under what condition.
   - step: name the sensitivity point — the single design choice that most changes that scenario's outcome.
3. **refresh-stale-scores**: Where refining an old score depends on facts outside this member's knowledge, consult the domain-owning member rather than guessing.
4. **record-on-item**: Hand the scores to `magic-coordinator` for recording on each item: in the session's report, or with `post-inquiry` when no session coordinator is present.

# Closure steps

1. **report-scored**: Report the items scored or changed, each new score and its reasoning. "Scores current" is a valid outcome.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-board-item-read <team-member> <item-filename>`
- `--member-upsert-member-inquiry <team-member> <item-filename>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- A scoring-only pass: scores and their one-line reasoning are kept current, never a triage that reassigns/splits/drops.
- The reasoning recorded is the concrete failure scenario plus its sensitivity point, not the bare score.

## Verbatim-tests (benchmarks)

- No open item in this skill's domain needs a score change: a valid, reportable "scores current" outcome.
- A score change is ready. It reaches the item through `magic-coordinator`; `magic-architect` never writes the board.

## Librarian Comments

### Reference

- `magic-architect.armed.md`'s `## Idle-Tasks` — when this routine fires.
- `magic-team.grooming.routine`'s `rice-scoring` block — the scoring model.

### Conventions

- none
