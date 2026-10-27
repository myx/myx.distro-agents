---
type: routine
executors: keeper-?, partner-?
maintainers: magic-coordinator, magic-librarian, magic-architect
invitees: none
requires-session-kind: standalone
input-scan-def: none
review-by: inherit
---
# magic-team.readme-gap.routine — the actual procedure

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

An idle-run routine of a `keeper-*` or `partner-*` member: it finds the most consequential README gap in that member's own territory, and closes it with one short, source-grounded README or a draft for `magic-librarian`.

## Goals

- Find, in the executor's own territory, one directory or package with no README, or a near-empty or unedited-stub one, that a person would actually hit while trying to understand the tree.
- Ground what is said in the real source, and say what the directory is and why it is distinct from its siblings, never a full manual.
- Either write the README, or hand `magic-librarian` a precise, grounded draft: the executor's own inputs say which.
- One gap per pass, cumulative.

## Scope

- Does:
  - One README gap per pass, in the executor's own territory, closed by the outcome its inputs name.
- Doesn't:
  - Write a full manual or exhaustive API docs, or re-touch a directory already logged in `processed/`.
  - Backfill a missing `CLAUDE.md`. A missing `CLAUDE.md` beside an existing README is a separate convention, filled incidentally during other work and never by a sweep. This routine is not used for it.
  - Ground content in ticket or board text, or in guesswork.
  - Set its own scheduling: that is the executor's `## Idle-Tasks` entry.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **read-own-inputs**: Read this routine's entry in the executor's own `.armed.md` `## Idle-Tasks`, and the inputs nested under it, rules:
   - `scope` is the territory.
   - `outcome` is `write` (the executor writes the README) or `hand-off` (the executor drafts it for `magic-librarian`).
   - `candidates`, `grounding`, `covers`, `lands-in`, `log` and `rules`, where given, are the executor's own: they apply in the steps below.
   - An entry with no `outcome` is a gap in that file: escalate it, and do not guess one.
2. **hunt-readme-gap**: Hunt the territory for a directory or package with no README, or a near-empty or unedited-stub one, rules:
   - Check the known `candidates` first, and recheck each rather than assume it is still true.
   - Skip anything already logged in `processed/`, and a directory that has a README but no `CLAUDE.md`.
   - Pick the most consequential gap, not the first found.
3. **establish-understanding**: Read the picked directory's own source until something true and specific can be said about it, rules:
   - The sources are the ones `grounding` names, else the directory's own `project.inf`, files and build files.
   - A directory whose purpose is only inferable from its name or its place in a taxonomy is not understood: pick another.
   - Depth the executor cannot verify itself is asked of the member its `rules` name, never guessed.
   - Nothing is written before this step's bar is met.
4. **close-the-gap**: With `outcome: write`, write a short README. With `outcome: hand-off`, draft it and hand it to `magic-librarian`, rules:
   - The README says what the directory is and why it is distinct from its siblings, at the angle `covers` names.
   - It is never a full manual and never repeats a credential.
   - `write`: the README lands only where `lands-in` says, and nothing else in the directory is edited.
   - `hand-off`: do not edit the README. Post `magic-librarian` an inquiry with the path and what it should say, grounded in what was read. Where the workspace keeps no team data (`this workspace keeps no team data`), the draft goes into the report instead.

# Closure steps

1. **report-and-log**: Report back to whoever dispatched this run: the directory picked, why it is the most consequential gap found, and what was written or handed over. Then log it, rules:
   - By default, log the outcome as a new dated file under `processed/` (`processed/<board-item-type>-<date>-<short-topic>.md`, a real board-item type, never an invented word), and file a `reflection-*` with `--upsert-inbox-reflection`.
   - Where the executor's `log` input names another form, that form is used instead.
   - Where the workspace keeps no team data, nothing is filed: what would have been filed goes into the report.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- The executing member is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- With `outcome: write`, the README is this routine's own sanctioned output: the executor's read-only-by-default posture for `README.md` does not block **close-the-gap**.
- The executor's own inputs bind as this routine's rules while it runs. Where an input and a rule here conflict, escalate it.
- Each pass advances to a new gap: coverage keeps growing, never stalls on a repeat.
- Idle-run scheduling (`weight`, `min-interval`, `scope`) is not set here: it is the executor's `## Idle-Tasks` entry, which its idle-task procedure reads.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## Tooling operations

- `--console-start [--override-workspace <path>] [--console DistroSourceConsole.sh|DistroDeployConsole.sh] [--ttl <seconds>]` (**hunt-readme-gap**, **establish-understanding**: batch the reads across the tree)
- `--console-send <channel> [-- <command...>]` (**hunt-readme-gap**, **establish-understanding**)
- `--upsert-inbox-inquiry --team-member <member> <item-filename> [--from-file <path>]` (**close-the-gap**, `hand-off`; also to ask depth of the member `rules` names)
- `--upsert-inbox-reflection <item-filename> [--from-file <path>|--edit-patch-from-stdin]` (**report-and-log**)
- `--upsert-inbox-note <item-filename> [--from-file <path>|--edit-patch-from-stdin]` (**report-and-log**, where `log` names a note)

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- A README written here says what the directory is and why it is distinct from its siblings, never how it works as a manual would.
- Nothing is written about a directory until its source has actually been read; content is grounded in real source, never ticket text.
- The most consequential gap is chosen. Where the outcome is a hand-off, the README itself is written by `magic-librarian`, not the executor.
- This routine is about READMEs alone; a `CLAUDE.md` gap is a different convention and is not closed here.

## Verbatim-tests (benchmarks)

- No consequential, understood README gap found this pass is a valid, reportable outcome.
- A directory with an existing README and no `CLAUDE.md` is not a candidate for this routine.
- A directory whose purpose is inferred from its name alone is rejected as a candidate.

## Librarian Comments

### Reference

- Each executor's `.armed.md` `## Idle-Tasks` entry for this routine — its scheduling and its inputs.
- `magic-team.file-comment-gap.routine` — the sibling routine with the same "read and actually understood" bar.
- `magic-librarian` — the README-writing destination of a hand-off.

### Conventions

- One shared routine for every member that runs it. What differs per member is an input in that member's own Idle-Tasks entry, never a copy of this file.
