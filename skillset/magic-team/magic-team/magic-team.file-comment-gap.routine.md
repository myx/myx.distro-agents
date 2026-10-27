---
type: routine
executors: keeper-?
maintainers: magic-coordinator, magic-librarian, magic-architect
invitees: none
requires-session-kind: standalone
input-scan-def: none
review-by: inherit
---
# magic-team.file-comment-gap.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Opening steps
- Steps
- Closure steps
- Routine's local procedures
- Routine's local rules
- Routine-specific tooling
  - Tooling operations
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions

# Summary

An idle-run routine of a `keeper-*` member: it adds one grounded file-header comment to an understood file of that keeper's own legacy tree that lacks one.

## Goals

- Pick one file of the executor's own territory that has been read and actually understood but lacks a good comment, and add a short file-header comment stating why this file is distinct from all the others: its specific reason for existing, the non-obvious thing about it.
- Never how it works line by line, and never a restatement of the interface it implements.
- One file per pass, cumulative.

## Scope

- Does:
  - One grounded distinctness comment per pass, on a genuinely understood file of the executor's territory.
- Doesn't:
  - Comment how the file works line by line, restate its interface, or re-touch a file already logged in `processed/`.
  - Change the file beyond its comment. What else the executor's `rules` input keeps out applies as well.
  - Set its own scheduling: that is the executor's `## Idle-Tasks` entry.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **read-own-inputs**: Read this routine's entry in the executor's own `.armed.md` `## Idle-Tasks`, and the inputs nested under it, rules:
   - `scope` is the territory, and the kinds of file in it.
   - `covers`, `lands-in`, `log` and `rules`, where given, are the executor's own: they apply in the steps below.
   - An entry with no `lands-in` is a gap in that file: escalate it, and do not guess one.
2. **pick-understood-file**: Pick one file of the territory that has been read and actually understood, lacks a good comment, and is not already logged in `processed/`, rules:
   - Understanding comes from reading the file and its own dependencies, never from its name or its package's place in a taxonomy.
   - A file that cannot be described in one specific, true sentence is not understood: pick another.
3. **add-distinctness-comment**: Add a short file-header comment stating why this file is distinct from all the others, at the angle `covers` names, rules:
   - Never line-by-line mechanics, and never a restatement of the interface it implements.
   - The comment lands only where `lands-in` says.

# Closure steps

1. **log-outcome**: Log the activity and its outcome, rules:
   - By default, log it as a new dated file under `processed/` (`processed/<board-item-type>-<date>-<short-topic>.md`, a real board-item type, never an invented word). Then run this member's own post-activity reflection (`--upsert-inbox-reflection`), per its own `.armed.md`.
   - Where the executor's `log` input names another form, that form is used instead.
   - Where the workspace keeps no team data (the tool answers `this workspace keeps no team data`), nothing is filed: what would have been filed goes into the report to whoever dispatched this run.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- The executing member is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- The executor's own inputs bind as this routine's rules while it runs. Where an input and a rule here conflict, escalate it.
- Each pass advances to a new file: coverage keeps growing, never stalls on a repeat.
- Idle-run scheduling (`weight`, `min-interval`, `scope`) is not set here: it is the executor's `## Idle-Tasks` entry, which its idle-task procedure reads.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## Tooling operations

- `--console-start [--override-workspace <path>] [--console DistroSourceConsole.sh|DistroDeployConsole.sh] [--ttl <seconds>]` (**pick-understood-file**: batch the reads)
- `--console-send <channel> [-- <command...>]` (**pick-understood-file**)
- `--upsert-inbox-reflection <item-filename> [--from-file <path>|--edit-patch-from-stdin]` (**log-outcome**)
- `--upsert-inbox-note <item-filename> [--from-file <path>|--edit-patch-from-stdin]` (**log-outcome**, where `log` names a note)

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- The comment states the file's reason for existing, never line-by-line mechanics; one file per pass, never a repeat.
- A comment is written only from source actually read — an unread file is never described.

## Verbatim-tests (benchmarks)

- No understood, un-commented file found this pass is a valid, reportable outcome.
- A file whose purpose is inferred from its package-taxonomy name alone is rejected as a candidate.

## Librarian Comments

### Reference

- Each executor's `.armed.md` `## Idle-Tasks` entry for this routine — its scheduling and its inputs.
- `magic-team.readme-gap.routine` — the sibling routine that reuses this "read and actually understood" bar.

### Conventions

- One shared routine for every member that runs it. What differs per member is an input in that member's own Idle-Tasks entry, never a copy of this file.
