---
type: routine
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
access-control: magic-librarian:allow-tool:skillset-upsert
requires-session-kind: standalone
routine-lock-document: inbox:{{team-member}}:note-20261020T000000Z-work-duty-state-and-lock.md
input-scan-def: work-duty --session-id {{session-id}}
wait-sources: inbox:{{team-member}} tagged:{{team-member}} mentions:{{team-member}}
reports-to: none
review-by: none
runs-at: none
cache-prefix: extended
---
# magic-team.work-duty.routine — the actual procedure

# Summary

A member's duty session: it works what its work-duty scan found, then waits for the next, until it is dismissed. The tooling starts it for a member when the schedule's flags allow and the member has something to work on. It has it dismissed at its next idle point when they stop allowing (`DistroAgentsDispatcher.fn.sh --current-flags`). It wakes within seconds of an item arriving in the member's inbox.

# Opening steps

The Opening steps of its session kind run first. Then:

1. **greet-the-team**: on the day's first work-duty run, post one short freeform greeting to `magic-team` before any other step.
2. **write-the-duty-list**: write these recurring duties to your `CheckList`, one item each:
   - work the input.
   - decide each item.
   - wait for more.

   Every cycle starts from that list.

# Steps

1. **work-the-input**: set each recurring duty on your `CheckList` to pending, and mark each done as this cycle finishes it. The input the spawner gave you is `input/input-scan.md`. Work it as your duty instructions (your `.armed.md`) say.
2. **decide-inline**: for each item, decide inline which it is, and move on. Work it at once in this session. Or, for anything larger, prepare its brief, record it and spawn a sub-task (the Agent tool). The sub-task reuses this session's cached prefix, so its first round is cheap.
3. **wait-for-more**: run `DistroAgentsSession.fn.sh --idle-wait`. A keepalive round comes back before the input cache expires with nothing arrived: run it again, so the cache stays alive. On an arrival, go to step 1. A `DISMISSED` ends the duty.

# Closure steps

None of its own: the Closure steps of its session kind run after a dismissal.

# Routine's local procedures

None.

# Routine's local rules

- Work the input before you wait; never wait with input unworked.

# Routine-specific tooling

Every harness tool and `magic-tooling` operation this routine uses. A harness tool is called by its own name. An operation is called through the harness tool of its tool file, with `operation` and `args`. Its behaviour is read with `--member-help`. Steps use its name only.

## Harness tools

- `CheckList` — your work queue. Pass the whole list every call, each item with `content`, `status` and `activeForm`, and one item `in_progress`. A call with no `todos` reads the list.
- `Agent` — the team tool that spawns a member, through `spawn-one-dispatch`. Never use a client's in-process subagent.

## Tooling operations

- `--idle-wait [--wait-timeout <seconds>]`
- `--skillset-upsert <team-member> <pathname>`
- `--queue-list`
- `--queue-take`
- `--queue-done <name>`
