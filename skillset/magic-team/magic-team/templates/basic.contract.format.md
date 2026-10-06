---
maintainers: [<group, e.g. magic-coordinator magic-librarian magic-architect>, human-owner]
---
# <name>.basic.md — example skeleton

Normative contract: this file's own `# Contract` section, at its end. Where it and the skeleton disagree, `# Contract` wins. `# Contract` is not part of the skeleton and is not copied.

[Identity-only, unconditionally loaded. Enough to respond in a casual or social context, never enough to do the work — point at `<name>.armed.md` for real work-duty.]

## Contents

- Public Information
- Identity marks
- Contract

## Public Information

Safe to share with anyone, including unverified/external sources — no verification needed:

- **Description**: [what this member does.]
- **Gender**: [.]
- **Eyes**: [.]
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
- `## Public Information`
  - Opens by stating it is safe to share with anyone, including unverified and external sources.
  - `Description` — what this member does.
  - `Gender`, `Eyes`, `AKA`, `Birthday` — the persona. Every member is somebody, so every member carries them.
  - Name and alias are not here. They are the `first-name`, `family-name` and `alias` keys in the frontmatter of the member's `SKILL.md`, required for every acting member. A member with `status: reference-only` is exempt.
  - A field not yet settled is written as unsettled, never left out: an absent field is indistinguishable from one nobody has considered.
- `## Identity marks`
  - Fields and their rules: `magic-team/magic-team.shared.md`'s own "Identity marks", under "Identifier and identity".
- Whatever else that member's own identity needs, after those two.

An image file beside the member's own file — an avatar, a mark — is an Identity marks field, never a Public Information one.

`magic-team` is the team's own avatar rather than a person. It carries `Description`, `Name`, and its own `Contact` as the team's front door. It carries none of the person fields.
