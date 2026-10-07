---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
invitees: magic-team
---
# magic-coordinator.daily.routine — the actual procedure

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

`magic-coordinator.daily.routine` is the team's daily checkpoint: surface every member's state, assign the day's work in dependency order, run a supervised work session, and report honestly.

## Goals

- Surface every permanent member's real state against the board at least once a day, so nothing open rots between grooming passes.
- Assign the day's work in dependency order.
- Run a bounded, supervised work session, so problems surface the same day.
- Leave the human team a visible, honest trace.

## Scope

- Does:
  - The standup, dependency-ordered assignment, and the supervised work session.
  - Mechanical board moves (`check-process-board`), simple interview posts, and simple grooming-shaped decisions needing no spawn.
  - Runs when the human-owner or a member asks for a daily meeting or standup, or when `magic-coordinator.heartbeat.routine` dispatches it.
- Doesn't:
  - Dispatch board work in its Steps. The one dispatch point is the closure's **run-advance-dispatch**; the work-session participants are this session's own members, not board dispatches.
  - Re-triage the backlog where investigation or design is needed. That is grooming's.
- Open, pending:
  - Open: a BPMN diagram sync step — a cheap mtime check of the team's Camunda diagrams against the team definition files, handing a redeploy to the owning `partner-*`'s diagram-sync routine. Waits for that routine to exist.
  - Held: idle-task assignment at **update-todos**, until the human-owner lifts the hold.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **acquire-lock**: Acquire the lock (`--magic-daily-lock-acquire`) before anything else. Contention means another daily is live: this pass does not start.
2. **spawn-morning-review**: Only when the acquire printed `first-today: yes`. Spawn `magic-librarian` with `magic-librarian.morning-review.routine` through `spawn-one-dispatch`, and wait for its report, per `magic-team.armed.md`'s **wait-never-quit**. Refresh the lock while waiting (`--magic-daily-lock-refresh`). On a `TIMEOUT`, ask the session for its status and wait again. Once it reports done, dismiss it (`spawn-one-dispatch`'s **spawn-dismiss**). A session found dead is flagged once in `magic-team` and in the close-out, and the daily continues without it.
3. **reload-active-duty-context**: Re-read this member's armed file and this routine with the skillset reader, so anything the morning review changed is in force. Skip if this session already loaded them after the morning review.
4. **session-start**, steps:
   - Write this pass's tracking note (`--magic-daily-state-and-lock-upsert`) and keep it current. Refresh the lock during the long pass.
   - Run `magic-team.coworking.routine`'s **session-start** group: this is a coworking-like session.
