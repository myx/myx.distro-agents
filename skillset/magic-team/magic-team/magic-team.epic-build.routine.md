---
type: routine
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: standalone
runs-at: none
review-by: inherit
---
# magic-team.epic-build.routine — the actual procedure

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

`magic-team.epic-build.routine` is the builder's run on one feature: the four beats of "How a feature is delivered", the build brief, and the apply tool, ending with the apply report.

## Goals

- Deliver one feature the epic names, by the four beats: readback and gaps, sandbox, gate, apply.
- Build and test in the builder's own scratch, red against live first for the stated reason, then green.
- End with the apply report, so the coordinator sets the feature's status line from it.

## Scope

- Does: one feature, from readback to the apply report. Any member the coordinator dispatches runs it.
- Doesn't: choose features, or check a gate. The coordinator runs `magic-team.epic-wave.routine` and checks; this routine sends the gate and applies on a yes.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, `magic-team.standalone.routine`).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **readback-and-gaps**: Read the feature, its Settled lines, the constraints naming it, and the code it touches. Where the epic is silent, send each gap with its proposed reading, before building that part; build only the parts the gap does not touch until it is answered.
2. **sandbox**: Build and test in your own scratch under `.local/temp/`. Write a test for each statement of the spec, red against live first for the stated reason, then green.
3. **gate**: Send the coordinator the conformance gate, in the compact form (the gate's form, filled by the tooling): the diff path; each statement mapped to `file:line`; the tests, red on live then green; anything the coordinator must rule; the economy and script-writes cases left undone. Nothing else.
4. **apply**: On a yes, apply through the apply tool (W2), then smoke, the named tests on live, a queued retest, and the knowledge lines for the librarian (`--request-update --kind knowledge ...`).
5. **apply-report**: End the run with the apply report (the apply report's form, filled by the tooling): what was applied, the smoke, the named tests on live, the queued retest, the knowledge lines, and the time.

# Closure steps

Run inline: none. Run as its own session: none of its own.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- The epic is the full spec: no gap is invented, and a gap is sent at once, one line, with the proposed reading.
- Scratch lives under the workspace; never `/tmp`, `TMPDIR`, or a template-less `mktemp`.
- No git outside a throwaway rig, no production host, no secret printed, no `CLAUDE.md` edited, no post as the human-owner.
- After sending the gate, end the turn; never idle in a long `Wait` for the coordinator.
- A mechanical step is one plain run of the tooling; a tool unsafe to use is fixed itself, never wrapped.
- Keep `event-track` current as the routine runs.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## Tooling operations

- `--request-update --kind knowledge --target <topic> --why <text> [--from-stdin|--from-file <path>] [--reply]`
- `--slack-send-message <target> [text...]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- A builder delivers one feature the epic fully specifies, inventing nothing the epic did not say.

## Verbatim-tests (benchmarks)

- A feature whose spec has a statement with no test written for it is not gated until that test exists, red then green.

## Librarian Comments

### Reference

- `magic-team.epic-wave.routine` — the coordinator that dispatches this routine and checks its gate.
- The apply tool (W2) — the one tool this routine applies through on a yes.

### Conventions

- The four beats are readback-and-gaps, sandbox, gate, apply — in that order, every feature, never out of order.
