---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# inbox-item.inquiry — frontmatter contract

Normative contract: this file's own `# Contract` section, at its end. The document shape is `inbox-item.inquiry.document.format.md`. Read by the document validator, `--intern-doc-validate inbox-item.inquiry <file>`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules

# Summary

A question or hand-off that needs an answer. The one member-to-member document: any member may post one into any inbox.

# Contract

- Kind `inbox-item.inquiry`: store inbox, type word `inquiry`.
- Filename: `inquiry-<date>-<matter>.md`. `<date>` is `YYYYMMDD'T'HHmm'Z'` (UTC), per `magic-team/magic-team.armed.md`'s Terminology.
- A document names this contract in `document-contract`, with the value `inbox-item.inquiry`. The writer fills it where missing.
- A key the Keys table does not name is not part of this contract. How a stored document that does not match is treated is set by the validator's per-rule disposition, not here.
- The validator reads the Keys table, the Body and the unmarked Rules. A rule marked `[store]` needs more than the file to check: the item's board state, its inbox, its writer or its authority. A rule marked `[judged]` is for a reader to judge.

## Keys

`presence`: `required` is present on every document of the kind; `optional` is present when it applies. `writer`: `member` is written by a member; `tooling` is never written by a member; `either` is filled by the tooling where missing, and written by a member only to set another value.

| key | presence | writer | value form | rule |
|---|---|---|---|---|
| `document-contract` | required | either | `literal inbox-item.inquiry` | Names this contract. The writer fills it where missing. |
| `type` | required | either | `literal inquiry` | The filename's type word, never a genre. Filled by inbox upsert where missing. |
| `from` | required | either | `member` | The author. Filled by inbox upsert where missing; a member sets another value only on another member's behalf. |
| `date` | required | either | `date-time` | Creation. Filled by inbox upsert where missing. |
| `owner` | required | either | `member` | The member whose inbox receives the inquiry, the addressee. |
| `communication-channel-id` | optional | member | `channel-id` | The one external message the item traces to. |
| `references` | optional | member | `item-names` | Items this one cites. An inbox item may cite vault and audit items. |
| `status` | optional | member | `text` | A state label in free text; dropped when stale. |
| `supersedes` | optional | member | `item-names` | Items this one replaces. |
| `superseded-by` | optional | member | `item-names` | Items that replace this one. |
| `processed-at` | optional | tooling | `date-time` | Stamped by `--mark-inbox-processed`. It decides the item's folder and is the retention clock. |
| `update-kind` | optional | member | `text` | `document`, `knowledge` or `skill`. Set by `--request-update` (`AgentLibrarianTools.fn.sh`): an inquiry to `magic-librarian` that carries it is a request of the librarian's update queue. |
| `update-target` | optional | member | `text` | With `update-kind`: the path of the document, the topic of the knowledge, or `<team-member>:<pathname>` of the skill file the update is about. |
| `update-form` | optional | member | `text` | With `update-kind`: `message` (words), `text` (the proposed whole text of a skill file, in the body) or `edit` (an old and a new string of a skill file, in the body). |
| `update-target-date` | optional | tooling | `date-time` | With `update-kind`: when the target file was last changed, as the tooling found it when the request was made. The requester never gives it. |
| `update-target-checksum` | optional | tooling | `text` | With `update-kind`: the sha256 of the target file as the tooling found it, `sha256:<hex>`, or `none` for a file not there yet. `--queue-take` says `BASE-CHANGED` when the file no longer matches. The requester never gives it. |
| `reply-requested` | optional | member | `literal yes` | Set by `--request-update --reply`: `--queue-done` then files one note with the outcome into the requester's inbox. Without it nothing is sent back. |
| `update-outcome` | optional | tooling | `text` | Stamped by `--queue-done` when the librarian closes the request: `applied`, `refused` or `closed`. |
| `update-result` | optional | tooling | `text` | Stamped by `--queue-done`: the librarian's result, on one line. |

## Value forms

- `literal` — exactly the text shown after it.
- `member` — one team member name, or `human-owner`.
- `date-time` — `YYYY-MM-DD HH:MM ±HHMM`, numeric offset, never a zone abbreviation (`magic-team/magic-team.armed.md`'s Terminology `date-time`).
- `channel-id` — `slack:<channel>`, `slack:<channel>:<ts>` or `email:<…>`.
- `item-names` — bare item names, no folder, no `.md`, comma-separated, no brackets.
- `text` — free text on one line.

## Body

- Free text after the frontmatter.
- A first `#` title line, `# <Type>: <matter, one line>`, is the convention of stored items. The validator does not check it.

## Rules

- `type` equals the type word in the filename (`inquiry`).
- [store] The inbox holds `note-*`, `inquiry-*` and `reflection-*` only. Any other type in an inbox is misfiled and is reported to `magic-coordinator`.
- [store] An item is handled by marking it processed with `--mark-inbox-processed`; an item still wanted stays unmarked.
- [store] A member never writes a key whose writer is `tooling`.
- [store] Posted with `--upsert-inbox-inquiry <target-member> <item-filename>`, adding `--from-member` only when writing on another member's behalf.
- [judged] `communication-channel-id` is given when the inquiry traces back to one external message.
