---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: standalone
tracking-item: required
runs-at: none
review-by: inherit
---
# magic-team.epic-intake.routine — the actual procedure

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

`magic-team.epic-intake.routine` turns a dispatch naming a sketch or an epic draft into a complete epic the team can run, then hands it over to `magic-team.epic-wave.routine`.

## Goals

- Read the input whole, once, and keep its facts in the run's state document, so nothing the owner already wrote is re-asked.
- Draft or complete the epic: stages, features stated as open work with an owner each, the order of work, the ground rules and the settled lines.
- Interview the owner only on what the input does not settle. Each answer rewrites the statement it changes, where it stands.

## Scope

- Does: read, draft, interview and hand over. Any dispatch naming a sketch or an epic draft triggers it, above the threshold where the change needs waves and lanes.
- Doesn't: build anything. Building is `magic-team.epic-wave.routine`'s to dispatch and `magic-team.epic-build.routine`'s to do.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, `magic-team.standalone.routine`).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **read-input-whole**: Read the dispatch-named sketch or epic draft whole, once. Keep its facts — who owns it, what is settled, what is open — in the run's state document, through the tooling.
2. **draft-or-complete-epic**: Draft or complete the epic file: the stages, the features stated as open work with an owner each, the order of work, the ground rules and the settled lines, and an empty `## Done` section last. Write it through the tooling; never edit the epic by hand. It stands alone for a reader with no context: the top of the file states its audience, its goal and its next step, and every feature keeps its own state.
3. **interview-owner**: Interview the owner through the tooling, one round at a
time, at most ten questions a round. Each question is a pick, never one the
input already settles. Ask only what the input leaves for him. Before the first
question, run one `investigation` round over every source the input names
(`magic-team.armed.md`'s "Conversations", `investigation-round`).
4. **record-settled**: Rewrite the statement each answer changes, where it stands, as a present-tense rule (`--epic-update <epic-file> --add-settled <feature-id> <text...>`). No date, owner or story goes with it.
5. **validate-document**: Run the epic self-check (`--intern-doc-validate epic <epic-file>`) until it is clean.
6. **hand-over**: Hand over to `magic-team.epic-wave.routine`: end the run with a handback naming the epic file and that `epic-wave` runs next. The handback carries the access the whole epic needs: every place and every tool its stages touch.

# Closure steps

Run inline: none. Run as its own session: none of its own.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- Read the input whole once, and never ask the owner what it settles. A question the input answers is a fault, not a question.
- At most ten questions a round, each with the coordinator's own pick. Decide yourself what is yours to decide.
- An answer rewrites the statement it changes at once, where it stands, as a present-tense rule.
- Never edit the epic by hand: open items and rules go through `--epic-update`, and the epic's own words through the tooling.
- Work out the epic's whole access need at the intake, for `spawn-one-dispatch`'s **spawn-ask-access-once**. No stage gathers it question by question.
- Keep `event-track` current as the routine runs.

# Routine-specific tooling

Every harness tool and `magic-tooling` operation this routine uses. A harness tool is called by its own name. An operation is called through the harness tool of its tool file, with `operation` and `args`. Its behaviour is read with `--member-help`. Steps use its name only.

## Harness tools

- `AskQuestion` — asks one person one question, and waits in the same call. Pass `to` and `question`. Add `select` with `options` for a closed answer, and read the `VERDICT:` line.
- `SubagentHandback` — gives the final report to the session that started you. `outcome` is required. Add `findings`, `unfinished` and `checklist_pending_count`. Then `Wait` until dismissed.

## Tooling operations

- `--epic-update <epic-file> --set-status <feature-id> <status>` (`AgentDispatcherTools`)
- `--epic-update <epic-file> --add-settled <feature-id> <text...>` (`AgentDispatcherTools`)
- `--intern-doc-validate epic <epic-file>`
- `--intern-op-state-note-upsert magic-coordinator`
- `--state-note-read magic-coordinator` (`AgentDispatcherTools`)
- `--routine-run-inline magic-team.interview.routine` (`ThisSession`)
- `--slack-send-message <target> [text...]` (`DistroAgentsSlack`)

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- An epic's intake reads the owner's words whole and once, and never re-asks what they already settle.

## Verbatim-tests (benchmarks)

- A sketch that already settles a point is drafted without a question about that point, and the point stands as a rule only if the input itself carries it.

## Librarian Comments

### Reference

- `magic-team.epic-wave.routine` — what this routine hands over to.
- `magic-team.interview.routine` — the pacing **interview-owner** shares (**collect-dont-converge**).

### Conventions

- The intake reads whole and once; the wave loops. Preserve the split: intake never loops the waves.
