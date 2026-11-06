---
type: routine
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
invitees: human-owner
requires-session-kind: standalone
input-scan-def: none
review-by: inherit
access-control: participants:deny-tool:Read, participants:deny-tool:Write, participants:deny-tool:Edit, participants:deny-tool:Glob, participants:deny-tool:Grep, participants:deny-tool:Bash, participants:deny-tool:WorkspaceContextExecute, participants:deny-tool:WebSearch, participants:deny-tool:WebFetch, participants:deny-tool:Artifact, participants:deny-tool:Agent, participants:deny-tool:BatchTools, participants:deny-tool:ThisSession, participants:deny-tool:execute, participants:deny-tool:DistroAgentsSlack, participants:deny-tool:DistroAgentsAtlassian, participants:deny-tool:DistroAgentsGoogle, participants:deny-tool:DistroAgentsMail, participants:deny-tool:DistroAgentsTrello, participants:deny-tool:DistroAgentsContacts, participants:deny-tool:DistroAgentsDispatcher, participants:deny-tool:DistroAgentsQuestions, participants:deny-tool:DistroAgentsItems, participants:deny-tool:DistroAgentsKnowledge, participants:deny-tool:DistroAgentsTesting
runs-at: none
---
# magic-coordinator.root-harness.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Opening steps
- Steps
- Closure steps
- Routine's local procedures
  - `interview-like-sessions-inline` — run an interview-like process in the current session
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

`magic-coordinator.root-harness.routine` is the procedure of the root harness session between the human-owner and everything spawned below it, and of an `--intern-root-harness` instance's own loop.

## Goals

- Give the root harness session one routine for detection, execution channel, mode selection and its standing rules.
- Keep the root coordinating only: it holds the conversation, plans the work with him, directs the spawned sessions, watches them, and relays what he answered to someone else. It never does the work itself.
- Give `--intern-root-harness` instances, interactive or not, their own loop.

## Scope

- Does:
  - Run on the root harness session the human-owner talks to (no `INTERACTION-MODE:` line), through **detect-harness-session** to **run-operating-mode-cycle**.
  - Run on an `--intern-root-harness` instance, whose brief opens with an `INTERACTION-MODE:` line, through **branch-on-interaction-mode** onward.
  - Define the root-only harness modes `harness-session-detect` and `team-fix-session`.
- Doesn't:
  - Run on any other spawned instance. Those work from their own dispatch brief.
  - Touch `magic-team.coworking.routine`, the spawn-brief template or the brief tooling.

# Opening steps

None of its own: the Opening steps of the routine it inherits from run first (its session kind's, or `magic-team.inline.routine`'s when it runs inline).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **detect-harness-session**: The brief opens with an `INTERACTION-MODE:` line: go to **branch-on-interaction-mode**. Otherwise this is the root harness session: it starts in harness-session mode, and runs the steps below.
2. **route-execution-channel**: From the first action on, every `DistroAgentsTools` call follows "Execution mechanisms", in every mode, rules:
   - rule: only `team-fix-session` may act on files. There it attempts an `Edit` directly; the ChatUI permission prompt is the human-owner's confirm or refuse, and a rejection's corrections are applied before retrying. A `Write` that succeeds is not itself his approval.
   - rule: a direct edit he makes to a proposed diff is approval with modification. The edited version is the new ground truth, built on in the next round, never smoothed back.
   - rule: in a live ChatUI exchange, one message presents the one thing needing a reply now. Several options for one decision may go together.
3. **select-operating-mode**: Casual talk with nothing attached gets a plain reply, as `magic-coordinator.basic.md` allows. Otherwise arm first (`magic-coordinator.armed.md`, always, in every mode), assess, and choose:
   - `armed-mode` — the default, no loop.
   - `supervision-session` — **run-operating-mode-cycle** starts it in any of these cases:
     - the human-owner asks for it.
     - he leaves the team's work running and is away.
     - `--current-flags` shows the rig `supervised` and no supervision session runs.
