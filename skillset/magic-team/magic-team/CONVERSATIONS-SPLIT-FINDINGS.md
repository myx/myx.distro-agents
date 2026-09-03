# Splitting `magic-team.conversations.md`

Two questions investigated: split into 2-3 files by reclassification, and thin the file by moving detail to references. Measured on the current file: 734 lines, 7,787 words, 72 step-named rules in 8 groups.

---

## Revised after human-owner review — the three-file split is withdrawn

Two objections, both correct:

- Corrections and approvals are part of every conversation. `judgment-gap-propose-and-confirm` is cited from all six authority contracts; `confirm-before-acting-mandatory`, `no-regress`, `rephrase-and-confirm-before-acting` fire in ordinary exchanges. The file's own header *Baseline rules (always in force)* is right. Labelling two-thirds of it "routine-loaded" was a policy change, not a classification.
- Topic-named files pull in routines. A complete *corrections* file needs `interview.routine`'s "Rephrase and confirm before acting, every time", the four rules `negotiations.md` carries, and `shared.md`'s approval standing rules. That is a cross-file rework, and it breaks the boundary the file states for itself: *"governs form, methodology and control points, not strategy. Goal-reaching strategy stays in interview.routine / discuss.routine / brainstorm.routine."*

**What survives — no new file names, everything moves to a file that already owns the topic:**

| move | words | to |
|---|---|---|
| non-operative lines (`verbatim-*`, `Why:`, `Distinct from`, `Related rule:`) | −1,848 | `magic-librarian/reference/` |
| Checkpoint loop (operational form) + When this mode is optional + Policy-bearing changes workflow | −419 | `magic-team.interview.routine.md` — the mode is named *Interview-alike*; the 122-word *When this mode is required* trigger block stays |
| `transcripts-are-verbatim-records`, `transcript-append-strict-and-utc`, `relaying-does-not-merge-transcripts`, `name-speaker-on-coworking-transcript` | −275 | `magic-team.coworking.routine.md` |
| **remaining `conversations.md`** | **≈ 5,245 words ≈ 6.3k tokens** | all genuinely always-in-force |

A 33% reduction, not 60%. Step-name citations stay valid across files by convention; the index idea below still applies for name → file resolution.

Part 1 below stands. Part 2's three-file table is retained as the record of what was considered and why it was rejected.

---

## Answer in one table

| approach | always-loaded size | passes `no-regress`? | fixes the Slack failure class? |
|---|---|---|---|
| today | 7,787 words ≈ 9k tokens | — | no — not loaded |
| thin + references only | 5,956 words (−23%) | yes, relocation | barely — the messaging group is 97% operative, thinning takes 72 words from it |
| split by context only | messaging file 2,781 words ≈ 3.5k tokens | yes, relocation | yes, if the messaging file is what `.claude/rules` loads |
| **both** | **messaging file ≈ 2,650 words ≈ 3.3k tokens** | yes | yes |

The gain comes from the split. Thinning is a second-order win and is exactly the same relocation already recommended for the 10.2% non-operational sections skillset-wide.

---

## Part 1 — what "detail to references" can and cannot move

Measured per group. *Non-operative* = `verbatim-intent`/`verbatim-benchmark` lines, `Why:` blocks, `Related rule:`/`Distinct from` notes, `The pattern:`/`Why it slips through:` narrative.

| group | operative | non-op | non-op % |
|---|---|---|---|
| Message and reaction discipline | 2,043 | 72 | 3% |
| Clarification and correction handling | 1,012 | 541 | 34% |
| Mode and pacing | 161 | 0 | 0% |
| Approval and relay safety | 784 | 107 | 12% |
| Anchor refusal safeguard | 363 | 0 | 0% |
| Correction persistence and answer precision | 967 | 1,128 | **53%** |
| Interview-alike checkpoint mode | 495 | 0 | 0% |
| **total** | **5,956** | **1,848** | **23%** |

**Will it work?** Yes for the 23%, because that content does not need to bind at runtime — it is what the librarian and tester check against. Moving it is the pattern `shared.md` already prescribes for Maintainer Notes, and `magic-librarian/reference/messaging.md` already exists as precedent. It passes `no-regress` because nothing is dropped.

**Where it will not work:** operative sub-clauses. Moving *"never the literal characters of a mention sitting in the text"* to a reference file re-creates the exact hole `shared.md` § *Prose cross-reference versus guaranteed load* names — a prose link binds only a member that follows it. The test for whether a line may move: would a member acting without it do something the rule forbids? If yes, it stays.

