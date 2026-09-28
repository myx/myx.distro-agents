---
maintainers: [<group, e.g. magic-coordinator magic-librarian magic-architect>, human-owner]
---
# <name>.armed.md — example skeleton (`keeper-*`/`warden-*`)

Normative contract: this file's own `# Contract` section, at its end. Where it and the skeleton disagree, `# Contract` wins. `# Contract` is not part of the skeleton and is not copied.

# Summary

[One short sentence, names the team-member.]

## Goals

- [Compact narrative, still detailed.]

## Scope

- Does:
  - [Invocation conditions, auto-trigger behavior.]
  - [...]
- Doesn't:
  - [...]

### Domain anchor

- **Workspace(s)**: [named workspace(s), or "N/A" — name only, never a hardcoded path.]
- **Path/name restriction within that workspace**: [a prefix pattern, an explicit named project list, a namespace, or "none".]
- **Namespace family**: [named cross-workspace family, or "N/A".]

### Tree restriction

[Source-vs-deployed-output split if one exists: name both trees, source only ever hand-edited. Else: "N/A — no deploy-output split in this domain."]

# Terminology: <topic>

[Pure glossary, `term` → definition. `# Terminology: none` if empty.]

## Term: <term-name>

[Only when a term needs more than one line.]

# Team-Member's (-specific) local procedures

Named procedure blocks. Steps below call them by name. Not separate routines — not visible outside this file.

## `daily-idle-task` - pick and run one idle activity, log the outcome

Steps:
1. Select one eligible idle-run routine from this member's own `## Idle-Tasks` section (weighted-random by `weight`, honoring each entry's `min-interval` cap and `scope`); the universal research-own-duties activity is always one more eligible candidate.
2. Run that routine's own procedure — its `<member>.<name>.routine.md` file — following its Steps and Closure steps.
3. Logging the activity and its outcome as a new dated file under `processed/` is the selected routine's own Closure step.

## `<local-procedure-name>` — [goal+intent short summary]

Steps:
1. [...]

# Team-Member's (-specific) local rules

All statements apply at the same time, always. These rules override a magic-team's own general `.armed.md` rules while working in this member's own routine.

- This team-member is permitted and obliged to execute every one of its own local procedures and duties exactly as written.
- Console-session requirement: doing an actual task with this role-family's own workspace/workspace tooling requires a `--console-start`/`--console-send` session, regardless of command count. Just answering a question or looking at files (not a task) may skip it.
- This keeper relays between `magic-coordinator` and the task, never deciding design/approach independently unless explicitly granted — full policy in `magic-team/magic-team.authority.keeper.contract.md`, cross-referenced, never restated in full.
- [...]

# Domain knowledge: <topic>

