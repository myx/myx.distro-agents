---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# audit-item.snapshot — frontmatter contract

Normative contract: this file's own `# Contract` section, at its end. The document shape is `audit-item.snapshot.document.format.md`. Read by the document validator, `--intern-doc-validate audit-item.snapshot <file>`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules

# Summary

A resource's full content, saved byte for byte before a write that could lose it. Written by the tooling before the write; if the save fails, the write is refused.

# Contract

- Kind `audit-item.snapshot`: store audit, type word `snapshot`.
- Filename: `snapshot-<utc-stamp>-<system>-<resource-type>-<resource-id>.md`, `<utc-stamp>` equal to `captured-at`.
- A document names this contract in `document-contract`, with the value `audit-item.snapshot`. The writer fills it where missing.
- A key the Keys table does not name is not part of this contract. How a stored document that does not match is treated is set by the validator's per-rule disposition, not here.
- The validator reads the Keys table, the Body and the unmarked Rules. A rule marked `[store]` needs more than the file to check: the item's board state, its inbox, its writer or its authority. A rule marked `[judged]` is for a reader to judge.

## Keys

`presence`: `required` is present on every document of the kind; `optional` is present when it applies. `writer`: `member` is written by a member; `tooling` is never written by a member; `either` is filled by the tooling where missing, and written by a member only to set another value.

| key | presence | writer | value form | rule |
|---|---|---|---|---|
| `document-contract` | required | tooling | `literal audit-item.snapshot` | Names this contract. |
| `type` | required | tooling | `literal snapshot` | The filename's type word. |
| `system` | required | tooling | `word` | The outside system the resource lives in, such as `jira` or `confluence`. |
| `resource-type` | required | tooling | `word` | The kind of resource, such as `issue` or `page`. |
| `resource-id` | required | tooling | `text` | The resource's identifier in that system. |
| `write-op` | required | tooling | `text` | The operation that is about to write, such as `client-comms-jira-issue-transition`. |
| `captured-by` | required | tooling | `member` | The acting member. |
| `captured-at` | required | tooling | `utc-stamp` | When the content was read. |

## Value forms

- `literal` — exactly the text shown after it.
- `word` — one word, no spaces.
- `text` — free text on one line.
- `member` — one team member name, or `human-owner`.
- `utc-stamp` — `YYYYMMDD'T'HHmmss'Z'`, UTC, seconds included.

## Body

- After the frontmatter, the resource's content exactly as read, with no summary and no edit.

## Rules

- `type` equals the type word in the filename (`snapshot`).
- The filename carries `captured-at`, `system`, `resource-type` and `resource-id` as the frontmatter gives them.
- [judged] A snapshot carries no secret or credential value.
