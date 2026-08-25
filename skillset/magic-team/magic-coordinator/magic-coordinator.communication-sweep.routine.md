---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-coordinator.communication-sweep.routine — the actual procedure

# Summary

Routine-communication-sweep is a fast, reliable check-and-act pass across every live communication platform (email, Trello, Slack), run every `magic-coordinator.heartbeat.routine` iteration.

## Goals

Give the team a real, reliable way to notice and act on incoming communication across every live platform (email, Trello, Slack) without either missing things (an unattended DM sitting unanswered for days) or manufacturing unnecessary work (chasing platforms that aren't actually live, or investigating every message as if it needed deep triage). The routine's whole shape — fast/parallel by default, deliberate/sequential only when something looks wrong — exists to make "check comms" cheap and reliable enough to run constantly (every `magic-coordinator.heartbeat.routine` iteration) without becoming its own burden.

## Scope

Does: fast/parallel-by-default check-and-act, one full sweep = one pass through all 6 steps for every live platform. Invoked from `magic-coordinator.daily.routine` (both start and end), `magic-coordinator.heartbeat.routine` every iteration, or standalone on direct request any time.
- Live-platform set is tracked knowledge, not rediscovered at sweep time: **email**, **Trello**, **Slack** (Jira/Confluence known-not-live). Update only on human-reported status change, or a check-call error pointing at a credential/availability problem.
- Credentials for every live platform are made available before check calls run, resolved by `magic-tooling` itself. Never print them into a transcript/chat/log.
- Credentials unavailable: stop and ask the user immediately — no filesystem search, no fallback connector, no solo puzzle-solving past one failed round.
- Open-thread set for Slack thread-reply checks: whichever `board-item`s are currently open and track a live Slack thread — `communication-channel-id` in the three-part `slack:<channel>:<ts>` shape; a bare `slack:<channel>` tracks no thread — read fresh each sweep, no separate registry.

Doesn't do: Google (Drive/Sheets) — extended procedure, only when the task is actually searching/grooming, not a default **check** call.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

1. **process-own-inbox**: run `magic-team.process-inbox.routine magic-coordinator` — items a previous sweep routed there and left unacted, read before this pass adds more.
2. **check**: read the sweep-state-note via --magic-sweep-state-read. Call --magic-sweep-input-scan <team-member> --comms-since-utime <last_swept_ts> — board-tracked threads and every watched source, one pass, covering both watched targets and every open thread (see Scope).
   - default: batch every platform's credential read + API call into one script/command block, piped through `mcp__myx_distro__execute`.
   - exception: a check call errors or returns something ambiguous → go deliberate.
   - a thread the coordinator's own identity participated in — started, was replied to, or was tagged in — is followed regardless of freshness; this widening degrades gracefully to the plain freshness check alone when the coordinator's identity can't be resolved this pass.
   - incoming messages are located by enumerating **the messages' own** timestamps — every participant's in the conversation, not one identity's — and diffing them against what was already handled; never by "what came after my own last post". Own posts move such a watermark forward, so any participant's message in a thread already replied to falls below the line and stops being findable at all; the misses concentrate exactly in the threads that look most attended. Two passes, both required every sweep: top-level, then each open thread via `--member-comms-slack-read <team-member> <channel>:<parent> --thread`, whose whole-thread result is enumerated the same way over every message in it that is not the acting member's own — a top-level-only enumeration silently drops thread replies (see this file's own Verbatim-tests).
   - the result of this step is one combined, deduplicated set of new messages across every platform/source, sorted **ascending by the message's own timestamp** — this ordering is what step 3 below iterates over.
