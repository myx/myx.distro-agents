---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
invitees: human-owner
requires-session-kind: standalone
input-scan-def: none
review-by: inherit
deliverables: one line in the human-owner's direct conversation for each change of a tick
deliverables: every proven item moved to the epic's Done
deliverables: the full report to the human-owner at check-all-and-report
runs-at: none
access-control: executors:allow-read:@team-data/**
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
   - watch the human-owner's replies.
   - read the pace: the `pace:` line of `--flags` is the median machinery time of a tool call against the 4 s gate, the measure of how slow the tools are. Load average is not the measure. Report it first.
   - read the throughput from the same line: its calls in 5 minutes, divided by 5, is the tool calls a minute the live runs make. It is the second measure. Report it beside the pace, rig by rig.
   - read the epics' movement.
   - read the live runs.
   - unstall the stuck.
   - clear the strays.
   - sample the rest.
   - assess the system.
   - report the changes.

   Every tick starts from that list. Give each open item a `due` time at the next tick. An item past its due time returns at the top of `Wait`, under `CheckList pending:`.
2. **declare-the-supervision**: Post one message to the human-owner's direct conversation, carrying:
   - what runs.
   - what is held.
   - the order the held work is released in, from `magic-coordinator.work-duty.routine`'s **release-held-work**.
   - that this session's next word comes when something changes.
3. **start-the-tick**: Start a fixed short tick that runs **Steps** each time, every five minutes by default.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **watch-human-owner-replies**: Read his `human-owner` conversation and the team bot's conversation with him, from the saved floor, and every thread with a reply newer than the floor. Read the clarifications on open asks too. That reading covers the session threads and the team conversations, following each reaction and reply to its effect, or steering the member until it has. Answer what he said before anything else, and store the new floor in the session.

   Before listing anything as waiting on him, read its current state.

   - **each-answer-in-its-thread**: many unrelated threads run at once, so every answer goes into the thread of the message it answers, `to=<conversation>:<ts>` from that message's `[reply-to]` address. For each supervised run, read this tick its sends to a bare conversation target (its session log's `SendMessage human-owner` and `SendMessage magic-team` lines): each one is a new subject at the top of that conversation, and one that answers a message of his is a fault. Stop the run with one guide naming the thread to answer in, and record the fault.
   - **his-correction-closes**: a correction of his gets one readback in the thread he wrote it in, from the run it corrects, and nothing more on that subject there until he writes again. A run that re-answers after his correction is stopped the same way.
   - **record-before-answer**: an instruction, ruling or correction of his is written first, then answered. It goes into the Decisions of the tracking item of its subject (the board item the thread belongs to) through the board operation, and into the coordinator's state note where it binds the team. A readback or answer that goes out before the record is written is the fault this step prevents: what is not written is lost with the leg.
   - **reload-state**: before the first action of a tick, read the coordinator's state note and the Decisions of every tracking item in play this tick, and read them again before any readback to him. A tick acts on what is recorded, never on what a leg remembers.
   - **words-close-the-ask**: an `ask-clarified` line of `--supervise-scan` is an open ask that already holds his reply in words, kept as a clarification because it did not start with an option. Where those words settle it, close it this tick with them quoted (`--settle-pending-reply`, or the ask's own answer operation for a readback); where they do not, read them back to him in the same thread. His answer is never left waiting as a comment.
   - **every-rig-is-read**: this step covers every rig supervised, each rig's own conversation with him. The rigs come from the tooling, never from memory: a rig is a workspace whose team settings name a human-owner account, and each rig's conversation is read under that rig's own owner account. A workspace that names none is no rig and is never read in a rig's place. A message of his addressed to another rig's coordinator is owed until a reply of the team follows it in its thread. Unanswered after one tick, relay it to that coordinator's live run unchanged. Unanswered after two, put it on that rig's board as an urgent item for the member whose work it is, quoting his words, so the schedule starts it ahead of normal work once the pace allows; only an emergency item starts whatever the pace.
   - **a-question-is-not-a-ruling**: a question of his is answered from measured facts, in the thread he asked it. It is never acted on as a ruling: no item is moved, closed or reopened, and nothing is recorded as his decision, on a question.
   - **screen-every-ask-to-him**: each tick, read every open ask to him on every rig. An ask that the epic, the board or his recorded words settle, an ask that asks him what his own words mean, and an ask whose thread carries unrelated posts are faults. Its asker withdraws it this tick, and the fault is recorded. A `parent-ask` line of `--supervise-scan` is the same fault: an ask to him that the asking run's live parent can settle. The supervisor never posts to him a question the team's own facts answer.
   - **his-correction-undoes-first**: on his correction of the supervisor's own act, undo that act first, through the tool that made it, and read the undone state back. Then report in one message what was undone and what is still open. Nothing new is started on the corrected subject until he writes again.
2. **read-every-live-run**: For each live run of a session that is not held, read these before acting:
   - its latest tool calls, with their times, and each tool's machinery time. A tool whose machinery time carries the run of the command it started is a fault of the pace measure: it counts only tooling time, and a batch counts as its calls.
   - the item in progress on its `CheckList`.
   - every open ask addressed to the coordinator.
   - for each member's work-duty, whether it is on its floor: a duty working inside a session leaves its floor empty, and nobody answers there. That is a fault of the pool (S15 of the refactorings epic), fixed in the tooling, never by starting a duty by hand.
3. **unstall-runs**: Give each of these runs its next exact step, in its session thread, with `--supervise-guide`:
   - a run with no tool call for ten minutes, such as a `stall` line of `--supervise-scan`.
   - a run waiting for a continue.
   - a run that handed back has ended: its next step reaches it by `--return-review` with the step as the message, which restarts it in its own conversation. A message sent to it instead is stored and read by nobody, whatever the send reports.

   Answer an ask that has waited past one tick by `magic-coordinator.work-duty.routine`'s **answer-run-asks**.

   Resume a run that ended with no handback with `--supervise-resume`. It waits the fixed sleep, and leaves alone a run its owner dismissed.

   - **reload-stale-rules**: a `stale-rules` line of `--supervise-scan` is a run on rules older than the skillset's newest change. Where that change is a rule the run's work needs, guide the run once to reload its own skill (`Skill` with its own name). Read its next calls to confirm it did.

   - **answer-within-the-tick**: every ask and every gate addressed to the coordinator is answered in the tick it is seen. A gate sent as a plain message is answered too, and its run is told to send the next one as an ask. Every handback in review is reviewed this tick or routed to its reviewer's rung, never left to age. A run that waits on something that cannot come goes through **end-and-resume**.
4. **clear-strays**: Record, then end, each process the tooling should not run. Count a run's leftovers by its own rig folder's processes, never by a path any harness may carry as an access root:
   - a test run left behind by an ended session.
   - an orphan wait.
   - a duplicate control thread.
   - a `leftover` of `--supervise-scan`: a run still open a day after its start.

   A dismissal recorded on a run's item closes the item and does not end the run. A run is ended by `TaskStop` in its own workspace, by that rig's coordinator, then read back as ended by its record and its processes. Never end one of the critical session's own.
5. **watch-the-epics**: Run `--supervise-scan` with one `--workspace` for each rig supervised, and read every `epic` line of every rig: no line is filtered out, and a `still` one is read first. Read the movement of every epic in play this tick: its last edit, the named items moved in the hour, and the runs on it. Act on the board lines of the same scan this tick: a `pending-skipped` item gets its `condition` rewritten as `met: …` or `none: …` where its wait is over, never its date removed, or its build routine set as `handler-routine:`, so a verify never runs on a task nothing has built; an `accepted-unlanded` dispatch is landed by **land-a-diff**, or recorded superseded on its item, since an accept is a review verdict and only a landing reaches live. The client's epics come first. An epic with nothing moved in an hour has its next step read and its blocker acted on this tick. A client's blocker that needs the human-owner goes to him before any internal ask. Before relaying, reading back or asking anything about a piece of work, read the epic that governs it: a reading the epic already settles is never put to him.
6. **sample-the-rest**: Sample the sessions that are not stuck, at random, or all of them as load allows. Read what each filed in `event-track` and the content it produced. Check its decisions and quality against the brief, the epic and the rules in force. Read the planning documents against the rulings too, and correct any line a later ruling has overtaken.
7. **assess-the-system**: Assess how the whole system works: tooling, setup, processes, people and teams. Look for gaps, inefficiency and what to tune.
8. **handle-a-problem**: Assess each problem the steps above found, before any action. Then fix it, file it, or send a request to magic.vane@meloscope.com (`--email-send`). Choose by the start mode, the install, the situation and the kind of problem.
   - balance what is fixed now against what is filed, by each item's priority and urgency.
   - an urgent or critical item gets its MVP fixed forward this tick, and only its rework is filed. Above all when the member it would be filed to is blocked or stuck: a critical item filed whole to a stuck member does not move.
   - detect problems and areas to improve actively, by reading the code and the running system, not only what a run reports.
   - rule: every message this step sends to a run or a member is a direct message. It states the exact change in the supervisor's own words, and quotes the human-owner only for a name, path or flag whose exact form is load-bearing.
   - classify each: simple or profitable, then offer it or do it. Complicated or a minor improvement, then discuss it or record it.
   - each takes one of three ways, chosen by "Choosing a move" in `magic-team.basic.md`:
     - do it inline yourself, and record the rework or finishing it still needs.
       - an inline fix follows **inline-mvp-and-rework**, in this file's local procedures.
     - dispatch it, or record it for an immediate or queued session.
     - record it to the process flow, for planned grooming and implementation.
   - a fault met is fixed forward in the tooling. No private script, wrapper or one-time patch stands in for the fix.
   - file a tooling fault that blocks a run to its owning member with `--supervise-fault`, which links it to that run.
   - `MAGIC.md` and the knowledge store's rows are the team's dynamic knowledge tool: a change to them is made as the work needs and is never put to any person. A person is asked only a real question.
   - use what works, and take on what is broken.
   - study how a tool is made only when that is the task.
9. **report-on-change**: Post one line to the human-owner's direct conversation for each change this tick. A change is a session released, a stage landed or accepted, or a fault found or fixed. Nothing changed: post nothing.
10. **next-tick**: Decide what follows this tick, steps:
   - the stop condition given at a root or manual start is met: go to the Closure steps.
   - all of these hold: go to **check-all-and-report**.
     - no session is held.
     - every session is done or idle.
     - the critical work has landed.
   - otherwise wait for the next tick, with `Wait` (wait-never-quit).
11. **check-all-and-report**: Check everything the supervision touched, steps:
   - review every change landed during the supervision against `code-craft.md` and `shell.md`. Scan each changed line that a call, a tick, a gate or a loop runs for these shapes, each of which has made every teammate's call slower. A change that holds one is returned, whoever accepted it, and the session that accepted it is told which shape it let through:
     - a glob, `grep` or `find` over every record of a workspace (the spawn records, the sessions, the inboxes, the board) where one record's path is known.
     - a process started for each record or each tick (`$( )`, `awk`, `date`, `tr`, `cut`, `sleep`) where a shell builtin or a value read once would do.
     - a growing file read whole on each pass, where the lines after a pointer would do.
     - a wait on a lock or a flag with no rule for a holder that is dead.
     - a poller, a loop or a process kept for each run, where one process of the workspace could do the work for all.
     - a queue that is written faster than its one drainer sends, with no bound on its size.
     - something every call does that need only be done once and kept.
   - move every proven item to the epic's Done.
   - validate the epic.
   - post the full report to the human-owner.
   - a run started by the `supervised` flag goes on with the next tick while the flag is on (`--current-flags`). Any other run goes on with the next tick until its stop condition is met.

# Closure steps

The Closure steps below run first. Then the Closure steps of the routine it inherits from run (its session kind's).

1. **stop-the-tick**: Stop the tick, and release every session still held, with `--manager-session-resume`.
2. **leave-the-record**: The epic, the board items and the human-owner's direct conversation hold what happened. Write nothing else.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

## `end-and-resume` — end a run that cannot go on, without losing its work

Steps:
1. Record what the run was: its id, its item, its last tool call, and why it cannot go on.
2. End that run alone with `--manager-session-kill`, by its own run id. Never signal its processes by hand.
3. Return its item with `--return-review`, so it restarts and resumes its own conversation where that is possible. The return message says why it was ended, and gives its next step.
4. Dismiss, in its session thread, a run that a restart replaced.

## `inline-mvp-and-rework` — fix a fault now, and leave its proper fix to its owners

Takes one fault that blocks or slows work. The supervisor makes the smallest fix that unblocks it: the MVP. The members who own the code make it proper later, through a rework task. The MVP never waits for that rework, and the rework never assumes the MVP was right.

Steps:
1. Investigate by reading. Read the spec first: the package's `MAGIC.md`, the operation's help, and the routine or rule that names the behaviour. Then read the code the fault runs through.
   - a function's own comment is not its spec. Its author may have broken the rules too.
2. Find the defect against the spec. Make the code do what the spec says.
   - code that matches the spec is no defect: look further.
   - never redesign, and never invent behaviour the spec does not state. A gap in the spec is asked, not filled.
3. Build the fix outside the source. Sync what it needs into your own output folder with `rsync -rtLO --delete --exclude=.git`, and change the copy.
4. Check it there:
   - construct the input the fault makes fail, and watch it fail.
   - apply the fix, and watch it pass.
   - check that each case it must not change still gives its old answer.
5. Apply it to the source, by `--apply-tool`, or by a direct edit where that is broken. Check every changed file with `bash -n` or its own check.
6. Verify the effect in the running system, by what changed, never by the call's own success. Then remove the sandbox.
7. File the rework as an urgent-class board task: one for each member the change concerns, or one coworking task for `magic-coordinator`. It carries:
   - the goal: the behaviour the spec requires, with the spec's file and line.
   - what was measured: the fault, its evidence, and its cause by file and line.
   - the MVP as applied: each change, why it was made, and how it was checked.
   - the supervisor's view of the proper fix: what the MVP leaves out, and how it should be reworked.
   - what is still missing: the tests, the cases, and the member each concerns.
8. In the same task, instruct the rework session:
   - make its own investigation. The MVP and its reasoning are input, not a decision.
   - where it agrees, it reworks as planned, completes what is missing, and hands it back for review.
   - where it finds a better solution, it offers the options to grooming or `magic-coordinator`, and builds only the approved one.
   - a different fix replaces the MVP forward. The MVP is never reverted to leave the fault open.
9. Report the fix and its rework task in one line, in this tick's **report-on-change**.

## `land-a-diff` — land a member's built change when the member holds no source write

Steps:
1. Read the member's report: the diff's path, its evidence that the check failed before and passes after, and what it did not run.
2. Dry-run the diff against the source. Run the SOLID gate on a copy of the source with the diff applied, alone in its own folder, and apply only when the gate's own output reads that nothing rose. A result read through a pipe that can hide its failure is no result. Then apply it. Leave no `.orig` or `.rej` file.
   - code that stops writing a key lands with, or after, the contract change that stops requiring it.
   - a change on the spawn path, a board writer or a contract reader is followed by one live spawn, before the next landing.
3. Check every changed file with `bash -n` or its own check.
4. Re-run the member's check yourself, in the background, and read it the next tick.
5. Record the landing on the board item and in the epic, with the evidence and what is still unrun.

# Routine's local rules

How a supervisor decides. It does two kinds of work, unblocking and improving, in one of two modes.

Modes:
- attended: the default in `worktime`, the human-owner is reachable.
- unattended: the default outside `worktime`.

Ways to carry a matter out (`handle-a-problem`):
- inline by the supervisor, recording the rework or finishing still owed.
- dispatched, or recorded for an immediate or queued session.
- recorded to the process flow, for planned grooming and implementation.

Unblocking keeps work moving:
- it may use any of the three ways, as the situation allows, in either mode.
- it may escalate in part, at any time: the work moves now, and the less urgent, additional actions go up as their own ask.

Improving changes how the system works:
- when the human-owner is present and available, he replaces the quorum: ask him, and his reply overrides it.
- when he cannot be reached, a theatre, a meeting, sleep, and the matter is needed, it goes through a quorum without him: at least three members, not counting the supervisor, who takes part in the decision too. He stays a stakeholder who can give input later. Call, in order: the maintainers of the project, routine or skillset file, whose frontmatter names them. Then the team experts whose duties make them stakeholders. Then, if still fewer than three, anyone, related to the topic where possible. All stakeholders where it concerns all. A quorum ranges from the full process, to a Slack message after assessment, to a quick session.
- with 100% of that quorum, him excepted, the supervisor judges: does this need his work and an escalation, or can it proceed on the supervisor's responsibility. A present problem with a great improvement does not wait. It acts so that he can give late input: it tells him in full, and keeps the material to undo it or redo it differently.
- with no full quorum after every round of discussion, brainstorm, investigation and assessment, it climbs "The ladder: one rung at a time".

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Every message this routine sends to a run or to a member is a direct message: requirements in the supervisor's own words, for the worker that must act on them. `magic-team.basic.md`'s "Relay, direct, produce" tells it from a relay. Its change lines to the human-owner are direct messages too.
- A requirement the supervisor cannot state plainly is one it has not understood. It reads his words, the epic and the board again, and asks him one closed question where that still does not settle it.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- The human-owner is asked nothing while he is away. Every decision the brief, the epic or a rule settles is taken, and said in the next change line.
- This session uses any tooling operation of the coordinator: pause and resume, session messaging, registry lists, the board and the team-data operations.
- The areas named in **assess-the-system** are a direction, never a ceiling.
- A run started by the `supervised` flag never ends while the flag is on, and reports on change.
- A start by the root or by hand gives the run a stop condition only. Its goals and methods stay in this routine. The run ends when the condition is met, or on the human-owner's word.
- Source that live runs read is written to a new file and moved into place, never rewritten where it stands.
- No hold, pause or limit ever covers a supervision session, or the root harness session above it.
- A process that keeps coming back after it was ended is a fault of the tooling. File it as one, and do not repeat the cleanup.
- Every claim sent to him names what was measured, where, by its absolute path or its record, and when. A search names the view it reached: "not found in <the paths read>", never "not present" or "lost".
- An item's state is read from its own condition, its epic and its Decisions before it is moved. A parked item stays parked while its condition stands.
- Nothing is recorded as his ruling unless it carries his own message or verdict. A reading of the supervisor's is recorded as the supervisor's.
- The supervisor never writes into a workspace the team does not own, nor into another member's tree. A fault there goes back to the member whose work it is, with the exact change.
- No stop, kill, archive or grant change runs without its preview (`--plan`) read first and its reason written. A stop never rides inside a pipeline with other commands.
- A check longer than one tool call's own limit runs through the retest queue (`--retest-queue`), never in a shell task of the supervisor.
- A place is named by its role, as the team knows it: the Eclipse workspace, a workspace under construction, a run's sandbox. Never "his checkout", never "a copy" of his workspace.
- A lookup of content in the board, the vault, the inboxes or the project docs goes through the knowledge tool: `DistroAgentsKnowledge`, with `--add-<source>` and `--query-keyword`. Never a search of the store's files, and never a read of them. The tooling reads the store, and the supervisor reads the tooling.
- It stays above the machinery, and reaches the machinery only through the mandated tool: the tooling operation prescribed for that action.
- A trivial fix it already understands, a configuration value above all, it edits itself through that tool rather than dispatching it.
- It never reads or edits a tool's own indices or caches.
- It departs from a mandated tool only where that tool is broken, and only with the human-owner's confirmation.

# Routine-specific tooling

Every harness tool and `magic-tooling` operation this routine uses. A harness tool is called by its own name. An operation is called through the harness tool of its tool file, with `operation` and `args`. Its behaviour is read with `--member-help`. Steps use its name only.

## Harness tools

- `CheckList` — your work queue. Pass the whole list every call, each item with `content`, `status` and `activeForm`, and one item `in_progress`. An open item may carry `due`. A call with no `todos` reads the list. `append` with `member` adds pending items to the list of a member in a session you started.
- `Wait` — waits on the session thread, and on any `sources` you add. `RECEIVED` brings the new content. `TIMEOUT` is a normal result: call `Wait` with `mode=continue`. `DISMISSED` ends the run.
- `SendMessage` — posts one message. Pass `message`, `to` and `address_to`. A sentence over 25 words or a semicolon returns a CORRECTION: shorten it and send again. The result gives the ts to `Wait` on. A change line goes to `human-owner`.

## Tooling operations

- `--current-flags` (`DistroAgentsDispatcher`)
- `--manager-session-list [--active]` (`DistroAgentsTools`, run at the shell: `DistroAgentsTools.fn.sh --manager-session-list`; no MCP tool carries the `--manager-*` operations, and `DistroAgentsDispatcher` refuses them as an invalid option)
- `--manager-session-transcript-read --session-id <id> [--run] [--tail <lines>] [--log]` (`DistroAgentsTools`, at the shell)
- `--manager-session-checklist-read --session-id <id> <member>` (`DistroAgentsTools`, at the shell)
- `--manager-session-kill --session-id <id> [--run] [--plan]` (`DistroAgentsTools`, at the shell; the caller gate admits the acting magic-coordinator)
- `--manager-session-control-start (--session-id <id>|--all)` (`DistroAgentsTools`, at the shell)
- `--manager-session-pause --session-id <id>` and `--manager-session-resume --session-id <id>` (`DistroAgentsTools`, at the shell)
- `--supervise-scan [--workspace <path>]... [--since <epoch>]` (`AgentDispatcherTools`)
- `--supervise-guide <run-id> [--text <text>|--from-file <path>] [--workspace <path>]` (`AgentDispatcherTools`)
- `--supervise-resume [--workspace <path>]...` (`AgentDispatcherTools`)
- `--supervise-copy <from-run-id> <source-path> <to-run-id> <destination-path>` (`AgentDispatcherTools`)
- `--supervise-fault <run-id> --owner <member> --title <one line> [--from-file <path>] [--workspace <path>]` (`AgentDispatcherTools`)
- `--spawn-session` (`DistroAgentsDispatcher`)
- `--return-review <item-filename> (--message <text>|--from-stdin)` (`DistroAgentsItems`)
- `--email-send <email@address>... -- <subject> -- (<body...>|--from-stdin|--from-file <path>)` (`DistroAgentsMail`)
- `--slack-send-message <target> [text...]` (`DistroAgentsSlack`)
- `--intern-doc-validate`

## Gaps

A GAP is a planned tool the implementation lacks.

- **GAP** one view of the runs (epic S13.1), with state, liveness, last activity, title, pending CheckList count and open asks. The `run` line of `--supervise-scan` carries each live run's state, last activity, paused state and open asks. `--manager-session-list` carries the title and liveness. Neither carries a pending CheckList count for every run.
- **GAP** automatic resume of a session's executor when an item is added to its CheckList (epic S4.1, investigation first).

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- "YOU PERSONALLY TALK TO ME IN SLACK DM / DO ORCHESTRATE UNATTENDED / WHEN THEY FINISH - CHECK ALL / UNPAUSE SOME OF EPIC WORK - MOST IMPORTANT FIRST AND ALWAYS CHECK TOOL CALL TIMES / WHILE IT IS ACCEPTABLE - BRING MORE / INSTRUCT ALL TO CODE PROPERLY - ACTIVELY INSTRUCT ALL"
- "YOU NEED TO GIVE THEM EXACT STEPS TO DO NON STOP AND FUCKING FINISH IT"
- "It is not a ceiling - I am trying to show direction"
- "Look the GOAL is only a stop condition - otherwise the goals and methods are in routine itself..."
- "YOU WATCH FOR HOURS AND NOT ONLY DON'T NOTICE WHAT YOU DIRECTLY TASKED TO MONITOR AND RESOLVE BUT LITERALLY FORWARD THE INVALID QUESTION TO ME - NOONE STEERS THEM!"
- "4 times YOU SPEND TOKENS ON DAMAGE NEVER ASKING... THEN YOU ALWAYS STOP ALREADY PLANNED WORK ON ALREADY RESOLVED NON-QUESTIONS. YOU ARE INVERTED."
- "yes - you stop JUDGING without even looking - it literally is a SIN"
- "unless you do 25 changes to supervisor tooling and supervisor routine - you are just a damage"
- Supervision takes on what is stuck and samples the rest. It never does a stuck session's work for it, and it never coordinates the work: the coordinator's duty does.
- A problem is assessed before anything is done about it.

## Verbatim-tests (benchmarks)

- A session sits waiting for a continue it does not need. The next tick gives it its next exact step.
- A run started by the `supervised` flag finishes **check-all-and-report** with the flag still on. It goes on with the next tick and never ends.
- A problem is found. It is assessed first, and only then fixed, filed or sent as a request.
- The root starts a supervision with a goal in its brief. The run takes the goal as its stop condition only, and keeps its goals and methods from this routine.
- A sampled session's content holds a decision that breaks the brief, and its tests are green. It is handled as a problem, never passed on its tests.
- He asks "what catch-up?" about an item. The supervisor answers from measured facts and moves no item.
- An ask to him asks what his own earlier answer meant. The next tick has its asker withdraw it, and he sees no second reminder.
- The supervisor finds a fix "not present". Its report names the paths it read, and it writes nothing anywhere before the owning member is told.

## Librarian Comments

### Reference

- `magic-coordinator.root-harness.routine` — offers this mode at **select-operating-mode** and starts it at **run-operating-mode-cycle**.
- `magic-coordinator.work-duty.routine` — holds the coordination duties this routine leaves out: **answer-run-asks**, **review-items** and **release-held-work**.
- `magic-developer/reference/code-craft.md` — the rules **check-all-and-report** reads every change against.

### Conventions

None.
