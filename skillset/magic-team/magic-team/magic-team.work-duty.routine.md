---
type: routine
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
allows: magic-librarian:skillset-upsert
requires-session-kind: standalone
input-scan-def: work-duty --session-id {{session-id}}
reports-to: none
review-by: none
runs-at: none
---
# magic-team.work-duty.routine — the actual procedure

# Summary

A member's duty session: it works what its work-duty scan found, then waits for the next, until it is dismissed. The tooling starts it for a member when the schedule's flags allow and the member has something to work on, and has it dismissed at its next idle point when they stop allowing (`DistroAgentsDispatcher.fn.sh --current-flags`).

# Opening steps

None of its own: the Opening steps of its session kind run first.

# Steps

1. **work-the-input**: the input the spawner gave you is `input/input-scan.md`. Work it as your duty instructions (your `.armed.md`) say.
2. **wait-for-more**: run `DistroAgentsSession.fn.sh --idle-wait`. On an arrival, go to step 1. It returns nothing until one comes; a `DISMISSED` ends the duty.

# Closure steps

None of its own: the Closure steps of its session kind run after a dismissal.

# Routine's local procedures

None.

# Routine's local rules

- Work the input before you wait; never wait with input unworked.

# Routine-specific tooling

- `--idle-wait [--wait-timeout <seconds>]`
- `--skillset-upsert <team-member> <pathname>`
- `--queue-list`
- `--queue-take`
- `--queue-done <name>`
