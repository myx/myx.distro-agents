---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-coordinator.retro.routine — the actual procedure

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

`magic-coordinator.retro.routine` is the team retrospective: how the work itself has been going, not what is outstanding.

## Goals

- Give recurring friction — a routine running long, a convention nobody follows, a boundary keeps getting straddled — a dedicated moment to surface and become concrete fixes.
- Include recurring problems with retro itself.

## Scope

- Does: reflection and methodology, drawing on recent work history. Runs when the human-owner asks for a "retro" or "retrospective".
- Doesn't: report what is outstanding (`magic-coordinator.daily.routine`), triage the backlog (`magic-team.grooming.routine`), or implement anything.
- Open: autonomous invocation from the heartbeat's day rhythm. Then **discuss-with-the-user** would not block: findings recorded as provisional and flagged for confirmation when a human is next present.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **acquire-lock**: Acquire the lock (`--magic-retro-lock-acquire`) before anything else. Contention means another retro is live: this pass does not start.
2. **session-start**: Run `magic-team.coworking.routine`'s **session-start** group: this is a coworking-like session. Write this pass's tracking note (`--magic-retro-state-and-lock-upsert`) and keep it current; refresh the lock during the long pass (`--magic-retro-lock-refresh`).
3. **invite-participants**: Spawn every participant into this session (`spawn-one-dispatch`) before **gather-recent-history**. Each stays to the close, listening to the others.
4. **gather-recent-history**: Read recent `board-processed` items, `reflection-*` items included, and the last several dailies' results and repeated blockers. Raw material, not something to re-narrate.
5. **self-analyse-per-member**: For each participant with enough recent history, steps:
   - Have it analyse itself against its own `.basic.md`/`.armed.md` (do they still match what it is asked to do), its past incidents and reflections, the team rules that apply to it, and its stated goals.
   - Have it speak first-person: what felt slow, what was satisfying, what keeps recurring.
   - Have it formulate one improvement proposal of its own, carried into **assess-methodology-failures**.
   A member with nothing meaningful to reflect on is skipped, not sent away.
6. **surface-cross-member-patterns**: Name what showed up in more than one member's self-talk.
7. **assess-methodology-failures**: Where did a routine, convention or way of working fall short this period, and why. Turn findings into concrete proposals, alongside the members' own. An empty result is fine.
8. **discuss-with-the-user**: Pause for the human-owner to react, add his reading or push back. He and `magic-librarian` decide which proposals to adopt. Refresh the lock on entering this step and at each pause.

# Closure steps

1. **close-session**: Run `magic-team.coworking.routine`'s **close-session** group. File exactly one concrete, actionable improvement for the next daily as a `note-*` in `magic-coordinator`'s own inbox (`--member-inbox-note-upsert`). Then dismiss every participant (`spawn-one-dispatch`'s **spawn-dismiss**).
2. **close-state-and-unlock**: Release the lock with `--magic-retro-close-state-and-unlock`, passing the closing status in the same call. Reference items by name.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- This routine extends `magic-team.coworking.routine`; this file wins on conflict. The executor still decides which members attend; **invite-participants** only sets when they arrive.
- First-person narration stays inside the session. Every external post is third person.
- Retro produces proposals, never actions, however small — a member's own proposal included.
- A cross-member pattern that looks like a design question goes to `magic-architect`.
- A proposal big enough to change how the whole team works is confirmed with the human-owner as build work before it goes anywhere.
- A finding about re-prioritising existing work is filed for grooming (`--member-inbox-note-upsert`), not worked here.
- No schedule or automation without the human-owner's confirmation.
- Keep `event-track` current as the routine runs.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-retro-lock-acquire <team-member> <owner-label>`
- `--magic-retro-lock-refresh <team-member>`
- `--magic-retro-close-state-and-unlock <team-member>`
- `--magic-retro-state-and-lock-upsert <team-member> [--header:...]...`
- `--member-inbox-note-upsert <team-member> <item-filename>`
- `--member-comms-slack-send-message <team-member> <target> [text...]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine exists because a team that only ever reports status never actually improves its own methodology — recurring friction needs a dedicated moment to surface and get turned into concrete fixes.
- A retro's value comes from members hearing each other, so the whole participant set is present for the whole session rather than each member appearing only for its own turn.

## Verbatim-tests (benchmarks)

- Retro asks how the work itself has been going, not what's outstanding — a session that turns into a task-status roll call has drifted into `magic-coordinator.daily.routine`'s own territory.
- A member is invited only when its own topic comes up. That is a defect in the pass: the cross-member reading depends on every participant having heard the earlier ones.

## Librarian Comments

### Reference

- `magic-team.coworking.routine` — the template: **session-start** and **close-session**.
- `magic-coordinator.daily.routine` — picks up the filed improvement at **update-todos**.

### Conventions

- "Retro produces proposals, not actions" is a hard distinction. Preserve it.
