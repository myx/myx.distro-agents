---
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# no-quorum document — the agreed-and-dissent format

Normative contract: this file's own `# Contract` section. Not a member or routine contract — the
shape of a document one session writes when its own group cannot reach `quorum-all-agree`, per
`magic-team/magic-team.armed.md`'s "The ladder: one rung at a time".

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
- Contract

# Summary

One document, for one matter a group could not agree on: what all agreed, and each member's own
comment or disagreement, sent up to the parent the same way an ordinary handback would go.

## Goals

- Nobody's dissent is silently dropped or folded into a majority's wording.
- The parent reading it sees the same two things every time: the agreed part, and each holdout's
  own case.

## Scope

- Does: shape the one no-quorum document a session writes when "The ladder: one rung at a time"
  finds no quorum.
- Doesn't: carry a verdict. The parent's own ruling, once it rules, is recorded where
  `magic-team/magic-team.armed.md`'s "Knowledge destinations" already says, never inside this
  document.

# Skeleton

```
# No quorum: <matter, one line>

## Agreed
<what every member of the group actually accepts, stated plainly>

## <member-name> — comment
<that member's own argument, in its own words>

## <member-name> — comment
<...>
```

# Contract

- One document per matter. A later round amends it in place; it is never duplicated.
- `## Agreed` holds only what every member of the group actually accepts. A partial agreement is
  stated as what it is, not rounded up to a full one.
- One `## <member-name> — comment` section per member who does not fully agree, in that member's
  own words, never paraphrased by another member.
- Carried up the same way an ordinary ask or handback goes, to the session's own parent.
- No board kind of its own: filed as the body of the item or inquiry already carrying this matter.
  No tooling composes it automatically yet — written by hand until a tooling call exists for it.
- Superseded once the parent rules: the ruling lands per "Knowledge destinations", and this
  document is referenced from then on, never repeated.
