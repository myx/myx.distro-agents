---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# routine-communication-sweep — the actual procedure

# Summary

Routine-communication-sweep is a fast, reliable check-and-act pass across every live communication platform (email, Trello, Slack), run every `routine-heartbeat` iteration.

## Goals

Give the team a real, reliable way to notice and act on incoming communication across every live platform (email, Trello, Slack) without either missing things (an unattended DM sitting unanswered for days) or manufacturing unnecessary work (chasing platforms that aren't actually live, or investigating every message as if it needed deep triage). The routine's whole shape — fast/parallel by default, deliberate/sequential only when something looks wrong — exists to make "check comms" cheap and reliable enough to run constantly (every `routine-heartbeat` iteration) without becoming its own burden.

## Scope

Does: fast/parallel-by-default check-and-act, one full sweep = one pass through all 6 steps for every live platform. Invoked from `routine-daily` (both start and end), `routine-heartbeat` every iteration, or standalone on direct request any time.
- Live-platform set is tracked knowledge, not rediscovered at sweep time: **email**, **Trello**, **Slack** (Jira/Confluence known-not-live). Update only on human-reported status change, or a check-call error pointing at a credential/availability problem.
- Credential path: `$MMDAPP/.local/.agents/magic-coordinator.agent.env` — source it (`set -a; . <path>; set +a`) for `EMAIL_*`/`TRELLO_*`/`SLACK_BOT_TOKEN`/`GOOGLE_*`. Never print its contents into a transcript/chat/log.
- Credential file not found at that exact path: stop and ask the user immediately — no filesystem search, no fallback connector, no solo puzzle-solving past one failed round.
- Open-thread set for Slack thread-reply checks: whichever `board-item`s are currently open and track a live Slack thread via `source-slack-channel`/`source-slack-ts` — read fresh each sweep, no separate registry.

Doesn't do: Google (Drive/Sheets) — extended procedure, only when the task is actually searching/grooming, not a default step-1 call.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

0. **process-own-inbox**: run `routine-process-inbox` on `magic-coordinator`'s own inbox — this routine's own executor.
1. **check**: read the `sweep-state-note` via `--magic-sweep-state-read`. Call `--magic-sweep-input-scan`, then `--sweep-read-incoming-comms --oldest <last_swept_ts>`. Call `--check-slack` for both watched targets and every open thread (see Scope).
   - default: batch every platform's credential read + API call into one script/command block, piped through `lib/execShStdin`.
   - exception: a check call errors or returns something ambiguous → go deliberate.
   - a newly-joined/missing Slack conversation surfaced by `--check-slack`'s discovery diff is an **analyze** candidate, not acted on here.
2. **read**: pull the actual content of what's new.
3. **analyze**: cross-reference **check**/**read** against current state (`TodoWrite`, the board) and identify: anything unblocked and ready to dispatch, anything a keeper-*/partner-* idle pass would pick up, new-knowledge candidates for `magic-librarian`, what needs a reply and what it should say. Empty result is normal, not a failure.
   - Slack: apply the `slack-reaction-tracking` procedure's Analyze-stage reaction.
4. **act**: route each candidate by size.
   - Approved, simple, obvious → do it inline, now, standard dispatch mechanism only.
   - Bigger/questionable, needs whole-team visibility → note for the next `routine-daily`.
   - Bigger/questionable, concerns specific member(s) only → propose a `routine-one-on-one` session.
   - Worth recording, no investigation needed now → into the backlog `routine-grooming` already triages.
   - Never start a new epic/initiative unilaterally inline.
   - Normalize every genuinely new incoming item into an Item (`note-*.md`/`inquiry-*.md`, per the team's own entity model): write it into `magic-coordinator`'s own inbox by default, or directly into the relevant member's own inbox via `--member-upsert-inbox-note` if clearly addressed to someone specific — filename shape mandatory, `note-<date>-<matter>.md` / `inquiry-<date>-<matter>.md`. Solo `magic-coordinator` work; no deep classification/enqueue-todo/triage here — that's `routine-grooming`'s job later.
   - Slack: apply the `slack-reaction-tracking` procedure's Act-stage reaction.
5. **reply-if-warranted**: respect each platform's own send/confirm rules.
   - minimum floor: acknowledge every non-ignored incoming message.
   - Slack, mandatory: target the reply at `<channel>:<ts>` of the specific message, never a bare `<channel>`.
   - Email: get human confirmation before sending, when a human is actually present in the session; running unattended (`routine-heartbeat`), send directly, no confirmation gate — the rest of this step's send/reply discipline still applies in full.
   - Slack/Trello comments in the coordinator's own channels: lead dialog directly, still pause before anything reading as a commitment/decision on the user's behalf.
   - always send under the coordinator's own identity — never impersonate.
   - send questions standalone, never bundled inside a longer status update.
   - no message bundles multiple distinct topics — unit is topic count, not send-call count.
   - mark read once handled, every platform (see Tooling for the per-platform mechanics).
   - Slack, additionally: apply the `slack-reaction-tracking` procedure's Reply-stage and terminal reactions.
   - `--format blocks` is a hard rule, no exceptions — never plain-text; every array element in a hand-built `blocks` payload needs its own block-level `"type"` wrapper.
6. **update-context**: fold platform mechanical-state findings (`last_swept_ts` frontmatter field, `known_comms_gaps` body list) into the `sweep-state-note` via `--magic-sweep-state-upsert` — `--edit-patch-from-stdin` for a single-field update, full-content write only for a genuine whole-record rewrite — invoked through `lib/execShStdin` only. Fold identity/routing data into the `roster-note` via `--member-upsert-inbox-note`.
   - Update the own-status Trello card: a standing checklist of what `magic-coordinator` is currently doing and what it needs from the human team, legible to someone who wasn't in the conversation — surface anything blocked on the human team here.
   - Keep `slack-magic-team` current as a standing narrative broadcast: post a milestone as it happens, in plain external-facing language; post a blocker the moment it's identified. No internal dispatch mechanics, agent IDs, or RICE scores. Post as threaded replies within the session's own root message, as small separate messages as things happen — not accumulated into end-of-session summaries. Does not replace direct in-conversation reporting to the user.
   - Post completion status to `slack-event-track`.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines - not visible outside this file.

## `slack-reaction-tracking` procedure

Slack-only — email/Trello have no reaction primitive. Real, load-bearing async-visibility channel, not cosmetic. Every Slack message this routine handles gets a running, stacking set of reactions as it progresses.

**Stage mapping** (grounded in Steps above, never fired eagerly at first contact):
- `:eyes:` — **analyze**, once understood/classified.
- `:writing_hand:` — **act**, conditional: only when genuinely blocked on/tied to an ongoing interview-like process. Genuinely unsure whether it applies: default to skipping the reaction.
- `:ok_hand:` — **reply-if-warranted**, same moment as "mark it read."
- `:white_check_mark:` — terminal, not automatic at sweep time, see split below.

**Additive by default, not an absolute never-remove rule.** Recognized exceptions where a reaction gets removed/replaced:
- underlying request/candidate refused/declined outright
- a request (not the human-owner's own) now blocked pending his approval
- human-owner asks to restart/stop/park the underlying work
- any agent's assumption the human-owner said was wrong/refused → react `:x:`/❌ on the traced-back message, replacing whatever was there

**Terminal-stage split:**
- **Same-sweep resolution**: add `:white_check_mark:` right away, alongside `:ok_hand:`, in **reply-if-warranted**.
- **Deferred resolution** — message became/already was the source of a tracked board Item staying open past this sweep: do not add the terminal reaction now, leave at `:eyes:`/`:writing_hand:`/`:ok_hand:`. File a lightweight pending-reaction record (into `magic-coordinator`'s inbox, or directly into `board-running`) carrying `source-slack-channel`/`source-slack-ts` + a `references` pointer. `routine-advance`'s own pending-reaction-lookup step adds the terminal reaction later.
- **Negative outcome, at that later point**: assessed per case, not one hardcoded emoji — `:x:`/❌ a sensible floor, `:-1:`/thumbsdown where it reads better.

**Origin-ts lifecycle**: a Slack message normalized into an Item may move inbox-file → formal board Item → `blocked/`/`parked/` → `processed/`/`archived/`. The reaction target never changes; whichever step promotes an inbox item into a formal board Item copies `source-slack-channel`/`source-slack-ts` across unchanged.

**Boundary**: only applies where a real Slack message exists — an Item created directly as a file has no `source-slack-channel`/`source-slack-ts` and no reaction step anywhere in its lifecycle.

**Out of scope**: a one-time backfill of `:eyes:` reactions onto already-handled-but-unreacted historical messages — this mechanism only applies to messages read from here forward.

**Mechanics**: the `--react-slack` operation, same bot-identity discipline as every other Slack action here. Already-present reaction is a harmless no-op.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- `magic-coordinator` (this routine's sole executor) is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- What myx (Alex Kharichev) asks carries direct authority: when he asks for something across any platform, that instruction is the priority — don't silently reinterpret, narrow its scope, or substitute a smaller action than what was actually asked for.
- Read each message in the context of its own thread, not in isolation: a short reply ("post", "confirm", "recheck") means whatever it means *given everything already said in that specific back-and-forth*.
- A session/activity's own progress reporting to `slack-magic-team` goes as threaded replies under one root message for that session — start one root when the session begins (or reuse an existing live one), reply within that thread as things happen, never repeated new root posts.
- An **act** candidate borderline between "approved, simple, obvious" and "bigger, questionable": default to the more conservative bucket.
- A message's intent is genuinely unclear: ask, don't guess and proceed — especially on Slack and in comments where tone/brevity make intent easy to misread. This is about being genuinely clear on content and intent before acting, not about adding friction to every message: an unambiguous, already-scoped ask still doesn't need a fresh round of confirmation each time.
- Goal-directedness: when a goal is set for this session, actively work to move the process toward that goal. Non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- `magic-coordinator` (this routine's sole executor) is obligated to keep `slack-event-track` activity tracking current as the sweep runs — sweep step-progress/status always targets `event-track` (debug-only); milestones, blockers, and escalations always target `magic-team`.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-sweep-input-scan <team-member>` (step 1: load sweep board-scan context)
- `--sweep-read-incoming-comms [--oldest <ts>] [--raw]` (step 1: Check, primary macro-op)
- `--check-email` (step 1: Check, Email)
- `--check-trello` (step 1: Check, Trello)
- `--check-slack <target> [--oldest <ts>] [--raw]` (step 1: Check, Slack — both watched targets, plus mandatory thread-reply checks)
- `--member-slack-send-message <team-member> <target> [text...]` (step 5: Reply)
- `--member-upsert-inbox-note <member> <item-filename>` (step 4: normalize a new incoming item into an inbox record)
- `--send-email-message <email@address>... -- <subject> -- <body...>` (step 5: Reply, email)
- `--mark-email-seen <uid>` (step 5: mark-read, email)
- `--react-slack <channel>:<ts> <emoji-name>` (`slack-reaction-tracking` procedure, throughout)
- `--magic-sweep-state-read <team-member>` (step 1: read the `sweep-state-note`)
- `--magic-sweep-state-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]` (step 6: rewrite the `sweep-state-note`)

## `--magic-sweep-input-scan` operation reference

`DistroAgentsTools.fn.sh --magic-sweep-input-scan <team-member>` — loads this routine's own board-thread context ahead of the **check** step.

## `--sweep-read-incoming-comms` operation reference

`DistroAgentsTools.fn.sh --sweep-read-incoming-comms [--oldest <ts>] [--raw]` — not a general-purpose Slack reader, takes no target at all. The dedicated macro-operation for this routine's own **check** step: reads the exact predefined watched-source set (both Slack targets via `--check-slack`, plus `--check-email` and `--check-trello`) in one combined pass. For one specific arbitrary Slack target/thread, call `--check-slack` directly instead.

## `--check-email` operation reference

`DistroAgentsTools.fn.sh --check-email` — IMAP STATUS INBOX (UNSEEN) check only, unread count, not a full fetch.

## `--check-trello` operation reference

`DistroAgentsTools.fn.sh --check-trello` — unread Trello notifications only (`read_filter=unread`), not a full board read.

## `--check-slack` operation reference

`DistroAgentsTools.fn.sh --check-slack <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [--oldest <ts>] [--raw]` — reads Slack activity for one specific, caller-chosen target. `magic-team`/`human-owner`/`event-track`/`event-alert` reads that watched target's `conversations.history`; `<channel>:<ts>` fetches `conversations.replies` for that specific thread. `--oldest <ts>` passes through as the incremental marker. No retry logic — one attempt, fails clean. Output is pretty-formatted by default; `--raw` opts into the full API response (needed for fields like `reply_count`/`thread_ts`).

## `--member-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>`.

## `--member-upsert-inbox-note` operation reference

`DistroAgentsTools.fn.sh --member-upsert-inbox-note <member> <item-filename> [--from-file <path>]` — writes (creates or overwrites) a note into `<member>`'s own inbox. Content via stdin by default, or `--from-file <path>`.

## `--send-email-message` operation reference

`DistroAgentsTools.fn.sh --send-email-message <email@address>... -- <subject> -- <body...>` (or `-- --from-stdin` / `-- --file <path>` in place of the trailing body) — real standalone SMTP send via curl. Multiple recipients accepted before the first `--`; subject is everything between the two `--` separators; everything after the second becomes the body. Exactly one body source required — giving more than one of trailing-body-argv/`--from-stdin`/`--file` together is an error.

## `--mark-email-seen` operation reference

`DistroAgentsTools.fn.sh --mark-email-seen <uid>` — marks one email (by IMAP UID) as `\Seen` via IMAP UID STORE — otherwise every sweep re-sees the same UIDs as unseen.

## `--react-slack` operation reference

`DistroAgentsTools.fn.sh --react-slack <channel>:<ts> <emoji-name>` — posts one Slack reaction (`reactions.add`) to a specific message. `<channel>:<ts>` only, no `magic-team`/`human-owner` shortcut. `<emoji-name>` has no colons (e.g. `white_check_mark`, not `:white_check_mark:`). An `already_reacted` error is treated as a harmless no-op, not a failure.

## `--magic-heartbeat-state-read` operation reference

`DistroAgentsTools.fn.sh --magic-heartbeat-state-read <team-member>` — read-only: prints the whole `heartbeat-state-note` on stdout, verbatim, this routine's source for `last_swept_ts` ahead of the **check** step. Prints `NO_STATE` and returns 0 when nothing is stored yet — a normal first-run outcome, not an error. `<team-member>` is the only argument.

## `--magic-heartbeat-state-upsert` operation reference

`DistroAgentsTools.fn.sh --magic-heartbeat-state-upsert <team-member> [--from-file <path>]` — writes (creates or overwrites) the `heartbeat-state-note`. Content comes via stdin by default, or via `--from-file <path>` (never a bare `--file`). Every call replaces the whole record and never appends, so the **update-context** step folds its own fields into the full current record rather than writing them alone. Empty content is refused rather than written. Takes no filename or path argument — storage is the operation's own concern.

# Maintainer Notes

Used to check this files own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives the team a reliable way to notice and act on incoming communication without missing things or manufacturing unnecessary work — cheap enough to run every main-loop iteration without becoming its own burden.

## Verbatim-tests (benchmarks)

- A new reply posted inside an existing Slack thread gets caught via the `conversations.replies` check — `conversations.history` alone never surfaces it.

## Librarian Comments

### Reference

- `routine-daily` — calls this routine at both start and end.
- `routine-heartbeat` — calls this every iteration as its "Comms" step.
- `routine-grooming` — deep classification/triage, Google Drive/Sheets, board-coverage diffing.
- `routine-advance` — its own pending-reaction-lookup step reacts on deferred-terminal messages later.
- `routine-process-inbox` — this routine's own inbox processing.
- `routine-one-on-one` — small-group proposal destination for member-specific findings.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — Keep-Alive Workspace Console Session mechanics, mandatory batching.
- `magic-team/SKILL.md` — Item entity model, `source-slack-channel`/`source-slack-ts` frontmatter convention.
- `magic-team/magic-team.board.md` — `processed/`/`archived/` outcome-ambiguity note.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.

### Conventions

- The Slack per-message reaction-tracking design (stage mapping, additive-vs-swap exceptions, the same-sweep-vs-deferred terminal split) is dense and load-bearing — preserve it precisely when editing, don't summarize it away.