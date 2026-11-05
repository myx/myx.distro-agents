---
maintainers: magic-librarian, magic-coordinator, magic-architect, human-owner
---
# vault-item.epic-blueprint — frontmatter contract

Normative contract: this file's own `# Contract` section, at its end. The document shape is the tooling's `sh-lib/templates/vault-item.epic-blueprint.document.format.md`, and `--upsert-vault-epic-blueprint` writes it. Read by the document validator, `--intern-doc-validate vault-item.epic-blueprint <file>`. The epic's own sections, features and `## Done` are the `epic` contract's, checked by `--intern-doc-validate epic <file>`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules

# Summary

An epic blueprint: the tracking document of the epic-* routines, kept as a standing vault document. It states the work and how it is checked, never one executable piece. One file therefore has two checks: this contract on every write, and the `epic` contract for its shape.

# Contract

- Kind `vault-item.epic-blueprint`: store vault, type word `epic-blueprint`.
- Filename: `epic-blueprint-<date>-<matter>.md`. `<date>` is `YYYYMMDD'T'HHmm'Z'` (UTC), per Terminology. It is the date the epic's own file carried, so the item's identity never changes with the day of a move; midnight UTC stands where the time was never recorded.
- A document names this contract in `document-contract`, with the value `vault-item.epic-blueprint`. The writer fills it where missing.
- A key the Keys table does not name is not part of this contract. How a stored document that does not match is treated is set by the validator's per-rule disposition, not here.
- The validator reads the Keys table, the Body and the unmarked Rules. A rule marked `[store]` needs more than the file to check. A rule marked `[judged]` is for a reader to judge.

## Keys

`presence`: `required` is present on every document of the kind; `optional` is present when it applies. `writer`: `member` is written by a member; `tooling` is never written by a member. `either` is filled by the tooling where missing, and written by a member only to set another value.

| key | presence | writer | value form | rule |
|---|---|---|---|---|
| `document-contract` | required | either | `literal vault-item.epic-blueprint` | Names this contract. The writer fills it where missing. |
| `type` | required | either | `literal epic-blueprint` | The filename's type word, never a genre. The writer fills it where missing. |
| `from` | required | either | `member` | The author, normally `magic-coordinator`. The writer fills it where missing. |
| `date` | required | either | `date-time` | When the epic was written as an item. The writer fills it where missing. |
| `owner` | optional | member | `owner-name` | The current holder, where one is named. |
| `references` | optional | member | `item-names` | The items this epic cites, its inputs among them. A vault item never cites a board item. |
| `reflect` | optional | member | `enum yes, no` | Whether this epic is projected at all. Absent means `no`. |
| `reflect-class` | optional | member | `enum jira-born, major, process, internal` | Which threshold line decided it. |
| `reflect-reason` | optional | member | `text` | Why, in a manager's words. |
| `jira-issue` | optional | member | `text` | The hub ticket's key, written by the mirror after a successful write. |
| `jira-synced-at` | optional | member | `date-time` | When the hub ticket last matched. |
| `confluence-page` | optional | member | `text` | The epic's page in the documents space, written by the mirror. |
| `confluence-synced-at` | optional | member | `date-time` | When that page last matched. |

## Value forms

- `literal` — exactly the text shown after it.
- `member` — one team member name, or `human-owner`.
- `date-time` — `YYYY-MM-DD HH:MM ±HHMM`, numeric offset, never a zone abbreviation (Terminology `date-time`).
- `owner-name` — a `member`, or a non-acting owner such as an external contact.
- `item-names` — bare item names, no folder, no `.md`, comma-separated, no brackets.
- `enum` — one of the words listed after it.
- `text` — free text on one line.

## Body

The body is the `epic` contract's shape, unchanged: the title, the `Source:` and `Builders:` preface, `## Decisions`, the `## <id> - <title>` features, `## Plans from investigations`, and `## Done` last. `--intern-doc-validate epic` reads it; this file adds nothing the epic checker does not already state.

A `## Sketch` chapter may hold a copy of the owner's own sketch. It says it is a copy, and it names the owner's file.

## Rules

- `type` equals the type word in the filename (`epic-blueprint`).
- `references` never names a board item: no name in it starts with `project-`, `task-`, `change-`, `idea-`, `proposal-`, `interview-`, `approval-`, `dispatch-` or `warning-`. A name starting with `investigation-` names a vault report.
- [judged] The body holds the work and how it is checked, never one executable piece: that is a ticket, and it lives on the board.
- [judged] An epic's inputs are items of their own, named in `references`, so each keeps its own type and its own history.
- [store] Every change to this document is a commit of the team-data store, where that store is a git repository.
