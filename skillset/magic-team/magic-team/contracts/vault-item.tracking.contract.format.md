---
maintainers: magic-librarian, magic-coordinator, magic-architect, human-owner
---
# vault-item.tracking — plain-document contract

Normative contract: this file's own `# Contract` section, at its end. The document is a plain vault file and carries no frontmatter block. Its kind is built from this file, and the validator lists `vault-item.tracking`. On the live tracking document it returns one `report-contract-frontmatter` row and stops, because the type reader needs a block to read. Measured 2026-11-12. `sh-lib/team-data/AgentsDocContract.registry` registers the kind by the name pattern `tracking-*.md`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules
  - Checks owed

# Summary

A tracking document is one run's record, kept as a standing vault document: what is done, what runs and what is next. One live document has this kind: `tracking-20261102-refactorings.md`, the night run of the 20261102 refactorings epic. That document states what every document of this kind promises: "This file says what is done, what runs and what is next. A restart reads it alone."

The document stands alone by design. A session restarted a month later continues from this file, with no transcript and no conversation at hand. So it carries the goal, why the work is done, its scope, its current state, its next step, the decisions taken and the open points. Each is a plain present-tense statement. Each state statement carries the moment it was read.

Its middle is the run's own. A planning document knows its sections in advance, because it fills them in order. A run cannot know its topics in advance, so between its opening section and its last the headings are the run's to choose. That free middle is the one dimension on which the two kinds differ.

# Contract

- Kind `vault-item.tracking`: store vault, type word `tracking`.
- Filename: `tracking-<YYYYMMDD>-<matter>.md`, in the vault. The date is the day the run's work started.
- No frontmatter: the document opens with its level-1 heading, carries no `---` block, and names no `document-contract`.
- Constraint: the Kind line above registers the type word `tracking` in the vault's type table, which `AgentsToolsDocValidateVaultTypes` reads from every `vault-item.*.contract.format.md` in the skillset. From the moment this file stands, the generic `--upsert-vault-item` refuses a `tracking-*` name and names `--upsert-vault-tracking` as its writer, and that operation is not built. Measured 2026-11-12: the refusal stands on the live tracking name. So a tracking document has no tooling write path until that operation exists.
- A rule marked `[store]` needs more than the file to check. A rule marked `[judged]` is held by a reader, and no check holds it.

## Keys

None. The document has no frontmatter block, so it has no key.

## Value forms

- `YYYYMMDD` — the day the run's work started, as in `20261102`, never a stamp.
- `date-time` — `YYYY-MM-DD HH:MM ±HHMM`, numeric offset, never a zone abbreviation (Terminology `date-time`).
- `HH:MM ±HHMM` — a clock time with its numeric offset, where a heading or a line stamps one moment of the run.
- `item-id` — the id an item carries where its epic or plan names it, such as `S12.30` or `Q4`.
- `member` — one team member name, or `human-owner`.
- `path` — a file path in backticks, relative to its tree or absolute.

## Body

| # | part | presence | what it holds |
|---|---|---|---|
| 1 | `# <subject>: <topic> (tracking)` | required, first line | The one level-1 heading. It names the subject and the run. |
| 2 | preface lines | required | Who leads the run and what started it. The epic or order of work it serves. The sentence that a restart reads this file alone. |
| 3 | `## Where the run stands` | required, first `## ` heading | The current state, opening `State at <date-time>:`, and naming the sections a restart reads first. |
| 4 | the run's own sections | required, the run's to name | One `## ` section a topic, in the order the run reached it. A moment belongs in its heading. |
| 5 | `## Next` | required, last `## ` heading | The steps in their order. Each names the member who does it and the item it moves. |

## Rules

- [judged] The first line is the only level-1 heading, and it names the subject and the run.
- [judged] The preface names who leads the run and what started it, and states that a restart reads this file alone.
- [judged] `## Where the run stands` is the first `## ` heading, and it opens `State at <date-time>:`.
- [judged] `## Where the run stands` names the sections a restart reads first, so no other section must be read before them.
- [judged] `## Next` is the last `## ` heading.
- [judged] A step in `## Next` names the member who does it and the item it moves.
- [judged] Every state statement carries the moment it was read, and a re-measurement carries a later moment than the state it replaces.
- [judged] A table of items carries, in its header or its cells, the moment each state cell was read.
- [judged] A check's result carries both numbers: the rows that passed and the rows there are.
- [judged] A part of the work left outside the run is recorded and not acted on, so a reader knows it was seen.
- [judged] The document states what holds and what waits. A design parameter, such as a bound or a limit, is allowed.
- [store] Every item the document calls open is open in its epic or on its board at the moment the line states.
- [store] Every change to this document is a commit of the team-data store, where that store is a git repository.

## Checks owed

No check exists for this kind. Measured 2026-11-12: the testbed of `ws-myx.prv-farm` holds 0 registered tests, and that of `ws-myx-devops` holds 12, none naming a planning or a tracking document. So no rule above names a check, and each carries its marker instead.

Five rules read off the document's own text, so a check can hold each of them:

- the level-1 heading count, and the subject and the run in its text.
- the first `## ` heading by name, and `## Next` last.
- a `date-time` after `State at ` in the opening section.
- a moment on each line that states a state, which needs the contract to fix the written form of that moment.
- the member and the item in every step of `## Next`.

The rest judge content or the store, and stay a reader's. Every missing check is asked of `magic-tester` in `inquiry-20261111T2359Z-planning-and-tracking-contract-checks`.