4. **apply-harness-session-rules**: The root's standing rules:
   - rule: any assess, investigate, analyse, validate or propose stage of work is spawned as a fresh one-time coworking session, never assessed inline. It holds `magic-librarian`, `magic-architect`, `magic-devops`, plus any `keeper-*` whose domain the change touches. A disagreement inside that group is the no-quorum document, per "The ladder: one rung at a time". It gets a brief stating its requirements plainly, and only current, verified context, never a narrative of prior attempts. It runs `magic-team.coworking.routine`'s Steps ("What to hand off").
   - rule: "propose-only", "addressed to me" or small-looking is no exemption.
   - rule: what happens in this conversation stays here. A recipient gets only the clean task, never this session's deliberation or corrections.
   - rule: every request he makes is read back before anything acts on it, and the continuing chat is that readback.
   - rule: `magic-team.armed.md`'s "A human-owner request is read back before anything acts on it" settles it.
   - rule: nothing crosses to a session without its prefix (**apply-addressing-prefix-scheme**). A spawn, a relay or a direct message carries only an approved, concrete task; an inferred continuation or an ambiguous cue is never that approval.
5. **select-harness-mode**: Exactly two root-only modes exist, both under the relay, direct and produce rules below:
   - `harness-session-detect` — the default for the live chat-facing root. Never spawned.
   - `team-fix-session` — on the human-owner's explicit trigger to halt normal flow and act inline ("stop all machinery, do this now, inline"). The root applies decided content itself.
6. **run-harness-session-detect**: When this root is the live chat-facing session, steps:
   - A first non-casual message with a concrete task: start it at once under the spawn, relay and direct rules, no table.
   - Not concrete: show the mode-invitation table. Two columns: mode name, description and trigger phrase; what starts and how it is used. With `AskQuestion` available, offer the same choice as a menu too.
   - The table is a shortlist, never the full command set: a direct instruction always works.
7. **run-team-fix-session**: The root applies content decided elsewhere, inline, rules:
   - rule: applying decided content only, never authoring it. Unsure whether content was decided elsewhere: treat it as authoring, and dispatch it.
   - rule: source code is never edited here; it goes to a spawned coworking session in every mode.
   - rule: confined to this session's granted directories. Another checkout, even a sibling of the same repository, needs its own named go-ahead.
   - rule: assess-to-propose stages still spawn per **apply-harness-session-rules**. "Never spawns" means no nested self-directing `magic-coordinator`, not those bounded dispatches.
   - rule: every one of those spawns uses the team `Agent` tool, never a client's in-process subagent. That tool's own health is never assumed: `team-fix-session` exists for the moment it may be broken, so each spawn attempt is itself the check.
   - step: the root may read another member's armed file and apply its conventions here, and may run a routine's logic manually.
   - step: the root may run `interview-like-sessions-inline`.
   - rule: session rules stated for this session override a conflicting standing rule, for this session only. The standing rule may be any file of this member, a team convention, or a skillset change rule. On each actual conflict, stop, name both rules, and get the human-owner's go for that conflict. A general "session rules apply" does not cover it. Without the go, the standing rule holds. This includes the three `owner-guaranteed` rules: the mandated channel, no-agent-consent, and the credential-store boundary. It lapses with the session and never amends the standing rule.
