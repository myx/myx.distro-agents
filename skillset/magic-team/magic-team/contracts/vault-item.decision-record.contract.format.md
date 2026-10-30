---
maintainers: magic-librarian, magic-coordinator, magic-architect, human-owner
---
# vault-item.decision-record — frontmatter contract

Normative contract: this file's own `# Contract` section, at its end. The document shape is the tooling's `sh-lib/templates/vault-item.decision-record.document.format.md`, and no writer fills it yet. Read by the document validator, `--intern-doc-validate vault-item.decision-record <file>`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules

# Summary

A decision record, in the manner of an architecture decision record (ADR): one technical question, the decision taken on it, and why. `magic-architect` produces one per distinct question it assesses, or finds the one that already exists.

# Contract

- Kind `vault-item.decision-record`: store vault, type word `adr`.
- Filename: `adr-<date>-<matter>.md`. `<date>` is `YYYYMMDD'T'HHmm'Z'` (UTC), per Terminology.
- A document names this contract in `document-contract`, with the value `vault-item.decision-record`. The writer fills it where missing.
- A key the Keys table does not name is not part of this contract. How a stored document that does not match is treated is set by the validator's per-rule disposition, not here.
- The validator reads the Keys table, the Body and the unmarked Rules. A rule marked `[store]` needs more than the file to check. A rule marked `[judged]` is for a reader to judge.

## Keys

`presence`: `required` is present on every document of the kind; `optional` is present when it applies. `writer`: `member` is written by a member; `tooling` is never written by a member. `either` is filled by the tooling where missing, and written by a member only to set another value.

| key | presence | writer | value form | rule |
|---|---|---|---|---|
| `document-contract` | required | either | `literal vault-item.decision-record` | Names this contract. The writer fills it where missing. |
| `type` | required | either | `literal adr` | The filename's type word, never a genre. |
| `from` | required | member | `member` | The deciding member, normally `magic-architect`. |
| `date` | required | member | `date-time` | When the record was written. |
| `status` | required | member | `text` | `proposed`, `accepted`, `superseded` or `deprecated`. |
| `decided-at` | optional | member | `date-time` | When the decision was accepted. Written with `status: accepted`. |
| `approved-by` | optional | member | `approval-ref` | Who accepted the decision, with the session and the time. |
| `supersedes` | optional | member | `item-names` | Earlier records this one replaces. |
| `superseded-by` | optional | member | `item-names` | The record that replaces this one. |
| `references` | optional | member | `item-names` | Vault and audit items this one cites, such as an `ivr-*`. A vault item never cites a board item. |

## Value forms

- `literal` — exactly the text shown after it.
- `member` — one team member name, or `human-owner`.
- `date-time` — `YYYY-MM-DD HH:MM ±HHMM`, numeric offset, never a zone abbreviation (Terminology `date-time`).
- `approval-ref` — as the board-item contracts define it.
- `item-names` — bare item names, no folder, no `.md`, comma-separated, no brackets.

## Body

- `# Question` — the one technical question, stated so another reader recognises it.
- `# Context` — the forces and constraints that make it a question: what must hold, what it costs, what it touches.
- `# Options` — every option weighed, each with what speaks for and against it.
- `# Decision` — the option chosen, in one or two sentences.
- `# Linchpin` — the assumption the decision rests on, and what changes if it is wrong.
- `# Consequences` — what follows: what gets easier, what gets harder, what must now be done.

## Rules

- `type` equals the type word in the filename (`adr`).
- [judged] One record, one question. A second question gets its own record.
- `references` never names a board item.
- [judged] `status` is `proposed`, `accepted`, `superseded` or `deprecated`, and `superseded-by` is present exactly when it is `superseded`.
- [judged] Before a new record is written, the existing records are searched for the same question. A record found is updated or superseded, never duplicated.
