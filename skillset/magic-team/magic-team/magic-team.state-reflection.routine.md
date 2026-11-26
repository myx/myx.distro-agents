---
type: routine
executors: magic-librarian
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
requires-session-kind: standalone
review-by: inherit
routine-lock-document: inbox:magic-librarian:note-20261125T000000Z-page-estate-state.md
runs-at: workdays 00:00
runs-after: magic-librarian.morning-review
deliverables: each generated page actualised to its sources, or named in the report with the reason it was not
deliverables: one inquiry per new page comment, filed with its comment id
deliverables: the estate check result, one row per failing page and rule
---
# magic-team.state-reflection.routine — the actual procedure

## Contents

- Summary
  - Goals
  - Scope
- Opening steps
- Steps
- Closure steps
- Routine's local procedures
- Routine's local rules
- Routine-specific tooling
  - Tooling operations
  - Gaps
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions

# Summary

`magic-team.state-reflection.routine` keeps the external view true to the team's own records. It regenerates each estate page from that page's own vault source, and reports every difference it cannot close.

## Goals

- Present the team's work and knowledge state in the external view, so a reader outside the team reads a page that matches its source.
- Make that presentation repeatable. Every estate page is actualised to its source on a period, with no hand on it.
- Turn every comment a reader leaves into an inquiry, so each one is answered.

## Scope

- Does:
  - The eleven pages of the `RMM 2` estate, each regenerated from its own vault source.
  - Every inline comment on those pages, filed as one inquiry per comment.
  - The estate check, its rows, and the report of what generation cannot close.
- Doesn't:
  - Personal reflection, and landing a lesson in the skillset: `magic-team.process-reflections.routine` keeps them.
  - The board's state model and cross-file consistency: `magic-librarian.morning-review.routine` keeps them.
  - Authoring a page: what a page says, for which reader, is `magic-team.public-documentation.routine`'s work.
  - Writing a Jira field: the member that moved the board item writes it.

# Opening steps

None of its own: the Opening steps of `magic-team.standalone.routine` run first, and then these Steps.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **open-the-run**: read the state note through `--get-inbox-item`, and take from it the estate list, the comment watermark and the last run's open rows.
   - rule: the state note is `note-20261125T000000Z-page-estate-state.md` in `magic-librarian`'s own inbox, and it is this routine's `routine-lock-document:`.
   - rule: the comment watermark is the note's `comments_read_since` key, an ISO UTC date.
   - rule: the estate is these eleven pages, and it is the state note's first content:
     - RMM 2 — `4919263234`
     - RMM2 rebuild — `4871880731`
     - Keenetic RMM 2 — backend implementation requirements (living draft) — `4861231112`
     - RMM2 — the plan — `4862017548`
     - RMM2 — how we prove it — `4861853706`
     - RMM2 — how we work with people — `4860903448`
     - RMM2 — assumptions and gaps — `4861755408`
     - RMM2 — findings register — `4861952021`
     - RMM2 backend — implementation requirements (English translation of v0.9) — `4919689217`
     - RMM2 — research archive v0.11 (evidence) — `4861362189`
     - RMM2 backend — требования к реализации (перевод v0.9) — `4861198339`
   - step: where the note carries no estate yet, write these eleven pages into it before any other step runs.

2. **gather-page-comments**: read the inline comments on the estate pages, and file one inquiry per new comment, steps:
   - step: read each page's comments with `--confluence-comment-read <page-id> --inline --since <comments_read_since>`.
   - rule: only a row whose `RESOLUTION_STATUS` is `open` is a comment to file.
   - step: file each new comment with `--upsert-inbox-inquiry magic-librarian <item> --from-comment confluence:<page-id>:<comment-id>`.
   - rule: the item's own `# ` heading carries the comment id, because the operation refuses a heading that does not.
   - step: move `comments_read_since` to the newest comment read, in the state note.
   - rule: the operation keeps its own list of filed comments, so a second pass files none.
   - rule: that list is `note-20261008T000000Z-doc-comments-state-and-lock.md`, which the operation writes itself.
   - rule: it is not this routine's state note. The state note holds the estate, the watermark and the open rows.
   - rule: a reply under a comment is not a new comment. The operation refuses one by its `PARENT_COMMENT_ID`.
   - rule: a comment whose inquiry is answered is resolved on its page with `--confluence-comment-resolve <page-id> <comment-id>`. The row it prints names the state left.

