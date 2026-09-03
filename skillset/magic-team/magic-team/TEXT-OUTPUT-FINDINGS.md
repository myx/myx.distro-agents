# Why the team's text output is unreliable

Investigation on the example of `magic-architect`. Findings apply to every member.

Measured over the whole skillset: 9 members, 44 markdown files, 3,874 rule-bearing lines.

---

## Summary

Four independent causes. Each one alone is enough to produce the failure. They compound.

1. The text rules are reached by prose cross-reference, so a member that skips the hop never meets them.
2. Four of nine `.armed.md` files carry no output-shape instruction at all — and `.armed.md` is the layer that overrides team rules.
3. The two rules that govern exactly this — `relevant-or-fun-fact-only`, `compact-structured-important-first` — are cited nowhere in the skillset. They are the only text rules with zero inbound references.
4. The rules break the rule they state. Rule 40 says instruction text is directive-first and tight; the rules average 117 words and half carry a negation.

Cause 3 is the cheapest to fix and probably the largest single lever.

---

## Evidence

### Load chain (cause 1)

`SKILL.md` → `<member>.basic.md` (unconditional) → prose mention of `conversations.md` and `shared.md` → `armed.md` only "if genuine active-work-duty".

Text rules sit at hop 3. `SKILL.md` never names `conversations.md` or `shared.md`. Its closing line asserts the member "is bound by" them without causing a load.

`magic-team.shared.md` already states the consequence:

> Nothing loads them automatically, so a member that does not comply never meets the rules they carry, and nothing reports that it did not.

Filed as *open, not settled*, awaiting the human-owner. Everything else is downstream of this.

### Output-shape terms per `.armed.md` (cause 2)

| member | output-shape terms present |
|---|---|
| magic-team | compact, narration, water, important first, brief |
| magic-coordinator | compact, narration, brief |
| magic-librarian | compact, narration, water |
| magic-frontender | compact, water |
| magic-tester | verbose |
| **magic-architect** | **none** |
| **magic-developer** | **none** |
| **magic-devops** | **none** |
| **human-owner** | **none** |

`magic-architect.armed.md` states it "follows this file's own rules over `magic-team`'s general `.armed.md` rules" — the strongest override position in the system — and is silent on text shape.

**Checkable prediction:** coordinator, librarian and frontender should already produce visibly better text than architect, developer and devops. If that matches experience, this diagnosis holds and the fix is known.

### Citation weight (cause 3)

Inbound references from anywhere in the skillset, excluding each rule's own definition:

| rule | files citing it |
|---|---|
| `message-shape-is-correctness` | 4 |
| `relevant-or-fun-fact-only` | 0 |
| `compact-structured-important-first` | 0 |
| `slack-post-one-ask-plain-language` | 0 |
| `rule-text-directive-first-and-tight` | 0 |
| `concrete-answers-to-concrete-questions` | 0 |

`message-shape-is-correctness` is the one message rule the librarian actively enforces, the one reinforced from four files, and the one that holds. The rules governing water, narration and history have no inbound edges at all — terminal leaves in the reference graph, each stated once and never invoked again.

### One rule holds without citations (observation)

`slack-post-one-ask-plain-language` has no inbound references either, yet it is the text rule least often broken. The difference is that it is the only one carrying a number — "roughly 10-20 words of real meaning" — so a draft can be checked against it before sending.

`compact-structured-important-first` describes the same property in adjectives: compact, structured, simple. Two rules, one measurable and one not.

Recorded as a finding about which existing rules hold and why. Whether the skillset does anything with it is the human-owner's decision.

### The rules violate the rule (cause 4)

Rule 40, `rule-text-directive-first-and-tight`:

> Lead with command, keep rationale short, avoid narrative preambles in instruction text.

Measured against the skillset's own rule text:

- 49% of rule lines (1,935 of 3,874) contain a negation; 16% carry it inside the first eight words.
- The *Message and reaction discipline* group averages 117 words per rule across 18 rules — 2,106 words for one group.
- The two rules demanding compactness are 143 and 94 words. `address-messages-clearly` is 347.
- Rule 40 itself is filed under *Approval and relay safety*, a group about approvals. Nothing about writing rules lives where rules get written.

A member reading 2,100 words of prose to learn "be compact" has already been shown the opposite.

### Ordering (cause 4, continued)

Ranking each rule by inbound citations and comparing to its position in its own group:

