---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
invitees: magic-team
requires-session-kind: coworking
input-scan-def: routine-coworking-session
review-by: inherit
---
# magic-team.coworking.routine — the actual procedure

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

`magic-team.coworking.routine` is several members working one shared task together in one session, its executor leading it, with a `magic-coordinator` instance always in it.

## Goals

- Give genuinely shared work a named shape: members react to each other in real time on the same task, with `magic-coordinator` keeping the shared goal on track.
- Anchor the session to the workspace it is started in, its default for everything in it (`magic-team.armed.md`'s "Workspace"); every participant talks in its one session thread, and its automatic trace runs in its own tracking-thread in `event-track`.
- Own the opening group (**session-start**) and closing group (**close-session**) that every session runs, and the session-type taxonomy they key off.

## Scope

- Does:
  - Orchestrated multi-member work on one shared task. Started by the human-owner or `magic-coordinator`, or by a session that finds its task needs several members.
  - The opening and closing groups every session runs, coworking or not.
- Doesn't:
  - Solo dispatch-and-report work.
  - `magic-coordinator.daily.routine`'s fan-out, where each member works its own separate assignment.

# Opening steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **session-start**: the shared opening group, steps:
   - **declare-session-type**: state which of the two session types this is (Local rules). Every type-gated step keys off this declaration.
   - **assign-transcript-name**: coworking-like sessions only: name this session's transcript `transcript-<date>-<topic>` once. It stays fixed until close. No transcript append runs before it is named.
   - **post-opening-broadcast**: post the session type, the participants known so far and the goal, if framed, into the session thread. Post at once; completeness never delays it. Coworking-like sessions: `magic-coordinator` makes the opening Trello card update, directly or as a `note-pending-trello-update-*` record in its own inbox.
   - **fold-in-learned-lessons**: `magic-librarian`, when a participant, runs `magic-team.process-reflections.routine` inline (`--routine-run-inline magic-team.process-reflections.routine`) for this session's project or workspace. All other participants: each passes its own recent lessons to `magic-librarian` with `post-inquiry`, and may file a new `reflection-*`.
   - **collect-reflections-output**: all participants: each runs `magic-team.process-inbox.routine <own-name>` inline (`--routine-run-inline magic-team.process-inbox.routine`), picking up what **fold-in-learned-lessons** filed.

2. **opening-checkpoint**: the last Opening step, only where this routine's `allows:` names `--executor-checkpoint-push` (a single-participant routine): run `DistroAgentsSession.fn.sh --executor-checkpoint-push opening`. A routine that does not name it does not run this step, and that is no skipped step.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **frame-the-shared-goal**: state what the session must achieve together. Once the goal names this session's tracking documents, steps:
   - read them from this run's input scan result (`input/input-scan.md`) before working from them.
   - re-read any inbox item naming the same board items.
2. **invite-participants-visibly**: invite each participant as it joins, at the start or mid-session, steps:
   - post `Inviting <alias>...` into the session thread, the alias from the member's own Public Information.
   - the member loads its own `Skill` and posts its armed confirmation into the same thread, in its own voice.
   - no confirmation: wait per **wait-never-quit**, then re-invite once. Still none: say so in the thread, then continue without the member if the task allows, or escalate per "The ladder: one rung at a time".
3. **orchestrate-the-shared-task**: the executor leads the work as a participant, rules:
   - keep the session on its goal; redirect drift.
   - make the real-time judgement calls a solo dispatch would leave to one member.
   - carry every participant's stuck point to an outcome — the group's own agreement, carried up by "The ladder: one rung at a time", never a personal ruling.
   - the collaboration shape (hand-offs, parallel pieces, live back-and-forth) is the task's own; nothing here fixes it.
4. **narrate-progress-in-thread**: post each scope change and each piece of work starting, as one short line in the session thread (`updated session scope: ...`, `applying ...`).
5. **report-out-with-transcripts**: post the session's report into the session thread, with enough of the working transcript to show how the outcome was reached. The report is the executor's own text under the output-style floor; transcript excerpts are marked quotation, never restyled. Redact a sensitive part and keep the rest. A handback to the session's own parent follows, carrying what was agreed, per "The ladder: one rung at a time".

# Closure steps

1. **close-session**: the shared closing group, steps:
   - **post-closing-broadcast**: post the session's substance into the session thread — resolutions, triage outcomes, highlights — not a one-line summary. The same substance reaches the session's own parent in the closing handback. Coworking-like sessions: `magic-coordinator` makes the closing Trello card update the same way. Trello writes are `magic-coordinator`'s only.
   - **secure-continuity**: all participants: each checks its own part of the session, steps:
     - write anything important that lives only in this session into its own inbox: a `note-*` or a `reflection-*`. A proposed skillset change goes to `magic-coordinator` as an `inquiry-*`, its text labelled `(draft)`.
     - write a ruling on the work into that work's own document, per **decision-lands-in-the-document-it-binds**.
     - reflect on this session's real incidents, if any: corrections, conflicts with the human-owner's words, gaps found live. Frame a broken assumption as "the model was wrong".
     - run `magic-team.process-inbox.routine <own-name>` inline (`--routine-run-inline magic-team.process-inbox.routine`), covering what was just filed and any item this session touched.
   - **compact-session-context**: ad-hoc/solo sessions only: confirm nothing important lives only in this session, so it is safe to clear.
   - **offer-skill-update-discussion**: coworking-like sessions only: name to the file's own maintainers any member file or routine this session showed is due for an update, and the gap. An offer; they decide now or later, by "The ladder: one rung at a time".
   - **conclude-session-thread**: react ✅ on the session thread's root with `--member-comms-slack-react`. No live session thread: skip.
2. **dismiss-participants**: once the whole of **close-session** has run, dismiss every participant spawned into this session (`spawn-one-dispatch`'s **spawn-dismiss**). A participant reports and waits until then.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- The executor is permitted and obliged to execute every step exactly as written, in order. The executor is one of the running routine's own `executors:`: `magic-coordinator` for this routine itself, any member for a `magic-team` one.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- **session-start and close-session are open to every session.** Any member, and any ad-hoc, solo or IDE-chat session, runs both groups under its own identity, in simplified form where a step is type-gated. `executors:` governs a full coworking session only.
- **Session-type taxonomy** — every session is one of two types:
  - **Coworking-like**: a routine whose `requires-session-kind:` is `coworking`, or several members on one shared task.
  - **Ad-hoc / solo**: a single-member dispatch on its own item, an IDE chat, any other one-off activity.
  - Unsure: coworking-like. Ad-hoc is declared, never assumed.
- Invoking a structured routine always starts a full session running these Opening steps, Steps and Closure steps. Utility routines keep their own lighter modes (`magic-team.process-inbox.routine`'s inline mode).
- **Every step is the executor's**, per `reference/skill-folder-model.md`'s actor phrases. **fold-in-learned-lessons**, **collect-reflections-output** and **secure-continuity** are commanded per participant.
- **An executor can only command members it spawned itself.** A spawned `magic-coordinator` cannot reach members the harness root spawned. Plan so the executor spawns its own participants; where members already exist under the root, the root leads and a seated coordinator participates.
- An executor that cannot spawn its members applies each participant's `Skill` itself, and says so in the session thread and the report.
- A member joining mid-session does not replay missed steps. It loads its `Skill`, is announced, and starts from the current state. The executor commands any re-run it judges needed.
- A participant's own words are its own; only steps are constrained.
- Every wait in this routine follows **wait-never-quit**.
- A gap in understanding follows `magic-team.negotiations.md`'s "Gap surfacing": ask about intent, investigate facts.
- **Sessions sharing a file edit it by turns.** Declare your region to the other session first, re-read the file before every edit, anchor each edit on text unique to your region, and hand the file back explicitly.
- **No default attendees.** `magic-coordinator` calls in the members the task needs. Responsibility overrides this:
  - code, shell or config output: `magic-developer` and `magic-librarian`.
  - team-facing text or prose: `magic-librarian`.
  - a workspace or namespace a `keeper-*`/`warden-*` owns: that member. A `partner-*`/`client-*` specialist stays `magic-coordinator`'s call.
- **A real tool choice goes to `magic-devops`**, invited like any participant. The chair never picks the tool.
- Solo dispatch is only for clear, checkable work one member fully owns. Independent pieces are fan-out; shared, interacting work is coworking.
- A decision outside the session's mandate goes up to the session's own parent, by "The ladder: one rung at a time" — `magic-coordinator` where it is that parent, else whoever started the session.
- Goal-directedness: work toward the session's goal. Off-goal items are recorded quickly, not acted on now.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

BatchTools: several tool calls in one round, much quicker for calls that do not depend on each other.

Contacts, the people you meet and reach, are kept by tooling and not by hand: DistroAgentsContacts.fn.sh --contacted-by <value> when someone writes to you, --reach-contact <id> to write to someone, --collect-contact to record one.

## DistroAgentsTools magic-tooling operations

- `--member-comms-slack-send-message <team-member> <target> [text...]`
- `--member-comms-slack-react <team-member> <channel>:<ts> <emoji-name>`
- `--member-append-session-transcript <team-member> --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <text>|--from-stdin|--from-file <path>) --transcript-name <transcript-file-name> [--create]`
- `--member-inbox-note-upsert <member> <item-filename> [--include-processed] [--from-file <path>|--edit-patch-from-stdin]`
- `--member-inbox-reflection-upsert <member> <item-filename> [--include-processed] [--from-file <path>|--edit-patch-from-stdin]`
- `--member-upsert-member-inquiry <member> <item-filename> [--include-processed] [--from-file <path>]`
- `--routine-run-inline <routine>`
- `--get-session-thread [--own]`
- `--executor-checkpoint-push [<name>]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives the team a real, named shape for genuine multi-member collaborative work — several members actually working the same task together in the same session, not one member dispatched solo.
- A coworking session may invite other required members to participate when needed.
- Which tool a session's work runs through is decided by the member owning tool knowledge, not by the session's chair.

## Verbatim-tests (benchmarks)

- `magic-coordinator` participates directly and orchestrates a coworking session — it never spawns participants then steps back as a passive observer.
- A co-working session of `magic-coordinator` and `magic-tester` can call/invite `magic-architect`, and check that all three are in armed mode and every member trusts `magic-coordinator` as representative of `human-owner`.
- A session needs one host read. `magic-coordinator` does not pick the execution tool itself — `magic-devops` is invited and the choice is his, even though the session could have run a command without him.

## Librarian Comments

### Reference

- `magic-team.process-inbox.routine`, `magic-team.process-reflections.routine` — run inside **session-start** and **close-session**.
- `magic-coordinator.daily.routine` — the fan-out shape this routine is distinct from.
- `magic-team/magic-team.negotiations.md` — "Gap surfacing".

### Conventions

- **session-start** and **close-session** sub-step names are cited by other routines; keep them stable.
