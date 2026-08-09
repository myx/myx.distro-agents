---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect
invitees: magic-librarian, magic-architect
---
# routine-grooming — the actual procedure

# Summary

Routine-grooming is backlog grooming: review, triage, and reprioritize the team's open backlog — is each item still worth doing, correctly owned, correctly sequenced.

## Goals

Backlog grooming: review, triage, and reprioritize the team's open backlog.

This is different from `routine-daily`:
- `routine-daily` reports *what is outstanding today*.
- Grooming asks *is this backlog still the right shape*. It checks three things:
  - Is the item still worth doing?
  - Is it still owned by the right member?
  - Is it still sequenced correctly?

Grooming is closer to a normal agile team's refinement session than a status pull.

Why this matters: a backlog that only grows, and is never re-checked, builds up stale items, wrong owners, and bad order. A daily roll-call alone cannot catch this — dailies only report on items. They do not re-examine whether an item still deserves its current state, owner, or priority.

Manually triggered, same as the other structured routines. Always confirm with the user before automating it.

## Scope

Does: full-backlog RICE re-score, per-item triage, `blocked/`/`parked/` active-pursuit chasing.
Doesn't do: daily status reporting (`routine-daily`'s job).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

0. **session-start**: execute `routine-coworking`'s Steps — grooming is coworking-like, so its coworking-gated parts apply.
1. **gather-the-backlog**
   - Read all of `the board`:
     - every permanent member's open, deferred, or "not yet done" items
     - across `running/`, `blocked/`, and `parked/`
   - Read every member's own inbox (`--member-work-session-input-scan` operation, once per member).
     - inboxes are not part of the board (see `routine-process-inbox`)
     - read everything landed there since the last grooming pass; it arrives via:
       - `routine-communication-sweep`
       - `routine-ingest-task`
       - a member writing directly into its own or another's inbox (a genuine write by that member itself, not routed through `magic-coordinator` first)
   - Mechanically, this read happens as:
     - the board half: `--magic-grooming-input-scan` operation — a fixed, read-only scan, always `backlog`/`pending`/`running`/`blocked`/`parked`, `--all-types`, every frontmatter field (wider than this step's own `running/`/`blocked/`/`parked/` wording above — flagged, not yet reconciled)
     - the inbox half: no mechanized equivalent — still a direct read
   - This is the same real backlog `magic-coordinator`'s Prioritize section already points to; grooming is where that backlog gets actively worked, not just consulted.
   - Sub-checks, also part of gathering:
     - **Roster/tooling recheck** (grooming-cadence, not every routine):
       - re-list `~/.claude/skills/*/` and re-read each `SKILL.md` description frontmatter
       - refresh the `roster-note` via the `--member-upsert-inbox-note` operation if anything drifted
       - spot-check `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section against anything that's actually come up as wrong since the last grooming
       - if a specific fact genuinely needs live confirmation, dispatch `magic-tester` for it — don't check it here directly
     - **Trello board coverage** (grooming-cadence, not every sweep):
       - diff `GET /1/members/me/boards` (id/name only) against the set of boards the coordinator's notification-feed check already covers
       - auto-subscribe (`PUT /1/boards/{id}/subscribed?value=true`) anything new
     - **Google Drive/Sheets check** (grooming-cadence, not every sweep):
       - `routine-communication-sweep` deliberately skips Google in its routine Check step — it's heavier and only worth it when actually searching or grooming
       - run it here instead: refresh the OAuth token, then `files.list` ordered by `modifiedTime desc`
     - **Human-action-required items**:
       - collect items that are generally approved but need the human-owner's own hands-on action (Slack app config, OAuth scope grants, and similar) as they accumulate; consolidate into one batch
       - **send this batch, don't just file it**: fire it directly via `--member-slack-send-message` operation, as part of this same pass:
         - at step 5's "Review with the user" conversation, if the user is live, or
         - proactively, once this step's gather is done —
         - whichever comes first
       - don't write a `note-2026-08-05-human-decision-batch.md` item and assume some other routine will later notice and pick it up (no routine's Steps currently do that)
       - the note is still filed in `board-processed` afterward, as the record of what was asked and when — not as the trigger mechanism itself
     - **Process own inbox** (every grooming pass, not cadence-gated like the roster recheck): run `routine-process-inbox magic-coordinator` (the confirmed default executor for this joint-executor routine) — inline execution (own identity). Fresh inbox items not yet on the board, gathered here so step 2 triages them alongside the open backlog. Not automatic just because this routine spawned — this explicit call is what actually guarantees it happens.
2. **triage-per-item**
   - For each open item, narrate its owning member deciding what happens to it. Same narrated-pass style as `routine-daily`'s roll call — this is not a full agent spawn per item. The outcome is one of:
     - **Keep** — as-is
     - **Defer**
     - **Reassign** — to a different member
     - **Split** — into smaller pieces
     - **Drop** — stale, no longer relevant
   - RICE scoring is its own dedicated pass (step 3, below), not folded in here — this step decides an item's *state*, step 3 decides its *numbers*.
   - **State transitions and their own re-check happen atomically.** When any part of this step moves an item into a state that has its own separate re-check procedure below (for example, the `board-blocked` re-check, the `board-running` in-place testing re-check), run that re-check right away, as part of the same move — not deferred to the next grooming pass. This rule applies everywhere in this step, not just at one spot.
   - **General resume-review delegation**:
     - when an item's type has an owning routine that defines its own `resume-review` procedure, run that procedure on pickup first — before judging this item's own triage outcome — so triage works from current content, not a stale snapshot
     - running it does two things: dispatch any already-settled-but-undispatched sub-pieces, and shrink tracking content to what's still open
     - current `board-item` prefix → owning routine list for this purpose (grows as more types define one):
       - `interview-*` → `routine-interview`
     - a type not listed here has no `resume-review` defined; ordinary triage applies directly, nothing skipped or missing
   - **Personal-inbox items specifically** (inboxes are not board folders): "triage" for an inbox item means the authority group decides whether it becomes a formal board-item. Outcome for each is one of:
     - **Promoted** — the authority group creates a new board-item (task/project/change/note/etc.), landing in `board-backlog` by default — a single `--magic-grooming-create-backlog` call.
     - **Denied** — rejected, with a resolution reply (see `magic-coordinator`'s own "Dispatch & delegation" standard for the fast-gate rules and the auto-reject vs. escalate split; auto-rejects don't need this step's full narration, just a cited rule)
     - **Ignored** — the inbox item itself is just deleted/left alone, nothing to do on the board side
     - **Not yet ready** — still needs back-and-forth in the member's own inbox before it's board-worthy; stays there, not promoted yet. Any processing checkpoint working that inbox can make this same call, not just grooming.
     - **Merged** — see duplicate-check below
     - where Promoted/Denied items land:
       - promoted or denied items land in `board-processed` with the resolution text attached, via `--magic-grooming-create-processed`; a promoted item lands in `board-backlog` by default, via `--magic-grooming-create-backlog`
       - when this authority group's combined context during grooming already warrants treating it as approved, `approved-by`/`approved-at` gets set directly at creation via `--magic-grooming-create-pending` with `--header:upsert:approved-by:<value>` and `--header:upsert:approved-at:<value>`, and the item lands in `board-pending` in that same action (the same mechanical `board-backlog`→`board-pending` trigger `check-process-board` also acts on, done here in the same breath since grooming already has the context)
       - when it instead genuinely needs human-owner-level approval, the authority group makes two calls: `--magic-grooming-create-running` for the `approval-*` item that runs the negotiation, and `--magic-grooming-create-blocked` for the promoted item (see the board's own `board-backlog` entry for the full mechanic)
       - each of these is the item's first write, not a move of an existing file: a `--magic-grooming-create-<state>` call, which takes a body-input mode and rejects `--from-state:`
       - `owner`, `groomed-at` and `track:true` are stamped; `groomed-from` is not
   - **Attach `source-slack-channel`/`source-slack-ts` at promotion time, when the item genuinely traces to one originating Slack message**:
     - when promoting an inbox item (or any item created directly during this pass) that started life as a specific Slack DM/channel message — not a migration artifact, not an indirect mention — record that message's channel id and ts in the new Item's frontmatter right then, at creation/promotion, not as a deferred cleanup
     - this is what makes the board's own Slack-reaction-on-resolution mechanism (and `magic-coordinator`'s `check-pending-comms-actions` procedure) actually able to find the right message later — a promoted item with no `source-slack-channel`/`source-slack-ts` is invisible to that mechanism even when a real originating message exists
     - `--header:upsert:source-slack-channel:<value>` and `--header:upsert:source-slack-ts:<value>` on that same create call — not a separate write
   - **Duplicate-check, before settling on one of the outcomes above**:
     - for each inbox item, do a quick, cheap look — is this a duplicate of (or cleanly mergeable with) something already sitting in:
       - the same member's inbox
       - `board-running` (the default intake state new items land in)
       - optionally `board-processed` (in case this is just restating something already resolved)
     - if the match is in `board-processed` — including a Denied precedent — whether to reopen or merge into it is a case-by-case judgment call, not a fixed rule
     - this is meant to be an obvious-case check, not an investigation
     - merge only when genuinely confident it's the same underlying ask (matching title-shape, same subject, filed close in time) — fold the new item's content into the existing record rather than creating a second one for it
     - **when in doubt, don't merge** — leave both as separate items; two redundant records a later pass can still catch and consolidate is a far smaller cost than silently collapsing two genuinely distinct asks into one
   - **When a merge does happen, record it with `supersedes`/`superseded-by`** (see the team's own field list):
     - the surviving item gets `supersedes: [<merged-item>]`
     - the merged item (moving to `board-processed`) gets `superseded-by: [<surviving-item>]`
     - also check whether the duplicate actually carries new information the original doesn't have — a duplicate is rarely byte-identical; it usually restates the same ask with something added (a clarifying detail, a changed constraint, a "also, X"). Don't just discard the duplicate once its title/subject matches — fold that new information into the original record:
       - **if the new information is itself already settled/final**, apply it directly into the original item's own current content — same "current state, not a history of edits" standard used for skill/definition files
       - **if the item is still actively in processing** (not yet resolved, real work still ahead of it), a dated addition or comment on the original is the right shape instead — board/task items *in flight* are legitimately allowed dated incremental notes as things develop; that's different from a finished skill/routine-definition file, which should never carry that kind of changelog language once settled. Don't over-apply the "no dates" hygiene standard to an item that's still genuinely being worked.
     - mechanically:
       - the surviving item's `supersedes` update, and any settled-info/dated-addition update: a single `--magic-grooming-to-<its current state>` call with `--from-state:` set to that same state
       - the merged item's `superseded-by` + `board-processed` landing: a single `--magic-grooming-to-processed` call
       - an item never filed on the board, landing in `board-processed` for the first time: a fresh create, not a move
   - **Cross-member handoff → immediate reply**:
     - whenever this step's outcome creates or updates a cross-member item (one member's item now owned by/assigned to another, not a self-write), that's the trigger point for `routine-process-inbox`'s own step 3 — send the compact who+`references` reply to `slack-magic-team` as part of closing out that item's triage, not as a separate deferred step
     - since `magic-coordinator` is the board's sole writer, this covers both halves: the ask itself and this step's resulting decision
     - peer-to-peer asks made outside grooming get the same treatment at the moment coordinator acts on them, via `routine-process-inbox`, not retroactively at the next grooming pass
   - **Triage verbs mapped onto board states**: for items already living in `board-backlog`, `board-pending`, or `board-running` (not just fresh inbox items), this same keep/defer/reassign/split/drop vocabulary applies:
     - **Keep** — stays in its current folder
     - **Defer** — moves to `board-parked` (deliberate, by the team's own choice — not `blocked/`, reserved for external stalls)
     - **Reassign** — `owner` field changes, folder doesn't
     - **Split** — child Item(s) created, referencing the parent; the parent itself moves to `board-blocked`, `blocked-by` the new child item(s) — an internal dependency, the same shape the board already recognizes ("waiting on another task/project's own completion"). If a split-off child is itself investigation/design-shaped (needs several members' judgment together, not a mechanical single-executor step), set `restart-session: <team-member> [<team-member>...]` on it at this same creation — the authority group's own call, same narrated judgment as the rest of this step.
     - **Drop** — moves to `board-archived` directly (no future intent) or is removed from the board (if it never had real substance — judgment call)
     - mechanically: **Defer** is a single `--magic-grooming-to-parked` call and **Split**'s parent move is a single `--magic-grooming-to-blocked` call; **Drop** to `board-archived` is a single `--magic-grooming-to-archived` call. A verb that only changes a field (owner, etc.) with no folder change is a single call; Split's child-item creation is also a single call (a fresh file)
   - **Advancement review**: as part of this same per-item pass:
     - run the `check-backlog-promote` procedure (below) against `board-backlog`
     - run the `check-reassess` procedure (below) against `board-pending`, `board-parked`, `board-blocked`, and `board-running` items — a separate call, own pass
     - `board-pending` items ready to dispatch into `board-running`
     - `board-running` items with a claimed completion — these get (or continue) their own in-place testing round, dispatching `magic-tester` rather than taking a completion claim at face value; no separate `board/testing/` folder, this happens in place
     - **`board-running` items that have stalled**: move to `board-blocked` rather than leaving it sitting there looking active
       - not the only trigger — see the board's own "at least three paths" note for the other two: live discovery during `routine-daily`; a member's own async block-report via `magic-coordinator`'s inbox, handled by `routine-process-inbox`
     - not every item needs this every pass — same "one at a time, narrated" treatment as inbox triage, skip what's genuinely unchanged
     - mechanically: the stalled-running→blocked move is a single `--magic-grooming-to-blocked` call
   - **`board-running` in-place testing re-check** (see the board's own entry for the full state definition): same cadence as the `board-blocked`/`board-parked` re-checks below — every board-item mid its own testing round gets at least a glance each pass, landing on one of:
     - **clean, no approval needed** — moves straight to `board-processed`
     - **clean, needs human-owner sign-off** — moves to `board-blocked`, filed under its "human-owner decision" reason
     - **concerns raised** — an investigation subtask exists or is created now (`references` the parent), which itself resolves to:
       - **escalate** — parent stays `board-running`, or moves to `board-blocked` if the escalation is itself now an external stall
       - **solve** — a solution/implementation subtask is created, parent stays `board-running` until it lands, then another round runs
     - same discipline as `board-blocked`'s own re-check: a board-item mid-testing should show a real attempt or a real subtask each pass, not a silent no-op
     - the move to `board-processed` is a single `--magic-grooming-to-processed` call; the move to `board-blocked` is a single `--magic-grooming-to-blocked` call
     - a new investigation or solution subtask is a fresh file with `references` pointing at the parent. Its landing state is decided by readiness alone — not by which of the two outcomes above created it, and not by the subtask's own item type:
       - ready to be run as it stands → `board-pending`, via `--magic-grooming-create-pending`, and `routine-advance` picks it up from there
       - still needs re-investigation or re-assessment before anyone can run it → `board-backlog`, via `--magic-grooming-create-backlog`
       - a subtask is never created straight into `board-running`: readiness means ready for `routine-advance` to start it, not already started
   - **Slack-reaction closeout**:
     - this step does not react to Slack messages on promotion/move
     - the reaction mechanism: execute `magic-coordinator`'s `check-pending-comms-actions` procedure
     - this step's only obligation on `source-slack-channel`/`source-slack-ts` (see the team's own Item entity model): carry the fields unchanged across any promotion/move — never react to the message itself, never drop or re-derive the fields
       - concretely: whenever a move re-assembles the item's content into the new state, these two fields must be copied over verbatim, not omitted or regenerated
     - full mechanic and rationale: `magic-coordinator`'s `check-pending-comms-actions` procedure, and the board's own `processed/`/`archived/` cross-cutting entry
   - **`board-blocked` re-check — four real outcomes, not just "still blocked or not"**: grooming is where `blocked/` items get periodically revisited — not every pass needs to resolve every one, but each should at least get a quick "has anything changed" glance. For each, the authority group's assessment lands on one of:
     - **Escalate** — push for resolution now (chase the human-owner's answer, investigate an alternative, whatever moves it). Stays `blocked/` while the escalation is in flight.
     - **Stays blocked, with a real attempt made this pass** — `blocked/` demands periodic active pursuit, so "stays blocked" is only legitimate when something was actually tried this review — never a silent no-op re-confirmation. If there's genuinely nothing left to try right now, that's a signal to consider the next outcome instead. This also covers a partial unblock: if only some of the item's `blocked-by` entries have cleared and others haven't, the item stays blocked until every entry clears.
     - **Becomes `parked/`** — the group decides continued active chasing isn't worth it right now; deliberately stop pushing and just wait instead. The moment an item stops getting active attempts made *at* it, it's no longer honestly `blocked/`, it's `parked/`.
     - **Unblocks** — the blocker is cleared, whether because the condition was actually satisfied or because the blocker itself got dropped/archived/superseded; moves to `board-pending`:
       - a resolved `approval-*` negotiation's approved outcome sets `approved-by`/`approved-at` and lands the item in `board-pending`, per the board's own `board-backlog` entry
       - `Becomes board-parked` uses `--magic-grooming-to-parked`; `Unblocks` uses `--magic-grooming-to-pending` — each a single call that moves the item and patches its headers together
     - a `blocked/` item waiting on **another task/project's own completion** has a known, trackable trigger — the "active pursuit" for this kind can be as light as confirming the dependency hasn't quietly finished already, but it's still a real check each pass, not a rubber stamp
   - **`board-parked` re-check, same cadence**:
     - moves back to an active state once its trigger condition arrives — and if the group concludes the trigger is never coming, that's when a parked item actually moves to `board-archived`, not before
     - a `blocked/` item can also move straight to `board-archived` (not via `parked/`) if the group decides even waiting isn't worth it
     - a parked item moving back to an active state uses `--magic-grooming-to-pending`; a move straight to `board-archived` is a single `--magic-grooming-to-archived` call
   - **`board-retained` `recheck-and-exit`**, `recheck-date`-scheduled:
     - for each item whose `recheck-date` is due or unset, re-check against the board's own qualifying-reference definition
     - still referenced → stays, `recheck-date` renewed via `--magic-grooming-to-retained --from-state:retained`
     - no longer referenced → normal `board-processed` GC flow
   - **Task-creation lifecycle**: the staged pipeline a real proposal/task moves through before it's genuinely ready, not just the cut-off-rules check above:
     - investigation
     - discussion/assessment with `magic-architect`
     - doc check and proposal check with `magic-librarian`
     - polished proposal and approval with `magic-coordinator`, using common sense
     - human-owner only if there's real doubt, with a short/clear description
     - sub-tasks are organized by `magic-coordinator` — upon a status check, or when another sub-task finishes and reports back — and route through the coordinator's own inbox usually, not direct inline invocation, matching the personal-inbox model rather than being a separate mechanism
   - **How this composes with the fast-gate check above**: the two aren't redundant —
     - the fast-gate rules (`magic-coordinator`'s own "Dispatch & delegation" standard) are a narrow, fast gate on whether a proposed task should even be allowed to exist (a permission/mandate check, can auto-reject), run early, typically right at intake
     - the staged lifecycle above is about whether a task that *does* pass that gate is actually well-formed and ready to commit to (a quality/readiness check, always needs real judgment, never auto-anything) — it's what a promoted item goes through on its way from `board-backlog` to `board-pending`, per the Advancement review above, not a substitute for it

3. **rescore-backlog-rice**
   - Do this every grooming — not just for newly-triaged items.
   - Before reprioritizing, re-score **every** open task and project across the board's states:
     - **`board-backlog`** — freshly-triaged, not yet assessed
     - **`board-pending`** — go decided, not yet dispatched
     - **`board-running`** — actively dispatched/executing
     - **`board-blocked`** — stalled on external/human-owner action
     - **`board-parked`** — deliberately deferred or waiting on external state change/check
   - The four normalized dimensions (Profit/Cost/Time/Dependencies) are relative to the whole current backlog, so an item that didn't change can still need a new number purely because something around it did.
   - Do this as one pass over the whole set, not folded item-by-item into step 2's triage — triage decides an item's *state*, this decides its *numbers*, and both use the same current-backlog snapshot to stay consistent with each other.
4. **reprioritize-across-members**
   - Apply the coordinator's own important-vs-eager distinction across the triaged, re-scored set — informed by the RICE numbers but not decided by them alone.
   - Surface blockers/dependencies between items explicitly rather than leaving a flat list, since a high score doesn't jump a queue if something else blocks it. This is where the coordinator's cross-team view earns its keep.
   - `blocks:`/`blocked-by:` are already recorded on the board-item files themselves — read them directly as part of this pass, don't recompute here.
   - **Prefer the nearest-to-approval item, not just the biggest-value one** — same discipline `routine-interview`'s own nearest-to-approval rule (its Local rules) applies to open questions, generalized here to backlog items:
     - when several items are otherwise close in priority, favor whichever has the smallest remaining scope/assumption gap and the highest likelihood of a clean approval, regardless of its own size
     - a large-but-ready item can still outrank a smaller-but-still-fuzzy one, and vice versa; readiness is its own axis, not just RICE's Cost/Time/Dependencies
5. **review-with-the-user**
   - This is a conversation, not a report.
   - Present the reprioritized, re-scored backlog and let the user reorder, push back, or approve before it's considered final.

# Closure steps

1. **close-session**
   - Execute `routine-coworking`'s Closure Steps:
     - continuity/reflection
     - the `slack-magic-team`/Trello broadcast
     - the skill-update-discussion offer
   - All apply here — grooming is coworking-like.
   - No status-file GC step exists in `routine-coworking`'s Closure Steps; this routine's own triage pass (step 2) is where drop/split decisions actually happen.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines - not visible outside this file.

## `check-backlog-promote` procedure

Single source for whether/how a `board-backlog` item advances — into `board-pending` or `board-blocked`. Once there, `routine-advance`'s own `check-execute-board` procedure takes over.

Go through every `board-backlog` item, same per-item pass as triage (Step 2), not a separate sweep.

Rules by filename prefix:

Each item is a tracking document. Where a rule below opens or resumes work on one, it spawns the group that item's `participants` record names, handing each member the goal, the task, the document itself, and that prefix's own rule below; a prefix may also have a routine assigned. A prefix with no rule yet stated is a deferral to complete, not a licence to improvise per item.

- `interview-*` / `talk-*` / `task-*` / `proposal-*`, zero activity since posting (`task-*`/`proposal-*` only when explicitly awaiting interview, not yet ingested — read content first, ordinary grooming material can look interview-shaped from its title alone):
  - Interactive-ownership check first: read `owner-session` frontmatter (set by `magic-team.interview.routine.md` step 1). If `owner-session: interactive` is present and `owner-session-since` is fresh (within ~1 hour), skip — a live session already owns it.
  - Otherwise, open or continue the interview thread via the already-sanctioned `routine-interview`/`routine-communication-sweep` Slack mechanism (not a new authority grant — a communication sweep already does this routinely).
  - Once the thread is genuinely active, move the item to `board-pending` via `--magic-grooming-to-pending`.
- Any other type:
  - Dependencies clear (`blocked-by`/`dependency-note` empty or already resolved) and priority confirmed (present authority group's own consensus this pass, not gated on Step 3's later RICE re-score):
    - Nobody dissents → `--magic-grooming-to-pending` operation, `approved-by`/`approved-at` set, moves the item to `board-pending`.
  - Dependency still open, confirmed this pass:
    - `--magic-grooming-to-blocked` operation, with a note. No `approval-*` — not a human decision.
  - Real doubt remains (priority, or whether a dependency still blocks):
    - Creates `approval-*` in `board-running` via `--magic-grooming-create-running`, then moves the original to `board-blocked` via `--magic-grooming-to-blocked`.
  - Not yet assessed:
    - Stays in `board-backlog`.

## `check-reassess` procedure

Decides whether a `board-pending`, `board-parked`, `board-blocked`, or `board-running` item goes back to `board-backlog` for full re-triage, or stays where it is.

Quorum: `magic-coordinator` + `magic-librarian` + `magic-architect`, jointly — this routine's own standing authority group (see this file's own Local rules: "Run by `magic-coordinator` + `magic-librarian` + `magic-architect`, jointly — not by any one of the three alone").

- Item's own scope or assumptions have shifted enough that its current triage state no longer reflects reality — not just "still blocked"/"still parked," the framing itself is stale:
  - Quorum agrees → `--magic-grooming-to-backlog` operation, `--from-state:<state>` set to the item's actual current state, with a note explaining what triggered the recall.
    - Item carries `approved-by`/`approved-at` → clear both in the same call; re-earned via `check-backlog-promote` on its next pass, not carried over.
  - Quorum disagrees → resolve through real discussion, same as the rest of Step 2's triage; never a silent default; escalate to the human-owner if genuinely unresolved.
- Framing still holds:
  - Quorum agrees → no state move; update frontmatter only if something narrower changed (owner, `recheck-date`, a note).

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-coordinator` (this routine's executor) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- This routine is an extension of `routine-coworking` — it inherits that routine's own instructions and follows them wherever they apply; on any conflict, this file's rules override the parent's.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- Run by `magic-coordinator` + `magic-librarian` + `magic-architect`, jointly — not by any one of the three alone. A different member may request/trigger a pass, but does not perform it.
- `routine-grooming` does all the quorum's work inline, itself — it never spawns a coworking session to do it. Work that needs one lands as a `board-pending` item instead — executed later by `check-execute-board` (`magic-coordinator.advance.routine.md`, `routine-advance`-only), not started here.
- All three report the outcome to `slack-magic-team` at close, regardless of outcome — "nothing new this session" is a valid, still-reportable result, not a skip.
- Never fully automated/scheduled without explicit human-owner confirmation.
- RICE re-scoring and per-item triage are separate passes with separate purposes (state vs. numbers) — never folded into each other, even though they happen in the same session.
- The task-creation lifecycle (investigation → `magic-architect` → `magic-librarian` → `magic-coordinator` polished proposal → human-owner only on real doubt) is not optional for a promoted item — `magic-coordinator`'s own "Dispatch & delegation" fast-gate rules are a separate, narrower permission check, not a substitute.
- `blocked/`'s "stays blocked" outcome requires a real attempt that pass — a silent no-op re-confirmation is not a legitimate outcome.
- Slack-reaction closeout is not this routine's job — `magic-coordinator`'s `check-pending-comms-actions` procedure reacts later, reading the resolution text this routine writes onto the item. `source-slack-channel`/`source-slack-ts` still carry unchanged across any promotion/move.
- The three-member group disagreeing on an item's triage outcome: resolve through actual discussion, never let one member's view silently win by default. If genuinely unresolved, surface to the human-owner rather than pick arbitrarily — running unattended (`routine-heartbeat`'s first-iteration-of-the-day branch, no human-owner to surface to), leave the item exactly where it already is, no forced pick, and flag the open disagreement for the next grooming pass.
- An item unchanged since the last grooming pass still gets at least a glance, not deep re-litigation.
- A `blocked/` item with genuinely nothing left to try this pass: don't manufacture a token action to force "stays blocked" — that's what `parked/` is for.
- RICE scores and recorded dependency ordering disagreeing on priority: record both truthfully, never smooth one to match the other.
- Autonomous invocation (`routine-heartbeat`'s first-iteration-of-the-day branch): step 5's user review does not block — findings are recorded provisional, flagged for confirmation next time a human is present.
- Goal-directedness: when a goal is set for this session, actively work toward it; non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- `magic-coordinator` is obligated to keep `slack-event-track` activity tracking current as things are found, not batch it artificially, while acting as executor here.
- Each board move posts one short structured line as it happens, per `magic-team.armed.md`'s announce rule, plus one short structured summary closing the pass.
- `DistroAgentsTools.fn.sh` trust policy: trust it by default day to day, no defensive re-verification on every call; propose interface changes through the idea → interview → proposal → approval pipeline, never an inline bypass.
- Check established conventions (documented and used) before any implementation step; only if genuinely nothing covers it, propose an alternative and ask before proceeding.
- Escalation ladder for a missing tool option/syntax: (1) check documented conventions/`--help` first; (2) not there, consult `magic-librarian` rather than inventing a flag; (3) librarian can't resolve it either, propose a concrete change through the idea → interview → proposal → approval pipeline. Never skip a rung.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--help`
- `--magic-grooming-input-scan <team-member>`
- `--magic-grooming-to-backlog <team-member> <item-filename> --from-state:<state> --owner <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]`
- `--magic-grooming-to-pending` (same shape as `--magic-grooming-to-backlog`, target fixed to `board-pending`)
- `--magic-grooming-to-processed` (same shape as `--magic-grooming-to-backlog`, target fixed to `board-processed`)
- `--magic-grooming-to-parked` (same shape as `--magic-grooming-to-backlog`, target fixed to `board-parked`)
- `--magic-grooming-to-blocked` (same shape as `--magic-grooming-to-backlog`, target fixed to `board-blocked`)
- `--magic-grooming-to-running` (same shape as `--magic-grooming-to-backlog`, target fixed to `board-running`)
- `--magic-grooming-to-archived` (same shape as `--magic-grooming-to-backlog`, target fixed to `board-archived`)
- `--magic-grooming-to-retained` (same shape as `--magic-grooming-to-backlog`, target fixed to `board-retained`)
- `--magic-grooming-create-backlog` (creates a new board-item in `board-backlog`)
- `--magic-grooming-create-pending` (creates a new board-item in `board-pending`)
- `--magic-grooming-create-running` (creates a new board-item in `board-running`)
- `--magic-grooming-create-blocked` (creates a new board-item in `board-blocked`)
- `--magic-grooming-create-processed` (creates a new board-item in `board-processed`)
- `--member-slack-send-message <team-member> <target> [text...]`
- `--member-work-session-input-scan <team-member>`
- `--member-upsert-inbox-note <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]`

## `--help` operation reference

Prints this syntax + summary and exits.

## `--magic-grooming-input-scan` operation reference

`DistroAgentsTools.fn.sh --magic-grooming-input-scan <team-member>` — read-only: lists board items as `<state>/<item-filename>`, one per line, with every frontmatter field. Always scans backlog/pending/running/blocked/parked, `--all-types`. Use this to find an item's actual current state before calling `--magic-grooming-to-*`.

## `--magic-grooming-to-backlog` operation reference

`DistroAgentsTools.fn.sh --magic-grooming-to-backlog <team-member> <item-filename> --from-state:<state> --owner <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]` — moves a board item to `board-backlog` and/or patches its frontmatter, one call, no full-content rewrite required. `--from-state:<state>` and `--owner` are both required; `groomed-at`/`groomed-from`/`track` are always auto-stamped, never caller-supplied.

Every grooming-driven state move uses its own `--magic-grooming-to-*` operation: it does the content patch and the move in one call. It is never replaced by a raw `Edit`/`Write`/`Bash mv` on a board-item file.

## `--magic-grooming-to-pending` operation reference

Same shape as `--magic-grooming-to-backlog` operation, target fixed to `board-pending` — the Advancement-review case (backlog→pending, e.g. `--header:upsert:approved-by:"<team-member> (<session-id>, <date-time>)"` `--header:upsert:approved-at:<date>`). `approved-by`'s value is validated: must match `<team-member> (<session-id>, <date-time>)` with an ISO UTC date-time (suffix `Z`).

## `--magic-grooming-to-processed` operation reference

Same shape as `--magic-grooming-to-backlog` operation, target fixed to `board-processed`.

## `--magic-grooming-to-parked` operation reference

Same shape as `--magic-grooming-to-backlog` operation, target fixed to `board-parked` — the Defer/Becomes-parked case.

## `--magic-grooming-to-running` operation reference

`DistroAgentsTools.fn.sh --magic-grooming-to-running <team-member> <item-filename> --from-state:<state> --owner <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]` — moves a board item into `board-running` in one call, and/or patches its frontmatter. `--owner` is mandatory; `groomed-at`/`groomed-from`/`track` are always auto-stamped, never caller-supplied.

## `--magic-grooming-create-*` operation reference

`DistroAgentsTools.fn.sh --magic-grooming-create-<state> <team-member> <item-filename> --owner <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...` — writes a new board-item into `board-<state>`. A body-input mode is required. `--from-state:` is rejected: a created item has no source state, and a move uses `--magic-grooming-to-<state>` instead. `owner`, `groomed-at` and `track:true` are stamped; `groomed-from` is not. Everything else the creating step sets — `approved-by`/`approved-at`, `blocks`/`blocked-by`, `references`, `source-slack-channel`/`source-slack-ts` — rides `--header:*` on the same call.

## `--magic-grooming-to-retained` operation reference

`DistroAgentsTools.fn.sh --magic-grooming-to-retained <team-member> <item-filename> --from-state:<state> --owner <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]` — moves a board item into `board-retained` in one call, and/or patches its frontmatter. `--owner` is mandatory; `groomed-at`/`groomed-from`/`track` are always auto-stamped, never caller-supplied. Called with `--from-state:retained` it is a same-state field update, which is how `recheck-and-exit` renews a `recheck-date`.

## `--magic-grooming-to-archived` operation reference

`DistroAgentsTools.fn.sh --magic-grooming-to-archived <team-member> <item-filename> --from-state:<state> --owner <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]` — moves a board item into `board-archived` in one call, and/or patches its frontmatter. `--owner` is mandatory; `groomed-at`/`groomed-from`/`track` are always auto-stamped, never caller-supplied.

## `--magic-grooming-to-blocked` operation reference

`DistroAgentsTools.fn.sh --magic-grooming-to-blocked <team-member> <item-filename> --from-state:<state> --owner <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]` — moves a board item into `board-blocked` in one call, and/or patches its frontmatter. `--owner` is mandatory. Auto-stamps `groomed-at`, `groomed-from` and `track:true` — full grooming policy, same as its `--magic-grooming-to-*` siblings and unlike the `--magic-advance-*`/`--magic-board-*` families, which stamp nothing.

## `--member-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

## `--member-work-session-input-scan` operation reference

Read-only: one member's own current work-session input — personal, not routine-dictated (every armed member runs this against its own name as it becomes armed, regardless of which routine triggered the arming). Fixed `--owner <member>` and `--all-types`.

## `--member-upsert-inbox-note` operation reference

`DistroAgentsTools.fn.sh --member-upsert-inbox-note <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]` — writes (creates or overwrites) a note into any member's own personal inbox; content via stdin. `<member>` must already exist as a real skill directory, `<item-filename>` must be a bare filename.

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- `routine-grooming` exists to give the three-actor authority group a regular, joint checkpoint for reprioritizing the backlog together — so priority decisions don't silently drift to whichever member happens to be looking at the board.
- A provisional reprioritization recorded without a live human present stays provisional until actually confirmed — silence is never treated as approval.
- A backlog only ever added to, never re-assessed, accumulates stale/mis-owned/mis-sequenced items a daily roll-call alone never catches.
- A `blocked/` item stays blocked only if something was actually tried this review, never a silent re-stamp.

## Verbatim-tests (benchmarks)

- A grooming session that finds nothing to reprioritize still reports "nothing new this session" to `slack-magic-team`, rather than skipping the report.
- A `blocked/` item with no real attempt made this pass moves to `parked/`.

## Librarian Comments

### Reference

- `routine-daily` — reports what's outstanding; grooming asks whether the backlog is still the right shape.
- `routine-coworking` — the template this routine extends; its Steps are the opening this routine executes.
- `routine-coworking` — its Closure Steps are the closing this routine executes.
- `routine-process-inbox` — own-inbox processing (step 1), and the personal-inbox model fresh items are triaged against.
- `magic-coordinator`'s `check-pending-comms-actions` procedure — the resolver of the Slack-reaction closeout. Not this routine's job.
- `routine-heartbeat` — can trigger this routine as its first-iteration-of-the-day branch (step 5's user review becomes non-blocking/provisional in that mode).
- `routine-communication-sweep` — feeds this routine's backlog (inbox items); this routine runs the heavier Google Drive/Sheets and Trello-coverage checks that sweep deliberately excludes.
- `magic-team/magic-team.board.md` — full board-state model (`running/`/`blocked/`/`parked/`/`processed/`/`archived/`/`cleanup/`), the `processed/`/`archived/` Slack-reaction cross-cutting entry, `board-backlog` entry, "at least three paths" note, qualifying-reference definition.
- `magic-coordinator/magic-coordinator.armed.md`'s "Dispatch & delegation" section (a subsection of its `# Domain knowledge`) — the fast permission/mandate gate rules (destructive-action mandate boundaries, the human-owner sole-channel rule, cross-domain task boundaries) checked at task-creation.
- `magic-coordinator/RICE-SCORING.md` — the four normalized dimensions (Profit/Cost/Time/Dependencies) used in step 3.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — Keep-Alive Workspace Console Session mechanics, calling convention, sole-sanctioned Slack-posting mechanism.
- `magic-team/magic-team.armed.md` — `board-item` entity model, `source-slack-channel`/`source-slack-ts` frontmatter convention, field list (`supersedes`/`superseded-by`).
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.

### Conventions

- `magic-coordinator` is this routine's sole executor; `magic-librarian`/`magic-architect` join as invitees. The three-person group jointly makes every judgment call the Steps/Local rules describe — that's what "run by all three, jointly" means — but `magic-coordinator` alone is who actually executes each step. Don't blur this into "all three are co-executors."
- Slack-reaction closeout is deliberately not this routine's job — `magic-coordinator`'s `check-pending-comms-actions` procedure owns it instead. Preserve this split precisely; don't let a future synthesis fold reaction handling back into this routine.
- The four `blocked/` re-check outcomes, the `parked/` re-check, the task-creation lifecycle, and how that composes with the fast-gate rules in `magic-coordinator/magic-coordinator.armed.md`'s "Dispatch & delegation" section are all dense and specific — preserve precisely, don't compress into a generic "triage backlog items" summary.
