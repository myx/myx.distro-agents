---
maintainers: magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner
---
# epic apply report — what a builder reports after an apply

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed shape of the report a builder sends after it applies (beat 4, apply, of `magic-team.epic-build.routine`, through the apply tool). The builder fills it through the tooling; the coordinator sets the feature's status line from it. It ends the builder's run.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
- Contract

# Summary

What a builder reports once it has applied on a yes: what was applied, the smoke, the named tests on live, the queued retest, the knowledge lines for the librarian, and the time the work took.

## Goals

- The coordinator can set the feature's status line and its live time from the report alone.
- A reader of an applied line knows which copy of a file was written, and can check the write itself.
- The librarian's queue is fed from the report's knowledge lines, never a loose file.
- Changing the form is an edit to this file, not to the routine.

## Scope

- Does: fix the fields of the apply report and their order.
- Doesn't: apply anything. The apply tool (W2) does that; this is the report after it.

# Skeleton

```
apply report: {{feature-id}}

applied:
{{applied}}

smoke:
{{smoke}}

named tests on live:
{{tests-live}}

queued retest:
{{retest}}

knowledge lines for the librarian:
{{knowledge-lines}}

time: {{time}}
```

# Contract

- rule: `{{feature-id}}` is the feature's id, the word after `## ` in its heading.
- rule: `{{applied}}` is what the apply tool applied, one line per file, and each line carries three things: the file's absolute path, the workspace it belongs to, and a read-back line (`cmp` against the staged file, or its hash). The apply tool prints the absolute path and the read-back on its own lines; the workspace is the repository the apply named.
- rule: `{{smoke}}` is the smoke run's result.
- rule: `{{tests-live}}` is the feature's named tests on live, each shown green.
- rule: `{{retest}}` is the queued retest and its result.
- rule: `{{knowledge-lines}}` are the builder's knowledge lines, queued for the librarian through `AgentLibrarianTools.fn.sh --request-update`, one line each.
- rule: `{{time}}` is the time the work took, as the builder measured it.
- rule: every line outside the slots is emitted exactly as written here.
- rule: a report whose `{{applied}}` names a file without its absolute path or without its read-back is refused by the handback and by a declared relay, and the refusal names what is missing.
