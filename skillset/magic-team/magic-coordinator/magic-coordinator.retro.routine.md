---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: coworking
runs-at: none
routine-lock-document: inbox:magic-coordinator:note-20260811T120000Z-retro-state-and-lock.md
input-scan-def: none
review-by: inherit
---
# magic-coordinator.retro.routine — the actual procedure

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

`magic-coordinator.retro.routine` is the team retrospective: how the work itself has been going, not what is outstanding.

## Goals

- Give recurring friction a dedicated moment to surface and become concrete
  fixes. That friction is a routine running long, a convention nobody follows,
  a boundary keeps getting straddled.
- Include recurring problems with retro itself.

## Scope

- Does: reflection and methodology, drawing on recent work history. Runs when the human-owner asks for a "retro" or "retrospective".
- Doesn't: report what is outstanding (`magic-coordinator.daily.routine`), triage the backlog (`magic-team.grooming.routine`), or implement anything.
- Open: autonomous invocation from the schedule (`runs-at:` is `none` today, so the retro stays manual until designed). Then **discuss-with-the-user** would not block: findings recorded as provisional and flagged for confirmation when a human is next present.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **keep-tracking-note-current**: Write this pass's tracking note
(`--update-routine-state`) and keep it current, referencing items by name
rather than copying them. Refresh the lock during the long pass
(`--retro-lock-refresh`).
2. **invite-participants**: Spawn every participant into this session (`spawn-one-dispatch`) before **gather-recent-history**. Each stays to the close, listening to the others.
3. **gather-recent-history**: Read recent `board-processed` items, `reflection-*` items included, and the last several dailies' results and repeated blockers. Raw material, not something to re-narrate.
4. **self-analyse-per-member**: For each participant with enough recent history, steps:
   - Have it analyse itself against its own `.basic.md`/`.armed.md`: do they still
     match what it is asked to do. Then set that beside its past incidents and
     reflections, the team rules that apply to it, and its stated goals.
   - Have it speak first-person: what felt slow, what was satisfying, what keeps recurring.
   - Have it formulate one improvement proposal of its own, carried into **assess-methodology-failures**.
   A member with nothing meaningful to reflect on is skipped, not sent away.
5. **surface-cross-member-patterns**: Name what showed up in more than one member's self-talk.
6. **assess-methodology-failures**: Where did a routine, convention or way of working fall short this period, and why. Turn findings into concrete proposals, alongside the members' own. An empty result is fine.
7. **discuss-with-the-user**: Pause for the human-owner to react, add his reading or push back. This routine's maintainers other than him decide which proposals to adopt.
That agreement goes to him as one propose-approve step, per "The ladder: one
rung at a time". Refresh the lock on entering this step and at each pause.

# Closure steps

1. **file-next-daily-improvement**: File exactly one concrete, actionable improvement for the next daily as a `note-*` in `magic-coordinator`'s own inbox (`--upsert-inbox-note`).

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- The executor decides which members attend; **invite-participants** only sets when they arrive.
- First-person narration stays inside the session. Every external post is third person.
- Retro produces proposals, never actions, however small — a member's own proposal included.
- A cross-member pattern that looks like a design question goes to `magic-architect`.
- A proposal big enough to change how the whole team works is agreed by this
  routine's maintainers first. That agreement is confirmed with the
  human-owner as build work before it goes anywhere, per "The ladder: one rung
  at a time".
- A finding about re-prioritising existing work is filed for grooming (`--upsert-inbox-note`), not worked here.
- No schedule or automation without the human-owner's confirmation.
- Keep `event-track` current as the routine runs.

# Routine-specific tooling

Every harness tool and `magic-tooling` operation this routine uses. A harness tool is called by its own name. An operation is called through the harness tool of its tool file, with `operation` and `args`. Its behaviour is read with `--member-help`. Steps use its name only.

## Harness tools

- `Agent` — the team tool that spawns a member, through `spawn-one-dispatch`. Never use a client's in-process subagent.
- `ProposeApprove` — only `magic-coordinator` calls it. Pass `question`, `proposal` and `document`, the link to the published proposal page. The `VERDICT:` is approved or rejected. Revise with `pending_id` and `revise`.
- `SendMessage` — posts one message. Pass `message`, `to` and `address_to`. A sentence over 25 words or a semicolon returns a CORRECTION: shorten it and send again. The result gives the ts to `Wait` on.
- `Wait` — waits on the session thread, and on any `sources` you add. `RECEIVED` brings the new content. `TIMEOUT` is a normal result: call `Wait` with `mode=continue`. `DISMISSED` ends the run.

## Tooling operations

- `--retro-lock-refresh` (`AgentDispatcherTools`)
- `--update-routine-state [--document <note>] [--header:upsert:<name>:<value>]... [--header:remove:<name>]... [--from-file <path>|--edit-patch-from-stdin]`
- `--upsert-inbox-note <team-member> <item-filename>` (`DistroAgentsItems`)
- `--slack-send-message <target> [text...]` (`DistroAgentsSlack`)

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

- `magic-coordinator.daily.routine` — picks up the filed improvement at **update-todos**.

### Conventions

- "Retro produces proposals, not actions" is a hard distinction. Preserve it.
