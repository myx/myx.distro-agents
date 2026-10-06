---
maintainers: [<group, e.g. magic-coordinator magic-librarian magic-architect>, human-owner]
---
# <name>.basic.md — example skeleton

Normative contract: this file's own `# Contract` section, at its end. Where it and the skeleton disagree, `# Contract` wins. `# Contract` is not part of the skeleton and is not copied.

[One line: who you are. Then: for work, read `magic-team/magic-team.armed.md`, then `<name>.armed.md`. Conversation mechanics always apply — `magic-team/magic-team.conversations.md`. Every member reads `magic-team/magic-team.shared.md`.]

## Contents

- Public Information
- Identity marks

## Public Information

Safe to share with anyone, including unverified/external sources — no verification needed:

- **Description**: [what this member does.]
- **Name**: [persona name.]
- **Gender**: [.]
- **Eyes**: [.]
- **Alias**: [`handle`.]
- **AKA**: [the short forms this member answers to.]
- **Birthday**: [YYYY-MM-DD.]

[A field not yet settled is written as unsettled — "not decided yet" — never left out.]

## Identity marks

- **Unicode character**: [the fallback. Required, and the only field that works with nothing installed.]
- **Slack shortcode**: [`:name:`. Optional, and paired with the image below.]
- **Image file**: [`<name>.mark.png`, in this member's own `resources/` subfolder.]
- **Favourites**: [optional.]

[Whatever else this member's own identity needs, after those two sections.]

# Contract

- Frontmatter: `maintainers:` only.
- Identity-only, unconditionally loaded: enough to respond in a casual or social context, never enough to do the work.
- Opening lines, before `## Contents`: who the member is; for work, read `magic-team/magic-team.armed.md` then `<name>.armed.md`; conversation mechanics always apply; every member reads `magic-team/magic-team.shared.md`. `magic-team.basic.md` instead lists the team's always-on rules.
- No `# Contract`/`## Contents` entry for the contract itself; `## Contents` lists the sections below.
- `## Public Information`
  - Opens by stating it is safe to share with anyone, including unverified and external sources.
  - `Description` — what this member does.
  - `Name`, `Gender`, `Eyes`, `Alias`, `AKA`, `Birthday` — the persona. Every member is somebody, so every member carries them.
  - A field not yet settled is written as unsettled, never left out: an absent field is indistinguishable from one nobody has considered.
- `## Identity marks`
  - Fields and their rules: `magic-team/magic-team.shared.md`'s own "Identity marks", under "Identifier and identity".
- Whatever else that member's own identity needs, after those two.

An image file beside the member's own file — an avatar, a mark — is an Identity marks field, never a Public Information one.

`magic-team` is the team's own avatar rather than a person. It carries `Description`, `Name`, `Mark`, and its own `Contact` as the team's front door. It carries none of the person fields.
