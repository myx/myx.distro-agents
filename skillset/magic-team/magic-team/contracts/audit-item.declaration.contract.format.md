---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# audit-item.declaration — frontmatter contract

Normative contract: this file's own `# Contract` section, at its end. The document shape is the tooling's `sh-lib/templates/audit-item.declaration.document.format.md`, filled by the output-style writer. Read by the document validator, `--intern-doc-validate audit-item.declaration <file>`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules

# Summary

The record of text a member declared as not message group, kept for a reader to judge. Written by the tooling, never by hand.

# Contract

- Kind `audit-item.declaration`: store audit, type word `declaration`.
- Filename: `declaration-<day>T0000Z-output-style.md`, `<day>` as `YYYYMMDD` (UTC). One document per UTC day: the writer creates it with its header and appends rows.
- A document names this contract in `document-contract`, with the value `audit-item.declaration`. The writer fills it where missing.
- A key the Keys table does not name is not part of this contract. How a stored document that does not match is treated is set by the validator's per-rule disposition, not here.
- The validator reads the Keys table, the Body and the unmarked Rules. A rule marked `[store]` needs more than the file to check: the item's board state, its inbox, its writer or its authority. A rule marked `[judged]` is for a reader to judge.

## Keys

`presence`: `required` is present on every document of the kind; `optional` is present when it applies. `writer`: `member` is written by a member; `tooling` is never written by a member; `either` is filled by the tooling where missing, and written by a member only to set another value.

| key | presence | writer | value form | rule |
|---|---|---|---|---|
| `document-contract` | required | tooling | `literal audit-item.declaration` | Names this contract. |
| `type` | required | tooling | `literal declaration` | The filename's type word. |
| `topic` | required | tooling | `literal output-style text-group declarations` | What the document records. |

## Value forms

- `literal` — exactly the text shown after it.

## Body

- A `# Declarations: text sent as not message group` title line, a blank line, then the header row and the rows.
- Header row: `date-time`, `kind`, `member`, `group`, `destination`, `text`, tab-separated.
- `date-time` is an `iso-utc`. `member` is the sender. `group` is the declared text group. `destination` is where the text was going. `text` is the whole text on one line, newlines and tabs collapsed to single spaces.

## Rules

- `type` equals the type word in the filename (`declaration`).
- The body header row has six tab-separated columns, and each row below it has six.
- A row's `kind` is `declaration` and its `group` is never `message`.
- [store] The writer refuses a further declaration once the document holds 1000 lines; a reader drains the queue.
