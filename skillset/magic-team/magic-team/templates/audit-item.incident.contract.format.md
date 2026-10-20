---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# audit-item.incident — frontmatter contract

Normative contract: this file's own `# Contract` section, at its end. The document shape is `audit-item.incident.document.format.md`. Read by the document validator, `--intern-doc-validate audit-item.incident <file>`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules

# Summary

An incident record. Thin until a writer exists: the team's model defines this type in one line, so this contract carries the common keys and the body is free.

# Contract

- Kind `audit-item.incident`: store audit, type word `incident`.
- Filename: `incident-<date>-<matter>.md`. `<date>` is `YYYYMMDD'T'HHmm'Z'` (UTC), per `magic-team/magic-team.armed.md`'s Terminology.
- A document names this contract in `document-contract`, with the value `audit-item.incident`. The writer fills it where missing.
- A key the Keys table does not name is not part of this contract. How a stored document that does not match is treated is set by the validator's per-rule disposition, not here.
- The validator reads the Keys table, the Body and the unmarked Rules. A rule marked `[store]` needs more than the file to check: the item's board state, its inbox, its writer or its authority. A rule marked `[judged]` is for a reader to judge.

## Keys

`presence`: `required` is present on every document of the kind; `optional` is present when it applies. `writer`: `member` is written by a member; `tooling` is never written by a member; `either` is filled by the tooling where missing, and written by a member only to set another value.

| key | presence | writer | value form | rule |
|---|---|---|---|---|
| `document-contract` | required | either | `literal audit-item.incident` | Names this contract. The writer fills it where missing. |
| `type` | required | either | `literal incident` | The filename's type word, never a genre. |
| `from` | required | member | `member` | The author. |
| `date` | required | member | `date-time` | When the incident was recorded. |
| `owner` | optional | member | `owner-name` | The current holder, where one is named. |
| `references` | optional | member | `item-names` | Items this one cites. A vault or audit item never cites a board item. |

## Value forms

- `literal` — exactly the text shown after it.
- `member` — one team member name, or `human-owner`.
- `date-time` — `YYYY-MM-DD HH:MM ±HHMM`, numeric offset, never a zone abbreviation (`magic-team/magic-team.armed.md`'s Terminology `date-time`).
- `owner-name` — a `member`, or a non-acting owner such as an external contact.
- `item-names` — bare item names, no folder, no `.md`, comma-separated, no brackets.

## Body

- Free text after the frontmatter.

## Rules

- `type` equals the type word in the filename (`incident`).
- `references` never names a board item: no name in it starts with `project-`, `task-`, `change-`, `idea-`, `proposal-`, `interview-`, `approval-`, `dispatch-` or `warning-`.