5. **librarian-confirms-roster**: Invite `magic-librarian` to confirm that the `roster-note` and `magic-team.armed.md`'s tooling section are current. Rewrite a drifted `roster-note` (`--magic-team-roster-upsert`).
6. **sweep-comms-read**: Run `magic-coordinator.communication-sweep.routine`'s **check** step. Fold what is relevant into the roll call. Acting on it is the closure's advance pass, not this step.
7. **roll-call**: For each permanent member except `magic-coordinator`, in a random order: read its board items (`--member-work-session-input-scan <member>`, board section only) and narrate what happened since last time, what is planned next and what blocks it. Every invitee gets a turn; `partner-*` members usually report nothing. Anything needing real discussion goes to **questions-then-conclude** or the backlog, never resolved here. The roll call must change the plan, not only record it.
8. **run-check-process-board**: Run `check-process-board` against `--magic-advance-input-scan`'s read, for the dependency order the assignment follows.
9. **update-todos**: Record the day's working list (`TodoWrite`) for the members getting a work session, in dependency order. The improvement the last retro filed for this daily (a `note-*` in `magic-coordinator`'s inbox) goes on it. Idle-task assignment is held until the human-owner lifts the hold: no idle task is assigned here meanwhile. Once lifted, a member with no assigned work gets one idle-run routine named explicitly, per `magic-team.armed.md`'s "Duties".
10. **questions-then-conclude**: Let the human-owner, or a member, ask anything before the standup closes. Running unattended, post the open questions to `magic-team` and continue. A question that must persist becomes an `inquiry-*` (`post-inquiry`) for the next daily.
11. **fan-out-work-sessions**: Spawn each permanent member with work today, except `partner-*` members, into this session as a participant (`spawn-one-dispatch`, joining this session's id). Each works its assigned items for about 20-30 minutes and reports into the session thread.
    - Name the item and, for an idle-run routine, the exact routine file in each brief. Ask each participant to compact its own `reflection-*` items before it closes.
    - Supervise: wait on the session thread (wait-never-quit), answer and redirect as reports arrive, and refresh the lock at each check-in. Post milestones and new blockers to `magic-team` as they happen.
    - A participant reporting it is stuck: move its item to `board-blocked` (`--magic-board-to-blocked`), recording why and any `blocked-by`.
    - A participant reporting completion: note the claim on the item, which stays in `board-running` for its testing round.
    - An ambiguous report: ask for a clearer status; until then the item keeps its state.
    - A new, unrelated ask a participant meets is filed for later, never switched to.

# Closure steps

1. **run-advance-dispatch**: Run `magic-coordinator.advance.routine` in full. Everything is decided by now, so dispatch goes out without corrections chasing it. Its comms sweep does the sweep's acting half. It does not re-dispatch this session's participants.
2. **close-out**: Once participants finish or the time box ends, summarise for the human-owner, run `magic-team.coworking.routine`'s **close-session** group, then dismiss every participant (**spawn-dismiss**). A participant reports and waits until then.
3. **close-state-and-unlock**: Release the lock with `--magic-daily-close-state-and-unlock`, passing the closing status in the same call. Reference items by name.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- This routine extends `magic-team.coworking.routine`; this file wins on conflict.
- The executor frames the day, supervises the work session, makes the board judgements, and owns the close. A participant works only its assigned items, reports when asked, and routes anything else to the executor. Board writes are the executor's alone.
- This routine is never put on its own schedule without the human-owner's confirmation.
- The board is the cross-day source of truth for each member's backlog; the todo list resets every session.
- A member's status too thin to assign from is flagged for **questions-then-conclude** or the backlog, never guessed. Nothing to report is a valid outcome.
- Priorities among idle tasks are never investigated during the roll call.
- A decision outside this routine's mandate goes through the chain of command. Unsure whether it is one: escalate.
- A step's precondition looking unmet is fixed before continuing.
- Keep `event-track` current as the routine runs.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-daily-lock-acquire <team-member> <owner-label>`
- `--magic-daily-lock-refresh <team-member>`
- `--magic-daily-close-state-and-unlock <team-member>`
- `--magic-daily-state-and-lock-upsert <team-member> [--header:...]...`
- `--member-work-session-input-scan <team-member>`
- `--magic-advance-input-scan <team-member>`
- `--magic-board-to-blocked <team-member> <item-filename> --from-state:<state> [--header:...]...`
- `--magic-advance-to-running <team-member> <item-filename> --from-state:running [--header:...]...`
- `--magic-team-roster-upsert <team-member>`
- `--member-comms-slack-send-message <team-member> <target> [text...]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- `magic-coordinator.daily.routine` exists to give the team a regular cadence that turns backlog into actively-supervised, coordinated work — not a check-in ritual with no real dispatch behind it.
- The executor/participant split exists so supervision and cross-cutting judgment calls stay in one place, while each participant stays focused purely on its own assigned work.
- This is the team's primary rhythm-setting mechanism — the thing that makes "the team is actually working, not just has a backlog" true on any given day.
- A supervised work session actually happens — bounded, checked-in-on, not a fire-and-forget dispatch — so problems (a member stuck, an item quietly done) surface the same day instead of at the next grooming.

## Verbatim-tests (benchmarks)

- A participant's own work surfaces a board-state need outside its assigned item; it reports the need back to `magic-coordinator` rather than writing to the board itself.
- An agent that gets genuinely stuck mid-work-session has its item moved from `board-running` to `board-blocked` within that same session, rather than leaving it looking active until the next grooming pass.

## Librarian Comments

### Reference

- `magic-team.coworking.routine` — the template this routine extends: its **session-start** and **close-session** groups.
- `magic-librarian.morning-review.routine` — spawned at **spawn-morning-review**.
- `magic-coordinator.advance.routine` — run at **run-advance-dispatch**.
- `magic-coordinator.communication-sweep.routine` — its **check** step at **sweep-comms-read**.

### Conventions

None.
