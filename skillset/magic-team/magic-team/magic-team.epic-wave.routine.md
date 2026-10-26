---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: standalone
runs-at: none
input-scan-def: work-duty --session-id {{session-id}}
wait-sources: inbox:{{team-member}}
review-by: inherit
---
# magic-team.epic-wave.routine — the actual procedure

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

`magic-team.epic-wave.routine` is the run's loop: it chooses the next features by the order of work, dispatches each to a builder, checks every gate, and keeps the epic and the state document current until the epic is done.

## Goals

- Move the epic forward by waves: choose by the order of work, dispatch at most as many builders as economy allows, and check every gate before any apply.
- Rule each gap by the spec, or ask the owner only when only he can decide.
- Set each feature's status line through the tooling, and keep the run's state document current.

## Scope

- Does: choose, dispatch, check gates, rule gaps, set status lines, remind the owner, and hand off the tail to the next epic.
- Doesn't: build. A builder runs `magic-team.epic-build.routine`; this routine checks its gate and reports.
- Doesn't: close the epic. `magic-team.epic-close.routine` does that when every feature is done or moved.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, `magic-team.standalone.routine`).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **choose-next-features**: Choose the next features by the epic's order of work, reordered as the epic goes, by effect and by the owner's word.
2. **dispatch-builders**: Dispatch each chosen feature to a builder (`--spawn-prompt`), with the build brief (filled by the tooling) and the feature's name, at most as many at once as economy allows.
3. **check-gates**: Check each builder's gate, every line against the spec and its Settled lines, and answer yes, yes-with-changes, or no. Most yeses come with one change; name it.
4. **rule-gaps**: Rule each gap the builder sends by the spec, or ask the owner when only he can decide; send the ruling back at once.
5. **inject-mid-run**: On a mid-run request from the owner, inject it into a feature in work when it is small and near; otherwise add it to the next epic's input.
6. **set-status**: After each apply, set the feature's status line, through the tooling (`--epic-update <epic-file> --set-status <feature-id> <status>`), with the live time.
7. **keep-state-current**: Keep the run's state document current (`--intern-op-state-note-upsert`) — the features in work, the gates open, the owner's rulings.
8. **fresh-builder**: Start a fresh builder when the last one's context has grown large; a long builder's context is never reused for speed.
9. **remind-owner**: Remind the owner of his own steps (a commit, a review, a rig update) by Slack DM (`--slack-send-message`) when each falls due.

# Closure steps

Run inline: none. Run as its own session: none of its own.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- Every gate is checked line by line before any yes. A yes that was not checked is a fault.
- A gap is ruled by the spec alone where the spec decides it; only a decision the owner alone can make reaches him, and it becomes a Settled line at once.
- Never edit the epic by hand: the status line and the Settled line go through `--epic-update`.
- The tail is postponed, never dropped: what does not finish goes to the next epic's input.
- Keep `event-track` current as the routine runs.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## Tooling operations

- `--epic-update <epic-file> --set-status <feature-id> <status>`
- `--epic-update <epic-file> --add-settled <feature-id> [--date <YYYY-MM-DD>] [--owner <name>] <text...>`
- `--spawn-prompt <team-member> [--routine <selector>] [--from-board <item> [--board-state <state>]...] [--description <text>]`
- `--intern-op-state-note-upsert magic-coordinator`
- `--state-note-read magic-coordinator`
- `--slack-send-message <target> [text...]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- A wave moves the epic forward by dispatching builders and checking gates, never by building with its own hands.

## Verbatim-tests (benchmarks)

- A gate whose one statement is not built where the spec says is answered no, even when every other line checks out.

## Librarian Comments

### Reference

- `magic-team.epic-build.routine` — what a dispatched builder runs.
- `magic-team.epic-intake.routine` — what hands this routine the epic.
- `magic-team.epic-close.routine` — what closes the epic once every feature is done or moved.

### Conventions

- The wave loops and the intake reads once. A mid-run request is injected small-and-near, else postponed; never both.
