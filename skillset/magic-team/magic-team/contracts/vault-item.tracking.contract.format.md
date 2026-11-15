---
maintainers: magic-librarian, magic-coordinator, magic-architect, human-owner
---
# vault-item.tracking — frontmatter contract

Normative contract: this file's own `# Contract` section, at its end. The document opens with a frontmatter block, which the typed writer stamps. Measured 2026-11-13: the live tracking document carries none, and the validator returns one `report-contract-frontmatter` row and stops. `sh-lib/team-data/AgentsDocContract.registry` registers the kind by the name pattern `tracking-*.md`.

## Contents

- Summary
- Contract
  - Keys
  - Value forms
  - Body
  - Rules
  - Checks owed

# Summary

A tracking document is one run's record, kept as a standing vault document: what is done, what runs and what is next. One live document has this kind: `tracking-20261102T0000Z-refactorings.md`, the night run of the 20261102 refactorings epic. That document states what every document of this kind promises: "This file says what is done, what runs and what is next. A restart reads it alone."

The document stands alone by design. A session restarted a month later continues from this file, with no transcript and no conversation at hand. So it carries the goal, why the work is done, its scope, its current state, its next step, the decisions taken and the open points. Each is a plain present-tense statement. Each state statement carries the moment it was read.

Its middle is the run's own. A planning document knows its sections in advance, because it fills them in order. A run cannot know its topics in advance, so between its opening section and its last the headings are the run's to choose. That free middle is the one dimension on which the two kinds differ.

# Contract

- Kind `vault-item.tracking`: store vault, type word `tracking`.
- Filename: `tracking-<YYYYMMDD>-<matter>.md`, in the vault. The date is the day the run's work started.
- A document names this contract in `document-contract`, with the value `vault-item.tracking`. The writer fills it where missing, with `type` beside it on every write.
- Constraint: the Kind line above registers the type word `tracking` in the vault's type table, which `AgentsToolsDocValidateVaultTypes` reads from every `vault-item.*.contract.format.md` in the skillset. So the generic `--upsert-vault-item` refuses a `tracking-*` name, and only `--upsert-vault-tracking` writes it. Measured 2026-11-13: the arm for that writer is in `AgentsTools.Member.include:442`. Neither `DistroAgentsItems` nor `DistroAgentsTools` routes to it. So a tracking document has no reachable write path until that route lands.
- A rule marked `[store]` needs more than the file to check. A rule marked `[judged]` is held by a reader, and no check holds it.

## Keys

`presence`: `required` is present on every document of the kind; `optional` is present when it applies. `writer`: `member` is written by a member; `tooling` is never written by a member. `either` is filled by the tooling where missing, and written by a member only to set another value.

| key | presence | writer | value form | rule |
|---|---|---|---|---|
| `document-contract` | required | either | `literal vault-item.tracking` | Names this contract. The writer fills it where missing. |
| `type` | required | either | `literal tracking` | The filename's type word, never a genre. The writer fills it where missing. |
| `from` | required | either | `member` | The author. The writer fills it when it creates the item. |
| `date` | required | either | `date-time` | When the tracking document was written as an item. Never the day the run's work started, which stands in the filename. The writer fills it when it creates the item. |

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
| 1 | `# <subject>: <topic> (tracking)` | required, first line after the block | The one level-1 heading. It names the subject and the run. |
| 2 | preface lines | required | Who leads the run and what started it. The epic or order of work it serves. The sentence that a restart reads this file alone. |
| 3 | `## Where the run stands` | required, first `## ` heading | The current state, opening `State at <date-time>:`, and naming the sections a restart reads first. |
| 4 | the run's own sections | required, the run's to name | One `## ` section a topic, in the order the run reached it. A moment belongs in its heading. |
| 5 | `## Next` | required, last `## ` heading | The steps in their order. Each names the member who does it and the item it moves. |

## Rules

- [judged] The only level-1 heading opens the body, and it names the subject and the run.
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
