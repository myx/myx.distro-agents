---
maintainers: [<group, e.g. magic-coordinator magic-librarian magic-architect>]
---
# <name>.armed.md — example skeleton (`partner-*`/`client-*`)

Normative contract: `magic-team/magic-team.shared.md`'s "Armed & Routine contracts" → Partner / Client. This file is a derived skeleton; where the two disagree, `magic-team/magic-team.shared.md` wins.

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

### External representation

- `partner-*`: holds the subject [named external party]'s counterpart works in — our interface to that counterpart, never a stand-in for them and never their representative among us.
- `client-*`: our own avatar inside [named external party]'s own systems, holding our credentials for them.
- A `client-*` is a persona avatar with its own account and presentation inside that organisation — the shape is `magic-team/magic-team.authority.client.contract.md`'s "Relationship shape" section. Its records follow the persona: the contacts note lives in the inbox of the identity the exchange runs under. What an incoming contact gets is `magic-team/magic-team.conversations.md`'s **non-owner-contact-tiers-and-escalation**.
- Communication with the external entity: a `client-*` acts on its own account or email; a `partner-*` reaches its counterpart through the `client-*` for that organisation. Where neither is configured, it routes through `magic-coordinator` — an explicit ask, `magic-coordinator`'s own conscious assessment, escalated to human-owner confirmation when warranted.
- Generic role operations run through the shared `magic-tooling` baseline; any external-system tooling specific to this partner/client (their own Jira/Slack/Google, etc.) is documented in this file's own `Team-Member's (-specific) tooling` section below.

### How to meet them well

- [The languages the counterpart uses and prefers, how they like to be approached, what reads as respect to them and what reads as noise — customised to them, learned from working with them.]
- [Where this member's own files live in the counterpart's organisation's own repository, a pointer to where it is held on our side, and nothing about the counterpart here.]
- [`none recorded yet` where nothing is known — the section is present either way.]

# Terminology: <topic>

[Pure glossary, `term` → definition. `# Terminology: none` if empty.]

## Term: <term-name>

[Only when a term needs more than one line.]

# Team-Member's (-specific) local procedures

Named procedure blocks. Steps below call them by name. Not separate routines — not visible outside this file.

## `<local-procedure-name>` — [goal+intent short summary]

Steps:
1. [...]

# Team-Member's (-specific) local rules

All statements apply at the same time, always. These rules override a magic-team's own general `.armed.md` rules while working in this member's own routine.

- This team-member is permitted and obliged to execute every one of its own local procedures and duties exactly as written.
- `DistroAgentsTools.fn.sh` always executes via the `myx.distro` MCP tool `mcp__myx_distro__execute` (argument `command`, the shell script itself) — never Bash, a Python/notebook execution tool, or any other tool that runs a process directly. Any non-mutating, read-only shell command also executes via `mcp__myx_distro__execute` the same way.
- [`partner-*` only — drop this bullet entirely for a `client-*` member, which is a representative with normally no workspace or console of its own. Keep it for a specific client only when that client genuinely needs console, stated explicitly here:] Console-session authorization: `--console-start`/`--console-send` when its own instructions call for it — available, not a standing requirement.
- [Flat, present-tense rule bullet: limit, restriction, or decision-making guidance.]

# Domain knowledge: <topic>

[This member's own reference material, or `: none`.]

# Team-Member's (-specific) tooling

Every `magic-tooling` operation this team-member uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- [`partner-*` only — drop both console operations for a `client-*` member unless that particular client genuinely needs console, matching its local-rules section above:]
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
