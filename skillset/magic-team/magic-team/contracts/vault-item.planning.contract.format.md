---
maintainers: magic-librarian, magic-coordinator, magic-architect, human-owner
---
# vault-item.planning — plain-document contract

Normative contract: this file's own `# Contract` section, at its end. The document is a plain vault file and carries no frontmatter block. Its kind is built from this file, and the validator lists `vault-item.planning`. On the live planning document it returns one `report-contract-frontmatter` row and stops, because the type reader needs a block to read. Measured 2026-11-12. `sh-lib/team-data/AgentsDocContract.registry` registers the kind by the name pattern `planning-*.md`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules
  - Checks owed

# Summary

A planning document is the recurrent work document of one planning cycle. It closes the cycle's gaps, states the goals and the deliverables, sets the constraints, orders the work and records what is settled. `planning-20261109-sprint.md`, the sprint starting 2026-11-09, is the first document of this kind, and the shape below is stated from it.

A planning round always runs the same way. It closes gaps, identifies goals, agrees deliverables, sets constraints, decomposes, then structures the plan. The sections below follow that order, so an open gap stands above the work that waits on it.

Planning is one kind with modes. The human-owner settled on 2026-11-09 that a mode deserving its own name and prefix extends planning, and that `epic-blueprint` is the epic mode's name. No prefix extends planning in the tooling yet, so this contract governs the `planning-*` documents alone.

# Contract

- Kind `vault-item.planning`: store vault, type word `planning`.
- Filename: `planning-<YYYYMMDD>-<matter>.md`, in the vault. The date is the cycle's start date, so a sprint's Monday.
- No frontmatter: the document opens with its level-1 heading, carries no `---` block, and names no `document-contract`.
- Constraint: the Kind line above registers the type word `planning` in the vault's type table, which `AgentsToolsDocValidateVaultTypes` reads from every `vault-item.*.contract.format.md` in the skillset. From the moment this file stands, the generic `--upsert-vault-item` refuses a `planning-*` name and names `--upsert-vault-planning` as its writer, and that operation is not built. Measured 2026-11-12: the refusal stands on the live planning name, and before this file existed the same write landed on a rig store. So a planning document has no tooling write path until that operation exists.
- A rule marked `[store]` needs more than the file to check. A rule marked `[judged]` is held by a reader, and no check holds it.

## Keys

None. The document has no frontmatter block, so it has no key.

## Value forms

- `YYYYMMDD` — the cycle's start date, as in `20261109`, never a stamp.
- `date-time` — `YYYY-MM-DD HH:MM ±HHMM`, numeric offset, never a zone abbreviation (Terminology `date-time`).
- `Q<n>` — a question's number, one decimal number, such as `Q4`.
- `item-id` — the id an item carries where its epic or plan names it, such as `S12.30`.
- `path` — a file path in backticks, relative to its tree or absolute.

## Body

The body is the level-1 heading, the `Audience:` line, then the sections in this order. One section holds the mode's own subsections, so a mode grows there and no other section moves.

| # | part | presence | what it holds |
|---|---|---|---|
| 1 | `# <cycle> <start date>: planning` | required, first line | The one level-1 heading. It names the cycle and its start date. |
| 2 | `Audience:` line | required | Who reads the document, and why it exists. |
| 3 | `## Contents` | required | The `## ` headings below it, in their order, nested under the parent. |
| 4 | `## What this is` | required | The document, its subject, its limit and its job. |
| 5 | `## What we are after` | required | `### Goals`, then `### Deliverables`, then `### Constraints`. |
| 6 | `## What is decided` | required | What the mode settles. Its subsections are the mode's own. |
| 7 | `## Questions` | required | One `- ` line a question, naming its `Q<n>` and how it is settled. |
| 8 | `## Pending` | required | `### Incoming`, `### Chosen`, `### Later`, `### Carried`, in that order. |
| 9 | `## The order` | required | The pieces in the order they run, or the reason they wait. |
| 10 | `## Status` | required | The gauge, carrying the moment it was drawn. |
| 11 | `## Evidence` | required | The readings the plan rests on. |
| 12 | `## Done` | required, last `## ` heading | One line a settled question, naming the repositories it touched. |

## Rules

- [judged] The first line is the only level-1 heading, and it names the cycle and its start date.
- [judged] `## Contents` lists the `## ` headings below it in their order, nested under their parent, and lists none that is absent.
- [judged] Every part stands once, in the table's order, and `## Done` is the last `## ` heading.
- [judged] `## Pending` holds `### Incoming`, `### Chosen`, `### Later` and `### Carried`, in that order.
- [judged] A question names its `Q<n>` and says how it gets settled.
- [judged] A settled question carries the word settled where it stands, and the same `Q<n>` stands in `## Done`.
- [judged] A line in `## Chosen` names its outcome, its owner and what it depends on.
- [judged] The gauge in `## Status` carries the moment it was drawn, and its counts match the document.
- [judged] A reading a later reader would take as current carries when it was taken.
- [judged] The document states what holds and what waits, in its own words. A design parameter, such as a bound or a limit, is allowed.
- [store] The epic or request the plan serves is named, and stands in the vault or on the board.
- [store] Every change to this document is a commit of the team-data store, where that store is a git repository.

## Checks owed

No check exists for this kind. Measured 2026-11-12: the testbed of `ws-myx.prv-farm` holds 0 registered tests, and that of `ws-myx-devops` holds 12, none naming a planning or a tracking document. So no rule above names a check, and each carries its marker instead.

Six rules read off the document's own text, so a check can hold each of them:

- the level-1 heading count, and the cycle and start date in its text.
- the `## ` heading sequence against the table's order, with `## Done` last.
- the `### ` sequence under `## Pending`.
- a `date-time` in the gauge of `## Status`.
- the nested list of `## Contents` against the headings below it.
- a `Q<n>` in `## Questions` standing in `## Done` where it carries settled.

The rest judge content or the store, and stay a reader's. Every missing check is asked of `magic-tester` in `inquiry-20261111T2359Z-planning-and-tracking-contract-checks`.
