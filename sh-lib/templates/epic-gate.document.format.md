---
maintainers: magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner
---
# epic gate — the conformance gate a builder sends

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed shape of the gate a builder sends the coordinator before it applies (beat 3 of "How a feature is delivered"). The builder fills it through the tooling; the coordinator checks every line against the spec and its Settled lines. Nothing else goes in a gate.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
- Contract

# Summary

The compact form a builder sends for one feature: the diff path; each statement of the epic mapped to `file:line`; the tests, red on live then green; anything the coordinator must rule; the cases of the economy and script-writes rules left undone. Nothing else.

## Goals

- The coordinator can check every statement of the feature and each of its Settled lines against what was built, from the gate alone.
- A gate that leaves out a part is a gate the coordinator cannot answer yes to.
- Changing the form is an edit to this file, not to the routine.

## Scope

- Does: fix the fields of the gate and their order.
- Doesn't: decide the verdict. The coordinator answers yes, yes-with-changes, or no.

# Skeleton

```
gate: {{feature-id}}

diff path: {{diff-path}}

statements:
{{statements}}

tests, red on live then green:
{{tests}}

the coordinator must rule:
[[{{rulings}}]]

economy and script-writes cases left undone:
[[{{left-undone}}]]
```

# Contract

- rule: `{{feature-id}}` is the feature's id, the word after `## ` in its heading.
- rule: `{{diff-path}}` is the path of the diff the apply will make.
- rule: `{{statements}}` is one line per statement of the feature and each of its Settled lines, mapped to the `file:line` where it is built.
- rule: `{{tests}}` is the feature's tests and those of the files touched, each shown red on live first for its stated reason, then green.
- rule: `{{rulings}}` is anything the coordinator must rule that the spec or its Settled lines do not already decide; the label and its lines are left out together when there is none.
- rule: `{{left-undone}}` is the cases of the economy and script-writes rules left undone; the label and its lines are left out together when there is none.
- rule: every line outside the slots is emitted exactly as written here.
