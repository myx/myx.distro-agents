---
maintainers: [magic-librarian, magic-coordinator, human-owner]
---
# audit-item.artifact — frontmatter contract

Normative contract: this file's own `# Contract` section, at its end. The document shape is `audit-item.artifact.document.format.md`. Read by the document validator, `--intern-doc-validate audit-item.artifact <file>`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules

# Summary

The record of one published document, rewritten whole at each of its states. Written by the tooling when a document is claimed and published, never by hand.

# Contract

- Kind `audit-item.artifact`: store audit, type word `artifact`.
- Filename: `artifact-<stamp>-<number in lowercase>.md` for a numbered document, such as `artifact-20261009T2327Z-adr-001.md`; `artifact-<stamp>-<slug of the title>.md` for an unnumbered one. `<stamp>` is `YYYYMMDD'T'HHmm'Z'` (UTC).
- A document names this contract in `document-contract`, with the value `audit-item.artifact`. The writer fills it where missing.
- A key the Keys table does not name is not part of this contract. How a stored document that does not match is treated is set by the validator's per-rule disposition, not here.
- The validator reads the Keys table, the Body and the unmarked Rules. A rule marked `[store]` needs more than the file to check: the item's board state, its inbox, its writer or its authority. A rule marked `[judged]` is for a reader to judge.

## Keys

`presence`: `required` is present on every document of the kind; `optional` is present when it applies. `writer`: `member` is written by a member; `tooling` is never written by a member; `either` is filled by the tooling where missing, and written by a member only to set another value.

| key | presence | writer | value form | rule |
|---|---|---|---|---|
| `document-contract` | required | tooling | `literal audit-item.artifact` | Names this contract. |
| `type` | required | tooling | `literal artifact` | The filename's type word. |
| `number` | required | tooling | `text` | `<CODE>-<NNN>` for a numbered document, `-` for an unnumbered one. |
| `kind` | required | tooling | `text` | The document's type code, such as `ADR`, or `-` for an unnumbered one. |
| `title` | required | tooling | `text` | The document's title. |
| `url` | required | tooling | `url` | Where the document was published. |
| `member` | required | tooling | `member` | The publishing member. |
| `session` | required | tooling | `text` | The publishing session's id, or `-`. |
| `date` | required | tooling | `date-time` | When this state was written. |
| `state` | required | tooling | `enum reserved, published, released` | `reserved` while the number is claimed, `published` once the document exists, `released` when the publish failed and the number is given back. |

## Value forms

- `literal` — exactly the text shown after it.
- `text` — free text on one line.
- `url` — one URL, or `-` while none exists.
- `member` — one team member name, or `human-owner`.
- `date-time` — `YYYY-MM-DD HH:MM ±HHMM`, numeric offset, never a zone abbreviation (`magic-team/magic-team.armed.md`'s Terminology `date-time`).
- `enum` — one of the values listed after it.

## Body

- One `# <number>: <title>` line for a numbered document, `# <title>` for an unnumbered one, and nothing else.

## Rules

- `type` equals the type word in the filename (`artifact`).
- [store] The record is rewritten whole at each state change; a number is claimed before anything is published.
