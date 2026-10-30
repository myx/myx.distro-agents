---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# vault-item.investigation-report — frontmatter contract

Normative contract: this file's own `# Contract` section, at its end. The document shape is the tooling's `sh-lib/templates/vault-item.investigation-report.document.format.md`, and no writer fills it yet. Read by the document validator, `--intern-doc-validate vault-item.investigation-report <file>`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules

# Summary

An investigation report (IVR): the result of one investigation, kept as a standing document. The running investigation is its board item; this is what it established.

# Contract

- Kind `vault-item.investigation-report`: store vault, type word `ivr`.
- Filename: `ivr-<date>-<matter>.md`. `<date>` is `YYYYMMDD'T'HHmm'Z'` (UTC), per Terminology.
- A document names this contract in `document-contract`, with the value `vault-item.investigation-report`. The writer fills it where missing.
- A key the Keys table does not name is not part of this contract. How a stored document that does not match is treated is set by the validator's per-rule disposition, not here.
- The validator reads the Keys table, the Body and the unmarked Rules. A rule marked `[store]` needs more than the file to check. A rule marked `[judged]` is for a reader to judge.

## Keys

`presence`: `required` is present on every document of the kind; `optional` is present when it applies. `writer`: `member` is written by a member; `tooling` is never written by a member. `either` is filled by the tooling where missing, and written by a member only to set another value.

| key | presence | writer | value form | rule |
|---|---|---|---|---|
| `document-contract` | required | either | `literal vault-item.investigation-report` | Names this contract. The writer fills it where missing. |
| `type` | required | either | `literal ivr` | The filename's type word, never a genre. |
| `from` | required | member | `member` | The investigating member. |
| `date` | required | member | `date-time` | When the report was settled. |
| `owner` | optional | member | `owner-name` | The current holder, where one is named. |
| `status` | required | member | `text` | `final` or `superseded`. |
| `supersedes` | optional | member | `item-names` | Earlier reports this one replaces. |
| `superseded-by` | optional | member | `item-names` | The report that replaces this one. |
| `references` | optional | member | `item-names` | Vault and audit items this one cites. A vault item never cites a board item. |

## Value forms

- `literal` — exactly the text shown after it.
- `member` — one team member name, or `human-owner`.
- `date-time` — `YYYY-MM-DD HH:MM ±HHMM`, numeric offset, never a zone abbreviation (Terminology `date-time`).
- `owner-name` — a `member`, or a non-acting owner such as an external contact.
- `item-names` — bare item names, no folder, no `.md`, comma-separated, no brackets.

## Body

- `# Question` — the question, the thing it is about, and what the answer is for.
- `# Answer` — the answer and the decision (record, investigate further, act), with how firmly each is shown.
- `# Findings` — each finding labelled shown, inferred or assumed, with its evidence: the file and line, the record, the check and its result.
- `# Assumptions checked` — each assumption, its check, and whether it held. A dropped assumption keeps the check that dropped it.
- `# Defect branch` — optional: the reproduction, the bounds, the candidates ruled out, the root.
- `# Open` — what could not be established, and what would settle it. `none` when nothing is open.
- `# Next legs` — the next flow steps the investigation named. `none` when it ended at record.

## Rules

- `type` equals the type word in the filename (`ivr`).
- `references` never names a board item: no name in it starts with `project-`, `task-`, `change-`, `idea-`, `proposal-`, `interview-`, `approval-`, `dispatch-`, `warning-` or `investigation-`.
- [judged] `status` is `final` or `superseded`, and `superseded-by` is present exactly when it is `superseded`.
- [judged] A finding labelled shown carries the check that showed it.
- [store] The investigation board item that produced this report names it in its own `references`.
