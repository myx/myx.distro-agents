---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# board-item.dispatch — frontmatter contract

Normative contract: this file's own `# Contract` section, at its end. The document shape is `board-item.dispatch.document.format.md`. Read by the document validator, `--intern-doc-validate board-item.dispatch <file>`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules

# Summary

The brief given to one spawned session, carried exactly, with a dated log of its reports. Written by the spawner when it starts the session.

# Contract

- Kind `board-item.dispatch`: store board, type word `dispatch`.
- Filename: `dispatch-<stamp>-spawn-proxy-<pid>-<first 8 characters of spawn-id>.md` for a session the spawner started, `<stamp>` as `YYYYMMDD'T'HHmmss'Z'` (UTC). A reused tracking document keeps its own name.
- A document names this contract in `document-contract`, with the value `board-item.dispatch`. The writer fills it where missing.
- A key the Keys table does not name is not part of this contract. How a stored document that does not match is treated is set by the validator's per-rule disposition, not here.
- The validator reads the Keys table, the Body and the unmarked Rules. A rule marked `[store]` needs more than the file to check: the item's board state, its inbox, its writer or its authority. A rule marked `[judged]` is for a reader to judge.

## Keys

`presence`: `required` is present on every document of the kind; `optional` is present when it applies. `writer`: `member` is written by a member; `tooling` is never written by a member; `either` is filled by the tooling where missing, and written by a member only to set another value.

| key | presence | writer | value form | rule |
|---|---|---|---|---|
| `document-contract` | required | tooling | `literal board-item.dispatch` | Names this contract. The writer fills it where missing. |
| `type` | required | tooling | `literal dispatch` | The filename's type word, never a genre. Filled by board create where missing. |
| `from` | required | tooling | `member` | The author. Filled by board create where missing; a member sets another value only on another member's behalf. |
| `date` | required | tooling | `date-time` | Creation. Filled by board create where missing. |
| `owner` | required | tooling | `owner-name` | The member the session is run as: the caller named in the spawn request. |
| `author` | optional | member | `member` | The creating author, where it differs from `from`. |
| `blocks` | optional | member | `item-names` | Items this item gates. |
| `blocked-by` | optional | member | `item-names` | Items gating this one. |
| `spawns` | optional | member | `item-names` | Items spawned from this one. |
| `spawned-by` | optional | member | `item-names` | The item this one was spawned from. |
| `supersedes` | optional | member | `item-names` | Items this one replaces. |
| `superseded-by` | optional | member | `item-names` | Items that replace this one. |
| `approved-by` | optional | member | `approval-ref` | Who gave the go, with the session and the time. Written with `approved-at`. |
| `approved-at` | optional | member | `date-time` | When the go was given. Written with `approved-by`. |
| `communication-channel-id` | optional | member | `channel-id` | The one external message the item traces to. |
| `status` | required | tooling | `text` | The run's state, set by the spawner and the review flow, such as `dispatch-started`. |
| `recheck-date` | optional | member | `date-time` | When to look again. Written with `condition`. |
| `condition` | optional | member | `text` | What the recheck looks for. Written with `recheck-date`. |
| `owner-session` | optional | member | `text` | The live session kind holding the item. |
| `owner-session-since` | optional | member | `date-time` | Since when `owner-session` holds it. |
| `session-id` | required | tooling | `session-id` | The session the spawn belongs to. |
| `participants` | optional | member | `members` | Who worked on it, added as they join. |
| `restart-session` | optional | member | `members` | Members to spawn as a coworking session instead of running inline. |
| `review-by` | optional | either | `reviewer` | The reviewer of the item. Written by the spawner only where the spawn request gave one; unset, the run's `reports-to` reviews. |
| `archive` | optional | member | `flag` | Keep this processed item permanently. |
| `outcome` | optional | member | `text` | What an advance pass did. Written by `magic-coordinator`. |
| `execution-receipt` | optional | member | `text` | The evidence for `outcome`, and for a move into `board-blocked`. Written by `magic-coordinator`. |
| `references` | optional | member | `item-names` | Items this one cites. A board item may cite vault and audit items. |
| `allows` | optional | tooling | `allows-set` | The approved permission set the tracked session carries, written when the set is approved (`--magic-permission-set-request`). `<granted-by>` is a holder, not the session's own member. |
| `processed-at` | optional | tooling | `date-time` | Stamped when the item is processed. |
| `resolved-at` | optional | tooling | `date-time` | Stamped when the item resolves. |
| `started-at` | optional | tooling | `date-time` | Stamped when work on the item starts. |
| `groomed-at` | optional | tooling | `date-time` | Stamped at a grooming move. |
| `groomed-from` | optional | tooling | `text` | The board state the item was groomed from. |
| `track` | optional | tooling | `flag` | Stamped by the tooling. |
| `spawn-id` | required | tooling | `session-id` | This spawn's own identity. |
| `executing-workspace` | required | tooling | `workspace-name` | The workspace the session executes in. Always written, also where all three workspaces are one. |
| `paying-workspace` | required | tooling | `workspace-name` | The workspace that pays for the session. |
| `member-workspace` | required | tooling | `workspace-name` | The workspace the member belongs to. |
| `tracks` | optional | tooling | `item-names` | The item its session's work is tracked in. |
| `transcript` | optional | tooling | `audit-path` | The session's own log, `session-*.log`. |
| `description` | optional | tooling | `text` | The spawn request's one-line description. |
| `session-comment` | optional | tooling | `text` | The spawn request's session name or comment. |
| `tokens` | optional | tooling | `tokens` | The session's token totals, kept up to date by the tooling. |
| `review-since-epoch` | optional | tooling | `epoch-seconds` | When the item entered review. |
| `review-reason` | optional | tooling | `text` | Why it entered review, such as `handback` or `ended-without-handback`. |

