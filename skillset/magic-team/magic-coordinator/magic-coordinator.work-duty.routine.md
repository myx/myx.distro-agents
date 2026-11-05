---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
access-control: magic-librarian:allow-tool:skillset-upsert
requires-session-kind: standalone
routine-lock-document: inbox:{{team-member}}:note-20261020T000000Z-work-duty-state-and-lock.md
input-scan-def: work-duty --session-id {{session-id}}
wait-sources: inbox:{{team-member}} tagged:{{team-member}} mentions:{{team-member}} board:backlog board:pending board:running board:review board:blocked board:parked
reports-to: none
review-by: none
runs-at: none
cache-prefix: extended
---
# magic-coordinator.work-duty.routine — the actual procedure

# Summary

The coordinator's duty session: it works what its work-duty scan found, then waits, and works what arrives, until it is dismissed. Its scan carries what the team's duty scan carries, and three things more. They are the due items of the human-owner and the external contacts, the open permission asks, and the board. The tooling starts it when the schedule's flags allow and something waits. That is an item of its inbox, one of the board that changed, or a recheck-date that arrived. The tooling has it dismissed at its next idle point when the flags stop allowing. It wakes within seconds of an item arriving in its inbox or in an active state of the board.

# Opening steps

The Opening steps of its session kind run first. Then:

1. **greet-the-team**: where this run's dispatch carries `day-first: yes`, post one short freeform greeting to `magic-team` before any other step: one message of one line. Where it carries `day-first: no`, post none.
2. **write-the-duty-list**: Write these recurring duties to your `CheckList`, one item each:
   - the inbox.
   - the due items.
   - the permission asks.
   - the board round.
   - the run asks.
   - the held work.
   - wait for more: call `ThisSession`, operation `idle-wait`.

   Every round starts from that list.

# Steps

1. **work-the-input**: set each recurring duty on your `CheckList` to pending, and mark each done as this round finishes it. The input the spawner gave you is `input/input-scan.md`. Read it by line range, and do not scan again. Work what it holds, in this order, a section reading `(none)` skipped:
   - the inbox: run `magic-team.process-inbox.routine magic-coordinator` inline (`--routine-run-inline magic-team.process-inbox.routine`). This is the round's one inbox processing.
   - the due items of the human-owner and the external contacts: `magic-coordinator.external-inbox-handle-loop.routine`, inline (`--routine-run-inline magic-coordinator.external-inbox-handle-loop.routine`).
   - the permission asks: `magic-coordinator.permission-escalation.routine`, inline (`--routine-run-inline magic-coordinator.permission-escalation.routine`).
   - the board and what is tagged to you: the board steps below, **reconcile-sessions** to **release-held-work**, against the scan's sections. Keep the round's tracking note current as the round proceeds (`--update-routine-state`), referencing items by name rather than copying them.