| group | most-cited rule | its position |
|---|---|---|
| Message and reaction discipline | `wtf-reaction-creates-reflection` | 13 of 18 |
| Approval and relay safety | `no-regress` | 8 of 12 |
| Checkpoint loop | `replacing-approved-point-needs-approval` | 8 of 10 |
| Correction persistence | `decision-lands-in-the-document-it-binds` | 5 of 8 |
| Mode and pacing | `dormancy-nudge-once-then-escalate` | 4 of 5 |

Five groups out of eight bury their most-referenced rule in the back half. In an 18-item list, the middle is the worst position for retention — which is exactly where the two compactness rules sit, at 5 and 6.

---

## What to change

Ordered by effect per edit. All of these apply to every member, not to `magic-architect` alone.

### 1. Give the text rules inbound edges

Cite `relevant-or-fun-fact-only` and `compact-structured-important-first` from each member's `.armed.md` local rules, the way `message-shape-is-correctness` is already cited from four files. The mechanism is proven inside this skillset — it is why that one rule holds and its neighbours do not.

Cheapest change in this document. One line per member.

### 2. Convert prohibition to instruction

The rules are positively opened but negatively loaded: a directive, then a run of exclusions. A model given five things to avoid still has no target to hit.

Worked example — rule 50, `concrete-answers-to-concrete-questions`, currently three prohibitions and no positive form:

> A narrow, concrete question gets a narrow, concrete answer. No unrequested recap of what was checked, no restated context, no "next steps" framing.

Converted:

> A narrow, concrete question gets the answer and stops. The answer is the first sentence. Anything that changes what the reader would do next follows it, in one sentence.

The exclusions survive as a separate deletion pass (below), where they are checkable against a finished draft rather than competing with the instruction at compose time.

Same conversion applies to `relevant-or-fun-fact-only`, whose five exclusions are its whole operative content.

### 3. Move `compact-structured-important-first` to the front of its group and cite it

Stated once, cited nowhere, sitting at position 6 of 18. Same treatment as item 1, applied to this rule specifically. Its text stays exactly as written.

### 4. Add a deletion pass, stated last

The exclusions currently sit inside compose-time rules. Move them to a pass run against the finished draft, placed at the end of the file where it is closest to generation:

> Before sending, delete: any sentence describing how the conclusion was reached; any restatement of what was just said; any history where the outcome is what's needed; any count the reader does not need in order to act; any answer to something not asked.

Deletion is verifiable against text that exists. "Write compactly" is not.

### 5. Reorder each group by citation weight

Most-cited first, least-cited last, within every group. The data above gives the order directly. Where two rules tie, the non-obvious one goes first — the obvious rule survives being read late, the surprising one does not.

For *Message and reaction discipline* specifically, the two compactness rules move from positions 5 and 6 to the top, since they govern every message the group is about.

### 6. Move rule 40 to where rules are written, and enforce it against the skillset

`rule-text-directive-first-and-tight` belongs beside `magic-team.armed.md`'s *Rule/instruction/definition/description conventions*, not under *Approval and relay safety*. Relocation only; its text stays as written.

Once it sits there, the librarian's `conventions-check` has it in scope, and the numbers above are what it would be checking against.

### 7. Close the load question

Already framed correctly in `shared.md` as the human-owner's decision. A `.claude/rules/*.md` file without `paths` frontmatter loads at launch, which converts the text rules from read-if-compliant to present-before-acting. Until that lands, items 1-6 raise the odds; they do not make it deterministic.

---

## Two defects found in passing

**Absolute paths that break under the `.agents` root.** `magic-architect/idle-tasks/grooming-scores.idle.md` hardcodes `~/.claude/skills/magic-coordinator/RICE-SCORING.md`, and `shared.md` § *Where the roster lives* hardcodes `ls ~/.claude/skills/*/*.routine.md`. The skillset is also reached through `~/.agents/skills`, where both resolve to nothing. `magic-architect.armed.md` cites the same document relatively. The relative form is the correct one.

**A live contradiction, deliberately unresolved.** `shared.md` § *No rephrasing…* names `rephrase-and-confirm-before-acting`, `rephrase-only-if-meaning-unchanged` and `interview.routine`'s "Rephrase and confirm before acting, every time" as instructing the opposite move, and closes "Nobody on the team resolves this one." Correct per the conflict rule, and a standing source of nondeterministic output while it stands.

---

## Worth keeping

- Step-name citation instead of rule numbers — names survive insertion and reordering, which is what makes item 5 above safe to do.
- `Verbatim-goals` / `Verbatim-tests` in every instruction file — an eval harness already in place, currently unused for text quality.
- `slack-post-one-ask-plain-language`'s word budget — the pattern the other text rules should copy.
- `message-shape-is-correctness` — the reinforcement model that works, and the proof that item 1 is worth doing.
