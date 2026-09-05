---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# magic-team.proposal.routine — the actual procedure

# Summary

Routine-proposal is the named shape for taking one proposal to the human-owner through its whole propose→work-out→approve life, in a single standing thread. The routine holds the sequence/flow/logic in its Steps; the proposal-thread mechanic holds the invariant shape, defined once in this file and referenced by the Steps.

## Goals

Give the team one routine for the entire propose→work-out→approve process with the human-owner: frame the invariant question as the thread root, put the proposed form to him as a clean in-thread reply, work it out across his comments by revising in place, and close on his own reaction. A routine can reference an instructed mechanic — the Steps carry the flow and logic, the `proposal-thread-mechanic` local procedure carries the invariant shape, and the two are kept distinct rather than one restating the other (the same relationship `magic-team.interview.routine`'s Steps have with the `check-restart` and conversation/negotiation mechanics they reference).

## Scope

Does: the full lifecycle of a single proposal to the human-owner — open the thread on the invariant question, post the proposal reply, work it out and revise by delete-and-replace, close on the root's own reaction. Triggered when a proposal to the human-owner is ready to put to him — by the human-owner or a member asking for it, or a routine reaching the point where a settled shape needs his approval.

Doesn't do: convergence/decision among team members (`magic-team.discuss.routine`), collection/understanding of another party's vision (`magic-team.interview.routine`). This routine starts once there is an actual proposed form to put to the human-owner.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **process-own-inbox**: run `magic-team.process-inbox.routine <executor>` — inline execution (own identity), so own inbox is read before the proposal is put.
2. **open-thread-on-invariant-question**: open the standing thread by posting its root, per **proposal-thread-mechanic**'s root clause — the root is the invariant question, and only that. Capture the root `<channel>:<ts>` as this proposal's own thread anchor; every later step targets that same thread. The root is never reposted or rewritten after this step.
3. **post-the-proposal-reply**: post the proposed form as an in-thread reply to the root, in the clean form **proposal-thread-mechanic**'s in-thread-proposal clause defines. One proposal reply is live in the thread at a time.
4. **work-out-across-his-comments**: the human-owner comments in the same thread; work the proposal out against what he says. Each reworked proposal is landed by **proposal-thread-mechanic**'s delete-and-replace clause — delete the superseded reply, post the fresh one into the same thread, root and thread left intact and unmarked. Repeat per revision until he closes it.
5. **close-on-root-reaction**: closure is the human-owner's own reaction on the root, per **proposal-thread-mechanic**'s root-reaction clause. The routine never sets that reaction — it reads the root to detect it, and treats it as the terminal signal for the whole process. Only after an approving root reaction does the approved work proceed; a negative root reaction closes the process as rejected/dropped.

# Closure steps

1. **close-session**: reference `magic-team.coworking.routine`'s **close-session** group and execute it alike under own identity.
2. **closing-reflection**, steps:
   - reflect on how the proposal process itself went (process/quality, not just outcome)
   - check memory notes
   - if the process surfaced a real behavior/pattern not yet backed by a written rule, record it as a finding
3. **carry-the-approved-work-forward**: on an approving root reaction, the approved work goes through the normal task-creation/dispatch lifecycle — this routine's own job ends at approval; it does not build the approved change itself.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

## `proposal-thread-mechanic` — the proposal-thread mechanic (defined once here, referenced by the Steps)

A proposal to the human-owner runs in one standing thread whose root stays for the whole propose→work-out→approve process.

- **root clause — root = the invariant question.** The thread's root message is the invariant question the proposal answers: self-contained, no history, no narrative, no references, phone-readable. It is the thread anchor and STAYS unchanged for the whole process — never deleted, never rewritten into the proposal itself.
- **in-thread-proposal clause — the proposal is a reply, in clean form.** The proposal itself is a reply in that thread. **A clean proposal is present/future-tense and states only the proposed form and its tight reasoning — no history, no narrative, no account of how it was reached, no precedent or tension recounting.** A proposal describes what is proposed, not the debate that produced it. Same body discipline as `magic-team/magic-team.shared.md`'s **A rule statement stays a rule statement** and `magic-team.discuss.routine`'s **keep-tracking-item-current**: the clean, timeless statement is what the reader sees; the investigative back-and-forth lives in the work's own tracking document, never folded into the proposal.
- **revision clause — delete-and-replace; the root and thread stay.** A reworked proposal replaces its predecessor in place: delete the superseded reply, post the fresh one into the same thread. Never stack the old proposal beneath the new one, never open a fresh thread for a revision, and never re-post or rewrite the root. A revision marks nothing; only closure marks the root.
- **root-reaction clause — closure is one reaction on the ROOT.** Per `magic-team/magic-team.board.md`'s Slack-originated-item reaction convention: `:white_check_mark:` for approved/done, an assessed negative reaction (`:x:`/❌ the floor, not a fixed choice) for rejected/dropped. The root's own reaction is the terminal signal for the whole process — a red mark means the proposal was rejected or abandoned, never that a single revision was superseded. The human-owner sets it; the routine never does.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- `magic-coordinator` (this routine's sole executor) is permitted and obliged to execute every step exactly as written, in order.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- **The routine never sets the root reaction.** Closure is the human-owner's own reaction on the root; the routine reads for it and acts on it, and does not react on the root itself for any reason.
- **Clean-proposal discipline governs every proposal reply**, per **proposal-thread-mechanic**'s in-thread-proposal clause: present/future-tense, proposed form plus its tight reasoning only, no history/narrative/how-reached/precedent/tension. A reply carrying any of those is not clean and is reworked before it stands.
- One proposal reply is live in the thread at a time — a revision is a delete-and-replace, never an addition.
- The root is posted once and never touched again except by the human-owner's own closing reaction.
- One documented mechanism failing once is a stop-and-ask signal, not a puzzle to solve alone.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-comms-slack-send-message <team-member> <target> [text...]` (**open-thread-on-invariant-question**: post the root; **post-the-proposal-reply** / **work-out-across-his-comments**: post the proposal reply and each replacement)
- `--member-comms-slack-delete-message <team-member> <channel>:<ts> [<channel>:<ts>...]` (**work-out-across-his-comments**: delete the superseded proposal reply on each revision)
- `--member-comms-slack-read <team-member> (<channel>:<ts> [--thread]|...)` (**close-on-root-reaction**: read the root to detect the human-owner's closing reaction)

## `--member-comms-slack-send-message` Operation Reference

`DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>:<ts>> [text...]` — posts a message, attributed to `<team-member>`. A bare conversation id posts a new top-level message (the root, in the human-owner's DM); a literal `<channel>:<ts>` posts a threaded reply (the proposal reply, under the root).

## `--member-comms-slack-delete-message` Operation Reference

`DistroAgentsTools.fn.sh --member-comms-slack-delete-message <team-member> <channel>:<ts> [<channel>:<ts>...]` — deletes one specific message the acting identity itself authored. This is the delete half of the revision clause's delete-and-replace. The acting identity must be the one that authored the reply being replaced.

## `--member-comms-slack-read` Operation Reference

`DistroAgentsTools.fn.sh --member-comms-slack-read <team-member> (<channel>:<ts> [--thread]|<channel>|<conversation-id>|...)` — reads a message/thread, used at **close-on-root-reaction** to detect the human-owner's closing reaction on the root.

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- A proposal to the human-owner lives in one standing thread — a short root gist that is the invariant question and stays, the proposal as an in-thread reply revised by delete-and-replace, and only the root's own reaction (green approved / red rejected-or-dropped) closing it.
- A clean proposal is present/future-tense and states only the proposed form and its tight reasoning — no history, no narrative, no account of how it was reached, no precedent or tension recounting; a proposal describes what is proposed, not the debate that produced it.
- The routine holds the sequence/flow/logic in its Steps and references the proposal-thread mechanic; a routine referencing an instructed mechanic is the established shape, not an either/or with it.

## Verbatim-tests (benchmarks)

- A proposal is reworked after the human-owner comments — the old proposal reply is deleted and the new one posted into the same thread, the root gist and thread left intact and unmarked, and no new thread opened; the root gets `:white_check_mark:` only when he approves, or an assessed negative reaction only if the whole proposal is dropped.
- A proposal reply carrying history, narrative, an account of how it was reached, or precedent/tension recounting is not clean — it is reworked to present/future-tense, proposed-form-plus-tight-reasoning only, before it stands.
- The routine never sets the root reaction — closure is detected from the human-owner's own reaction on the root.

## Librarian Comments

### Reference

- `magic-team/magic-team.conversations.md` — the proposal-thread lifecycle clause and its cross-references lived here before this consolidation; a short pointer remains there, and this routine is the single home now.
- `magic-team/magic-team.board.md` — the Slack-originated-item reaction convention **proposal-thread-mechanic**'s root-reaction clause uses.
- `magic-team/magic-team.shared.md` — **A rule statement stays a rule statement**, the body discipline the in-thread-proposal clause reuses.
- `magic-team.discuss.routine` — convergence/decision among members, distinct from this routine's human-owner-proposal purpose; its **keep-tracking-item-current** shares the clean-statement discipline.
- `magic-team.interview.routine` — the sibling routine whose Steps-reference-a-mechanic shape this routine matches.
- `magic-team.coworking.routine` — its **close-session** group, referenced by this routine's Closure Steps.

### Conventions

- Matches the sibling `magic-team.*.routine.md` structure (`magic-team.interview.routine.md` among them): `# Summary`/`## Goals`/`## Scope`, `# Steps`, `# Closure steps`, `# Routine's local procedures`, `# Routine's local rules`, `# Routine-specific tooling`, `# Maintainer Notes`.
