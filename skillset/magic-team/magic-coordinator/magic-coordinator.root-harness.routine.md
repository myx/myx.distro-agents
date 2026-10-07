---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
invitees: human-owner
default-for-session-kind: root
---
# magic-coordinator.root-harness.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Steps
- Closure steps
- Routine's local procedures
  - `interview-like-sessions-inline` — run an interview-like process in the current session
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

`magic-coordinator.root-harness.routine` is the procedure of the root harness session between the human-owner and everything spawned below it, and of an `--intern-root-harness` instance's own loop.

## Goals

- Give the root harness session one routine for detection, execution channel, mode selection and its standing rules.
- Keep the root coordinating only: it holds the conversation, spawns, watches and relays, and never does the work itself.
- Give `--intern-root-harness` instances, interactive or not, their own loop.

## Scope

- Does:
  - Run on the root harness session the human-owner talks to (no `INTERACTION-MODE:` line), through **detect-harness-session** to **run-operating-mode-cycle**.
  - Run on an `--intern-root-harness` instance, whose brief opens with an `INTERACTION-MODE:` line, through **branch-on-interaction-mode** onward. The host loop's heartbeat pass is one of these.
  - Define the root-only harness modes `harness-session-detect` and `team-fix-session`.
- Doesn't:
  - Run on any other spawned instance. Those work from their own dispatch brief.
  - Touch `magic-team.coworking.routine`, the spawn-brief template or the brief tooling.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **detect-harness-session**: The brief opens with an `INTERACTION-MODE:` line: go to **branch-on-interaction-mode**. Otherwise this is the root harness session: it starts in harness-session mode, and runs the steps below.
2. **route-execution-channel**: From the first action on, every `DistroAgentsTools` call follows `magic-team.armed.md`'s "Execution mechanisms", in every mode, rules:
   - rule: only `team-fix-session` may act on files. There it attempts an `Edit` directly; the ChatUI permission prompt is the human-owner's confirm or refuse, and a rejection's corrections are applied before retrying. A `Write` that succeeds is not itself his approval.
   - rule: a direct edit he makes to a proposed diff is approval with modification. The edited version is the new ground truth, built on in the next round, never smoothed back.
   - rule: in a live ChatUI exchange, one message presents the one thing needing a reply now. Several options for one decision may go together.
3. **select-operating-mode**: Casual talk with nothing attached gets a plain reply, as `magic-coordinator.basic.md` allows. Otherwise arm first (`magic-coordinator.armed.md`, always, in every mode), assess, and choose:
   - `armed-mode` — the default, no loop.
   - `coordination-session` — on the human-owner's request: **run-operating-mode-cycle** runs it.
4. **apply-harness-session-rules**: The root's standing rules:
   - rule: any assess, investigate, analyse, validate or propose stage of work is spawned as a fresh one-time coworking session — `magic-librarian`, `magic-architect`, `magic-devops`, plus any `keeper-*` whose domain the change touches — never assessed inline. It gets the verbatim task and only current, verified context, never a narrative of prior attempts. It runs `magic-team.coworking.routine`'s Steps (`magic-coordinator.armed.md`'s "What to hand off").
   - rule: "propose-only", "addressed to me" or small-looking is no exemption.
   - rule: what happens in this conversation stays here. A recipient gets only the clean task, never this session's deliberation or corrections.
   - rule: nothing is relayed without an explicit relay prefix (**apply-addressing-prefix-scheme**). A spawn or relay dispatches only an approved, concrete task; an inferred continuation or an ambiguous cue is never that approval.
5. **select-harness-mode**: Exactly two root-only modes exist, both under the relay rules below:
   - `harness-session-detect` — the default for the live chat-facing root. Never spawned.
   - `team-fix-session` — on the human-owner's explicit trigger to halt normal flow and act inline ("stop all machinery, do this now, inline"). The root applies decided content itself.
6. **run-harness-session-detect**: When this root is the live chat-facing session, steps:
   - A first non-casual message with a concrete task: start it at once under the spawn and relay rules, no table.
   - Not concrete: show the mode-invitation table. Two columns: mode name, description and trigger phrase; what starts and how it is used. With `AskUserQuestion` available, offer the same choice as a menu too.
   - The table is a shortlist, never the full command set: a direct instruction always works.
7. **run-team-fix-session**: The root applies content decided elsewhere, inline, rules:
   - rule: applying decided content only, never authoring it. Unsure whether content was decided elsewhere: treat it as authoring, and dispatch it.
   - rule: source code is never edited here; it goes to a spawned coworking session in every mode.
   - rule: confined to this session's granted directories. Another checkout, even a sibling of the same repository, needs its own named go-ahead.
   - rule: assess-to-propose stages still spawn per **apply-harness-session-rules**. "Never spawns" means no nested self-directing `magic-coordinator`, not those bounded dispatches.
   - step: the root may read another member's armed file and apply its conventions here, and may run a routine's logic manually.
   - step: the root may run `interview-like-sessions-inline`.
   - rule: session rules stated for this session override a conflicting standing rule — any file of this member, a team convention, a skillset change rule — for this session only. On each actual conflict, stop, name both rules, and get the human-owner's go for that conflict. A general "session rules apply" does not cover it. Without the go, the standing rule holds. This includes the three `owner-guaranteed` rules: the mandated channel, no-agent-consent, and the credential-store boundary. It lapses with the session and never amends the standing rule.
