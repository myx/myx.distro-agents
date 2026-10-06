---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-team.interview.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Steps
- Closure steps
- Routine's local procedures
- Routine's local rules
- Routine-specific tooling
  - DistroAgentsTools magic-tooling operations
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions

# Summary

`magic-team.interview.routine` captures another party's vision or inquiry precisely, before anything converges on it.

## Goals

- Collect the other party's intent — the human-owner's design thinking, an external contact's need — in their own terms, without deciding anything on their behalf.
- Narrow the `interview-*` tracking item, round by round, until nothing open remains: settled pieces are approved, dispatched and compacted out.

## Scope

- Does:
  - Collection by minimal-assumption questions, one topic per thread.
  - Opened manually — the human-owner or a member asks for an interview with a party on a topic — or by two intakes:
    - `magic-coordinator`'s `missing-tool-option-escalation` procedure, for a tooling gap that is not simple.
    - **design-question-intake**: a member's open design question, filed to `magic-coordinator` with `post-inquiry`, when its answer fixes an interface or an invariant something will depend on **and** no written record answers it. A question the source answers is a fact to look up. Anything below this bar is the member's own judgement call.
  - Continued by any pickup: this routine, a grooming pass, `magic-coordinator.coordination-session.routine`, or a `magic-coordinator.advance.routine` round.
- Doesn't:
  - Reach agreement (`magic-team.discuss.routine`).
  - Build anything bigger than its own inline cycles.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **process-own-inbox**: run `magic-team.process-inbox.routine magic-coordinator`.
2. **open-channel-and-create-item**: on opening or resuming, steps:
   - rule: one topic, one thread. An unrelated topic surfacing mid-interview is forked into its own thread.
   - open or continue the channel: a Slack thread by default; email for slow or unusually complex matters.
   - create the `interview-*` tracking item now, in `board-running` with `--magic-board-create-running`, unless it already exists. Never deferred.
   - a live interactive session sets `owner-session: interactive` and `owner-session-since: <now>` on the item, and refreshes them at each **resume-review**.
3. **name-the-interview-on-resume**: with more than one interview open, a resume names which one. A bare "continue" is an assumption gap: ask which, per **readback-on-suspected-assumption-gap**.
4. **resume-review**: on every pickup, before any new question, steps:
   - mark the item `resume-review in progress` so a second pickup does not collide.
   - find the pieces already settled and not yet dispatched.
   - for each: formulate the dispatch, get it approved in this continuation, dispatch it, shrink the open scope.
   - never block the pass that triggered the pickup.
5. **reassess-before-next-message**: on every pickup, before writing the next message, steps:
   - work from this interview's item only, re-read fresh: board changes, incoming messages, and any new message in this thread.
   - a new message conflicting with the gathered state: resolve the conflict first. An approval: act on it and close the round. New content: collect it.
   - gather the initial ask, approved parts, collected material (summary, verbatim-intents, verbatim-benchmarks, notes) and session state (goal, scope, open questions, open conflicts).
   - check the gathered material for internal conflicts, even with no new message. Conflict: resolve it before drafting.
   - draft fresh each round. Where wording matters, compare several phrasings, per **wording-and-substance-are-separate-checks**.
   - check the draft keeps every verbatim-intent, verbatim-benchmark and stated goal.
   - a corrected draft shows what changed against the prior one.
   - prefer small steps gathering exact wording bit by bit over showing the whole draft.
6. **inherit-check-restart**: on any resume, apply `magic-team.negotiations.md`'s "Check-restart procedure". A nudge restates the current open topic.
7. **collect-dont-converge**: ask small, minimal-assumption questions, one at a time; never bundle decisions. Once a point is clear and agreed, move on. Rules:
   - in an interactive chat, small structured questions (`AskUserQuestion`) are the default, one topic each.
   - **open-before-closed**: a design point new to this session opens with one open question in the party's own terms. A closed option list follows in a later round, once that framing is on record. Every option list carries a literal `none of these — my own:` choice.
   - switch from asking to proposing only once a piece is verified settled: a plain one-line restatement the party did not correct.
   - a piece not yet settled stays in full live context, never summarised.
8. **dispatch-settled-points**: dispatch each piece the moment it settles and is approved, steps:
   - send it where it belongs: a board item in `board-backlog` with `--magic-grooming-create-backlog`, carrying `approved-by`/`approved-at` and `spawned-by` the interview item; or an `inquiry-*` to the member who owns it.
   - compact it into one present-tense block: the resulting rule, fact or decision, never the question-and-answer history. Keep every distinct settled point. The wording is simple and drops no intent, detail or benchmark.
   - give each settled design point two fields: `rejected:` — one line naming the live alternatives that lost, and why; `status:` — `settled`, or `superseded` with a pointer to its replacement.
   - remove it from the open scope. Context changes may still reopen it.
   - keep the categories separate: plan, verbatim-intents, verbatim-benchmarks, corrections, settled facts, sub-parts.
   - periodically compact already-resolved material even before it is dispatched.
9. **run-minimal-step-cycle**: for a small agreed step, inline, repeated per step until nothing is left to focus on, steps:
   - assess it with `magic-architect`, live.
   - turn it into a proposal.
   - present it to the human-owner in this interview for approval.
   - approved: dispatch it per **dispatch-settled-points**.
10. **run-bigger-mechanism-cycle**: for a mechanism or design, driven by this same session, steps:
    - once its shape settles, spawn a coworking sub-session (for example `magic-librarian`, `magic-architect`, `magic-tester`) to produce a tested work plan grounded in real files.
    - collect the plan in this session and dispatch its pieces, asking small questions only where something is still ambiguous.
    - queue what the plan defers as board items, with `restart-session:` naming the same members.
    - a sub-session not yet finished keeps its piece open on the item; **resume-review** picks it up on the next pickup.
