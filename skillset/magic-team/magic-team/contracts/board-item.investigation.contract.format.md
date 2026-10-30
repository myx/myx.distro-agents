---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# board-item.investigation — frontmatter contract

Normative contract: this file's own `# Contract` section, at its end. The document shape is the tooling's `sh-lib/templates/board-item.investigation.document.format.md`, filled by the board writer from the member's slots. Read by the document validator, `--intern-doc-validate board-item.investigation <file>`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules

# Summary

A running investigation: the process document `magic-team.investigate.routine` works on, round by round. Its result is a `vault-item.investigation-report` (`ivr-*`), which this item names in `references` when it closes.

# Contract

- Kind `board-item.investigation`: store board, type word `investigation`.
- Filename: `investigation-<date>-<matter>.md`. `<date>` is `YYYYMMDD'T'HHmm'Z'` (UTC), per Terminology.
- A document names this contract in `document-contract`, with the value `board-item.investigation`. The writer fills it where missing.
- A key the Keys table does not name is not part of this contract. How a stored document that does not match is treated is set by the validator's per-rule disposition, not here.
- The validator reads the Keys table, the Body and the unmarked Rules. A rule marked `[store]` needs more than the file to check: the item's board state, its inbox, its writer or its authority. A rule marked `[judged]` is for a reader to judge.

## Keys

`presence`: `required` is present on every document of the kind; `optional` is present when it applies. `writer`: `member` is written by a member; `tooling` is never written by a member. `either` is filled by the tooling where missing, and written by a member only to set another value.

| key | presence | writer | value form | rule |
|---|---|---|---|---|
| `document-contract` | required | either | `literal board-item.investigation` | Names this contract. The writer fills it where missing. |
| `type` | required | either | `literal investigation` | The filename's type word, never a genre. Filled by board create where missing. |
| `from` | required | either | `member` | The author. Filled by board create where missing; a member sets another value only on another member's behalf. |
| `date` | required | either | `date-time` | Creation. Filled by board create where missing. |
| `owner` | required | either | `owner-name` | The current assignee. Filled by board create with the acting member where none is given; a create that has neither is refused. A non-acting owner, the human-owner or an external contact, has its inbox content in `magic-coordinator`'s inbox. |
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
| `status` | optional | member | `text` | A state label in free text; dropped when stale. |
| `recheck-date` | optional | member | `date-time` | When to look again. Written with `condition`. |
| `condition` | optional | member | `text` | What the recheck looks for. Written with `recheck-date`. |
| `owner-session` | optional | member | `text` | The live session kind holding the item. |
| `owner-session-since` | optional | member | `date-time` | Since when `owner-session` holds it. |
| `session-id` | optional | member | `session-id` | The active coworking session. |
| `participants` | optional | member | `members` | Who worked on it, added as they join. |
| `restart-session` | optional | member | `members` | Members to spawn as a coworking session instead of running inline. |
| `review-by` | optional | member | `reviewer` | The reviewer of a `board-review` item. Unset, it is the run's `reports-to`. `none` means no review: the item closes straight to `board-processed`. |
| `handler-routine` | optional | member | `routine` | The routine that runs this item's next iteration, over its type's default. Never overrides a gate. Set only by grooming or `magic-coordinator`, with its reason in `## Decisions`. |
| `archive` | optional | member | `flag` | Keep this processed item permanently. |
| `outcome` | optional | member | `text` | What an advance pass did. Written by `magic-coordinator`. |
| `execution-receipt` | optional | member | `text` | The evidence for `outcome`, and for a move into `board-blocked`. Written by `magic-coordinator`. |
| `references` | optional | member | `item-names` | Items this one cites. A board item may cite vault and audit items. |
| `access-control` | optional | tooling | `item-access-rows` | The approved permission set the tracked session carries, written when the set is approved (`--request-permission-set`), in the rows of a routine's `access-control:`. `<granted-by>` is a holder, not the session's own member. |
| `processed-at` | optional | tooling | `date-time` | Stamped when the item is processed. |
| `resolved-at` | optional | tooling | `date-time` | Stamped when the item resolves. |
| `started-at` | optional | tooling | `date-time` | Stamped when work on the item starts. |
| `groomed-at` | optional | tooling | `date-time` | Stamped at a grooming move. |
| `groomed-from` | optional | tooling | `text` | The board state the item was groomed from. |
| `track` | optional | tooling | `flag` | Stamped by the tooling. |
| `spawn-id` | optional | tooling | `session-id` | The spawn that tracks the item, written when a spawn reuses the item as its tracking document. |
| `executing-workspace` | optional | tooling | `workspace-name` | The workspace that spawn executes in. Written with `spawn-id`. |
| `paying-workspace` | optional | tooling | `workspace-name` | The workspace that pays for that spawn. Written with `spawn-id`. |
| `member-workspace` | optional | tooling | `workspace-name` | The workspace the spawned member belongs to. Written with `spawn-id`. |
| `transcript` | optional | tooling | `audit-path` | That spawn's own log, `session-*.log`. Written with `spawn-id`. |
| `review-since-epoch` | optional | tooling | `epoch-seconds` | When the item entered review. Written with `review-reason`, removed when a verdict takes the item out of review. |
| `review-reason` | optional | tooling | `text` | Why it entered review, such as `handback`. Written with `review-since-epoch`. |
| `follows-up` | optional | tooling | `item-names` | The item this one follows up. Written by `--follow-up-review` on the item it creates in `board-pending`. |