2. **reconcile-sessions**: compare the scan's session registries with the board before any other board work. Each handler states its outcome, steps:
   - **reconcile-read**: read the spawned-sessions and pending-replies registries, and match each `board-running` item to its session by `session-id`. A pending-replies row's `session-id` is the id of the run that asked, never of the coworking session that run joined.
   - **reconcile-dead-session**: a `board-running` item other than a `dispatch-*` whose session is not live is a failed spawn. Record the registry reading in its `execution-receipt`. It carries `restart-session`: respawn that group at the item's recorded state, outcome `respawned`. Otherwise: move it to `board-blocked` with a `condition` naming the dead session, outcome `flagged-once`.
   - **reconcile-untracked-session**: a live session with no board item is flagged once in `event-track`, naming its session id, member and sandbox. No item is created; whether it becomes tracked work is a judgement. Outcome `flagged-once`.
   - **reconcile-finished-session**: a live session whose tracked work reports finished and which nothing else needs is dismissed (`spawn-one-dispatch`'s **spawn-dismiss**). This covers sessions an earlier round dispatched.
   - **reconcile-lost-reply**: a `board-blocked` item waiting on a reply the registry no longer holds open: read its `communication-channel-id` thread. The addressee's answer is there: apply it and continue the item. None: re-ask the same party in that thread (`AskQuestion`, `wait: false`) and keep the item blocked, outcome `nudged`. A missing record is never consent and never a deny. An open ask never expires by age: the human may be away for weeks. It is closed only when its question is no longer current, is a duplicate, was resolved another way, or its session is complete and closed.
3. **review-items**: for each `board-review` item whose `review-by` is `magic-coordinator`, or is empty and its run reports to `magic-coordinator` (the scan's review-items section lists them), steps:
   - apply `magic-team.handback-review.routine` to it, inline (`--routine-run-inline magic-team.handback-review.routine`). Every such item is reviewed here, whatever its size.
   - a verdict this member cannot settle alone, such as one that binds the team, climbs by "The ladder: one rung at a time". The item stays in `board-review` meanwhile.
   - a check that times out on both the old and the new tree compares nothing: drop it from the gate as not measurable under load.
   - a defect: return the item with the exact files, lines and change, and the instruction to land it without stopping. Code that re-enters a command script for an internal step that has its own include is always a defect.
   - sound work: accept the item. Then move each proven epic item to Done at once, with its evidence in one line (`--epic-update <epic-file> --set-status <feature-id> done`), and validate the epic (`--intern-doc-validate`).
   - a handback that closes one round of an item still open: accept the round in the session thread. Then send the session on to the next round.
4. **communication-sweep**: run `magic-coordinator.communication-sweep.routine`'s Steps inline (`--routine-run-inline magic-coordinator.communication-sweep.routine`), against this round's board read.
5. **check-process-board**: run `check-process-board` against this round's read.
6. **start-pending**: start decided `board-pending` work, steps:
   - candidates: approved `board-pending` items with no dispatch recorded, a child that `check-process-board` promoted from an approved parent included. The approval is the go; the running session covers the spawn.
   - conflict gate: any one of these keeps the item in `board-pending`, with `recheck-date` advanced:
     - package or topic overlap with a running job.
     - resource contention shown by a live signal this round: an active lock or channel.
     - a document the item needs, being edited by another live session.
   - "Dispatched earlier today" or "liveness unknown" alone is never evidence. Ambiguous evidence counts as a conflict.
   - start at most one per round, oldest first: spawn its `restart-session` group, or else its `owner`, through `spawn-one-dispatch`, and move it to `board-running`. One item per session.
   - a spawn that fails: move the item to `board-parked` (`--advance-to-parked`) with `condition`, `handoff-action: spawn retry`, `execution-receipt` and `--recheck-in 17`, and post once to `event-track`. Each recheck retries once.
   - this is the only starter of an unrequested `board-pending` item. Another routine may call `spawn-one-dispatch` only on its own instruction.
7. **continue-running**: every `board-running` item, every round, steps:
   - an item whose `recheck-date` is still in the future, or below the staleness threshold, is skipped untouched: no write, no record.
   - `session-id` set: nudge the session with this round's relevant findings (`SendMessage`). Never spawn a second session for it. A failed nudge, or a session with no state change past the staleness threshold, is treated as `session-id` absent.
   - `session-id` absent, and no owning duty: run `magic-team.advance.routine` for it, inline (`--routine-run-inline magic-team.advance.routine`).
   - `session-id` absent, `restart-session` present, and the item's next iteration needs that group: respawn it through `spawn-one-dispatch`, with `--advance-to-running --from-state:running --recheck-in 7±2`.
   - approved, but no session, no `restart-session` and no dispatch recorded, past the threshold since `started-at`: dispatch its `participants`, else its `owner`, through `spawn-one-dispatch`. Outcome `respawned`.
   - console-backed work: check its channel with `--console-list`. A channel expected but gone is flagged, never restarted. A live item that this round's findings concern gets them relayed through its own channel: `SendMessage`, or `--console-send` for console-backed work.
   - a named participant cannot be spawned: move the item to `board-parked` (`--advance-to-parked`) with `condition` naming that participant and a `recheck-date`, and report it.
8. **answer-run-asks**: answer each open ask addressed to the coordinator, from the pending-replies registry, steps:
   - answer it at once, in its own thread, by the brief and the epic (`--answer-escalation`). Pick the option that keeps the work moving without the human-owner.
   - an ask only he can answer, while a supervision session runs: record it for him, and tell its run what to do meanwhile. Never ask him. Otherwise forward it to him (`--forward-escalation`).
9. **release-held-work**: hold the work at what the machine carries, rules and steps:
   - rule: held work is the epic's sessions that wait for release, in its release order: most important first, by its urgency marks. A critical session is never held.
   - rule: while a supervision session runs, hold each session that started since the last round. Never hold the critical session, a released session, a supervision session or this one.
   - rule: the measure of capacity is the gap between tool calls that a run feels, never the load average alone.
   - step: for every live run, take the gaps between its consecutive tool calls over the last ten minutes, and their median. One long call that is a Wait or a test run is not a slow call.
   - step: ask one Permission set for the session next in the release order, where it has no approved `access-control:` set (`--request-permission-set`, on the item that tracks it). Cover every place, tool and member it will use.
   - step: every median under a minute and no run stuck, as `magic-coordinator.supervision-session.routine`'s **unstall-runs** defines it: release the next held session in the release order, per `release-a-session`.
   - step: a median of a minute or more: release nothing. Find the cause in the call path, and dispatch its fix with no regression.
10. **decide-inline**: for each item of this round, decide inline which it is, and move on, steps:
   - small: work it at once here, as an inline routine (`--routine-run-inline`).
   - larger: prepare its brief, record it and spawn a sub-task (the Agent tool). The sub-task reuses this session's cached prefix, so its first round is cheap.
11. **post-the-round**: post one line into the session thread (`ThisSession`, operation `post`): what this round started, moved or flagged, or that it found nothing. Post the round's record to `event-track` (`SendMessage`): the outcomes per item and their counts, the items left untouched, and what was started. It never repeats `check-process-board`'s **board-report**.
12. **wait-for-more**: run `ThisSession`, operation `idle-wait`. Your list's `wait for more` item is this call: making it does that item. An arrival is any message addressed to you: new work, an ask or news. Go to **work-the-input** on one, and a `DISMISSED` ends the duty.

# Closure steps

None of its own: the Closure steps of its session kind run after a dismissal.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

## `release-a-session` — release one held session

Takes the held session. A critical session gets the same message when its work starts.

Steps:
1. Release the session and every run joined to it, and add it to the released list, so **release-held-work** leaves it alone.
2. Post in its session thread, addressed to its executor, that it is released and goes on without stopping. Give its exact numbered steps to run without stopping.
3. In the same message, give the four call-path rules of `code-craft.md` "Each call runs only its own path":
   - each call parses and runs only its own path.
   - nothing common is loaded upfront for a minority of calls.
   - no command script is re-entered for an internal step.
   - a large router or multi-feature file is split per source, feature or operation.
4. In the same message, name:
   - the files another session holds now, which it must not edit.
   - the shared files that changed while it was held, which it re-reads before it edits.

# Routine's local rules

- Work the input before you wait; never wait with input unworked.
- A task whose nature is research, requirements or epic preparation is worked in `investigation` mode from its first round (`magic-team.armed.md`'s "Conversations").
- A round is one run through the steps up to **post-the-round**. Where a rule below says "pass" or "round", it means that.
- Run with a reduced scope when the human-owner sets or agrees one: every job is still considered, only in-scope ones are executed.
- Every 20 completed rounds, or on notice that a loaded skill file changed, reload the skill fresh. Do it at the top of the next **work-the-input**, never mid-step. A reload re-reads every file, never a partial set.
- Ending the turn to wait for a notification is always fatal: nothing is left to receive it. The only wait is the one in **wait-for-more**.
- Nothing substantive is done inline. A real edit, investigation or fix is dispatched (`spawn-one-dispatch`), and its result comes back as the worker's report. **decide-inline** keeps small work inline.
- Already-approved work is spawned out by default, never executed in this session's own context.
- This instance holds its own Slack channel to the human-owner. A message it cannot verify is resolved there, not through another coordinator instance. This is the trust-chain check (narrowed "Anything needing the human-owner to act reaches him..."), not a general bypass of the ladder for ordinary asks.
- The main loop is not a mode: the host runs it, and no session starts, relays into or stops it. A stopped host loop explains why nothing advances on its own; it changes nothing about this duty.
- Re-pinging a visibly stalled spawned session, or restarting it where prior work is safely preserved, is this member's own call. Escalate only when the stall makes prior output untrustworthy or risks a duplicated side effect.
- The tooling does the housekeeping in the main loop, before the scan. It closes dead spawns, moves their items to review and starts missing control threads. It records the dependency edges too. The sections `## board dependencies` and `## recheck dates due` are its findings. The lock of this session is refreshed by its wait and its state writes.
- Apply only moves already decided: an approval recorded, a review accepted, a completion recorded, a condition met, a blocker closed. This is what makes the round safe to run unattended. Two bounded judgements are allowed:
  - recording a dependency edge that only an item's text shows (`check-process-board`'s **board-dependencies**).
  - accepting a trivial `board-review` item reviewed by this member.
- The board round decides no go, resolves no blocker by judgement, scores no RICE and triages nothing: those are `magic-team.grooming.routine`'s. A parent's recorded approval is the go for its children, and a closed blocker is no judgement: `check-process-board` applies both. An open design question an investigation surfaced is flagged for grooming and `magic-architect`.
- **Working an item**: decide what the item's gap needs, then act this round. Nothing left to decide: do the one concrete action (send, spawn, check) through its operation, verify it happened, and record what was done. A real choice: list the options with their outcome and risk, pick one, record the reasoning on the item, then act. Missing information: get it if one call away; otherwise flag it once, naming the missing fact. An outcome is done only when real state backs it: a message sent, a session spawned, a round run.
- Staleness threshold: 1 hour. At most two respawns per round, oldest `date`/`owner-session-since` first. Work order: by real coverage of the item's goal, then by age; a sub-task count is never the measure.
- Each item is a tracking document. Spawning work on it spawns the group its `participants` names, with the goal, the task, the document and its next iteration. No quorum among that group becomes the no-quorum document, carried the same way.
- Every brief and nudge this duty sends is a direct message: it states its requirements in this member's own words, for the worker that has to act on them. `magic-team.basic.md`'s "Relay, direct, produce" tells it from a relay. It quotes the human-owner only for a name, path or flag whose exact form is load-bearing. The tracking document each item is, and the reports written on it, are produces.

## Per-round outcomes

- Every due `board-running` item ends the round with one outcome: `nudged`, `advanced`, `respawned`, `redispatched`, `flagged-once` or `no-action`. A spawn-failure park is `parked-spawn-failed`. "Deferred" is invalid.
- `no-action` has exactly four valid reasons:
  - no row and no `handler-routine:` matches the item.
  - the digest marks the item `held`.
  - its owner's live duty holds it.
  - a temporary error this round stopped the real handling.
- `execution-receipt` is one of: a spawn receipt id, a dispatch or session id, `inline:<timestamp>`, or `no-action:<reason-code>`.
- Bookkeeping-only outcomes for several items go in one `--advance-batch-outcome` call. `interview-*` and `proposal-*` outcomes never do: each comes from its own round.
- A side-effecting call (spawn, nudge, redispatch, park) is followed by `--advance-sleep-run` before the next item.

## What reaches the human-owner

- The whole record of a round goes to `event-track`. Keep it current as things are found, not batched.
- A DM goes only for something he can act on:
  - a decision only he can make.
  - something blocked on him that he does not know.
  - something that changes what he believed.
- A tally, an extension, a re-confirmed no-action or "nothing new" never qualifies.
- A round with nothing qualifying sends nothing. That is the step completing.
- A DM carries one topic and leads with what is needed. A continuation goes into its own thread; a new topic is a new message.
- A `recheck-date` is set with `--recheck-in <minutes>[±<jitter-minutes>]`, never computed by hand.

# Routine-specific tooling

Every harness tool and `magic-tooling` operation this routine uses. A harness tool is called by its own name. An operation is called through the harness tool of its tool file, with `operation` and `args`. Its behaviour is read with `--member-help`. Steps use its name only.

## Harness tools

- `CheckList` — your work queue. Pass the whole list every call, each item with `content`, `status` and `activeForm`, and one item `in_progress`. A call with no `todos` reads the list. `append` with `member` adds pending items to the list of a member in a session you started.
- `AskQuestion` — asks one person one question, and waits in the same call. Pass `to` and `question`. Add `select` with `options` for a closed answer, and read the `VERDICT:` line. To re-ask a party in a thread, pass `wait: false`.
- `Agent` — the team tool that spawns a member, through `spawn-one-dispatch`. Never use a client's in-process subagent.
- `SendMessage` — posts one message. Pass `message`, `to` and `address_to`. A sentence over 25 words or a semicolon returns a CORRECTION: shorten it and send again. The result gives the ts to `Wait` on. A nudge goes to the session thread of the session it is for.
- `ThisSession` — acts on this session. `operation` is `post` (with `message` and `address_to`), `routine-run-inline` (with `routine`), `get-uninvited-participants`, `set-session-topic` or `set-session-chapter`. `post` puts the round's line into this session's thread.

## Tooling operations

- `--idle-wait [--wait-timeout <seconds>]` (`ThisSession`)
- `ThisSession`, operation `post` (`message`, `address_to <team-member>`): one line into this session's own thread.
- `--routine-run-inline <routine>` (`ThisSession`)
- `--update-routine-state [--document <note>] [--header:upsert:<name>:<value>]... [--header:remove:<name>]... [--from-file <path>|--edit-patch-from-stdin]`
- `--advance-to-running <item-filename> --from-state:<state> [--header:...]...` (`DistroAgentsItems`)
- `--advance-to-parked <item-filename> --from-state:<state> [--header:...]...` (`DistroAgentsItems`)
- `--move-to-blocked <item-filename> --from-state:<state> [--header:...]...` (`DistroAgentsItems`)
- `--move-to-pending <item-filename> --from-state:<state> [--header:...]...` (`DistroAgentsItems`)
- `--move-to-processed <item-filename> --from-state:<state> [--header:...]...` (`DistroAgentsItems`)
- `--advance-batch-outcome <team-member> --items:<item-filename>:<outcome>:<execution-receipt>[,...]` (`DistroAgentsItems`)
- `--advance-sleep-run` (`AgentDispatcherTools`)
- `SendMessage` (`to`, `address_to`, `message`): one message to any target. `DistroAgentsSlack` `--slack-send-message` for `--text-group`, `--update-ts`, `--identity-bot` or a file.
- `--console-list`
- `--console-send <channel> [-- <command...>]`
- `--answer-escalation <request-id> <verdict> [text]` (`DistroAgentsQuestions`)
- `--request-permission-set <item> (--entry <tool[,tool...]:target>... [--purpose <text>])... [--scope task|session] [--session-id <id>] [--participant <member>]...` (`AgentDispatcherTools`)
- `--forward-escalation <request-id>` (`DistroAgentsQuestions`)
- `--accept-review <item-filename> [--summary <text>]` (`DistroAgentsItems`)
- `--return-review <item-filename> (--message <text>|--from-stdin)` (`DistroAgentsItems`)
- `--epic-update <epic-file> --set-status <feature-id> <status>` (`AgentDispatcherTools`)
- `--intern-doc-validate`
- `--skillset-upsert <team-member> <pathname>`
- `--queue-list`
- `--queue-take`
- `--queue-done <name>`

## Gaps

A GAP is a planned tool the implementation lacks.

- **GAP** the hold and release of a session (epic S19.1). No operation does either, so **release-held-work** is done through the console until one exists.
- **GAP** automatic resume of a session's executor when an item is added to its CheckList (epic S4.1, investigation first).

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine does the periodic board reconciliation process-flow needs to keep moving — without it, board state can drift from reality between full daily/grooming cycles.
- `check-process-board`'s own dependencies step exists so task-ordering/dependency reasoning (what blocks what) is a standing, repeatable step recorded on the board itself — not a one-off answer that evaporates once the conversation moves on.
- The round's full record is kept without spending the human-owner's attention on it: the record goes to `slack-event-track` every round, and his own channel carries only what he can act on.
- A duty session never does substantive work inline: every real edit, investigation, or fix is dispatched to a sub-spawned session.
- The reload trigger keeps a long-running duty instance's loaded skill files from silently drifting from what is actually on disk.
- Held work is released at what the machine carries, most important first. A released session is told how to code and what to do without stopping.
- "YOU PERSONALLY TALK TO ME IN SLACK DM / DO ORCHESTRATE UNATTENDED / WHEN THEY FINISH - CHECK ALL / UNPAUSE SOME OF EPIC WORK - MOST IMPORTANT FIRST AND ALWAYS CHECK TOOL CALL TIMES / WHILE IT IS ACCEPTABLE - BRING MORE / INSTRUCT ALL TO CODE PROPERLY - ACTIVELY INSTRUCT ALL"
- "YOU NEED TO GIVE THEM EXACT STEPS TO DO NON STOP AND FUCKING FINISH IT"
- "CODE REVIEW ALSO SHOULD SEE IT - THEY SUPPOSED TO LOOK AT CODE NOT AT GREEN TEST RESULT"

## Verbatim-tests (benchmarks)

- A round re-confirms every `board-running` item and finds nothing needing him. It posts the full record to `slack-event-track` and sends him nothing — the silence is the closing step completing, not a step skipped.
- A `board-running` item whose own content already says it moved to `board-blocked`, but is still physically sitting in `board-running`, gets moved to match — without waiting for the next grooming round.
- Dependency reasoning worked out ad hoc in a chat reply gets recorded on the board-item files themselves — the next round doesn't have to redo it from scratch.
- An approved `board-running` item carrying none of `session-id`, `restart-session:`, an active console session, or an unresolved dispatch note, sitting past the staleness threshold, gets a real dispatch this round — never a blanket `no-action` stamp with nothing actually tried.
- A `session-id`-set item that keeps getting nudged with zero observed state change past the staleness threshold is treated as if the nudge failed — not renudged indefinitely as "still working."
- A high-RICE item blocked on a low-RICE one still records the gate plainly — never silently reordered to make the numbers look consistent.
- A duty instance ends its own turn to wait for a notification with nothing left alive to receive it. That is always fatal, never a valid wait.
- One of this session's own watched skill files shows a newer mtime mid-round. The reload waits for the next **work-the-input** rather than firing mid-step.
- Tool calls slow to minutes after a release. Nothing more is released until the cause in the call path is fixed.
- A handback whose new code re-enters a command script for an internal step goes back with the exact lines, even with its tests green.
- A check times out on both the old and the new tree. It is dropped from the gate, and never rerun in batches.
- An ask only the human-owner can answer arrives while a supervision session runs. It is recorded for him and its run is told what to do meanwhile. He is not asked.

## Librarian Comments

### Reference

- `magic-team.advance.routine` — the next iteration of each running document, run at **continue-running**.
- `magic-coordinator.armed.md` — `check-process-board`, `check-pending-comms-actions`, `spawn-one-dispatch`.
- `magic-team/reference/board-model.md` — board states and the advance/grooming split.
- `magic-coordinator.supervision-session.routine` — the unattended loop that leaves answering, reviewing and releasing to this routine.
- `magic-developer/reference/code-craft.md` — "Each call runs only its own path", the rule every released session is given and every review requires.
- `magic-team.handback-review.routine` — its **review-code** step is the first review bullet of **review-items**.

### Conventions

- **reconcile-sessions**, **review-items**, **communication-sweep**, **check-process-board**, **start-pending**, **continue-running**, **answer-run-asks** and **release-held-work** are cited by name from other files.
