---
maintainers: magic-librarian, magic-coordinator, magic-architect, human-owner
---
# epic — document contract

Normative contract: this file's own `# Contract` section, at its end. The document is a plain source file with no frontmatter. The document validator reads it with `--intern-doc-validate epic <file>`, and `--epic-update` edits it.

## Contents

- Summary
- Contract
  - Sections
  - Feature
  - Done
  - Rules

# Summary

An epic is the tracking document of the epic-* routines. It holds the work that must finish before a named point. Each feature states its open work with an owner. A closed item leaves its feature and stands as one line in `## Done`.

# Contract

- Kind `epic`: a plain source file named `<YYYYMMDD>-<matter>.epic.md`, in the `backlog` folder of a `todo-sketchpad` scratchpad.
- It has no frontmatter and no store. The tooling finds it by its path.
- The epic-* routines hold it as their tracking document, as they hold any other. They declare `tracking-item: required`, which makes the spawner attach a board item to each run. The epic is not that item.
- The epic file owns scope, order, settled lines and status. The `project-*` item owns run state and names the epic file in its body.
- The dispatch input names the epic file and the feature id.
- A key the Sections and Feature tables do not name is not part of this contract.
- The validator reads the Sections table, the Feature table and the unmarked Rules. A rule marked `[store]` needs more than the file to check. A rule marked `[judged]` is for a reader to judge.

## Sections

`presence`: `required` stands in every epic. `optional` stands where it applies. The sections run in this order.

| section | heading | presence | holds |
|---|---|---|---|
| title | `# <title>` | required | The first line, and the only level-1 heading. |
| preface | `Source:` and `Builders:` lines | required | The sketch the epic comes from, and who builds. |
| decisions | `## Decisions` | required | What the epic settles, as plain present-tense bullets. |
| ground rules | `## Ground rules` | optional | Rules every item keeps. |
| standing rulings | `## Standing rulings` | optional | The owner's rulings that stand for the whole run. |
| feature | `## <id> - <title>` | optional, repeatable | One piece of open work. Features stand in their order of work. See Feature. |
| close-out | `## <id> - Close-out: <title>` | optional | The last feature. Its items are the proofs that close the epic. |
| plans | `## Plans from investigations` | optional | One bullet for each investigation-first feature, naming where its plan arrives. |
| done | `## Done` | required | The last section. See Done. |

A `---` line may separate the decisions from the features.

## Feature

A feature is a `## ` section whose heading starts with its id. The id is `S` and a number, such as `S24`. `--epic-update` finds a feature by `## <id> `.

| part | form | presence | rule |
|---|---|---|---|
| heading | `## <id> - <title>` | required | The id stands once in the file. The title may name its sketch section. |
| owner line | `Owner: <members>.` and then `State: <text>.` | required unless each open item names its owner | Who builds the feature, and where it stands. |
| input | `Input: <document>` | optional | The document the feature starts from. |
| status | `Status: <text>` | optional | Written only by `--epic-update --set-status`. |
| settled | plain lines after a `Settled:` label or the status line | optional | Present-tense rules. `--epic-update --add-settled` writes them. |
| open work | numbered items, `N. <text>` | required while the feature stands | One item states one outcome that a check can pass or fail. An item with two outcomes is split before either closes. |
| item owner | `Owner: <member>.` ending the item | required unless the owner line covers it | The member who builds the item. |
| moved item | `Moved to <epic file>, section <id>: <what>.` | optional | Stands in place of an item that left this epic. |
| sub-heading | `### <text>` | optional | Groups a feature's items, such as stages. |

A label line, such as `Settled:`, `Open:`, `Rules:`, `MUST:` or `SHOULD:`, heads a group of lines. A label is not an item.

## Done

- `## Done` is the last section of the file. It may hold no line.
- One line stands for each closed item: `- <id>: <what holds now>`. The id is a feature id, or a feature id and an item number, such as `S23.8`.
- The line is plain and present tense. It carries no date and no owner.
- `--epic-update --set-status <id> done` writes the line and takes the closed item out of its feature.

## Rules

- `## Done` is the last `## ` heading of the file.
- Every feature id is `S` and a number, and stands once.
- A `## Done` id stands once, and no open item carries it.
- Every feature has an owner, in its owner line or in each open item.
- A feature holds open work or moved items. A closed item is removed and goes to `## Done`.
- [judged] Features stand in their order of work. The file order is that order.
- [judged] Item numbers are ids. They are never renumbered and never reused, because `## Done` cites them.
- [judged] An item holds one outcome. An item with two is split before either closes.
- [judged] An open item states an outcome and the check that proves it, never a list of actions.
- [judged] A settled line is a plain present-tense rule. It carries no date, no owner and no story.
- [judged] The file holds no rework log and no status diary.
- [store] Every moved item exists in the epic file and the section its moved line names.
