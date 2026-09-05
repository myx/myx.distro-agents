---
maintainers: [<group, e.g. magic-coordinator magic-librarian magic-architect>]
---
# <name>.armed.md — example skeleton (`keeper-*`/`warden-*`)

Normative contract: `magic-team/magic-team.shared.md`'s "Armed & Routine contracts" → Keeper / Warden. This file is a derived skeleton; where the two disagree, `magic-team/magic-team.shared.md` wins.

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
- `DistroAgentsTools.fn.sh` always executes via the `myx.distro` MCP tool `mcp__myx_distro__execute` (argument `command`, the shell script itself) — never Bash, a Python/notebook execution tool, or any other tool that runs a process directly. Any non-mutating, read-only shell command also executes via `mcp__myx_distro__execute` the same way.
- Console-session requirement: doing an actual task with this role-family's own workspace/workspace tooling requires a `--console-start`/`--console-send` session, regardless of command count. Just answering a question or looking at files (not a task) may skip it.
- This keeper relays between `magic-coordinator` and the task, never deciding design/approach independently unless explicitly granted — full policy in `magic-team/magic-team.authority.keeper.contract.md`, cross-referenced, never restated in full.
- [...]

# Domain knowledge: <topic>

[This member's own reference material, or `: none`.]

## Idle-Tasks

[Scheduling policy for this member's idle-run routines — one entry per idle-run `<member>.<name>.routine`, each stating its relative `weight`, its `min-interval` (wall-clock "not more frequent than" cap), and its `scope`. The `## daily-idle-task` procedure selects from this list — weighted-random among eligible entries — never from a directory listing; a routine not listed here is not idle-run. The universal research-own-duties activity is always one more eligible candidate beyond the listed routines. Omit this subsection only if the member has no idle-run routines at all.]

# Team-Member's (-specific) tooling

Every `magic-tooling` operation this team-member uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--console-start [--override-workspace <path>] [--console DistroSourceConsole.sh|DistroDeployConsole.sh] [--ttl <seconds>]`
- `--console-send <channel> [-- <command...>]`
- [`--operation-name <args>`]

## `--operation-name` Operation Reference

[Syntax again, plus every exact description/comment needed to run it correctly.]

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