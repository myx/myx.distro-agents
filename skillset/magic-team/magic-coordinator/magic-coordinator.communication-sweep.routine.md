---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-coordinator.communication-sweep.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Steps
- Closure steps
- Routine's local procedures
  - `slack-reaction-tracking` — the reaction ladder on each Slack message
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

`magic-coordinator.communication-sweep.routine` is the check-and-act pass over every live communication platform.

## Goals

- Notice and act on incoming communication on every live platform, without missing anything and without manufacturing work.
- Stay cheap enough to run every main-loop iteration.

## Scope

- Does:
  - Sweep the live platforms — email, Trello, Slack — for two source sets at once: the executor's own team sources, and every `client-*` member's own external sources. A `client-*` member is an avatar of this routine's executor, so its traffic is swept here; no routine belongs to one client.
  - Treat two kinds of traffic differently. A message addressed from one member to another is **routed**: the coordinator delivers it and does not answer it. A message addressed to the coordinator, any DM, any client DM, and an unaddressed external request in a team channel is **handled** here.
  - Run inside `magic-coordinator.advance.routine` every pass, in `magic-coordinator.daily.routine`, in `magic-coordinator.coordination-session.routine`, or standalone on request.
- Doesn't:
  - Read Google Drive or Sheets. That is grooming's, when searching.
  - Triage or classify deeply. Grooming does that later.
  - Start a new epic or initiative inline.

Open, pending:
- Open: "tagged anywhere" coverage — finding a mention outside the watched sources. The scan covers watched sources only; a known thread outside them is read directly.
- Open: editing the own-status Trello card as a standing checklist. Until an operation exists, the status goes as a card comment.

The live-platform set changes only on a human-reported status change, or a check error pointing at availability. Unavailable credentials are escalated at once.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **process-own-inbox**: Run standalone (not inside an advance pass or a daily): run `magic-team.process-inbox.routine magic-coordinator` first. Inside those, the caller already did.
2. **check**: Run `--magic-sweep-input-scan <team-member>`. Each member's part resumes from that member's own `last_swept_ts`, by the tooling. Read the result this way:
   - New messages are found by every participant's own message timestamps, diffed against what was handled — never by "after my own last post". Read the top level, then each open thread in full (`--member-comms-slack-read <team-member> <channel>:<ts> --thread`). Open threads are the open board items whose `communication-channel-id` is `slack:<channel>:<ts>`.
   - A thread this member started, was answered in or was tagged in is followed whatever its age.
   - The executor's own new messages form one set, ascending by timestamp. Each member's part is attributed by the member it names, and read in the order it declares. Messages are never ordered across sources.
   - Nothing new, could not be read, and no part at all are three different results. The run's exit status says whether all, some or none of the sources were scanned; output present is never evidence of success. A capped section is never read as complete.
   - A member's own inbox and board items in its part are read to know what is recorded, never answered.
   - A post by another member is inbound. Its author is the item's `author:`, who it is for its `addressees:`; `@here (unaddressed)` is unaddressed. The conversation it was posted in settles neither.