3. **check-the-estate**: run `--confluence-page-check` over the estate pages, rules:
   - rule: every estate page id is passed on the call. A bare call falls back to `CONFLUENCE_PAGE_CHECK_PAGES`, which names the estate only where the workspace sets it.
   - rule: it prints one row per failing page and rule, and it writes no page.
   - rule: a page it cannot read is a failing row, never a skip.
   - step: keep its rows as this run's open rows in the state note.

4. **regenerate-in-write-order**: regenerate each estate page from its own vault source, and write only the page whose body differs, steps:
   - step: read the page's stored body and its version with `--confluence-page-read <page-id> --format storage`.
   - step: render the page with `--confluence-page-render --source <source> --page-id <page-id>`, the source being the vault item the page's own `Source:` line names.
   - rule: a source reads as `vault:page-source-<page-id>-<name>`, the form the render reports for page `4861362189`.
   - rule: the render's `--page-id` arm compares the render against the live page. It exits 1 where the live page carries a rendered line the render does not produce. That case is not written, and it goes to **report-what-generation-cannot-close**.
   - step: write a differing body with `--confluence-page-update <page-id> --if-version <version read> --title <title> --status current --body-storage-from-file <path>`.
   - rule: the title comes from the source's own header block, never from the page.
   - rule: `--status` is Confluence's page state, never the header block's `Status:` field. It is `current`, and `archived` where the body declares a freeze under R13.
   - rule: write order is pointers after their targets, and the landing page `4919263234` last.
   - rule: a write answering CONFLICT with exit 10 skips its page, and the run reports that page.

5. **hold-the-review-line**: a page this run wrote reads unconfirmed until its named reviewer confirms it, rules:
   - rule: `--confluence-page-render` emits `AI-generated — not yet reviewed` as a constant, and reads no reviewer from the source.
   - rule: **regenerate-in-write-order** writes the render's own text, so every page this run writes carries that line.
   - rule: no confirmation carries forward from the page's previous body.
   - step: test the stored body for R2's named form, `AI-generated — reviewed by <name>`, a named reviewer being a person.
   - rule: a body carrying only `AI-generated — not yet reviewed`, or no review line, names no reviewer.
   - rule: every page this run writes names no reviewer, so each becomes one inquiry at **report-what-generation-cannot-close**.

6. **report-what-generation-cannot-close**: file one inquiry for each case this run cannot close, rules:
   - rule: the addressee is `magic-coordinator`, filed with `--upsert-inbox-inquiry magic-coordinator <item>`, naming the page by its title and its id.
   - rule: the cases are four. A page with no vault source, a source its body contradicts, a render whose `--page-id` arm exits 1, and a page with no named reviewer.
   - rule: a case already filed and still open is not filed again.
   - rule: two cases of one page carry different headings, so they stay two items.

7. **close-the-run**: write this run's state into the state note with `--update-routine-state`, steps:
   - rule: the update happens last, after every page write and every inquiry of the run.
   - step: patch in the estate as it stands, the `comments_read_since` watermark, and this run's open rows, one row a line.
   - rule: the note stands alone. It states the estate, the watermark, the next step and the open rows, each in the present tense.
   - rule: the note is the run's `routine-lock-document:`, so a restarted run continues from it alone.

# Closure steps

Run inline: none of its own. **close-the-run** closes the run's state.
Run as its own session: none of its own. The closing group of `magic-team.standalone.routine` runs after these Steps.

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

