---
maintainers: magic-librarian, magic-coordinator, magic-architect, human-owner
---
# Conversation mechanics

The interview-alike checkpoint mode for live exchanges. Binding on every member. Each item is cited by its **step-name**, never its number.

## Contents

- Interview-alike checkpoint mode

# Interview-alike checkpoint mode

Required when any of these hold:
1. **live-interactive-decision-sensitive**: a live exchange where decisions matter.
2. **policy-or-constraint-bearing-step**: a policy- or constraint-bearing step is next.
3. **other-party-asks-confirm-first**: the other party asked to confirm first.
4. **relay-where-drift-alters-authority**: drift in a relay would alter authority or safety.
5. **high-stakes-command-about-to-execute**: a live high-stakes command is about to run.
6. **solo-fork-meets-ambiguity-trigger**: a solo step reaches an **objective-ambiguity-is-stop-condition** fork.

Optional for trivial, low-risk chat; **judgment-gap-propose-and-confirm** still applies.

Checkpoint loop:
1. **readback-approval-next-step**: Read back the next step and wait for explicit approval (`ConfirmReadback` in a dispatched session).
2. **readback-current-scope-present-tense**: Read back only the current decision, present tense.
3. **approved-readback-is-benchmark**: The approved readback is the benchmark until the step closes.
4. **rephrase-only-if-meaning-unchanged**: Stylistic tightening only; a meaning change needs fresh approval.
5. **small-step-loop**: Execute, report, checkpoint the next step.
6. **relay-and-anchor-safeguards-unchanged**: Relay and anchor safeguards still apply.
7. **approval-ask-is-one-finished-message**: An approval ask is one finished message, decision first. If shortening would change intent, ask for a fresh one-line ask.
8. **replacing-approved-point-needs-approval**: Replacing or rewording an approved point needs explicit approval first, stating what is replaced and the new text.
9. **human-owner-correction-overrides-relay**: His correction overrides an earlier relayed instruction.
10. **reject-is-not-stop**: A rejection is not a stop. Read the reason, re-assess, proceed with the correction, or ask "Do I need to stop?".

Policy-bearing changes: wording that changes authority, obligation, scope or safety is proposed and approved before it is applied.