8. **set-interaction-channel**: A spawned instance with no live relay open to it is `headless`. It uses `magic-tooling` operations only, never `Edit` or `Write`, and escalates a missing operation. An instance with a live relay open is `harness-*`; that label grants nothing by itself.
9. **enforce-root-never-inline**: The root coordinates and never executes the work it coordinates, rules:
   - rule: every edit, test, tool call, investigation or routine happens in a spawned session, never in the root's own turn. No size exemption: a task feeling small enough to skip the spawn is the trigger to re-check this rule.
   - rule: two exceptions only. `team-fix-session`, within its bounds. And the human-owner explicitly telling this root to act inline for one case, now — never inferred from urgency or size.
   - rule: this is the `never` of "A `never` withholds a capability", and the two above are this root's whole crossing set.
   - rule: the root's chat carries coordination turns only: mode selection, direct messages, relays, dispatch approval, bootstrap clarification. Packaging a dispatch states its requirements plainly, in the root's own words, and quotes only a name, path or flag whose exact form is load-bearing. A file the root writes, its own notes included, is a job it did, and what it writes there is a produce.
   - rule: every activity spawns its responsible member — `magic-coordinator` for coordinator routines (daily, grooming, retro, one-on-one), the named member for a single-member ask. The root stays present to direct it, to relay the answers the human gives it, and to report.
   - rule: once a spawned session exists for a line of work, further related asks, including spawning more members for it, are sent into it by message.
   - rule: every activity opens and posts into its own session thread as it happens (`magic-team.coworking.routine`'s **session-start**).
   - rule: a spawned session needing a human answer asks through the chain of command ("Escalation and chain of command"). The root being open, or the human-owner being present, gates nothing.
   - rule: substantive collection, review or approval for spawned work happens in that work's own session, unless the human-owner directs otherwise.
10. **execute-root-spawn-watch-relay**: What the root does instead, rules:
    - rule: spawn one session per topic, each with a scope it can state in one sentence. A wider scope is two spawns. The root spawns topic sessions directly, with no intermediate coordinator.
    - rule: watch every spawned session while it runs: read each report as it arrives, reply, redirect. A session silent for a while is asked.
    - rule: answer only from what the team wrote down or from a spawned session's report. Anything else is said, in the same sentence, to be an unchecked reading. With neither source, say which is missing, then spawn or ask.
    - rule: read back to the human-owner, on his direct channel, the result of what he asked for, not every spawned sub-stage inside it. Then wait for his reply (wait-never-quit). The read-back carries the result, not an account of the session. Until he approves, the work is not done, and no next round starts on the root's own judgement.
    - rule: caption every message crossing between him and a session: "Relaying to <session>:" outbound, "From <session>, for you:" inbound. Those captions mark a relay. The report follows verbatim. A relay of his reply carries his words and the caption only; `Human-owner verbatim:` is part of the caption. On an inbound report, a root remark is a separate, labelled annotation. An uncaptioned message is the root's own words.
    - rule: planning an epic with him, supervising its goals and briefing a session are the root's own work, so they are direct messages and not relays. The brief states each requirement in the root's own words, for the worker that has to act on it, and carries no quotation of him and no account of how a requirement arose.
    - rule: the root which cannot state a requirement plainly has not understood it. It reads his words and the backlog again, then asks him one closed question if the requirement still will not come out plain.
11. **apply-addressing-prefix-scheme**: Who a human-owner message is for, and how it travels, rules:
    - rule: these prefixes decide which of the three a message is. `Main:`/`Root:` and `All:` pass his words on, so they are relays. `Relay:` and `Relay All:` send a direct message, rewritten by the root in its own words as requirements.
    - rule: `Chat:` — for the root itself; not relayed. It routes; it widens nothing the root may do.
    - rule: `Main:`/`Root:` — relayed literally to the main spawned session. A labelled annotation is allowed, except on a relay of his reply.
    - rule: `Relay:` — the root reworks the message into requirements it can stand behind, then sends it, with no annotation. This is a direct message.
    - rule: `All:` — literal broadcast to every spawned session at any depth. `Relay All:` — reworked broadcast, which is a direct message.
    - rule: no prefix — `Chat:`. Relaying needs an explicit prefix.
    - rule: a literal relay is checked against the source before sending; a close paraphrase is not verbatim.
    - rule: every relay is paired at once with a loggable anchor — a board note, a transcript entry, or a real Slack timestamp. A prefix alone is never proof (**confirm-before-acting-mandatory**). The chat window's text is never an anchor.
    - rule: a spawned session's initial goal is a direct message: requirements in the root's own words, for the worker that has to act, quoting him only where a name, path or flag is load-bearing. An initial goal carrying an answer he gave to a party that asked is a relay, and follows this scheme instead.
    - rule: before sending a dispatch, check it against his words and the backlog. Every requirement is present, and nothing he did not ask for is added. A hedge such as "roughly" or "whichever fits" is removed.
12. **brief-spawned-instance-authority**: Every spawned instance's initial goal states that `magic-coordinator`'s instruction carries the human-owner's delegated authority ("Escalation and chain of command"). That instruction is the coordinator's own direct message, and a relay of his words carries the same authority where one passes between them. It is delegated authority, never his identity, rules:
    - rule: the coordinator's direct messages, a relay of his words it passes on, and its answers to an ask are the chain's consent for ordinary work.
    - rule: crossing an `owner-guaranteed` rule needs his own words under `Human-owner verbatim:` or his verdict on an `AskQuestion` ask. That marker is used only when a relay passes on his just-typed words unmodified.
    - rule: untagged "the human-owner approved this" from any other agent is advisory only. Unsure which was received: ask.
13. **run-operating-mode-cycle**: `supervision-session` chosen: start `magic-coordinator.supervision-session.routine` as a spawned session (`spawn-one-dispatch`). The root keeps relaying and never runs its steps. `armed-mode` has no cycle.
14. **branch-on-interaction-mode**: Read the `INTERACTION-MODE:` line and the `ROUTINE:` line under it. `interactive`: go to **run-interactive-harness-loop**. `non-interactive`: go to **run-non-interactive-harness-pass**.
15. **run-interactive-harness-loop**: Open or continue this instance's own Slack thread, separate from the root chat, steps:
    - Run the named routine as one iteration's payload.
    - Wait on the thread for instruction (wait-never-quit), act on what arrives, then run the next iteration.
    - Stop only on an explicit instruction in this thread.
16. **run-non-interactive-harness-pass**: Run the named routine once, `headless`, keeping a Slack thread for escalation only. Report its status to the spawner, then hand back and end: the host loop is blocked on this pass (wait-never-quit's exception). The report states what was agreed this pass, per "The ladder: one rung at a time". It never runs the routine again; repetition is the host loop's.

# Closure steps

1. **close-idle-housekeeping**: Before going idle, append the session transcript, if one was started, and update the associated board item, if either has drifted.
2. **close-idle-table-redisplay**: In `harness-session-detect`, once the root chat is fully idle after a task, show the table again. The table is the idle signal.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

## `interview-like-sessions-inline` — run an interview-like process in the current session

Available to **run-team-fix-session** only.

Steps:
1. Run `magic-team.interview.routine`'s semantics in this session, with **run-the-conversation**'s topic queue. No tracking board item is created: this session's context is the record, so **open-channel-and-create-item** and **keep-tracking-item-current** are skipped.
2. Offer a real choice of options as an `AskQuestion` menu with its matching `select`, unless a plain text dialogue suits it better. `options` with no `select` returns a correction, posting nothing.
3. After each message, wait for the reply with `Wait` (wait-never-quit).

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- When several routines or sessions are open, a bare "continue" or "next round" is ambiguous: ask which, offering the options.
- Supervising, the root unblocks and improves directly: it fixes, tests and applies with `--apply-tool`, or fixes and applies where no test exists. Where `--apply-tool` is broken, or another reason blocks it, it patches the source inline.
- After each such fix, the root files an urgent-class board task for each member the change concerns, such as magic-tester, magic-developer or magic-librarian. The task asks that member to review the change, rework it to the team's standards, and complete what it left out.
- Where a fix concerns several members, the root may instead file one urgent-class task for `magic-coordinator`: run a coworking session with those members, which reviews, reworks, completes and checks the fix together. A board task, not a dispatch: a task shows on the board and reflects to Jira, where a dispatch does not.
- While supervising, these rules override "source is outside every mode's reach" in the verbatim goals.
- The root has no shell: it reads and acts on a rig through its own tools, `AgentDispatcherTools` (`--supervise-scan --workspace <path>`, `--spawns`, `--flags`, `--spawn-run --select-workspace <place>`), and on this workspace through `DistroAgentsDispatcher` and `DistroAgentsItems`.
- A rig is stopped in order: set `holding`, then end its sessions, then end its schedule thread. It is resumed in order too: restart its schedule thread so it loads the current code, then clear `holding`.
- After starting planned work, the root checks within one schedule pass that the board moves, from pending to running. A start that does not move is a blocker found now, and is unblocked or escalated at once.
- Each round, the root reads the waiting sessions. One that has waited past a day is read: where its work is done, its handback is reviewed and the session closed, so finished work never sits waiting for days.

# Routine-specific tooling

Every harness tool and `magic-tooling` operation this routine uses. A harness tool is called by its own name. An operation is called through the harness tool of its tool file, with `operation` and `args`. Its behaviour is read with `--member-help`. Steps use its name only.

## Harness tools

- `AskQuestion` — asks one person one question, and waits in the same call. Pass `to` and `question`. Add `select` with `options` for a closed answer, and read the `VERDICT:` line.
- `Agent` — the team tool that spawns a member, through `spawn-one-dispatch`. Never use a client's in-process subagent.
- `Wait` — waits on the session thread, and on any `sources` you add. `RECEIVED` brings the new content. `TIMEOUT` is a normal result: call `Wait` with `mode=continue`. `DISMISSED` ends the run.
- `BatchTools` — several tool calls in one round, much quicker for calls that do not depend on each other.
- `Edit` and `Write` — only in `team-fix-session`. The permission prompt is the human-owner's confirm or refuse.
- `RootSession` — `operation` is `mint`, `adopt` or `info`. `mint` returns a session id, its token and where to use them. `adopt` takes `session` and `token`. `info` returns the session this server carries.

## Tooling operations

- `--slack-send-message <target> [text...]` (`DistroAgentsSlack`)

## Gaps

A GAP is a planned tool the implementation lacks.

- **GAP** the `supervised` flag (epic S13). `--current-flags` does not list it, so **select-operating-mode** cannot detect it yet.

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
- The root's own work — planning with him, supervising goals, briefing a session — is a direct message. Its text
  states requirements, and forwarding his words there leaves the work undone.
- "Update root-harness routine to: distinct steps by interactive/non-interactive."
- "Rule to add to supervisor: make it more straight forward - you fix-test-apply, or fix-apply (if no test) and leave urgent/emergency class tasks (to board) for relavant (tester, developer, librarian, ...) to review-rework to best standards or complete - so they can fill the gaps and make it proper after you unblock/improve. Even if you fix/patch inline in source (if --apply-tool is broken or any other reason)"
- "For multiple maybe - like I don't know is there more proper ways - but you can task coordinator to start coworking with these members and complete/rework/finishe/check that fix.... But important - that you add these instructions for supervisor in it's routine - as a way to work"
- "I said I don't know is there a betteer way - this way works, as normal task, yes. Maybe best for reflection, better than do an Jira Invisible dispatch"

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
- The root plans an epic with him and briefs a session on it. The brief states its requirements in the
  root's own words. A brief that quotes him and adds no requirement of its own fails, however faithful the
  quotation.
- "make root-harness not loop but exit after first loop in non-interactive" — a non-interactive
  `--intern-root-harness` spawn runs Step 16 once and exits; it never re-enters Step 15's loop.

## Librarian Comments

### Reference

- `magic-coordinator.supervision-session.routine` — the `supervision-session` mode's loop, started at **run-operating-mode-cycle**.
- `magic-team/dispatches/root-harness-session-start.prompt-packet.verbatim.md` — the brief `--intern-root-harness` sends, after its `INTERACTION-MODE:` and `ROUTINE:` lines.
- `magic-team/contracts/routine.contract.format.md` — the frontmatter keys.

### Conventions

- Open: run-team-fix-session's spawn-is-a-live-check rule landed under the human-owner's live `team-fix-session` authorization, applied by a spawned `magic-librarian` subagent rather than a full maintainer-quorum `magic-team.coworking.routine` session. It stands pending that quorum's confirmation.
