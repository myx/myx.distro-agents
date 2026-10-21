---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
allows: magic-librarian:skillset-upsert
requires-session-kind: standalone
routine-lock-document: inbox:{{team-member}}:note-20261020T000000Z-work-duty-state-and-lock.md
input-scan-def: work-duty --session-id {{session-id}}
wait-sources: inbox:{{team-member}} tagged:{{team-member}} board:pending board:running board:review board:blocked board:parked
includes: magic-coordinator.advance.routine.md: Steps, Routine's local procedures, Routine's local rules, Routine-specific tooling
reports-to: none
review-by: none
cache-prefix: routine
runs-at: none
---
# magic-coordinator.work-duty.routine — the actual procedure

# Summary

The coordinator's duty session: it works what its work-duty scan found, then waits, and works what arrives, until it is dismissed. Its scan carries what the team's duty scan carries and three things more: the due items of the human-owner and the external contacts, the open permission asks, and the board for the rules of `magic-coordinator.advance.routine`, whose Steps, local procedures, local rules and tooling are mixed in below by the tooling and stand in no copy. The tooling starts it when the schedule's flags allow and something waits (an item of its inbox, one of the board that changed, a recheck-date that arrived), and has it dismissed at its next idle point when they stop allowing. It wakes within seconds of an item arriving in its inbox or in an active state of the board.

# Opening steps

None of its own: the Opening steps of its session kind run first.

# Steps

1. **work-the-input**: the input the spawner gave you is `input/input-scan.md`. Work what it holds, in this order, a section reading `(none)` skipped:
   - the inbox: run `magic-team.process-inbox.routine magic-coordinator` inline (`--routine-run-inline magic-team.process-inbox.routine`);
   - the due items of the human-owner and the external contacts: `magic-coordinator.external-inbox-handle-loop.routine`, inline (`--routine-run-inline magic-coordinator.external-inbox-handle-loop.routine`);
   - the permission asks: `magic-coordinator.permission-escalation.routine`, inline (`--routine-run-inline magic-coordinator.permission-escalation.routine`);
   - the board and what is tagged to you: the Steps of `magic-coordinator.advance.routine` below, from the second on (the first is the inbox, done above), against the scan's sections.
2. **post-the-round**: post one line into the session thread (`--post-session-channel`): what this round started, moved or flagged, or that it found nothing.
3. **wait-for-more**: run `DistroAgentsSession.fn.sh --idle-wait`. On an arrival, go to step 1. It returns nothing until one comes; a `DISMISSED` ends the duty.

# Closure steps

None of its own: the Closure steps of its session kind run after a dismissal.

# Routine's local procedures

None of its own: the local procedures of `magic-coordinator.advance.routine` follow.

# Routine's local rules

- Work the input before you wait; never wait with input unworked.
- A round is one run through steps 1 and 2. Where a rule below says "pass" or "round", it means that.
- The housekeeping the advance Steps speak of (closing dead spawns, moving their items to review, starting missing control threads) and the dependency edges are the tooling's, done by the main loop before the scan; the lock of this session is refreshed by its wait and its state writes.

# Routine-specific tooling

- `--idle-wait [--wait-timeout <seconds>]`
- `--post-session-channel [--address-to <team-member>]... (<text...>|--from-stdin)`
- `--routine-run-inline <routine>`
- `--skillset-upsert <team-member> <pathname>`
- `--queue-list`
- `--queue-take`
- `--queue-done <name>`