3. **process-each-message**: for every message in **check**'s own ascending-time-ordered set, in that order, one message at a time — not as five separate batch passes over the whole set. Each message runs this full local sequence before moving to the next:
   1. **read**: pull this message's actual content. A message that quotes a block is read in full, never from the preview: the instruction usually sits *after* the quoted text and is exactly what a truncated read loses.
   2. **analyze**: cross-reference against current state (`TodoWrite`, the board) and identify what this one message needs: anything unblocked and ready to dispatch, anything a keeper-*/partner-* idle pass would pick up, a new-knowledge candidate for `magic-librarian`, whether it needs a reply and what it should say. Empty result (nothing needed) is normal, not a failure.
      - whether a message was handled is judged from what its own text asked for and whether that thing was actually done — the existence of a later reply of the coordinator's own is not evidence of it.
      - Slack: apply the `slack-reaction-tracking` procedure's Analyze-stage reaction (`:eyes:`) on **this message**, now — this is the visible marker that this specific message was actually seen; it happens as this message is processed, never deferred to a later batch step.
   3. **act**: route this message's candidate(s) by size.
      - Approved, simple, obvious → do it inline, now, standard dispatch mechanism only.
      - Bigger/questionable, needs whole-team visibility → note for the next `magic-coordinator.daily.routine`.
      - Bigger/questionable, concerns specific member(s) only → propose a `magic-coordinator.one-on-one.routine` session.
      - Worth recording, no investigation needed now → into the backlog `magic-team.grooming.routine` already triages.
      - Never start a new epic/initiative unilaterally inline.
      - Normalize a genuinely new incoming item into an Item (`note-*.md`/`inquiry-*.md`, per the team's own entity model): write it into `magic-coordinator`'s own inbox by default, or directly into the relevant member's own inbox via `--member-upsert-inbox-note` if clearly addressed to someone specific — filename shape mandatory, `note-<date>-<matter>.md` / `inquiry-<date>-<matter>.md`. Solo `magic-coordinator` work; no deep classification/enqueue-todo/triage here — that's `magic-team.grooming.routine`'s job later.
      - Slack: apply the `slack-reaction-tracking` procedure's Act-stage reaction on **this message**, now.
   4. **reply-if-warranted**: respect each platform's own send/confirm rules, for this message specifically.
      - minimum floor: acknowledge every non-ignored incoming message.
      - Slack, mandatory: target the reply at `<channel>:<ts>` of this specific message, never a bare `<channel>`.
      - Email: get human confirmation before sending, when a human is actually present in the session; running unattended (`magic-coordinator.heartbeat.routine`), send directly, no confirmation gate — the rest of this step's send/reply discipline still applies in full.
      - Slack/Trello comments in the coordinator's own channels: lead dialog directly, still pause before anything reading as a commitment/decision on the user's behalf.
      - always send under the coordinator's own identity — never impersonate.
      - genuinely requires the addressee's reaction/reply before anything proceeds → explicitly `@`-mention them, per `magic-team.conversations.md` rule 4c — posting where they might see it is not enough.
      - send questions standalone, never bundled inside a longer status update.
      - no message bundles multiple distinct topics — unit is topic count, not send-call count: one root message naming the overall topic, then each distinct point as its own separate threaded reply under it, per `magic-team.conversations.md` rule 1/1a — never one long message covering several points, never several unthreaded top-level posts on the same topic.
      - mark read once handled, every platform (see Tooling for the per-platform mechanics).
      - Slack, additionally: apply the `slack-reaction-tracking` procedure's Reply-stage and terminal reactions on **this message**, now.
      - `--format blocks` is a hard rule, no exceptions — never plain-text; every array element in a hand-built `blocks` payload needs its own block-level `"type"` wrapper.
   5. **advance-watermark**: only now, after this message's full local sequence above is done, does this message count as swept — record its own timestamp as this pass's running high-water mark (used by **update-context** below). Move to the next message in the ordered set.
# Closure steps

1. **update-context**: fold platform mechanical-state findings into the `sweep-state-note` via `--magic-sweep-state-upsert` — `--edit-patch-from-stdin` for a single-field update, full-content write only for a genuine whole-record rewrite — invoked through `mcp__myx_distro__execute` only. Fold identity/routing data into the `roster-note` via `--member-upsert-inbox-note`.
   - **`last_swept_ts`, precisely**: **process-each-message**'s own running high-water mark — the timestamp of the last message that actually completed its full read→analyze→act→reply-if-warranted→react sequence this pass. Never wall-clock time at whatever moment this Closure step happens to run — this step runs after every message's own processing, which can take minutes, and writing "now" here silently advances the cutoff past any message that arrived during that processing window, permanently skipping it on every later pass (confirmed real-world failure: a human-owner reply arrived after the last message's own processing finished but before this write, and no later pass ever surfaced it). If **check** found zero messages this pass, `last_swept_ts` is left unchanged from its prior stored value, never bumped to now.
   - A message's own `:eyes:` reaction (or lack of one) is the visible, auditable record of whether that specific message was ever actually processed — deliberately redundant with `last_swept_ts`, so a human can verify sweep coverage by looking at real Slack reactions, not just trusting the stored state note.
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
- **Deferred resolution** — message became/already was the source of a tracked board Item staying open past this sweep: do not add the terminal reaction now, leave at `:eyes:`/`:writing_hand:`/`:ok_hand:`. File a lightweight pending-reaction record (into `magic-coordinator`'s inbox, or directly into `board-running`) carrying the `communication-channel-id` + a `references` pointer. `magic-coordinator.advance.routine`'s own pending-reaction-lookup step adds the terminal reaction later.
- **Negative outcome, at that later point**: assessed per case, not one hardcoded emoji — `:x:`/❌ a sensible floor, `:-1:`/thumbsdown where it reads better.

**Origin-ts lifecycle**: a Slack message normalized into an Item may move inbox-file → formal board Item → `blocked/`/`parked/` → `processed/`/`archived/`. The reaction target never changes; whichever step promotes an inbox item into a formal board Item copies `communication-channel-id` across unchanged.

**Boundary**: only applies where a real Slack message exists — an Item created directly as a file carries no `communication-channel-id` at all, and has no reaction step anywhere in its lifecycle.

**Out of scope**: a one-time backfill of `:eyes:` reactions onto already-handled-but-unreacted historical messages — this mechanism only applies to messages read from here forward.

**Mechanics**: the `--member-comms-slack-react` operation, same bot-identity discipline as every other Slack action here. Already-present reaction is a harmless no-op.

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
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-sweep-input-scan <team-member> [--comms-since-utime <v>|--comms-since-date-time <v>]` (**check**: primary op — board-tracked threads plus every watched source)
- `--member-comms-email-check <team-member>` (**check**: Email)
- `--member-comms-trello-check <team-member>` (**check**: Trello)
- `--member-comms-slack-send-message <team-member> <target> [text...]` (**reply-if-warranted**)
- `--member-upsert-inbox-note <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]` (**act**: normalize a new incoming item into an inbox record)
- `--member-comms-email-send <team-member> <email@address>... -- <subject> -- <body...>` (**reply-if-warranted**: email)
- `--member-comms-email-mark-seen <team-member> <uid>` (**reply-if-warranted**: mark-read, email)
- `--member-comms-slack-react <team-member> <channel>:<ts> <emoji-name> [--identity-bot]` (`slack-reaction-tracking` procedure, throughout)
- `--member-comms-slack-read <team-member> <channel>:<ts> [--thread] [--identity-bot]` (**check**: read one arbitrary target/thread the scan does not cover)
- `--magic-sweep-state-read <team-member>` (**check**: read the `sweep-state-note`)
- `--magic-sweep-state-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]` (**update-context**)

## `--magic-sweep-input-scan` operation reference

`DistroAgentsTools.fn.sh --magic-sweep-input-scan <team-member> [--comms-since-utime <v>|--comms-since-date-time <v>]` — this routine's own **check** step in one pass: the board-tracked threads this routine already follows, plus every watched source across every live platform. The cut-off is optional and the two spellings are mutually exclusive, neither repeatable — one cut-off, one spelling. `--comms-since-utime` takes epoch seconds, with or without a fractional part. This is not a platform-wide search: a conversation outside the already-watched sources, or an identity mention that falls outside them, stays undiscoverable here — true "tagged anywhere" coverage is a separate, not-yet-built capability. A single arbitrary target/thread outside the watched set is not covered by this scan — read it directly with `--member-comms-slack-read <team-member> <channel>:<ts>` when its id is known.

## `--member-comms-email-check` operation reference

`DistroAgentsTools.fn.sh --member-comms-email-check <team-member>` — IMAP STATUS INBOX (UNSEEN) check only, unread count, not a full fetch. `<team-member>` comes first and is required: the count is that member's own mailbox, strictly — never another member's, and never a fallback to one. This routine passes `magic-coordinator`, its sole executor.

## `--member-comms-trello-check` operation reference

`DistroAgentsTools.fn.sh --member-comms-trello-check <team-member>` — unread Trello notifications only (`read_filter=unread`), not a full board read. `<team-member>` comes first and is required: the unread list is that member's own notifications, strictly — never another member's, and never a fallback to one. This routine passes `magic-coordinator`, its sole executor.

## `--member-comms-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>`. Identity (native user token vs. team bot token) is resolved internally — the caller never specifies it: auto-detected from `<team-member>`/`--identity-bot`/configured token as before, and if a send fails with `channel_not_found` under the auto-detected identity, the op retries once under the other identity on its own before giving up.

## `--member-upsert-inbox-note` operation reference

`DistroAgentsTools.fn.sh --member-upsert-inbox-note <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]` — writes (creates or overwrites) a note into `<member>`'s own inbox. Content via stdin by default, or `--from-file <path>`.

## `--member-comms-email-send` operation reference

`DistroAgentsTools.fn.sh --member-comms-email-send <team-member> <email@address>... -- <subject> -- <body...>` (or `-- --from-stdin` / `-- --from-file <path>` in place of the trailing body) — real standalone SMTP send via curl. `<team-member>` comes first and is required: it is the acting identity, and the credentials the send authenticates with are that member's own, strictly — never another member's, and never a fallback to one. This routine passes `magic-coordinator`, its sole executor, the same member its check step used. Multiple recipients accepted before the first `--`; subject is everything between the two `--` separators; everything after the second becomes the body. Exactly one body source required — giving more than one of trailing-body-argv/`--from-stdin`/`--from-file` together is an error.

## `--member-comms-email-mark-seen` operation reference

`DistroAgentsTools.fn.sh --member-comms-email-mark-seen <team-member> <uid>` — marks one email (by IMAP UID) as `\Seen` via IMAP UID STORE — otherwise every sweep re-sees the same UIDs as unseen. `<team-member>` comes first and is required: the mailbox written to is that member's own, strictly, and a UID only means anything inside one mailbox — the same `<uid>` under a different member names a different message, or none. This routine passes `magic-coordinator`, its sole executor, the same member its check step used.

## `--member-comms-slack-react` operation reference

`DistroAgentsTools.fn.sh --member-comms-slack-react <team-member> <channel>:<ts> <emoji-name> [--identity-bot]` — posts one Slack reaction (`reactions.add`) to a specific message. `<channel>:<ts>` only, no `magic-team`/`human-owner` shortcut. `<emoji-name>` has no colons (e.g. `white_check_mark`, not `:white_check_mark:`). An `already_reacted` error is treated as a harmless no-op, not a failure. `<team-member>` is the acting identity — the reaction is posted BY that member, under its own identity when it has one and the team bot when it does not; `--identity-bot` reacts as the team bot instead.

## `--member-comms-slack-read` operation reference

`DistroAgentsTools.fn.sh --member-comms-slack-read <team-member> <channel>:<ts> [--thread] [--identity-bot]` — reads one specific message in full, or the whole thread it belongs to with `--thread`. `<channel>:<ts>` only: unlike the scan ops it takes no `magic-team`/`human-owner` shortcut, since it retrieves one exact message and that needs its own `<ts>`. `<team-member>` is the acting identity, and it decides WHICH conversation is read at all — a direct conversation belongs to one identity pair, so the member's own identity and the team bot hold two different DMs with the same person. Its own identity when it has one, the team bot when it does not; `--identity-bot` reads the bot's conversation instead. A call that could not see the message asked for fails loud — an empty result is never reported as an outcome, so "nothing there" can never be concluded from a failed read.

## `--magic-sweep-state-read` operation reference

`DistroAgentsTools.fn.sh --magic-sweep-state-read <team-member>` — read-only: prints the whole `sweep-state-note` on stdout, verbatim, this routine's source for `last_swept_ts` ahead of the **check** step. Prints `NO_STATE` and returns 0 when nothing is stored yet — a normal first-run outcome, not an error. `<team-member>` is the only argument.

## `--magic-sweep-state-upsert` operation reference

`DistroAgentsTools.fn.sh --magic-sweep-state-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]` — writes (creates or overwrites) the `sweep-state-note`. Content via stdin by default; `--from-file <path>` for a full-content write, `--edit-patch-from-stdin` for a single-field update — per **update-context**, the patch form is used for a single-field update, full-content write only for a genuine whole-record rewrite. Empty content is refused rather than written. Takes no filename or path argument — storage is the operation's own concern.

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives the team a reliable way to notice and act on incoming communication without missing things or manufacturing unnecessary work — cheap enough to run every main-loop iteration without becoming its own burden.

## Verbatim-tests (benchmarks)

- A new reply posted inside an existing Slack thread gets caught via the `conversations.replies` check — `conversations.history` alone never surfaces it.
- A message from any conversation participant that is older than the coordinator's own last post in the same thread is still surfaced, and still assessed as unhandled until its own ask is done.

## Librarian Comments

### Reference

- `magic-coordinator.daily.routine` — calls this routine at both start and end.
- `magic-coordinator.heartbeat.routine` — calls this every iteration as its "Comms" step.
- `magic-team.grooming.routine` — deep classification/triage, Google Drive/Sheets, board-coverage diffing.
- `magic-coordinator.advance.routine` — its own pending-reaction-lookup step reacts on deferred-terminal messages later.
- `magic-team.process-inbox.routine` — own-inbox processing.
- `magic-coordinator.one-on-one.routine` — small-group proposal destination for member-specific findings.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — Keep-Alive Workspace Console Session mechanics, mandatory batching.
- `magic-team/magic-team.armed.md`'s "Board & Inbox board-items entity model" section — `board-item` entity model, `communication-channel-id` frontmatter convention.
- `magic-team/magic-team.board.md` — `processed/`/`archived/` outcome-ambiguity note.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.

### Conventions

- The Slack per-message reaction-tracking design (stage mapping, additive-vs-swap exceptions, the same-sweep-vs-deferred terminal split) is dense and load-bearing — preserve it precisely when editing, don't summarize it away.
