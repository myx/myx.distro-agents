---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: standalone
input-scan-def: none
review-by: inherit
---
# magic-team.standalone.routine — the actual procedure

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
  - DistroAgentsTools magic-tooling operations
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions

# Summary

`magic-team.standalone.routine` is one member's session on one task, in a session thread humans and other members talk to it in, until it is dismissed.

## Goals

- Give one member's long-lived work the same named shape a coworking session has: a session thread, an opening, a closing, and a person free to drive it through many topics and long hours.
- Define the `standalone` session kind: the rules, the opening and closing steps and the default settings every routine naming `requires-session-kind: standalone` inherits.
- Let a session start with no routine selected: the dispatch given at the start is the task, and it is updated and replaced as the session goes.

## Scope

- Does:
  - One member's session on the task its dispatch names, with the opening and closing groups every session runs, in their solo form.
  - Start as itself, with no ready task: `--routine magic-team.standalone`.
- Doesn't:
  - Members working together in one session: that is `magic-team.coworking.routine`.
  - A task with a handback from a prompt or a raw dispatch, which has no session documents or folders: that is an ad-hoc start, never a routine.

# Opening steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **session-start**: the shared opening group, in its solo form, steps:
   - **declare-session-type**: state that this session is standalone. Every type-gated step keys off this declaration.
   - **post-opening-broadcast**: post the session type and the goal, if framed, into the session thread. Post at once; completeness never delays it.
   - **fold-in-learned-lessons**: `magic-librarian`, when this session is its own, runs `magic-team.process-reflections.routine` inline (`--routine-run-inline magic-team.process-reflections.routine`) for this session's project or workspace. Any other member passes its own recent lessons to `magic-librarian` with `post-inquiry`, and may file a new `reflection-*`.
   - **collect-reflections-output**: the member runs `magic-team.process-inbox.routine <own-name>` inline (`--routine-run-inline magic-team.process-inbox.routine`), picking up what **fold-in-learned-lessons** filed.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **work-the-dispatch**: the task is the dispatch given at the start, as it stands now: it is updated and replaced as the session goes, and the latest one is the task. Work it, and say each scope change and each piece of work starting as one short line in the session thread (`updated session scope: ...`, `applying ...`).

# Closure steps

1. **close-session**: the shared closing group, in its solo form, steps:
   - **post-closing-broadcast**: post the session's substance into the session thread — resolutions, outcomes, highlights — not a one-line summary. The same substance reaches the session's own parent in the closing handback.
   - **secure-continuity**: the member checks its own part of the session, steps:
     - write anything important that lives only in this session into its own inbox: a `note-*` or a `reflection-*`. A proposed skillset change goes to `magic-coordinator` as an `inquiry-*`, its text labelled `(draft)`.
     - write a ruling on the work into that work's own document, per **decision-lands-in-the-document-it-binds**.
     - reflect on this session's real incidents, if any: corrections, conflicts with the human-owner's words, gaps found live. Frame a broken assumption as "the model was wrong".
     - run `magic-team.process-inbox.routine <own-name>` inline (`--routine-run-inline magic-team.process-inbox.routine`), covering what was just filed and any item this session touched.
   - **compact-session-context**: confirm nothing important lives only in this session, so it is safe to clear.
   - **conclude-session-thread**: react ✅ on the session thread's root with `--member-comms-slack-react`. No live session thread: skip.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- The executor is permitted and obliged to execute every step exactly as written, in order. The executor is one of the running routine's own `executors:`: `magic-coordinator` for this routine itself, whoever the routine names for a routine of this kind.
- **A standalone session has a session thread**, where humans and other members communicate with it. It does not aim to exit as soon as it can: a person may drive it through many topics and long hours, until it is dismissed.
- **session-start and close-session are open to every session.** Any member, and any ad-hoc, solo or IDE-chat session, runs both groups under its own identity, in simplified form where a step is type-gated.
- **Steps are never inherited.** A routine naming this kind inherits this routine's Opening steps, its Closure steps, these rules, its tooling block and its default settings, and runs its own Steps.
- Every wait in this routine follows **wait-never-quit**.
- A gap in understanding follows `magic-team.negotiations.md`'s "Gap surfacing": ask about intent, investigate facts.
- A decision outside the session's mandate goes up to the session's own parent, by "The ladder: one rung at a time".
- Goal-directedness: work toward the session's goal. Off-goal items are recorded quickly, not acted on now.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-comms-slack-send-message <team-member> <target> [text...]`
- `--member-comms-slack-react <team-member> <channel>:<ts> <emoji-name>`
- `--member-append-session-transcript <team-member> --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <text>|--from-stdin|--from-file <path>) --transcript-name <transcript-file-name> [--create]`
- `--member-inbox-note-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]`
- `--member-inbox-reflection-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]`
- `--member-upsert-member-inquiry <member> <item-filename> [--from-file <path>]`
- `--routine-run-inline <routine>`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- A standalone session is one member's session with a session thread, driven by a person or by other members for as long as it is wanted, until it is dismissed.
- A kind is defined by a routine that ships with the tooling; a routine of the kind inherits its rules, its opening and closing steps and its default settings, and nothing else.

## Verbatim-tests (benchmarks)

- A routine naming `requires-session-kind: standalone` runs this routine's Opening steps first and its Closure steps last, around its own Steps.
- `--routine magic-team.standalone` with a dispatch starts one member's session whose task is that dispatch.

## Librarian Comments

### Reference

- `magic-team.coworking.routine` — the kind of members working together in one session; its **session-start** and **close-session** groups are the full forms of the solo groups here.
- `magic-team/magic-team.negotiations.md` — "Gap surfacing".

### Conventions

- **session-start** and **close-session** sub-step names are cited by other routines; keep them stable.