None.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- The estate is the eleven pages of **open-the-run**, and nothing wider.
- A failing page is reported by **check-the-estate**. It is never rewritten in the run that failed it.
- A generated body carries no approval block, and a frozen page stays frozen. No confirmation survives into a new body.
- A body is never hand-pinned. A save sets each link's pin, so a hand edit there is drift.
- A rule the estate check prints no row for is not a pass. R6, R7, R12, R14 and R15 each need a reader.
- A case this run cannot close reaches the team as one inquiry, never as a quiet edit to a page.
- Waiting for a maintainer or a reviewer follows **wait-never-quit**.
- Goal-directedness: work toward the session's goal. Off-goal items are recorded quickly, not acted on now.

# Routine-specific tooling

Every harness tool and `magic-tooling` operation this routine uses. A harness tool is called by its own name. An operation is called through the harness tool of its tool file, with `operation` and `args`. Its behaviour is read with `--member-help`. Steps use its name only.

## Tooling operations

- `--confluence-comment-read [--team-member <team-member>] <page-id> [--inline] [--since <iso-utc-date>]` (`DistroAgentsAtlassian`)
- `--confluence-comment-resolve [--team-member <team-member>] <page-id> <comment-id>` (`DistroAgentsAtlassian`)
- `--confluence-page-check [--team-member <team-member>] [<page-id>...]` (`DistroAgentsAtlassian`)
- `--confluence-page-render [--team-member <team-member>] --source <spec> [--page-id <page-id>]` (`DistroAgentsAtlassian`)
- `--confluence-page-read [--team-member <team-member>] <page-id> [--format storage|atlas_doc_format] [--version <n>]` (`DistroAgentsAtlassian`)
- `--confluence-page-update [--team-member <team-member>] <page-id> (--version <n>|--if-version <n>) --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--space-id <numeric-id>]` (`DistroAgentsAtlassian`)
- `--get-inbox-item [--team-member <member>] <item-filename> [--include-processed]` (`DistroAgentsItems`)
- `--upsert-inbox-inquiry <target-member> <item-filename> [--from-member <member>] [--from-comment <service>:<page-or-file>:<comment-id>] [--from-file <path>|--upsert-from-slots]` (`DistroAgentsItems`)
- `--update-routine-state [--team-member <team-member>] [--document <note>] [--header:upsert:<name>:<value>]... [--header:remove:<name>]... [--edit-patch-from-stdin|--from-file <path>]` (`DistroAgentsSession`)

## Gaps

- **GAP** a record that carries a reviewer's confirmation across a write. Its epic item is `epic-20261124T1200Z-reflection-and-document-generation-as-standing-periodic-work.md`. Until it exists, every page a run writes becomes one inquiry.

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- The team's external view shows its own records as they stand now, without a hand on each page.
- What generation cannot close reaches the team, rather than being left unsaid or quietly patched into a page.

## Verbatim-tests (benchmarks)

- A page's source moves and the page does not. The run writes the page, and its body then equals the render.
- A reader leaves a comment and never sees it answered. The run files it, and the run after it files nothing.
- The run writes the landing page before its pointers. The pointers go stale, and the write order is the finding.
- A page's stored body names no reviewer. The page is not confirmed, and one inquiry names it.
- A page fails the estate check. The run reports the row, and the page's body is unchanged.

## Librarian Comments

### Reference

- `magic-team.process-reflections.routine` — the retro: personal reflection and landing a lesson. It assesses no page.
- `magic-librarian.morning-review.routine` — the run before this one in the schedule chain.
- `contracts/confluence-page.contract.format.md` — the fifteen rules, and which of them the estate check decides.

### Conventions

- The estate is written once, in **open-the-run**. A page joins it there, never in a later step.
- A rule the check decides and a complaint a reader leaves are two findings, and they reach two different places.