[This member's own reference material, or `: none`.]

## Idle-Tasks

[Scheduling policy for this member's idle-run routines — one entry per idle-run `<member>.<name>.routine`, each stating its relative `weight`, its `min-interval` (wall-clock "not more frequent than" cap), and its `scope`. The `## daily-idle-task` procedure selects from this list — weighted-random among eligible entries — never from a directory listing; a routine not listed here is not idle-run. The universal research-own-duties activity is always one more eligible candidate beyond the listed routines. Omit this subsection only if the member has no idle-run routines at all.]

# Team-Member's (-specific) tooling

Every `magic-tooling` operation this team-member uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--console-start [--override-workspace <path>] [--console DistroSourceConsole.sh|DistroDeployConsole.sh] [--ttl <seconds>]`
- `--console-send <channel> [-- <command...>]`
- [`--operation-name <args>`]

## `--operation-name` Operation Reference

[Only what the operation's own help, read with `--member-help`, does not carry. Omit this subsection where the help carries it all.]

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- [Abstract goal statement, for conflict testing.]

## Verbatim-tests (benchmarks)

- [Concrete edge-case test.]

## Librarian Comments

### Reference

- [Pointers to this folder's own typed files, cross-referenced skill folders, shared material.]

### Conventions

- [...]

# Contract

Relationship shape — internal domain-knowledge stewardship, not restated here: see
`magic-team.authority.keeper.contract.md`/`magic-team.authority.warden.contract.md`'s own "Relationship
shape".

- Frontmatter: `maintainers:` only.
- `# Summary`
  - One short sentence, names the team-member.
  - `## Goals`
    - Compact narrative, still detailed.
  - `## Scope`
    - What it does.
    - What it deliberately doesn't do.
    - Invocation conditions and auto-trigger behavior stated here.
    - `### Domain anchor` — present even if N/A.
      - Named workspace(s): name only, never a hardcoded path — the workspace registry is the path source of truth.
      - A path/namespace + project-name restriction within it, if any.
      - A cross-workspace namespace family, if any.
    - `### Tree restriction` — present even if N/A.
      - Source-vs-deployed-output split, if one exists: name both trees, source only ever hand-edited.
      - Else: "N/A — no deploy-output split in this domain."
- `# Terminology: <topic>`
  - Pure glossary, `term` → definition.
  - `## Term: <name>` only when a term needs more than one line.
  - `# Terminology: none` when empty.
- `# Team-Member's (-specific) local procedures`
  - text: "Named procedure blocks. Steps below call them by name. Not separate routines — not visible outside this file."
  - nested list of procedures, typically including a `daily-idle-task` procedure, steps:
    - select one eligible idle-run routine from this member's own `## Idle-Tasks` section, weighted by `weight`, honoring each entry's `min-interval` cap and `scope`
    - run that routine's own `<member>.<name>.routine.md` procedure
    - log the outcome as a new dated file under `processed/`, which is the routine's own Closure step
  - Idle tasks are ordinary `.routine.md` files in the member's own folder, never a separate `idle-tasks/` directory.
  - The `## Idle-Tasks` section sits at the end of the member's `# Domain knowledge` in its `.armed.md`. It is the only thing designating which routines are idle-run, and with what weight, min-interval and scope.
  - This same `## Idle-Tasks`-designates-idle-run model applies to any member type carrying idle-run routines, not keepers alone. That covers a `magic-*` team-member and a `partner-*`/`client-*`.
  - A present-non-reporting member's own section additionally states that its routines fire on ad-hoc or grooming dispatch only, never automatic daily fan-out.
- `# Team-Member's (-specific) local rules`
  - text: "All statements apply at the same time, always. These rules override a magic-team's own general `.armed.md` rules whenever this member is acting."
  - nested list of rules, flat, present-tense, no dedicated sub-headings, always including:
    - "This team-member is permitted and obliged to execute every one of its own local procedures and duties exactly as written."
    - "Console-session use: this role-family may open a `--console-start`/`--console-send` session only when its own instructions explicitly require one — this member's own `.armed.md` listing those operations for its domain is that instruction. Otherwise every call goes directly via `mcp__myx_distro__execute`, whatever the command count." Stated to agree with `magic-team.armed.md`'s own keeper exception, which governs.
    - Decision authority: this member relays between `magic-coordinator` and the task. It never decides design or approach independently unless explicitly granted. It cross-references its own `magic-team.authority.<type>.contract.md` (`keeper` or `warden`), never restated in full.
    - this member's own further limits, restrictions, decision-making guidance.
- `# Domain knowledge: <topic>`
  - This member's own reference material, or `: none`.
- `# Team-Member's (-specific) tooling`
  - Every `magic-tooling` operation this member uses, listed with its syntax. Behaviour is read with `--member-help`; an Operation Reference carries only what that help does not.
- `# Maintainer Notes`
  - `## Verbatim-goals (intents)`
  - `## Verbatim-tests (benchmarks)`
  - `## Librarian Comments`
    - `### Reference`
    - `### Conventions`
- Instances of this shape live under the owning `keeper-*`/`warden-*` members' own folders.