11. **record-two-verbatim-kinds**: keep two separate lists, bullets, never paraphrased:
    - **verbatim-benchmarks**: scenario → expected outcome. A growing, non-exhaustive checklist: "the proper solution will have/allow: ...".
    - **verbatim-intents**: purpose statements and invariants ("this exists so that ...").
    - both are a floor, never a ceiling, unless the party states a ceiling.
    - a session's own rephrasing is labelled as a derivative. The party's original wording stays retrievable and controlling.
12. **keep-tracking-item-current**: keep the item's "settled so far" and "still open" sections current as **dispatch-settled-points** narrows the scope, with same-state `--magic-advance-to-running` calls.

# Closure steps

1. **closing-reflection**: reflect on how the session went, as process and quality. A behaviour or pattern with no written rule behind it becomes a `reflection-*`.
2. **hand-off-dont-build**: once the party's vision is captured, anything beyond the inline cycles goes through the normal task-creation lifecycle.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- `magic-coordinator` is permitted and obliged to execute every step exactly as written, in order.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- This routine follows `magic-team.negotiations.md`: both presentation modes are available.
- Every exchange is kept as a `transcript-*` with `--member-append-session-transcript`, per **transcripts-are-verbatim-records**.
- Before acting on anything the party just said, read back a one-line understanding and wait for confirmation, per **rephrase-and-confirm-before-acting**. Waiting follows **wait-never-quit**.
- **Two gates.** A design point — a shape, an interface, an invariant — is approved by a one-line readback the party confirms. Executing anything — a dispatch, a spawn, a filing, a real change — passes the pre-dispatch gate as well, even for an approved design.
- **Pre-dispatch gate**, steps:
  - post a `STATE` block: `session goal`, `session transcript`, `session members`, `session scope`, `session constraints`, `expected outputs`, `board usage` (`NO` unless directly authorised).
  - post a `DISPATCH PAYLOAD` block: the exact payload, verbatim.
  - a risky, irreversible or detail-sensitive action adds the line `member confirms dangerous/detail action`.
  - execute nothing until the human-owner answers `APPROVE`. `NO`: nothing runs.
- Nothing is filed mid-interview unilaterally: propose the piece, type and goal, and wait, unless the human-owner asked for that filing.
- **Unattended rounds.** `magic-coordinator.advance.routine` runs one round per pass on an open interview, with nobody present. The round runs **resume-review** for pieces whose approval is already recorded, then **reassess-before-next-message**, sending at most one message. It never creates an interview item, never approves, files or dispatches anything not already approved, and never reads silence as an answer.
- `GOOD`/`BAD INTERVIEW`, or `GOOD`/`BAD ASSESSMENT` pinned to a quoted statement: read back the understood lesson and record it per **quality-marker-creates-reflection**. This file changes only by the skillset change rule.
- **Scope-steering keywords.** Each is read back and confirmed before it counts. Its topic stays on the record, unlike content under `magic-team.conversations.md`'s `DETOUR:` marker (**detour-offtopic-marker**):
  - `detour:` — the topic goes to the top of this interview's plan.
  - `later:` — the topic goes to the end of the plan.
  - `next:` — the topic becomes the current item.
  - `fork:` — the topic becomes its own new `interview-*` item, at the top of its plan.
- **Work the item nearest to approval next**: the smallest remaining assumption gap and the likeliest approval, whatever its size.
- A small, stable understanding is applied and recorded inline at once.
- A bigger understanding not yet concrete enough for either cycle is filed with `post-inquiry` to `magic-coordinator`, referencing the interview, for later decomposition.
- The party pushes to decide: keep collecting while there is more to capture, but never fight a convergence the party wants. Say that the mode shifted.
- Unsure whether something said is a firm requirement: treat it as one, unless the party says otherwise.
- A member with a domain interview need asks `magic-coordinator` to run it.
- Goal-directedness: work toward the session's goal. Off-goal items are recorded quickly, not acted on now.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-comms-slack-send-message <team-member> <target> [text...]`
- `--member-comms-slack-read <team-member> <channel>:<ts> --thread`
- `--member-comms-email-send <team-member> <email@address>... -- <subject> -- <body...>`
- `--magic-board-create-running <team-member> <item-filename> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...`
- `--magic-advance-to-running <team-member> <item-filename> --from-state:running [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]`
- `--magic-grooming-create-backlog <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...`
- `--member-append-session-transcript <team-member> --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <text>|--from-stdin|--from-file <path>) --transcript-name <transcript-file-name> [--create]`
- `--member-inbox-reflection-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]`
- `--member-upsert-member-inquiry <member> <item-filename> [--from-file <path>]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine exists to precisely understand another party's vision or inquiry before trying to converge on anything — collection and convergence are genuinely different modes.

## Verbatim-tests (benchmarks)

- A bare "continue"/"next round" with no interview named, when more than one interview's tracking board-item is open, is treated as a genuine assumption gap — it asks which interview rather than guessing.

## Librarian Comments

### Reference

- `magic-team.discuss.routine` — convergence; `magic-team.brainstorm.routine` — idea generation.
- `magic-coordinator.advance.routine` — runs the unattended rounds.
- `magic-team/magic-team.conversations.md`, `magic-team/magic-team.negotiations.md` — the mechanics the steps cite.

### Conventions

- **resume-review**, **reassess-before-next-message**, **open-channel-and-create-item**, **keep-tracking-item-current** and **collect-dont-converge** are cited by name from other files.