## Value forms

- `literal` — exactly the text shown after it.
- `member` — one team member name, or `human-owner`.
- `date-time` — `YYYY-MM-DD HH:MM ±HHMM`, numeric offset, never a zone abbreviation (Terminology `date-time`).
- `owner-name` — a `member`, or a non-acting owner such as an external contact.
- `item-names` — bare item names, no folder, no `.md`, comma-separated, no brackets.
- `approval-ref` — `<member> (<session-id>, <iso-utc>)`.
- `channel-id` — `slack:<channel>`, `slack:<channel>:<ts>` or `email:<…>`.
- `text` — free text on one line.
- `session-id` — one session id.
- `members` — comma-separated `member` names.
- `reviewer` — `human-owner`, a member, a session, `<session-id>:<member>`, a routine such as `grooming.routine`, or `none`.
- `flag` — the word `true`.
- `item-access-rows` — comma-separated rows `participants:allow-read:<target>:<granted-by>:<stamp>`, `participants:allow-write:<target>:<granted-by>:<stamp>` or `participants:allow-tool:<tool>:<target>:<granted-by>:<stamp>`, `<stamp>` as `YYYYMMDD'T'HHmm'Z'`, target %-escaped. A row holds for the session on the session's dispatch item, and for the task on the item it tracks.
- `workspace-name` — a workspace's basename, or `unknown`.
- `audit-path` — a path under the audit store, as the audit reader names it.
- `epoch-seconds` — whole seconds since the epoch.
- `routine` — a routine's file name without `.md`, such as `magic-team.research.routine`.

## Body

- The leg floor, each section present from creation, in this order:
  - `# Question` — the question, the thing it is about, and what the answer is for.
  - `# Goal` — the exit conditions, each able to pass or fail; the round limit or time box; the walk-away point.
  - `# Current` — what is established so far: each finding labelled shown, inferred or assumed, with its evidence. Regenerated in place each round.
  - `# Settled` — each settled part as one present-tense statement, with who settled it and when.
  - `# Open` — the open parts, nearest to closing first. `none` when nothing is open.
  - `# Log` — one line per round: what moved, what closed, what stays open. History lives only here.
- A `## Decisions` section, when present, is the one the tooling wrote: the heading is followed at once by `<!-- decisions-of: <item-name> -->`. A member adds to it only with `--record-decision`, never by hand.

## Rules

- `type` equals the type word in the filename (`investigation`).
- [store] A closed investigation names its `ivr-*` report in `references`.
- `approved-by` and `approved-at` appear together.
- `recheck-date` and `condition` appear together.
- [store] Only `magic-coordinator` creates or moves a board item.
- [store] A move into `board-blocked` carries an `execution-receipt`.
- [store] The dependency recompute keeps both directions of `blocks`/`blocked-by`.
- [store] A member never writes a key whose writer is `tooling`.
