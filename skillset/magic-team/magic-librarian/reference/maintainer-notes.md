# magic-librarian — Maintainer Notes

The body of `# Maintainer Notes` in `magic-librarian.armed.md`. Read it when that file is updated, assessed or tested.

## Contents

- Verbatim-intents and Verbatim-benchmarks convention
- Verbatim-goals (intents)
- Verbatim-tests (benchmarks)
- Librarian Comments
  - Reference
  - Conventions

## Verbatim-intents and Verbatim-benchmarks convention

The authoritative definition every file's pair is authored and checked against.

- The pair is `## Verbatim-goals (intents)` and `## Verbatim-tests (benchmarks)` under the file's own `# Maintainer Notes`, opening with the one team-wide banner: "Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!"
- Files that follow a member or routine contract carry it; other shared files carry none (`magic-team/magic-team.armed.md`).
- **Verbatim-intent**: the file's own single core goal, taken from its stated purpose — not a restated operational rule, and not a mechanism another member owns.
- **Verbatim-benchmark**: a concrete edge case testing that goal — never a rephrased intent, domain trivia, or a test of a mechanism owned elsewhere.
- A test is checked against the whole skillset, not its own file: the rule it tests may live in the baseline.
- A test often quotes a rule word for word. Before changing a rule sentence, search the skillset for it and update every quote in the same pass.
- Neither is paraphrased once written, except through the skillset change rule.

## Verbatim-goals (intents)

- Content that does not match the implementation is never silently deleted or rewritten away — the discrepancy is surfaced to whoever asked for the check, who decides.
- A one-line fix produces a one-line diff, never a rewritten file.
- Every substantive rule, condition, carve-out, or fact that dated language was anchoring survives into the rewrite.
- A conventions-check finding must cite an actual file/line it's checked against — never an invented convention.
- A reviewed formulation fails review if a readback of it drops any intent, detail, or benchmark the original had.

## Verbatim-tests (benchmarks)

- A `MAGIC.md` fix for one stale install command produces a one-line diff, not a wholesale rewrite of the file.
- A proposed rule change that silently drops one of three original benchmarks fails review, even if the wording is otherwise clean.
- A skillset file lands with a rule built to its point, carrying the reasoning that produced it and phrased for weight. It fails the language level and style convention, whether or not every sentence in it is relevant.
- A landed instruction-layer document uses US spelling. It stands as written: not a defect, and not grounds for a rewrite.
- A session prepares a mutation on a project. It reads the touched repo's own `MAGIC.md`, the `util.repository-<namespace>/MAGIC.md` for its namespace root, and the workspace project's own, before trusting anything else in that tree.
- The audit finds a stale rule in another member's file. It reports it and proposes the fix; the edit lands only through the skillset change rule.

## Librarian Comments

### Reference

- `reference/mcp.md` — MCP / JSON-RPC 2.0, including hand-rolled servers.
- `reference/messaging.md` — messaging platforms: size limits, silent truncation, composition.
- `reference/project-inf.md` — `project.inf` install fragments and declared directives the shipped manuals do not carry.
- `magic-developer/reference/` — per-language modules, the same shape as these.
- `magic-team/reference/skill-folder-model.md` — the skill-folder model; `magic-team/contracts/` — the contracts.

### Conventions

- Future reference modules (HTTP, TLS, SSH, ACM.TPL conventions) are created only when a task needs one.
- Open: who may change this file's definition (the maintainer list) is a default extended from the routine-change group, not a confirmed decision.
- A new kind of team log, beyond `board-processed`, is a deliberate decision when a need arises, never a default.
- Lists of rules, operations and tests stay enumerated, never compressed into prose.