## Value forms

- `literal` — exactly the text shown after it.
- `member` — one team member name, or `human-owner`.
- `date-time` — `YYYY-MM-DD HH:MM ±HHMM`, numeric offset, never a zone abbreviation (`magic-team/magic-team.armed.md`'s Terminology `date-time`).
- `owner-name` — a `member`, or a non-acting owner such as an external contact.
- `item-names` — bare item names, no folder, no `.md`, comma-separated, no brackets.
- `approval-ref` — `<member> (<session-id>, <iso-utc>)`.
- `channel-id` — `slack:<channel>`, `slack:<channel>:<ts>` or `email:<…>`.
- `text` — free text on one line.
- `session-id` — one session id.
- `members` — comma-separated `member` names.
- `reviewer` — `human-owner`, a member, a session, `<session-id>:<member>`, a routine such as `grooming.routine`, or `none`.
- `flag` — the word `true`.
- `allows-set` — comma-separated entries `session:<tool>:<target>:<granted-by>:<stamp>` or `task:<tool>:<target>:<granted-by>:<stamp>`, `<stamp>` as `YYYYMMDD'T'HHmm'Z'`, target %-escaped.
- `workspace-name` — a workspace's basename, or `unknown`.
- `audit-path` — a path under the audit store, as the audit reader names it.
- `tokens` — `in=<N> cache-read=<N> cache-write=<N> out=<N>`.
- `epoch-seconds` — whole seconds since the epoch.

## Body

- A first line `# Spawn-proxy dispatch: <caller member>`.
- A `## Brief` section carries the spawn request exactly as given.
- A `## Result` section, written by the tooling when the session ends, carries `status:`, `exit-code:`, `output-file:` and `completed-at:` lines.
- A dated log of the session's reports follows the brief.
- A `## Decisions` section, when present, is the one the tooling wrote: the heading is followed at once by `<!-- decisions-of: <item-name> -->`. A member adds to it only with `--member-decision-record`, never by hand.

## Rules

- `type` equals the type word in the filename (`dispatch`).
- `approved-by` and `approved-at` appear together.
- `recheck-date` and `condition` appear together.
- [store] Only `magic-coordinator` creates or moves a board item.
- [store] A move into `board-blocked` carries an `execution-receipt`.
- [store] The dependency recompute keeps both directions of `blocks`/`blocked-by`.
- [store] A member never writes a key whose writer is `tooling`.
- [store] Created in `board-running`.
- [judged] A dispatch is the record of one session; it carries no work of its own beyond the brief.
