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
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions

# Summary

`magic-team.process-reflections.routine` turns accumulated `reflection-*` lessons into durable team knowledge.

## Goals

- Close the loop on reflections: each lesson ends incorporated in the skillset, filed as an open question, or retired as already covered — never left in a growing pile.

## Scope

- Does:
  - The reflections and lesson inquiries in `magic-librarian`'s inbox: assess, propose, agree with maintainers, land, retire.
  - Runs at `magic-team.coworking.routine`'s **fold-in-learned-lessons**, in `magic-librarian`'s own daily audit, or on request for a project or workspace.
- Doesn't:
  - A general inbox pass (`magic-team.process-inbox.routine`).
  - Land a skillset change outside the change rule.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **process-own-inbox**: run `magic-team.process-inbox.routine magic-librarian`, collecting the `reflection-*` items and the lessons other members passed as `inquiry-*`.
2. **assess-each-lesson**: per lesson, check the current source files, never the reflection's own claim about them, steps:
   - already captured in a skillset file or standing rule: a retirement candidate.
   - not yet captured, and clear: draft the exact change — file, section, wording, labelled `(draft)` — as a `note-*` in own inbox. Never a live edit.
   - still unresolved: file it as an `inquiry-*` to `magic-coordinator`.
   - a conventions question: run `magic-librarian.conventions-check.routine` on it.
3. **merge-across-the-batch**: read the open set together, steps:
   - fold lessons describing one underlying lesson into one replacement item or one consolidated draft.
   - sort the rest: ready now, still open, stale or superseded.
   - re-assess each lesson against the others; a lesson complete alone may be incomplete or contradicted beside another.
   - a consolidated draft joins the batch for **agree-with-maintainers**, never landed from here.
4. **agree-with-maintainers**: bring the drafts to a `magic-team.coworking.routine` session whose participants are each target file's `maintainers:`, with `magic-librarian` running `magic-librarian.conventions-check.routine` on them. A draft lands only on `quorum-all-agree` of that file's maintainers. No such session can run now: ask `magic-coordinator` to convene one, with `post-inquiry`. A draft not agreed returns to **assess-each-lesson**.
5. **apply-approved-edit**: apply each agreed change to the real skillset file, exactly as agreed or as amended in that session.
6. **reassess-against-new-cases**: re-check landed and pending lessons as new real cases arrive. A case exposing a gap reopens the lesson.
7. **retire-ingested-files**: mark each lesson whose change has landed, and held against real cases, processed with `--librarian-inbox-to-processed`.

# Closure steps

Run inline: none. Run as its own session: run `magic-team.coworking.routine`'s **close-session** group.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- `magic-librarian` is permitted and obliged to execute every step exactly as written, in order.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- Every lesson goes through **agree-with-maintainers**, however small, and whatever was processed elsewhere before.
- A lesson is incorporated only by a real change to a real skillset file, never by content invented to close the item.
- A lesson lands where `magic-team.armed.md`'s "Knowledge destinations" says.
- Waiting for maintainers follows **wait-never-quit**.
- Goal-directedness: work toward the session's goal. Off-goal items are recorded quickly, not acted on now.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-inbox-note-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]`
- `--member-upsert-member-inquiry <member> <item-filename> [--from-file <path>]`
- `--librarian-inbox-to-processed <team-member> <item-filename> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine turns a session's own accumulated `reflection-*` inbox notes into actual, durable team knowledge — rather than letting them accumulate indefinitely as an ever-growing pile nobody revisits.

## Verbatim-tests (benchmarks)

- A `reflection-*` item whose lesson already lives durably somewhere else (a section of the skillset md-files, a standing rule) becomes a candidate for retirement, not left sitting alongside its now-redundant duplicate.

## Librarian Comments

### Reference

- `magic-team/magic-team.armed.md` — the skillset change rule **agree-with-maintainers** applies.
- `magic-librarian.conventions-check.routine` — run on every draft.

### Conventions

- `magic-librarian` is the sole executor; keep it so.
