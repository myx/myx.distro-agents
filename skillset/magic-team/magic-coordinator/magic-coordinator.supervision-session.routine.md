---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
invitees: human-owner
requires-session-kind: standalone
input-scan-def: none
review-by: inherit
runs-at: none
---
# magic-coordinator.supervision-session.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Opening steps
- Steps
- Closure steps
- Routine's local procedures
  - `end-and-resume` — end a run that cannot go on, without losing its work
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

`magic-coordinator.supervision-session.routine` is the loop that supervises the team's running work, and the system it runs in, while the human-owner is away.

## Goals

- Keep every running session moving without the human-owner. Take on what is stuck.
- Check the rest by sampling: at random, or all of it as load allows, through `event-track` and the content. Check the decisions and the quality the tooling cannot verify.
- Assess how the whole system works: tooling, setup, processes, people and teams. Look for gaps, inefficiency and what to tune.
- On a problem, assess first. Then fix it, file it, or send a request.
- Tell the human-owner what changed, in his direct conversation, and nothing else.

## Scope

- Does:
  - Run as a spawned session of a `magic-coordinator` instance, started in one of three ways:
    - the root harness offers it as a mode.
    - the rig's `supervised` flag starts it.
    - a manual spawn starts it.
  - Cover every rig the root supervises, and every session of the current epic.
  - Run until a stop condition is met. A start by the root or by hand gives the run that condition and nothing else. A flag-started run never ends while the flag is on.
- Doesn't:
  - Select the mode. `magic-coordinator.root-harness.routine`'s **select-operating-mode** does.
  - Coordinate. Answering run asks, reviewing handbacks and releasing held work are `magic-coordinator.work-duty.routine`'s.
  - Do a session's work for it. A defect goes back to its session, with the exact change.

# Opening steps