3. **process-each-message**: For each message, in order — the executor's set, then each `client-*` member's run — run this sequence before the next one. A message on a member's own source is handled as that member: it is the `<team-member>` of every call, steps:
   1. **read**: Read the full message. A message quoting a block is read past the quote: the instruction is usually after it.
   2. **analyze**: Cross-reference it with the board and the current todo state. Identify what it needs: work ready to dispatch, an idle-pass candidate, a knowledge candidate for `magic-librarian`, a reply. Nothing needed is a normal result. Whether it was handled is judged from what it asked and whether that was done, never from a later reply existing. Slack: react 👀 now.
   3. **act**: Settle whether it is routed or handled:
      - Addressed to another member: deliver it into that member's inbox as an `inquiry-*` (`post-inquiry`), carrying its `communication-channel-id`. Routing is the whole handling. Never answer it on that member's behalf, however obvious the answer.
      - Handled here, by size: approved, simple and obvious → do it now through the standard dispatch; bigger, needing the whole team → note it for the next daily; concerning specific members → propose a one-on-one; worth recording only → file it for grooming.
      - A genuinely new item is filed as a `note-*` in `magic-coordinator`'s own inbox (`--member-inbox-note-upsert`), or as an `inquiry-*` to the member it clearly concerns (`post-inquiry`). Filing settles where the record lives, not whose words it carries or who replies.
      - Slack: react per `slack-reaction-tracking`'s act stage.
   4. **reply-if-warranted**: Acknowledge every message not ignored, by each platform's own rules:
      - Slack: reply to `<channel>:<ts>` of this message, never a bare channel. `--format blocks`, always.
      - Email, and any reply into an external party's conversation: the human-owner's go first (`AskUserQuestion`; running unattended, `wait: false`, and the reply waits for it).
      - In the coordinator's own Slack or Trello threads, lead the dialogue directly, but pause before anything reading as a commitment or decision on the human-owner's behalf.
      - Never impersonate: nobody passes off words that are not their own. The source settles who sends: team sources send as the coordinator, a member's source as that member.
      - A reply the addressee must act on tags them (`magic-team.conversations.md`'s **address-messages-clearly**).
      - A question goes standalone. Distinct points go as threaded replies under one root message, never one long message (**one-message-one-speech-act**).
      - Mark it read on every platform (`--member-comms-email-mark-seen` for email). Slack: react per `slack-reaction-tracking`'s reply stage.
   5. **advance-pointer**: Only now is this message swept. Move this member's pointer to it (`--magic-sweep-state-advance <team-member> <ts>`) before the next message.

# Closure steps

1. **update-context**: steps:
   - Sources a pass could not read go in that member's `sweep-state-note` (`--magic-sweep-state-upsert`).
   - Fold identity and routing changes into the `roster-note` (`--magic-team-roster-upsert`).
   - Post today's status and what is blocked on the human team to the own-status Trello card (`--magic-comms-trello-post-comment`).
   - Post milestones and blockers to `magic-team` as threaded replies under the session's root message, as they happen, in plain language. No dispatch mechanics, ids or scores.
   - Post completion status to `event-track`.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

## `slack-reaction-tracking` — the reaction ladder on each Slack message

Slack only. Reactions add up, per `magic-team.conversations.md`'s **react-at-each-stage**, and use the `Wait` sets:
- 👀 seen — at **analyze**, once understood.
- ✍️ noted — at **act**, when the message is routed or filed for later.
- ✅ done — at **reply-if-warranted**, when it is resolved this sweep.
- ⏳ waiting — at **reply-if-warranted**, when it now waits on a tracked board item. File a `note-pending-slack-reaction-<matter>` record in `magic-coordinator`'s own inbox (`--member-inbox-note-upsert`), naming the `communication-channel-id` and the board item. `check-pending-comms-actions` adds the outcome reaction when the item resolves.

A reaction is removed or replaced when the request is declined, becomes blocked pending the human-owner, or he stops or parks the work. An assumption he called wrong gets ❌ on the message it came from. The reaction target stays the original message for the item's whole life: promotion carries `communication-channel-id` unchanged. React on the member's own source as that member (`--member-comms-slack-react`). Messages handled before this routine read them are not backfilled.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- The human-owner's ask, on any platform, is the priority: never reinterpret it, narrow it, or substitute a smaller action.
- Read each message in its own thread's context: a short reply ("post", "confirm") means what the thread so far makes it mean.
- A candidate between "simple and obvious" and "bigger" goes to the more conservative bucket.
- Unclear intent is asked about, never guessed. An unambiguous, already-scoped ask needs no fresh confirmation.
- Step progress goes to `event-track`; milestones, blockers and escalations go to `magic-team`.
- Credentials are never printed into a transcript, chat or log.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-sweep-input-scan <team-member> [--comms-since-utime <v>|--comms-since-date-time <v>]`
- `--magic-sweep-state-read <team-member>`
- `--magic-sweep-state-advance <team-member> <ts>`
- `--magic-sweep-state-upsert <team-member>`
- `--member-comms-slack-read <team-member> <channel>:<ts> [--thread]`
- `--member-comms-slack-send-message <team-member> <target> [text...]`
- `--member-comms-slack-react <team-member> <channel>:<ts> <emoji-name>`
- `--member-comms-email-send <team-member> <email@address>... -- <subject> -- <body...>`
- `--member-comms-email-mark-seen <team-member> <uid>`
- `--member-upsert-member-inquiry <member> <item-filename>`
- `--member-inbox-note-upsert <team-member> <item-filename>`
- `--magic-team-roster-upsert <team-member>`
- `--magic-comms-trello-post-comment <team-member> <card-id> [text...]`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives the team a reliable way to notice and act on incoming communication without missing things or manufacturing unnecessary work — cheap enough to run every main-loop iteration without becoming its own burden.
- Every external relationship a `client-*` member holds is read in this same sweep, under that member's own credentials, so a client's traffic never waits on a routine written for one particular client — no such routine exists, and none is written.

## Verbatim-tests (benchmarks)

- A new reply posted inside an existing Slack thread gets caught via the `conversations.replies` check — `conversations.history` alone never surfaces it.
- A message from any conversation participant that is older than the coordinator's own last post in the same thread is still surfaced, and still assessed as unhandled until its own ask is done.
- A second `client-*` member joins the team. The next sweep reads it under its own credentials, with no edit to this file and no file anywhere naming it. With one `client-*` member on the roster this test cannot run, and says so rather than reporting clean.
- One member's sweep fails while others succeed. The run's own status reports that some sources were scanned and some were not, each member's own part says which it was, and no member is recorded as clean on the strength of another. With one `client-*` member on the roster this test cannot run, and says so rather than reporting clean.
- A member's mail is read and answered but never marked seen. The next sweep reports the same messages as new: on mail the unread flag is what carries idempotence, and the stored high-water mark carries no per-member position.
- One member posts to the team channel addressing another. It is recognised as inbound from its own author line rather than the platform's sender field, and is routed to the addressee's own inbox — not read as the coordinator's own post and passed over, which is what leaves an asker waiting on a reply nobody is composing.
- A message addressed to another member has an answer the coordinator already knows. It is still routed, and still left to that member to answer.
- A message carries an author line and is addressed `@here`. It is unaddressed for routing, and the coordinator handles it itself — the conversation it arrived in settles neither who wrote it nor who it is for.
- A member's chat message is fully handled and carries its terminal reaction. The next sweep still cannot tell it from an unhandled one out of the document alone, because the document carries no reaction — establishing it takes a direct read of that message.

## Librarian Comments

### Reference

- `magic-coordinator.advance.routine` — runs this routine every pass at **advance-process-comms**.
- `magic-coordinator.armed.md`'s `check-pending-comms-actions` — adds deferred outcome reactions.
- `magic-team.shared.md`'s "Partner / Client" section — the client sweep this routine wraps.

### Conventions

- The reaction ladder and the routed-versus-handled split are load-bearing. Preserve them precisely.
