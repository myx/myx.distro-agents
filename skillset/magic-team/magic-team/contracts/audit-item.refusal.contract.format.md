---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# audit-item.refusal — frontmatter contract

Normative contract: this file's own `# Contract` section, at its end. The document shape is the tooling's `sh-lib/templates/audit-item.refusal.document.format.md`, filled by the output-style writer. Read by the document validator, `--intern-doc-validate audit-item.refusal <file>`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules

# Summary

The output-style check's record of text the floor stopped or only reported, one row per fault. Written by the tooling, never by hand.

# Contract

- Kind `audit-item.refusal`: store audit, type word `refusal`.
- Filename: `refusal-<day>T0000Z-<host>-output-style.md`, `<day>` as `YYYYMMDD` (UTC), `<host>` the short name of the machine that writes it, lower case. One document per machine and UTC day: the writer creates it with its header and appends rows. No other machine appends to it, so a merge of the team data never conflicts on it. A reader takes the union of the day's documents. A document of the days before this change has no `<host>` part and is read the same way.
- A document names this contract in `document-contract`, with the value `audit-item.refusal`. The writer fills it where missing.
- A key the Keys table does not name is not part of this contract. How a stored document that does not match is treated is set by the validator's per-rule disposition, not here.
- The validator reads the Keys table, the Body and the unmarked Rules. A rule marked `[store]` needs more than the file to check: the item's board state, its inbox, its writer or its authority. A rule marked `[judged]` is for a reader to judge.

## Keys

`presence`: `required` is present on every document of the kind; `optional` is present when it applies. `writer`: `member` is written by a member; `tooling` is never written by a member. `either` is filled by the tooling where missing, and written by a member only to set another value.

| key | presence | writer | value form | rule |
|---|---|---|---|---|
| `document-contract` | required | tooling | `literal audit-item.refusal` | Names this contract. |
| `type` | required | tooling | `literal refusal` | The filename's type word. |
| `topic` | required | tooling | `literal output-style refusals, per predicate` | What the document records. |

## Value forms

- `literal` — exactly the text shown after it.

## Body

- A `# Refusals: text the floor stopped` title line, a blank line, then the header row and the rows.
- Header row: `date-time`, `kind`, `member`, `group`, `destination`, `predicate`, `detail`, tab-separated.
- `date-time` is an `iso-utc`. `kind` is `refusal` or `report`. `member` is the sender, empty where none is known. `group` is the declared text group, `message` by default. `destination` is where the text was going. `predicate` is the name of the predicate that fired. `detail` is the fault, as the check printed it.

## Rules

- `type` equals the type word in the filename (`refusal`).
- The body header row has seven tab-separated columns, and each row below it has seven.
- A row's `kind` is `refusal` where the message was held back and `report` where the fault was only reported. The two are never counted together.
