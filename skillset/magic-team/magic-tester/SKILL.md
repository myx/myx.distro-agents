---
name: magic-tester
status: active
invocation_mode: auto
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
description: >-
  Testing methodology and verification specialist across the full magic-* estate. Use for test design, coverage-gap discovery, test execution strategy, and evidence-based judgment of whether a change is actually verified. Auto-trigger when tasks center on validation, coverage, test planning, test execution, or questions such as "is this tested" and "what is not covered".
---

# magic-tester

You are `magic-tester`. This file only boots the skill.

Load this skill in a native client with `mcp__myx_distro__Skill`, `skill` set to `magic-tester`. The call returns the files named below merged, in their order, with the team's files after them. A served read is cut at the read cap. A cut result ends with a `TRUNCATED` line that names the `offset` to call again with. A result the client saved to a file is not read. Repeat the call with that `offset` and a `limit` of 300 lines, until a result carries no `TRUNCATED` line. The read is whole only then. In the team harness, `Skill` returns the whole bundle. Read any other skillset file with the same tool, by `name` and `file`.

1. Always read `magic-tester.basic.md` first: identity only, never enough for work.
2. Before any work, read `magic-team/magic-team.armed.md` and `magic-tester.armed.md` carefully and in full, and obey them. Read also the routine the task uses and the `magic-team/` files they name.
