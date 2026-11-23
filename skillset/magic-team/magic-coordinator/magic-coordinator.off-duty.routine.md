---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: standalone
input-scan-def: work-duty --session-id {{session-id}} --floor off-duty
wait-sources: inbox:{{team-member}} tagged:{{team-member}} mentions:{{team-member}} board:backlog board:pending board:running board:review board:blocked board:parked
reports-to: none
review-by: none
runs-at: none
cache-prefix: extended
---
# magic-coordinator.off-duty.routine — the actual procedure

# Summary

The coordinator's out-of-hours duty session, the lazy duty. It works the light floor its scan found, handles five things inline, and leaves the rest as items for the work-duty, spawning nothing.

## Goals

- Keep the coordinator reachable around the clock on one small session.
- Answer only what a recorded decision settles, and leave every judgement for the work-duty.

## Scope

- Does:
  - The light floor: the team channel and the human-owner's messages, the member's own inbox, and the board.
  - The five things of **handle-inline**, and nothing more.
- Doesn't:
  - Spawn or dispatch, or wake a member outside `worktime`, `overtime` and `emergency`.
  - Review a handback, reconcile the board, judge a question, release held work, or edit a source file.
  - Read email, Trello, or the external due items.
  - Decide keep-or-stop, or hold a resting state.

# Opening steps

The Opening steps of its session kind run first. Then:

1. **write-the-duty-list**: Write these recurring duties to your `CheckList`, one item each:
   - the human-owner's messages and the team channel.
   - the inbox.
   - the board news.
   - the inline handling.
   - wait for more: call `ThisSession`, operation `idle-wait`.

   Every round starts from that list.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **work-the-input**: work each thing the scan holds, in the scan's own order, a section reading `(none)` skipped. The input the spawner gave you is `input/input-scan.md`. Read it by line range, and do not scan again. Take one of two courses for each thing:
   - it is one of the five of **handle-inline**: handle it there.
   - it is anything else: leave it by **leave-for-the-work-duty**.
2. **handle-inline**: what this duty acts on itself, each one operation, each already decided, steps:
   - the schedule flag the human-owner asks for: set it with `--override-flag <flag>`, and clear it with `--override-flag --no <flag>`. The call asks the schedule thread once, so a flag starts the duties it opens.
   - an ask that blocks a live run: answer it with `--answer-escalation`, from a decision already on its record. A record holding no decision leaves the ask to **leave-for-the-work-duty**.
   - the human-owner's own message to this bot: acknowledge it in its thread, then leave it by **leave-for-the-work-duty**.
   - a board move whose verdict the item already records: make the move, and name that verdict in its `## Decisions`.
   - an emergency item: the tooling confirms it and sets the flag. Handle it only as far as its record already decides. Ask the human-owner nothing, and set no flag.
3. **leave-for-the-work-duty**: every other thing waits, steps:
   - write it into this member's own inbox as a `note-*`, in the words the work-duty needs to act on it.
   - name what was left, and which kind it is, one of:
     - a dispatch, a review verdict, a judging step, a board reconciliation.
     - an email, a Trello item, an external due item, a held-work release.
4. **post-the-round**: post one line into the session thread (`ThisSession`, operation `post`): what this round handled, left or flagged, or that it found nothing. Post the round's outcomes to `event-track` (`SendMessage`).
5. **wait-for-more**: run `ThisSession`, operation `idle-wait`. Your list's `wait for more` item is this call: making it does that item. An arrival is any message addressed to you: new work, an ask or news. Go to **work-the-input** on one, and a `DISMISSED` ends the duty.

# Closure steps

None of its own: the Closure steps of its session kind run after a dismissal.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Nothing is spawned here, and no member is woken out of hours. A member stays technically available, and this duty never calls on it.
- The run takes the cheapest service preset its rig offers. This duty carries no work whose quality depends on a larger one.
- Nothing substantive is done here. An edit, an investigation, a fix, a review and a dispatch all wait for the work-duty.
- Only a decided thing is applied. A judgement is never made out of hours: it is left for the work-duty.
- The five handlers of **handle-inline** are closed. A sixth is a change to this file's design, never a live decision.
- The floor narrows what arrives, never how the run is woken. A person's tag, an inbox item and the board all still wake it.
- Keeping is the cheaper course while the wakes left before the next worktime cost less than one rebuild of the floor.
- A wake that read nothing from the cache stops the keeping at once, since every wake past it is paid whole.
- The tooling applies keep-or-stop at its own pass and ends the duty there. The run neither decides it nor keeps a resting state.
- A round is one run through the steps up to **post-the-round**.
- Ending the turn to wait for a notification is always fatal: nothing is left to receive it. The only wait is the one in **wait-for-more**.

