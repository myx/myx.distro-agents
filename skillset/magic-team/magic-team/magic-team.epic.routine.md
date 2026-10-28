---
type: routine
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: coworking
reports-to: none
review-by: none
runs-at: none
---
# magic-team.epic.routine — the actual procedure

# Summary

An epic's session: it works the epic's own step list, the features the epic declares, in their order. Then it hands back where the epic's project item says. A run of this routine is a run of the epic named by its file, so the epic's steps stand as this routine's `# Steps`.

# Opening steps

None of its own: the Opening steps of its session kind run first.

# Steps

1. **work-the-epic-steps**: the epic's step list is this routine's own `# Steps`, carried in the file that names the epic. Work the steps in order, one at a time, as the epic's project item and the input the spawner gave you (`input/input-scan.md`) say.
2. **hand-back**: the epic's Closure steps hand the outcome back to the routine's own parent, carrying what was agreed.

# Closure steps

None of its own: the Closure steps of its session kind run after the hand-back.

# Routine's local procedures

None.

# Routine's local rules

- Work one epic step to its agreed done before the next.
- A step that cannot execute as written: escalate it, and never skip it silently.

# Routine-specific tooling

- `--idle-wait [--wait-timeout <seconds>]`
