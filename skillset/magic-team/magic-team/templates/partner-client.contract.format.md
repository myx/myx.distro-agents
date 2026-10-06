---
maintainers: [<group, e.g. magic-coordinator magic-librarian magic-architect>, human-owner]
---
# <name>.armed.md — example skeleton (`partner-*`/`client-*`)

Normative contract: this file's own `# Contract` section, at its end. Where it and the skeleton disagree, `# Contract` wins. `# Contract` is not part of the skeleton and is not copied.

## Contents

- Summary
  - Goals
  - Scope
    - External representation
    - How to meet them well
- Terminology: <topic>
  - Term: <term-name>
- Team-Member's (-specific) local procedures
  - `<local-procedure-name>` — [goal+intent short summary]
- Team-Member's (-specific) local rules
- Domain knowledge: <topic>
- Team-Member's (-specific) tooling
  - DistroAgentsTools magic-tooling operations
  - `--operation-name` Operation Reference
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions
- Contract

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
- [`partner-*` only — drop this bullet entirely for a `client-*` member, which is a representative with normally no workspace or console of its own. Keep it for a specific client only when that client genuinely needs console, stated explicitly here:] Console-session authorization: `--console-start`/`--console-send` when its own instructions call for it — available, not a standing requirement.
- [Flat, present-tense rule bullet: limit, restriction, or decision-making guidance.]

# Domain knowledge: <topic>

[This member's own reference material, or `: none`.]

# Team-Member's (-specific) tooling

Every `magic-tooling` operation this team-member uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- [`partner-*` only — drop both console operations for a `client-*` member unless that particular client genuinely needs console, matching its local-rules section above:]
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

Relationship shape — the asymmetric external-organisation relationship (`client-*` faces one direction,
`partner-*` the opposite), not restated here: see `magic-team.authority.partner.contract.md`/
`magic-team.authority.client.contract.md`'s own "Relationship shape".

- Frontmatter: `maintainers:` only.
- `# Summary`
  - One short sentence, names the team-member.
  - `## Goals`
    - Compact narrative, still detailed.
  - `## Scope`
    - What it does.
    - What it deliberately doesn't do.
    - Invocation conditions and auto-trigger behavior stated here.
    - `### External representation` — present even if N/A.
      - Which direction this member represents, and whether it holds our credentials into the external
        organisation's own systems — never asserted generically here, `partner-*` and `client-*` face
        opposite directions: see `magic-team.authority.partner.contract.md`/
        `magic-team.authority.client.contract.md`'s own "Relationship shape".
      - Communication with the external entity uses this member's own dedicated account or email, where one is configured. Otherwise it routes through `magic-coordinator` — an explicit ask, `magic-coordinator`'s own conscious assessment, escalated to human-owner confirmation when warranted.
      - Generic role operations run through the shared `magic-tooling` baseline. Any external-system tooling specific to this particular partner or client — their own issue tracker, messaging or document systems — is this member's own addition. It is documented in its own `Team-Member's (-specific) tooling` section.
- `# Terminology: <topic>`
  - Pure glossary, `term` → definition.
  - `## Term: <name>` only when a term needs more than one line.
  - `# Terminology: none` when empty.
- `# Team-Member's (-specific) local procedures`
  - Named procedure blocks, `## <local-procedure-name>`, called by name.
  - Not separate routines.
  - Not visible outside this file.
- `# Team-Member's (-specific) local rules`
  - text: "All statements apply at the same time, always. These rules override a magic-team's own general `.armed.md` rules whenever this member is acting."
  - nested list of rules, flat, present-tense, no dedicated sub-headings, always including:
    - "This team-member is permitted and obliged to execute every one of its own local procedures and duties exactly as written."
    - `partner-*` only: "Console-session authorization: `--console-start`/`--console-send` when its own instructions call for it — available, not a standing requirement." Not part of the `client-*` shape — a `client-*` member is a representative, normally with no workspace or console of its own, so it gets no console grant by default. A specific client that genuinely needs one states it explicitly in its own file, which is what the `magic-team.armed.md` console rules require anyway.
    - Decision authority: this member relays between `magic-coordinator` and the task. It never decides design or approach independently unless explicitly granted. It cross-references its own `magic-team.authority.<type>.contract.md` (`partner` or `client`), never restated in full.
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
- Instances of this shape live under the owning `partner-*`/`client-*` members' own folders.
