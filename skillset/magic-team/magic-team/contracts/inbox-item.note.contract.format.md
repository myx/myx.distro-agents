---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# inbox-item.note — frontmatter contract

Normative contract: this file's own `# Contract` section, at its end. The document shape is the tooling's `sh-lib/templates/inbox-item.note.document.format.md`, filled by the inbox writer from the member's slots. Read by the document validator, `--intern-doc-validate inbox-item.note <file>`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules

# Summary

Context or coordination.

# Contract

- Kind `inbox-item.note`: store inbox, type word `note`.
- Filename: `note-<date>-<matter>.md`. A standing note keeps its name across rewrites. `<date>` is `YYYYMMDD'T'HHmm'Z'` (UTC), per `magic-team/magic-team.armed.md`'s Terminology.
- A document names this contract in `document-contract`, with the value `inbox-item.note`. The writer fills it where missing.
- A key the Keys table does not name is not part of this contract. How a stored document that does not match is treated is set by the validator's per-rule disposition, not here.
- The validator reads the Keys table, the Body and the unmarked Rules. A rule marked `[store]` needs more than the file to check: the item's board state, its inbox, its writer or its authority. A rule marked `[judged]` is for a reader to judge.

## Keys

`presence`: `required` is present on every document of the kind; `optional` is present when it applies. `writer`: `member` is written by a member; `tooling` is never written by a member; `either` is filled by the tooling where missing, and written by a member only to set another value.

| key | presence | writer | value form | rule |
|---|---|---|---|---|
| `document-contract` | required | either | `literal inbox-item.note` | Names this contract. The writer fills it where missing. |
| `type` | required | either | `literal note` | The filename's type word, never a genre. Filled by inbox upsert where missing. |
| `from` | required | either | `member` | The author. Filled by inbox upsert where missing; a member sets another value only on another member's behalf. |
| `date` | required | either | `date-time` | Creation. Filled by inbox upsert where missing. |
| `owner` | required | either | `member` | The member whose inbox holds the note. A member writes a note into its own inbox only (`--upsert-inbox-note`). |
| `communication-channel-id` | optional | member | `channel-id` | The one external message the item traces to. |
| `references` | optional | member | `item-names` | Items this one cites. An inbox item may cite vault and audit items. |
| `status` | optional | member | `text` | A state label in free text; dropped when stale. |
| `mark` | optional | member | `enum important, emergency` | Marks the item for the main loop (T3): an `important` item is spawned for, an `emergency` one is confirmed with the owner and sets the emergency flag. |
| `standing` | optional | member | `enum yes, no` | `yes` marks a standing note: while it is unprocessed it is in force, shown by `AgentDispatcherTools.fn.sh --standing-directives` and given to every spawn in its brief. `no` or absent is an ordinary note. Set with `--upsert-inbox-note --standing yes|no`. |
| `supersedes` | optional | member | `item-names` | Items this one replaces. |
| `superseded-by` | optional | member | `item-names` | Items that replace this one. |
| `processed-at` | optional | tooling | `date-time` | Stamped by `--mark-inbox-processed`. It decides the item's folder and is the retention clock. |

## Value forms

- `literal` — exactly the text shown after it.
- `member` — one team member name, or `human-owner`.
- `date-time` — `YYYY-MM-DD HH:MM ±HHMM`, numeric offset, never a zone abbreviation (`magic-team/magic-team.armed.md`'s Terminology `date-time`).
- `channel-id` — `slack:<channel>`, `slack:<channel>:<ts>` or `email:<…>`.
- `item-names` — bare item names, no folder, no `.md`, comma-separated, no brackets.
- `enum` — one of the values listed after it.
- `text` — free text on one line.

## Body

- Free text after the frontmatter.
- A first `#` title line, `# <Type>: <matter, one line>`, is the convention of stored items. The validator does not check it.

## Rules

- `type` equals the type word in the filename (`note`).
- [store] The inbox holds `note-*`, `inquiry-*` and `reflection-*` only. Any other type in an inbox is misfiled and is reported to `magic-coordinator`.
- [store] An item is handled by marking it processed with `--mark-inbox-processed`; an item still wanted stays unmarked.
- [store] A member never writes a key whose writer is `tooling`.
- [store] A standing note, such as the roster, is rewritten in place under its fixed name and is never marked processed. It holds only what is in force now, short and current.
