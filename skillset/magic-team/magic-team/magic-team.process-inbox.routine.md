---
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-team.process-inbox.routine — the actual procedure

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

`magic-team.process-inbox.routine <team-member>` works one member's own inbox: read, reply, route, resolve.

## Goals

- Give every acting member a working mailbox, so hand-offs and self-notes land and get worked without relaying every exchange through `magic-coordinator`.
- Keep the split: any member works its own mail; only `magic-coordinator` writes the board.

## Scope

- Does:
  - One member's own inbox, named by the one mandatory argument `<team-member>`. Run by that member, from any routine's explicit call or on its own initiative.
- Doesn't:
  - Board writes by any member but `magic-coordinator`.
  - Non-acting owners' content in `magic-coordinator`'s inbox: `magic-coordinator.external-inbox-handle-loop.routine` works it.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **read-and-classify**: read the inbox with `--member-work-session-input-scan <team-member>`, and each body with `--member-inbox-item-read` where it was truncated. Classify each item by what it says: a status or block report, a request or question, a hand-off, a reflection, anything else.
2. **act-lightweight**: per item, steps:
   - reply, route it on with `post-inquiry`, or resolve it inline when it is simple, obvious and within this member's own duties. Failing that bar, route it.
   - a needed board change: `magic-coordinator` makes it; any other member routes it to `magic-coordinator`, however small.
   - an item of a type other than `note-*`, `inquiry-*` or `reflection-*` is misfiled: report it to `magic-coordinator`.
3. **reply-on-cross-member-handoff**: a reply, route or hand-off touching another member gets an immediate compact post into the session thread: who, and which item. `magic-coordinator` posts it for a hand-off it decided, even where another member did the write. Unsure whether it is significant: post it.
4. **mark-handled**: mark each handled item processed with `--member-inbox-to-processed`. An item still wanted stays unmarked; a standing note is never marked.

# Closure steps

Run inline: none. Run as its own session: run `magic-team.coworking.routine`'s **close-session** group.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- The executing member is permitted and obliged to execute every step exactly as written, in order.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- **Execution mode follows identity.** `<team-member>` is the executor's own name: run inline, in the same session. Otherwise the executor spawns `<team-member>` to run it; no member works another member's inbox under its own identity.
- **Not automatic.** A session processes its member's inbox only when its routine's Steps call `magic-team.process-inbox.routine <team-member>` explicitly.
- Who delivers into an inbox: `magic-team.armed.md`'s "Board & Inbox board-items entity model"; another member's inbox only through `post-inquiry`. Only the inbox's owner processes it.
- **reflection-promotion**: a reflection about running an activity stays in its member's own inbox, compacted with the others, until it becomes a proposal, is discussed at `magic-coordinator.retro.routine`, or is dropped. Where it needs `magic-coordinator`'s action, its member files an `inquiry-*` to `magic-coordinator` with `post-inquiry`. A reflection never moves into another member's inbox.
- Goal-directedness: work toward the session's goal. Off-goal items are recorded quickly, not acted on now.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-work-session-input-scan <team-member>`
- `--member-inbox-item-read <member> <item-filename> [--start-line <N> --end-line <N>]`
- `--member-upsert-member-inquiry <member> <item-filename> [--from-file <path>]`
- `--member-comms-slack-send-message <team-member> <target> [text...]`
- `--member-inbox-to-processed <team-member> <item-filename> [--header:<upsert|append|remove>:name[:value]]...`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine ensures every acting member's own inbox actually gets processed — not left to sit unread just because nothing automatically triggers it.

## Verbatim-tests (benchmarks)

- Any member can deliver into another member's inbox through `post-inquiry` (`--member-upsert-member-inquiry`), but only that inbox's own owner processes what's inside it — same as real email.

## Librarian Comments

### Reference

- `magic-coordinator.external-inbox-handle-loop.routine` — the non-acting-owner counterpart.
- `magic-coordinator.retro.routine` — discusses retained reflections.

### Conventions

- The one mandatory `<team-member>` argument, the "not automatic" rule and the identity-based execution mode are this routine's load-bearing properties.
- **reflection-promotion** and **reply-on-cross-member-handoff** are cited by name from other files.