# Routine-specific tooling

Every harness tool and `magic-tooling` operation this routine uses. A harness tool is called by its own name. An operation is called through the harness tool of its tool file, with `operation` and `args`. Its behaviour is read with `--member-help`. Steps use its name only.

## Harness tools

- `CheckList` — your work queue. Pass the whole list every call, each item with `content`, `status` and `activeForm`, and one item `in_progress`. A call with no `todos` reads the list.
- `SendMessage` — posts one message. Pass `message`, `to` and `address_to`. A sentence over 25 words or a semicolon returns a CORRECTION: shorten it and send again. The result gives the ts to `Wait` on.
- `ThisSession` — acts on this session. `operation` is `post` (with `message` and `address_to`) and `idle-wait`. `post` puts the round's line into this session's thread.

## Tooling operations

- `--idle-wait [--wait-timeout <seconds>]` (`ThisSession`)
- `ThisSession`, operation `post` (`message`, `address_to <team-member>`): one line into this session's own thread.
- `--override-flag [--no] <flag> [<ttl>] [--days <n>]` (`DistroAgentsDispatcher`)
- `--answer-escalation <request-id> <verdict> [text]` (`DistroAgentsQuestions`)
- `--advance-to-running <item-filename> --from-state:<state> [--header:...]...` (`DistroAgentsItems`)
- `--move-to-backlog <item-filename> --from-state:<state> [--header:...]...` (`DistroAgentsItems`)
- `--move-to-pending <item-filename> --from-state:<state> [--header:...]...` (`DistroAgentsItems`)
- `--move-to-blocked <item-filename> --from-state:<state> [--header:...]...` (`DistroAgentsItems`)
- `--move-to-parked <item-filename> --from-state:<state> [--header:...]...` (`DistroAgentsItems`)
- `--move-to-processed <item-filename> --from-state:<state> [--header:...]...` (`DistroAgentsItems`)
- `--upsert-inbox-note <team-member> <item-filename> [--include-processed] [--from-file <path>|--edit-patch-from-stdin]` (`DistroAgentsItems`)
- `SendMessage` (`to`, `address_to`, `message`): one message to any target.

## Gaps

A GAP is a planned tool the implementation lacks.

none

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- The coordinator stays reachable around the clock, and its out-of-hours run pays no rebuild of its own session cache.
- A duty that spawns nothing out of hours keeps every member asleep, and keeps the production decisions inside worktime.

## Verbatim-tests (benchmarks)

- He asks at 02:00 to turn on `overtime`. The duty sets the flag, posts its round line, and spawns nobody.
- A blocking ask arrives at 03:00 whose decision no record carries. It is left in the inbox for the work-duty, and not answered.
- The human-owner's message at 04:00 is acknowledged in its thread and filed as an inbox note. No member is woken.
- An emergency item arrives. The tooling confirms it and sets the flag, and the routine neither asks the human-owner nor sets the flag.
- The last wake of the night read nothing from the cache. The tooling ends the duty, and no run is left in a resting state.
- A dispatch, a review verdict and a held-work release arrive out of hours. Each is left as an inbox note, and none runs here.

## Librarian Comments

### Reference

- `magic-coordinator.work-duty.routine` — the routine this one sheds parts from. Its board round is what this one leaves alone.
- `magic-coordinator.communication-sweep.routine` — the incoming sweep that runs inside the work-duty, and not here.
- `magic-team/reference/board-model.md` — the board states an item is left in.

### Conventions

- `off-duty` joins the routine contract's type-word list beside `work-duty` and `epic` when this file lands. The list names the two today.
- Its floor and its inline scope are the difference from the work-duty. Its form, its opening list and its waiting step otherwise follow that file.
