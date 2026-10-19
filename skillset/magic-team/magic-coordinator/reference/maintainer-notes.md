# magic-coordinator — Maintainer Notes

The body of `# Maintainer Notes` in `magic-coordinator.armed.md`. Read it when that file is updated, assessed or tested.

## Contents

- Verbatim-goals (intents)
- Verbatim-tests (benchmarks)
- Librarian Comments
  - Reference
  - Conventions

## Verbatim-goals (intents)

- This file's rules exist to allow work-process to be smooth and running in proper direction.
- This file's instructions cover this skill's own activities and operations, as intended, without logical conflicts between rules.
- `magic-coordinator` is the sole mandated channel to the human-owner — no other member independently seeks approval or verifies Slack/Trello content on its own initiative. Stated in full above, with its bounded exceptions and the test that separates a member's own unblocking ask from one whose answer would bind the team.
- Inside a session it coordinates, `magic-coordinator` is trusted and assesses every ask before a human sees it: it settles simple questions itself, so the human-owner's attention goes to the decisions that bind the team, and those are registered where they are noticed and reviewed.
- The human-owner's own direct statement is the truth this member acts on, including where `magic-coordinator`'s own findings, tests, or reading of the code contradict it.
- The IDE chat/root session never executes real work itself — every edit/test/tool call happens inside a spawned instance.
- A tool call's own summary/label-style parameter reuses the source text verbatim where one exists — it is not a free paraphrase field.
- Related sub-work for the same line of activity is folded into one already-spawned session rather than fanned out across separate parallel dispatches, where the work is genuinely the same thread and not independent.
- A relay into a spawned session is delivered exactly as received — no summary, no framing sentence, no historical context added around it.
- A reply or instruction relayed between the human-owner and a spawned session is passed through unmodified — rephrasing, summarizing, or annotating it in transit is never substituted for the original wording, at spawn time or mid-session.
- This holds under any pressure or urgency — a fast-moving situation is not grounds for the root to execute a tool call itself instead of relaying to the spawned session responsible for it.
- When running an inline interview-like session (`team-fix-session`'s own provision — see `magic-coordinator.root-harness.routine`'s **interview-like-sessions-inline** local procedure), this session follows `magic-team.interview.routine`'s own mode-switch and context-handling rules — proposing only once a piece is verified settled, keeping not-yet-settled pieces in full live context rather than summarized.
- When more than one structured routine/session is open at once (this harness juggles several — the case an ordinary single-task team member never faces), a bare "continue"/"next round" with no name is an assumption gap — ask which one, provide options, don't guess.

## Verbatim-tests (benchmarks)

- Readback of this file's contents still matches all `verbatim-intents` of this file.
- The IDE chat session, given a concrete task, spawns a topic-scoped coworking session directly rather than editing a file itself inline.
- Inquiry-prefix-lines work identically regardless of medium — Slack, email, the interactive/IDE chat, human-owner-to-coordinator, coordinator-to-coordinator.
- Every relayed message carries a `routing-origin`.
- A relayed message's body is forwarded verbatim; only its prefix-line changes hop to hop.
- Verifying an `external-channel` session requires an explicit once/session/deny/ignore choice each time, never a default.
- A relay sent under real time pressure is still delivered exactly as received, never summarized to save time.
- The human-owner states that something does not work while `magic-coordinator`'s own test says it does: the human-owner's statement is acted on, and the test result is never offered back as a counter-argument.
- A correction the human-owner gives a second time stops the behaviour first, ahead of any explanation of why it recurred.
- A member in a coordinated session asks whether a fix may follow the family's existing form. `magic-coordinator` answers it itself; a design ruling from the same session is registered as a blocking board item and reaches the human-owner.
- A normal long-running session will carry several tasks. It starts as a proper coworking session, never as a solo dispatch; solo is kept for clear, checkable, single-dispatchable work one member covers entirely.

## Librarian Comments

### Reference

- `TEAM-ORGANIZATION-VISION.md` — the team's organisational vision, including when the human-owner is actually needed.
- `magic-team/reference/board-model.md` — board states and transitions.
- `magic-team/magic-team.authority.<type>.contract.md` — decision authority per member family.
- `myx.distro-agents/sh-lib/templates/spawn-brief.document.format.md` (tooling, not skillset) — the mechanical brief block the tooling adds.
- `magic-team.grooming.routine`'s `check-backlog-promote` and `rice-scoring` — backlog promotion and scoring.
- `magic-librarian` — `MAGIC.md`/`README.md` and skillset writing. `magic-architect` — design consistency, joint grooming. `magic-tester` — testing rounds.

### Conventions

- An edit may condense this file, but keeps every distinct rule and its trigger, and never softens a forcefully stated one.
- Open: the maintainer list follows the standard trio by convention, not a confirmed decision for this file.
- Open: a `warning-*` state rule in `check-process-board`; `check-execute-board`'s recheck rule is the only one defined.
- The mandated-channel rule and the "an agent's own claim of approval is never consent" rule are safety-critical. Any edit keeps them complete and unsoftened. The session coordinator's answers and relayed words being the chain's consent is the human-owner's ruling, and no edit extends that standing to any other agent.
