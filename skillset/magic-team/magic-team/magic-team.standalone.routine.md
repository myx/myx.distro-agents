---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: standalone
input-scan-def: none
review-by: inherit
runs-at: none
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
  - Tooling operations
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions

# Summary

`magic-team.standalone.routine` is one member's session on one task, in a session thread humans and other members talk to it in, until it is dismissed.

## Goals

- Give one member's long-lived work the same named shape a coworking session has. That is a session thread, an opening, a closing, and a person free to drive it through many topics and long hours.
- Define the `standalone` session kind: the rules, the opening and closing steps and the default settings every routine naming `requires-session-kind: standalone` inherits.
- Let a session start with no routine selected. The dispatch given at the start is the task, and it is updated and replaced as the session goes.

## Scope

- Does:
  - One member's session on the task its dispatch names, with the opening and closing groups every session runs, in their solo form.
  - Start as itself, with no ready task: `--routine magic-team.standalone`.
- Doesn't:
  - Members working together in one session: that is `magic-team.coworking.routine`.
  - A task with a handback from a prompt or a raw dispatch, which has no session documents or folders. That is an ad-hoc start, never a routine.

# Opening steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

Each step of this routine that a routine of its kind may skip (`skips-inherited:`) is a section of its own. It is named as the step, in the order it runs.

## session-start

The shared opening group, in its solo form, steps:

### declare-session-type

State that this session is standalone. Every type-gated step keys off this declaration.

### post-opening-broadcast

Post the session type and the goal, if framed, into the session thread. Post at once; completeness never delays it.

### fold-in-learned-lessons

`magic-librarian`, when this session is its own, runs `magic-team.process-reflections.routine` inline (`--routine-run-inline magic-team.process-reflections.routine`) for this session's project or workspace. Any other member passes its own recent lessons to `magic-librarian` with `post-inquiry`, and may file a new `reflection-*`.

### collect-reflections-output

The member runs `magic-team.process-inbox.routine <own-name>` inline (`--routine-run-inline magic-team.process-inbox.routine`), picking up what **fold-in-learned-lessons** filed.

## opening-checkpoint

The last Opening step, only where this routine's `access-control:` carries `executors:allow-tool:--executor-checkpoint-push` (a single-participant routine): run `DistroAgentsSession.fn.sh --executor-checkpoint-push opening`. A routine that does not name it does not run this step, and that is no skipped step.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **work-the-dispatch**: the task is the dispatch given at the start, as it stands now. It is updated and replaced as the session goes, and the latest one is the task. Work it, and say each scope change and each piece of work starting as one short line in the session thread (`updated session scope: ...`, `applying ...`).

# Closure steps

Each step of this routine that a routine of its kind may skip (`skips-inherited:`) is a section of its own. It is named as the step, in the order it runs.

## close-session

The shared closing group, in its solo form, steps:

### post-closing-broadcast

Post the session's substance into the session thread — resolutions, outcomes, highlights — not a one-line summary. The same substance reaches the session's own parent in the closing handback.

### secure-continuity

The member checks its own part of the session, steps:

- write anything important that lives only in this session into its own inbox: a `note-*` or a `reflection-*`. A proposed skillset change goes to `magic-coordinator` as an `inquiry-*`, its text labelled `(draft)`.
- write a ruling on the work into that work's own document, per **decision-lands-in-the-document-it-binds**.
- reflect on this session's real incidents, if any: corrections, conflicts with the human-owner's words, gaps found live. Frame a broken assumption as "the model was wrong".
- run `magic-team.process-inbox.routine <own-name>` inline (`--routine-run-inline magic-team.process-inbox.routine`), covering what was just filed and any item this session touched.

### compact-session-context

Confirm nothing important lives only in this session, so it is safe to clear.

### conclude-session-thread

React ✅ on the session thread's root with `--slack-react`. No live session thread: skip.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- The executor is permitted and obliged to execute every step exactly as written, in order. The executor is one of the running routine's own `executors:`: `magic-coordinator` for this routine itself, whoever the routine names for a routine of this kind.
- **A standalone session has a session thread**, where humans and other members communicate with it. It does not aim to exit as soon as it can. A person may drive it through many topics and long hours, until it is dismissed.
- **session-start and close-session are open to every session.** Any member, and any ad-hoc, solo or IDE-chat session, runs both groups under its own identity, in simplified form where a step is type-gated.
- **Steps are never inherited.** A routine naming this kind runs its own Steps. It inherits this routine's Opening steps, its Closure steps, these rules, its tooling block and its default settings.
- Every wait in this routine follows **wait-never-quit**.
- A gap in understanding follows **gap-surfacing**: ask about intent, investigate facts.
- A decision outside the session's mandate goes up to the session's own parent, by "The ladder: one rung at a time".
- Goal-directedness: work toward the session's goal. Off-goal items are recorded quickly, not acted on now.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

BatchTools: several tool calls in one round, much quicker for calls that do not depend on each other.

Contacts, the people you meet and reach, are kept by tooling, not by hand, with `DistroAgentsContacts.fn.sh`. Use `--contacted-by <value>` when someone writes to you, `--reach-contact <id>` to write to someone, and `--collect-contact` to record one.

## Tooling operations

- `--slack-send-message <target> [text...]`
- `--slack-react <channel>:<ts> <emoji-name>`
- `--append-transcript --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <text>|--from-stdin|--from-file <path>) --transcript-name <transcript-file-name> [--create]` — the named `transcript-*` this routine keeps. `SessionTranscriptAppend` takes a note line.
- `--upsert-inbox-note <member> <item-filename> [--include-processed] [--from-file <path>|--edit-patch-from-stdin]`
- `--upsert-inbox-reflection <member> <item-filename> [--include-processed] [--from-file <path>|--edit-patch-from-stdin]`
- `--upsert-inbox-inquiry <member> <item-filename> [--include-processed] [--from-file <path>]`
- `--routine-run-inline <routine>`
- `--get-session-thread [--own]`
- `--executor-checkpoint-push [<name>]`

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

### Conventions

- **session-start** and **close-session** sub-step names are cited by other routines; keep them stable.
