---
type: routine
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: standalone
start-context: inline
input-scan-def: none
review-by: inherit
---
# magic-team.inline.routine — the actual procedure

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

`magic-team.inline.routine` is what a routine run inline inherits, in place of its session kind's routine: the Closure steps and the rules of a call inside the caller's own session.

## Goals

- Make an inline run a call: it inherits the caller's session, its thread and its context, and gives back only its result.
- Let an inline run carry only steps designed for inline, and none of a session's, such as the reflections or a post of its own.

## Scope

- Does:
  - Supply the Closure steps and the rules that `--routine-run-inline` mixes around the Steps of the routine it hands the caller.
- Doesn't:
  - Run on its own: it is never started as a session (`start-context: inline`). It has no Opening steps and no Steps: a routine run inline brings its own.
  - Start a session, name a transcript, hand back or dismiss anyone: the caller's session does.

# Opening steps

None.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

None of its own: the routine run inline brings its own Steps.

# Closure steps

Run inline: the result goes back to the caller, below. Each step of this routine that a routine may skip (`skips-inherited:`) is a section of its own, named as the step.

## return-the-result

Give the result back to the caller as the end of the call: what the routine did, what it found and what it leaves for the caller to do. The caller's own steps carry on from it. No handback, no dismissal and no reflection of its own: the caller's session closes them.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- The caller is permitted and obliged to execute every step exactly as written, in order.
- An inline run is the caller's own: the same member, the same session thread, the same workspace and tracking documents. It starts no session of its own, and every wait in it follows the caller's.
- The input scan of the routine run inline was run for this call by `--routine-run-inline`, and its result is where that call said: "this run's input scan result" means that file.
- Steps are never inherited. A routine run inline inherits this routine's Closure steps and these rules, in place of those of its session kind, and runs its own Steps.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## Tooling operations

None.

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- An inline run is a call, not a session: it inherits the caller's context and returns only its result into it.
- An inline run carries only steps designed for inline, and none of a session's, such as the reflections.

## Verbatim-tests (benchmarks)

- `--routine-run-inline` of a routine hands the run the routine's Steps with this routine's Closure steps after them, and none of its session kind's Opening or Closure steps.
- The text handed back has neither the routine's frontmatter nor its Maintainer Notes.

## Librarian Comments

### Reference

- `magic-team.standalone.routine`, `magic-team.coworking.routine` — the session kinds whose Opening and Closure steps an inline run does not inherit.
- `magic-team/magic-team.negotiations.md` — "Gap surfacing".

### Conventions

- **return-the-result** is cited by other routines; keep it stable.
