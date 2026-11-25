---
maintainers: magic-librarian, magic-developer, magic-architect, human-owner
---
# confluence-page — document contract

Normative contract: this file's own `# Contract` section, at its end. The rules below are the mechanical half of the documentation convention. The judgement half belongs to the reviewer, and a check never mixes the two.

## Contents

- Summary
- The rules
- What the check does not decide
- Contract

# Summary

A Confluence page carries a header block, a TL;DR, sections and a change log at its end. This file states each property a validator decides, with the test that decides it. `DistroAgentsAtlassian.fn.sh --confluence-page-check` is the check that reads them.

## The rules

The rule ids are the convention's own, kept so a row of the check reads the same to the page's owner and to the note that set it. Each rule is mechanical: a validator decides it, and no reviewer is asked.

| # | Rule | Test |
|---|---|---|
| R1 | The page names its one source | `Source: ` followed by a non-space matches in the first ten rendered lines |
| R2 | The page states its review state | `AI-generated — reviewed by <name>` or `AI-generated — not yet reviewed` in the header block, a named reviewer being a person |
| R3 | The header block carries six fields, in this order: status, type, owner, approver, last reviewed, Jira | six labelled fields, none empty, the status one of the legend's seven |
| R4 | A TL;DR of three to five bullets stands before the first section heading | the list items before the first `h2` number three to five |
| R5 | A change log ends the page, one line per published version | the last `h2` is a change log, and its last line names the page's current version |
| R8 | No two pages in a space share a title | a uniqueness count of zero duplicates over the checked set |
| R9 | No internal link pins a version older than its target's current version | for each `ri:page` link, `ri:version-at-save` is at least the target's current version |
| R10 | No internal vocabulary on a published page | no match for `magic-[a-z]+`, `armed\.md`, `board://` or a Slack `channel:ts` |
| R11 | No credential value, no secret's path and line, no exploit command, no private contact detail | no bearer token, private-key header or password-shaped assignment; the rest is the reviewer's |
| R13 | A frozen archive carries no approval block, carries `Superseded by <link>`, and does not change after its freeze | three predicates over the body, the freeze declared as `frozen <date> at version <n>` |
| R15 | The stored body equals the render of its source, apart from the render stamp | a byte comparison after normalising the stamp |

The legend's seven status values: `DRAFT`, `IN REVIEW`, `WAITING FOR DECISION`, `APPROVED`, `LIVING`, `KNOWN WRONG / REJECTED`, `ARCHIVED`.

Three of the convention's rules are not mechanical, or not mechanical here. R6 needs the first paragraph read as intent. R7 needs the page inventory. R12 needs a size reason, and a size is a judgement of a page's shape. R14 needs a live read of the linked Jira issue. R15 needs a render, which no operation writes yet, so it is enforced where the render is built.

## What the check does not decide

- One fault is reported once. A page failing three rules gets three rows, and a rule that passes prints nothing.
- The check reads, and never writes a page.
- A page it cannot read is a failing row, never a skip. Confluence answers 404 for a missing page and for a page this identity may not see, and the row says both.
- R9 compares a pin against the current version of its target. A title the checked set's spaces do not hold is reported on stderr as uncompared, never counted as clean.
- R8's title prefix and R7's one landing page belong to the page inventory, which is a later layer.

# Contract

- Kind `confluence-page`: the stored body of a Confluence page, read at `--format storage`, with the page's id, title and version taken from the read's own header line.
- The body is storage format, so it carries no line of its own. The convention's "line" is a rendered one: a paragraph, heading, list item, table cell or preformatted block.
- The header block is the rendered lines the page opens with that carry the rule's own labelled fields. R1, R2 and R3 read those lines, and R3's six fields are read in the order it names.
- `Source:` and the six header fields are plain text at the start of a rendered line. A bold or emphasised label is not a match: the convention states literal text, and a page is corrected to it rather than the check widened.
- A status is one of the legend's seven, matched with no case sensitivity and its own spelling.
- The change log is the page's last `h2`. Its last rendered line carries the version, alone or in a comma-separated list, as `v<n>` or as the page's own `<n>`. A `Version:` field in the header block is read too.
- R13's freeze is declared in the page's own text as `frozen <YYYY-MM-DD> at version <n>`, and a page at another version has changed since its freeze.
- R9's map is the current version of every title in the checked set, and of every page of each space the set lives in, listed once per space.
- A row is `<page id> TAB <rule> TAB <finding>`, and the exit status is non-zero wherever a row printed.