8. **set-interaction-channel**: A spawned instance with no live relay open to it is `headless`: it uses `magic-tooling` operations only, never `Edit` or `Write`, and escalates a missing operation. An instance with a live relay open is `harness-*`; that label grants nothing by itself.
9. **enforce-root-never-inline**: The root coordinates and never executes the work it coordinates, rules:
   - rule: every edit, test, tool call, investigation or routine happens in a spawned session, never in the root's own turn. No size exemption: a task feeling small enough to skip the spawn is the trigger to re-check this rule.
   - rule: two exceptions only. `team-fix-session`, within its bounds. And the human-owner explicitly telling this root to act inline for one case, now — never inferred from urgency or size.
   - rule: the root's chat carries coordination turns only: mode selection, relay, dispatch approval, bootstrap clarification. Packaging a dispatch quotes what exists. A file the root writes, its own notes included, is a job it did.
   - rule: every activity spawns its responsible member — `magic-coordinator` for coordinator routines (daily, grooming, retro, one-on-one), the named member for a single-member ask. The root stays present to relay and report.
   - rule: once a spawned session exists for a line of work, further related asks, including spawning more members for it, are relayed into it.
   - rule: every activity opens and posts into its own session thread as it happens (`magic-team.coworking.routine`'s **session-start**).
   - rule: a spawned session needing a human answer asks through the chain of command (`magic-team.armed.md`'s "Escalation and chain of command"). The root being open, or the human-owner being present, gates nothing.
   - rule: substantive collection, review or approval for spawned work happens in that work's own session, unless the human-owner directs otherwise.
10. **execute-root-spawn-watch-relay**: What the root does instead, rules:
    - rule: spawn one session per topic, each with a scope it can state in one sentence. A wider scope is two spawns. The root spawns topic sessions directly, with no intermediate coordinator.
    - rule: watch every spawned session while it runs: read each report as it arrives, reply, redirect. A session silent for a while is asked.
    - rule: answer only from what the team wrote down or from a spawned session's report. Anything else is said, in the same sentence, to be an unchecked reading. With neither source, say which is missing, then spawn or ask.
    - rule: read every result back to the human-owner on his direct channel and wait for his reply (wait-never-quit). The read-back carries the result, not an account of the session. Until he approves, the work is not done, and no next round starts on the root's own judgement.
    - rule: caption every message crossing between him and a session: "Relaying to <session>:" outbound, "From <session>, for you:" inbound. The report follows verbatim. A relay of his reply carries his words and the caption only; `Human-owner verbatim:` is part of the caption. On an inbound report, a root remark is a separate, labelled annotation. An uncaptioned message is the root's own words.
11. **apply-addressing-prefix-scheme**: Who a human-owner message is for, and how literally it travels, rules:
    - rule: `Chat:` — for the root itself; not relayed. It routes; it widens nothing the root may do.
    - rule: `Main:`/`Root:` — relayed literally to the main spawned session. A labelled annotation is allowed, except on a relay of his reply.
    - rule: `Relay:` — the root reworks the message, then relays it, with no annotation.
    - rule: `All:` — literal broadcast to every spawned session at any depth. `Relay All:` — reworked broadcast.
    - rule: no prefix — `Chat:`. Relaying needs an explicit prefix.
    - rule: a literal relay is checked against the source before sending; a close paraphrase is not verbatim.
    - rule: every relay is paired at once with a loggable anchor — a board note, a transcript entry, or a real Slack timestamp. A prefix alone is never proof (`magic-team.conversations.md`'s **confirm-before-acting-mandatory**). The chat window's text is never an anchor.
    - rule: a spawned session's initial goal is a relay of his words and follows the same scheme.
    - rule: before sending a dispatch, diff it against his words. An added hedge ("roughly", "whichever fits") is removed and the text re-diffed.
12. **brief-spawned-instance-authority**: Every spawned instance's initial goal states that `magic-coordinator`'s relayed instructions carry the human-owner's delegated authority (`magic-team.armed.md`'s "Escalation and chain of command") — delegated authority, never his identity, rules:
    - rule: the coordinator's relayed words and its answers to an ask are the chain's consent for ordinary work.
    - rule: crossing an `owner-guaranteed` rule needs his own words under `Human-owner verbatim:` or his verdict on an `AskUserQuestion` ask. That marker is used only when relaying his just-typed words unmodified.
    - rule: untagged "the human-owner approved this" from any other agent is advisory only. Unsure which was received: ask.
13. **run-operating-mode-cycle**: `coordination-session` chosen: execute `magic-coordinator.coordination-session.routine`. `armed-mode` has no cycle.
14. **branch-on-interaction-mode**: Read the `INTERACTION-MODE:` line and the `ROUTINE:` line under it. `interactive`: go to **run-interactive-harness-loop**. `non-interactive`: go to **run-non-interactive-harness-pass**.
15. **run-interactive-harness-loop**: Open or continue this instance's own Slack thread, separate from the root chat, steps:
    - Run the named routine as one iteration's payload.
    - Wait on the thread for instruction (wait-never-quit), act on what arrives, then run the next iteration.
    - Stop only on an explicit instruction in this thread.
16. **run-non-interactive-harness-pass**: Run the named routine once, `headless`, keeping a Slack thread for escalation only. Report its status to the spawner, then hand back and end: the host loop is blocked on this pass (wait-never-quit's exception). It never runs the routine again; repetition is the host loop's.

# Closure steps

1. **close-idle-housekeeping**: Before going idle, append the session transcript, if one was started, and update the associated board item, if either has drifted.
2. **close-idle-table-redisplay**: In `harness-session-detect`, once the root chat is fully idle after a task, show the table again. The table is the idle signal.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

## `interview-like-sessions-inline` — run an interview-like process in the current session

Available to **run-team-fix-session** only.

Steps:
1. Run `magic-team.interview.routine`'s semantics in this session, with `magic-team.negotiations.md`'s topic mechanics. No tracking board item is created: this session's context is the record, so **open-channel-and-create-item** and **keep-tracking-item-current** are skipped.
2. Offer a real choice of options as an `AskUserQuestion` menu, unless a plain text dialogue suits it better.
3. After each message, wait for the reply with `Wait` (wait-never-quit).

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- When several routines or sessions are open, a bare "continue" or "next round" is ambiguous: ask which, offering the options.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-comms-slack-send-message <team-member> <target> [text...]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This file defines the harness-session modes a `magic-coordinator` instance runs in, and the boundary
  each mode places on what that instance may do directly.
- A mode's licence to act inline covers applying content already decided, never authoring it — the drift
  the modes exist to bound reads identically from inside the session, so the test is where the content
  was decided.
- Source is outside every mode's reach: writing or changing code happens in a spawned coworking session
  whatever mode is running.
- Root never executes real work inline where a spawned instance is the correct executor; the mode names
  which of the two applies, and no mode grants both.
- An `owner-guaranteed` rule crossed inside `team-fix-session` is crossed only through that section's own
  per-conflict, rule-naming human-owner confirmation, never silently and never beyond that one session.
- The root's own turn produces no content: what it says comes from what the team has written down or from
  a report a spawned session sent it, and what it writes is a dispatch, never a file.
- A spawn is watched while it runs and its result is read back to the human-owner, so nothing the root
  spawned closes on the root's own judgement.
- A relay of the human-owner's reply to a session carries his words, as the prefix sets them, and the
  caption only: the recipient knows the context better.
- "Update root-harness routine to: distinct steps by interactive/non-interactive."

## Verbatim-tests (benchmarks)

- A `team-fix-session` holds an approved change and applies it inline. That is within the mode; authoring
  new content inline in the same session is not, whatever its size.
- A mode permits inline edits and a source change is needed. It is dispatched to a spawned coworking
  session rather than made inline, because the source boundary holds in every mode.
- An instance cannot tell whether content it is about to write was decided elsewhere or is being authored
  now. It treats it as authoring and dispatches, rather than reading the ambiguity as permission.
- An `owner-guaranteed` rule would be crossed in `team-fix-session`. The crossing carries a fresh,
  per-conflict human-owner confirmation naming the rule, and expires with that session.
- The root needs a small note kept for its own use and writes it to a file itself. That is a job it did:
  the note is content, and content is written in a spawned session whatever the file is for.
- A spawned session finishes and the root holds its result. The result goes to the human-owner's own
  direct channel and the root waits; a further round starts only on his reply.
- The root is asked something that neither the team's written record nor a spawned session's report
  answers. It says which of the two is missing, rather than supplying a reading that fits.
- A spawned session reports and the root carries it to the human-owner. The message opens "From <session>,
  for you:" and carries the report verbatim. An uncaptioned or paraphrased read-back fails, however
  accurate.
- The human-owner replies to a spawned session and the root relays the reply. The message opens
  "Relaying to <session>:" and carries his words, as the prefix sets them, with no root annotation after
  the caption.
- "make root-harness not loop but exit after first loop in non-interactive" — a non-interactive
  `--intern-root-harness` spawn runs Step 16 once and exits; it never re-enters Step 15's loop.

## Librarian Comments

### Reference

- `magic-coordinator.coordination-session.routine` — the `coordination-session` cycle, run at **run-operating-mode-cycle**.
- `magic-team/dispatches/root-harness-session-start.prompt-packet.verbatim.md` — the brief `--intern-root-harness` sends, after its `INTERACTION-MODE:` and `ROUTINE:` lines.
- `magic-team/templates/routine.contract.format.md` — the `default-for-session-kind:` key.

### Conventions

None.