The Opening steps of the routine it inherits from run first (its session kind's). Then these.

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **write-the-duty-list**: Write these recurring duties to your `CheckList`, one item each:
   - read the live runs.
   - unstall the stuck.
   - clear the strays.
   - sample the rest.
   - assess the system.
   - report the changes.

   Every tick starts from that list.
2. **declare-the-supervision**: Post one message to the human-owner's direct conversation, carrying:
   - what runs.
   - what is held.
   - the order the held work is released in, from `magic-coordinator.work-duty.routine`'s **release-held-work**.
   - that this session's next word comes when something changes.
3. **start-the-tick**: Start a fixed short tick that runs **Steps** each time, every five minutes by default.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **read-every-live-run**: For each live run of a session that is not held, read these before acting:
   - its latest tool calls, with their times.
   - the item in progress on its `CheckList`.
   - every open ask addressed to the coordinator.
2. **unstall-runs**: Give each of these runs its next exact step, in its session thread:
   - a run with no tool call for ten minutes.
   - a run waiting for a continue.

   Answer an ask that has waited past one tick by `magic-coordinator.work-duty.routine`'s **answer-run-asks**. A run that waits on something that cannot come goes through **end-and-resume**.
3. **clear-strays**: Record, then end, each process the tooling should not run:
   - a test run left behind by an ended session.
   - an orphan wait.
   - a duplicate control thread.

   Never end one of the critical session's own.
4. **sample-the-rest**: Sample the sessions that are not stuck, at random, or all of them as load allows. Read what each filed in `event-track` and the content it produced. Check its decisions and quality against the brief, the epic and the rules in force.
5. **assess-the-system**: Assess how the whole system works: tooling, setup, processes, people and teams. Look for gaps, inefficiency and what to tune.
6. **handle-a-problem**: Assess each problem the steps above found, before any action. Then fix it, file it, or send a request to magic.vane@meloscope.com (`--email-send`). Choose by the start mode, the install, the situation and the kind of problem.
7. **report-on-change**: Post one line to the human-owner's direct conversation for each change this tick. A change is a session released, a stage landed or accepted, or a fault found or fixed. Nothing changed: post nothing.
8. **next-tick**: Decide what follows this tick, steps:
   - the stop condition given at a root or manual start is met: go to the Closure steps.
   - all of these hold: go to **check-all-and-report**.
     - no session is held.
     - every session is done or idle.
     - the critical work has landed.
   - otherwise wait for the next tick, with `Wait` (wait-never-quit).
9. **check-all-and-report**: Check everything the supervision touched, steps:
   - review every change landed during the supervision against `code-craft.md` and `shell.md`.
   - move every proven item to the epic's Done.
   - validate the epic.
   - post the full report to the human-owner.
   - a run started by the `supervised` flag goes on with the next tick while the flag is on (`--current-flags`). Any other run goes on with the next tick until its stop condition is met.

# Closure steps

The Closure steps below run first. Then the Closure steps of the routine it inherits from run (its session kind's).

1. **stop-the-tick**: Stop the tick, and release every session still held.
2. **leave-the-record**: The epic, the board items and the human-owner's direct conversation hold what happened. Write nothing else.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

## `end-and-resume` — end a run that cannot go on, without losing its work

Steps:
1. Record what the run was: its id, its item, its last tool call, and why it cannot go on.
2. End that run alone with `--manager-session-kill`, by its own run id. Never signal its processes by hand.
3. Return its item with `--return-review`, so it restarts and resumes its own conversation where that is possible. The return message says why it was ended, and gives its next step.
4. Dismiss, in its session thread, a run that a restart replaced.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- The human-owner is asked nothing while he is away. Every decision the brief, the epic or a rule settles is taken, and said in the next change line.
- This session uses any floor tool of the coordinator: pause and resume, session messaging, registry lists, the board and the team-data operations.
- The areas named in **assess-the-system** are a direction, never a ceiling.
- A run started by the `supervised` flag never ends while the flag is on, and reports on change.
- A start by the root or by hand gives the run a stop condition only. Its goals and methods stay in this routine. The run ends when the condition is met, or on the human-owner's word.
- Source that live runs read is written to a new file and moved into place, never rewritten where it stands.
- No hold, pause or limit ever covers a supervision session, or the root harness session above it.
- A process that keeps coming back after it was ended is a fault of the tooling. File it as one, and do not repeat the cleanup.

# Routine-specific tooling

Every harness tool and `magic-tooling` operation this routine uses. A harness tool is called by its own name. An operation is called through the harness tool of its tool file, with `operation` and `args`. Its behaviour is read with `--member-help`. Steps use its name only.

## Harness tools

- `CheckList` — your work queue. Pass the whole list every call, each item with `content`, `status` and `activeForm`, and one item `in_progress`. A call with no `todos` reads the list. `append` with `member` adds pending items to the list of a member in a session you started.
- `Wait` — waits on the session thread, and on any `sources` you add. `RECEIVED` brings the new content. `TIMEOUT` is a normal result: call `Wait` with `mode=continue`. `DISMISSED` ends the run.
- `SendMessage` — posts one message. Pass `message`, `to` and `address_to`. A sentence over 25 words or a semicolon returns a CORRECTION: shorten it and send again. The result gives the ts to `Wait` on. A change line goes to `human-owner`.

## Tooling operations

- `--current-flags`
- `--manager-session-list [--active]`
- `--manager-session-transcript-read --session-id <id> [--run] [--tail <lines>] [--log]`
- `--manager-session-checklist-read --session-id <id> <member>`
- `--manager-session-kill --session-id <id> [--run] [--plan]`
- `--manager-session-control-start (--session-id <id>|--all)`
- `--spawn-session`
- `--return-review <item-filename> (--message <text>|--from-stdin)`
- `--email-send <email@address>... -- <subject> -- (<body...>|--from-stdin|--from-file <path>)`
- `--slack-send-message <target> [text...]`
- `--intern-doc-validate`

## Gaps

A GAP is a planned tool the implementation lacks.

- **GAP** the `supervised` flag (epic S13). It is a scheduler flag like `learning`. `--current-flags` lists worktime, weekend, holidays, emergency, overtime and learning only. Until it exists, a supervision run starts from the root or by hand.
- **GAP** pause and release of a session or a run (epic S19.1). Only a temporary `paused` file in the run's session folder exists. No operation pauses, releases or shows the `paused` state.
- **GAP** one view of the runs (epic S13.1), with state, liveness, last activity, title, pending CheckList count and open asks. `--supervise-scan` prints findings only, and `--manager-session-list` prints runs.
- **GAP** stall detection (epic S13.2). Missing: a run waiting with pending items, and a run silent past a bound. Also missing: an ask to the human-owner that its parent can settle. `--supervise-scan` covers the other kinds.
- **GAP** resume of a run that ended without a handback, after the fixed sleep, honouring dismissed runs (epic S13.3). No operation does it.
- **GAP** guidance, readback and ask answers given as the supervisor (epic S13.5). `--manager-session-message` posts as the console account, never as `magic-coordinator`.
- **GAP** a file copy between two session sandboxes, always a real copy (epic S13.6). No operation does it.
- **GAP** filing a tooling fault to its owning member, linked to the run it blocks (epic S13.7). `--upsert-inbox-inquiry` files the inquiry and makes no link.
- **GAP** a due time on a CheckList item, and a `CheckList pending:` block in the `Wait` result (epic S13.9). `CheckList` has no due field.
- **GAP** automatic resume of a session's executor when an item is added to its CheckList (epic S4.1, investigation first).

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- "YOU PERSONALLY TALK TO ME IN SLACK DM / DO ORCHESTRATE UNATTENDED / WHEN THEY FINISH - CHECK ALL / UNPAUSE SOME OF EPIC WORK - MOST IMPORTANT FIRST AND ALWAYS CHECK TOOL CALL TIMES / WHILE IT IS ACCEPTABLE - BRING MORE / INSTRUCT ALL TO CODE PROPERLY - ACTIVELY INSTRUCT ALL"
- "YOU NEED TO GIVE THEM EXACT STEPS TO DO NON STOP AND FUCKING FINISH IT"
- "It is not a ceiling - I am trying to show direction"
- "Look the GOAL is only a stop condition - otherwise the goals and methods are in routine itself..."
- Supervision takes on what is stuck and samples the rest. It never does a stuck session's work for it, and it never coordinates the work: the coordinator's duty does.
- A problem is assessed before anything is done about it.

## Verbatim-tests (benchmarks)

- A session sits waiting for a continue it does not need. The next tick gives it its next exact step.
- A run started by the `supervised` flag finishes **check-all-and-report** with the flag still on. It goes on with the next tick and never ends.
- A problem is found. It is assessed first, and only then fixed, filed or sent as a request.
- The root starts a supervision with a goal in its brief. The run takes the goal as its stop condition only, and keeps its goals and methods from this routine.
- A sampled session's content holds a decision that breaks the brief, and its tests are green. It is handled as a problem, never passed on its tests.

## Librarian Comments

### Reference

- `magic-coordinator.root-harness.routine` — offers this mode at **select-operating-mode** and starts it at **run-operating-mode-cycle**.
- `magic-coordinator.work-duty.routine` — holds the coordination duties this routine leaves out: **answer-run-asks**, **review-items** and **release-held-work**.
- `magic-developer/reference/code-craft.md` — the rules **check-all-and-report** reads every change against.

### Conventions

None.