**Will it help?** Modestly on its own. The group that governs every message — the one the Slack failure fell under — is already 97% operative. Thinning takes 72 words out of 2,120. The two heavy groups (Correction persistence, Clarification) drop by half, but those are not the always-load candidates.

---

## Part 2 — the split

### Classification by *when the rule applies*, balanced to near-equal size

| file | groups and rules | words | after thinning |
|---|---|---|---|
| **messaging** — every message a member sends, any context | Message and reaction discipline (18) · Mode and pacing (5) · from Correction persistence: `concrete-answers-to-concrete-questions`, `partial-reply-leaves-rest-unchanged`, `exact-complete-fulfillment-not-more-less-none` | 2,781 | ≈ 2,650 |
| **corrections** — interpreting incoming input, handling corrections and gaps | Clarification and correction handling (12) · from Correction persistence: `preserve-hedges-correction-is-binding`, `criterion-diversion-under-concurrency-is-structural-failure`, `recheck-available-context-before-treating-as-unknown`, `ceiling-insertion-during-restatement` | 2,677 | ≈ 1,500 |
| **approvals** — relaying, approving, checkpointing, where rulings land | Approval and relay safety (12) · Anchor refusal safeguard (1) · Interview-alike checkpoint mode (16) · Policy-bearing changes · from Correction persistence: `decision-lands-in-the-document-it-binds` | 2,288 | ≈ 2,050 |

The only group that has to be split at rule level is *Correction persistence and answer precision* — it is a mix of answer-shape rules (→ messaging) and correction-handling rules (→ corrections), plus one rule about where decisions land (→ approvals). Every other group moves whole.

### Internal citations survive the split

Rules cite each other by **step-name in bold**, never by number or file — `conversations.md` line 14 states this as the convention. Ten citation edges cross the proposed file boundaries; all ten remain valid because the name is the address. What a reader needs is a way to resolve a name to a file, which the index below provides.

### External references: 74 lines in 38 files — zero mandatory edits

| reference kind | count | after split |
|---|---|---|
| step-name cited from outside (26 distinct names) | 60 lines | unchanged — name is file-agnostic |
| boilerplate *"Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply"* | 18 lines in routine files | unchanged if `conversations.md` stays as the index; optionally sharpened |
| boilerplate *"`magic-team.conversations.md` — conversation mechanics …"* in Librarian Comments | 10 lines | unchanged |
| specific prose references (`shared.md`, `armed.md`, `negotiations.md`) | ~6 lines | unchanged |

**Keep `magic-team.conversations.md` as a thin index** — the Fast use model plus a step-name → file table, ~40 lines. Every existing reference stays correct on the day of the split. Sharpening the 18 boilerplate lines to name the specific file becomes optional cleanup, not a prerequisite.

Note the boilerplate phrase itself already lists three things: *message shape* and *reaction meaning* (→ messaging), *confirming corrections before acting* (→ corrections). The split matches the phrase.

### `.claude/rules` after the split

Only the messaging file is symlinked into `.claude/rules/`. Corrections and approvals load the way they do today — by routine files that need them (`interview.routine`, `coworking.routine`, `negotiations.md` already cite their rules by name). ≈ 3.3k tokens always-loaded instead of 9k.

---

## What needs the human-owner

- **Three new names.** Siblings: `magic-team.conversations.md`, `magic-team.negotiations.md`, `magic-team.shared.md`, `magic-team.board.md`. Candidates: `magic-team.messaging.md`, `magic-team.corrections.md`, `magic-team.approvals.md`. Per the naming rule, with siblings shown, before anything is built.
- **Reclassifying what is "always in force".** Today the file declares groups 1-6 as *Baseline rules (always in force)*. The split makes only the messaging file always-loaded; corrections and approvals become routine-loaded. That is a policy change, not a wording change.
- **`magic-team.negotiations.md` overlap.** It already cites four clarification rules by name. Whether it absorbs some of the corrections file, or the corrections file absorbs it, was not checked — the file was not in the reviewed set.

---

## Sequence, if approved

1. Names approved.
2. Create the three files by moving groups whole and the eight Correction-persistence rules individually — atomic move edits, one block per edit, deletion and insertion in the same diff.
3. Reduce `conversations.md` to the index.
4. Move non-operative lines to `magic-librarian/reference/` — same pass or a later one; independent of the split.
5. Librarian conventions-check + tester verification on the result.
6. Symlink the messaging file into `~/.claude/rules/` (human-owner) or `<ws>/.claude/rules/`.
7. Optional: sharpen the 18 boilerplate lines.
