---
maintainers: [magic-coordinator, magic-librarian, magic-architect]
---
# contacts document — `note-20260904T190756Z-contacts.md` format

Normative contract: the human-owner's own contacts-note specification. This file is the derived
skeleton; where the two disagree, the specification wins.

Not a member/routine contract — this is the shape of a **hand-maintained inbox note**, one per
identity that can reach people, written and re-written through `--member-inbox-note-upsert` and
read before any exchange with a non-owner.

# Summary

One note per **contacting identity**, held in that identity's own inbox, recording every person that
identity is in contact with, what we are allowed to say to each of them, and the human-owner's own
standing comments on how to behave with them.

## Goals

- **One note per identity, not per person and not per member.** An identity is a scope that holds
  its own token and therefore its own conversations. A member with a `SLACK_USER_TOKEN` has one;
  the shared `SLACK_BOT_TOKEN` identity has one, in the inbox of the member that holds that token,
  because every member without a token of its own speaks through it and must read the same note.
- A reader can tell, for every contact, which level the row records and where it came from — read from
  `permission-level:` and its `permission-set-*` provenance. `unset` is the state of a **new** contact
  nobody has ruled on; it is not a queue. It leaves the contact fully reachable: tier 1 (ingest) and
  tier 2 (basic) are open, and tier 3 escalates.
- The fields a contact records are the fields a `partner-<organisation>-<role|person>` member would
  need, so conversion later is a promotion of an existing record, not a fresh interview.

## Scope

- Does:
  - Name the identity it is written for, and the contacts reachable through it.
  - Carry the human-owner's set permission level, or state that none is set.
  - Carry the escalation log: what was asked, what he answered, when.
- Doesn't:
  - Hold credentials. Identifiers only — the same rule the session-context document's `identity:`
    line follows.
  - Gate ordinary exchange. It gates one class only — affecting the team board, dispatching jobs,
    requesting internal information. An absent or `unset` level is no **tier-3** permission; ingest,
    gossip, public information, consultation and expertise continue under tiers 1-2.
  - Duplicate a converted member. Once a contact becomes a `partner-*`/`client-*`, the record keeps
    only the pointer and the conversion date.

# Skeleton

Three sections, in this order: `# Index`, `# Contacts`, `# Maintainer Context Data`.

```
---
document-type: contacts
identity-scope: <member whose config holds the token>
identity-kind: <user|bot>
identity-slack-id: <U…|B…, or <unresolved>>
contacts-recorded: <N>
contacts-with-level-set: <N>
last-audit: <UTC timestamp of the comms read this note was populated from>
---

# Index

| slack-id | contact | handle | email | organisation | permission level |
| --- | --- | --- | --- | --- | --- |
| <U…, or <unresolved>> | <stable-slug> | @<handle> | <email, or <unresolved>> | <organisation> | unset |

<- one row per contact. The Slack id leads because it is the key a lookup starts
   from: a sweep delivers `<@U…>`, and the row answers who that is, at which
   organisation, at what level. The full record is under `# Contacts`, at the
   matching `## <stable-slug>`.

# Contacts

## <stable-slug>

slack-id: <U…, or <unresolved>>
handle: <@handle, or <unresolved>>
email: <address, or <unresolved>>
display-name: <as the service shows it, or <unresolved>>
organisation: <organisation, or none recorded yet>
role: <role at that organisation, or none recorded yet>
relationship: <what connects them to us, one line>
conversations: <conversation ids, comma-separated, or none recorded yet>
reached-via: <identity-scope + identity-kind this contact is reachable under>
is-owner: no
permission-level: unset   <- tiers 1-2 open; tier 3 escalates
permission-set-by: <human-owner, or -- >
permission-set-at: <UTC, or -- >
permission-source: <communication-channel-id of his answer, or -- >
prospective-member-id: partner-<organisation>-<role|person>   <- the id conversion would take
converted-to: <member id and UTC date, once converted; absent until then>

### How to meet them well

[The human-owner's own standing comments on this person: what reads as respect, what to avoid,
what stays out of the conversation. `none recorded yet` where nothing is known — the section is present
either way. Same section name and same unknown-marker as the partner/client contract format, so a
conversion carries it across unchanged.]

### Escalations

- <UTC> -- asked: <the one case> -- answered: <his answer, verbatim> -- level after: <level or unchanged>

# Maintainer Context Data

<- how this note is kept: what the last audit covered and what it did not, any
   `**NOTE:** partial` or `**NOTE:** no scan was made` marks, and the reading
   guidance. Last, because a reader whose view was cut needs it least.
```

# Rules

- rule: **`permission-level:` is written by the human-owner's answer only.** No member sets, raises,
  widens or infers one — not from the contact's seniority, not from what a previous exchange got
  away with, not from the note's own silence. The only two truthful states are a level he set, with
  its `permission-set-*` provenance, `basic` where established correspondence puts the contact at tier 2,
  and `unset` for a contact nobody has ruled on yet.
- rule: **The recordable values are the tiers' own words.** `unset` — a new contact, nobody has ruled;
  `basic` — an established contact we already correspond with, at tier 2. `basic` records what is true
  about the correspondence and grants no tier 3; tier 3 stays what the human-owner sets, and a `basic`
  row escalates for it exactly as an `unset` row does. Provenance says which: a level he set carries him
  in `permission-set-by:`, a level that follows from the standing tiers says so instead.
- rule: **`unset` blocks tier 3 only.** Ingest is granted to everyone always; gossip, public
  information, consultation and expertise are basic and need no record, so long as they stay
  non-long-running and non-expensive. A recorded level is required for affecting the team board,
  dispatching jobs, or requesting internal information — and for nothing else. See
  **non-owner-contact-tiers-and-escalation** in `magic-team/magic-team.conversations.md`.
- rule: Contacts are **generally not owners**. `is-owner:` exists so that fact is stated per contact
  rather than assumed either way. The human-owner is recorded as `human-owner`; contacts are the people
  reached through an identity.
- rule: **A tier-3 case with no permission, or not enough, escalates — it does not stop.** The member
  assesses it as granted, needs-escalation, or must-be-denied; where it escalates, it goes to the
  human-owner with **who wants what**, and does not proceed on a best guess. He may allow, deny, or
  reply back so the member gathers more from the contact and continues the loop. Every outcome is an
  `### Escalations` entry the same session. He may resolve the one case only, leaving the level
  `unset`, or set a level. A level comes from him setting one; repeated case-by-case resolutions stay
  recorded as the cases they were.
- rule: **Every escalation is appended, keeping the entries already there.** The level is the current
  state; the escalation log is how it got there, and a level carries the escalation that produced it.
- rule: **The log entry keeps the record on the contact; a digest tells the human-owner.** Every
  assessment this note takes part in — granted, denied or escalated — is written to him as a small
  compact digest opening with the `client-`/`partner-` that received the request — carried in the `to`
  position, as he has ruled — then who wanted what, then the resolution: auto approvals and denials to the
  bot's own conversation with him, cases needing his ruling to his own Slack DM. A relay identifies whose
  words it carries, so the sending account does not stand in for the origin. One event, filed in both
  places.
  See **non-owner-contact-tiers-and-escalation** for the routing.
- rule: One contact appears in **one** identity's note per identity that reaches them. The same
  person reachable under both the user and the bot identity is two records, because what may be said
  can differ by the identity saying it.
- rule: An unknown value is **written out** — `<unresolved>` for an identifier the service did not
  return, `none recorded yet` for a fact nobody has told us. Every key stays present, so a reader takes
  an absent key as a field that does not apply.
- rule: **The order of the three sections is a truncation strategy, not a preference.** The
  session-context document renders an inbox item's body under a byte cap, and the cut takes the
  **end**. `# Index` therefore sits
  first and always survives: a reader whose view was cut still sees every contact, their organisation
  and their level. `# Maintainer Context Data` sits last because it is what such a reader needs least.
- rule: **The index is the mapping surface between what arrives in a sweep and what we know about the
  person.** A reader of it is a human or an agent, and a column earns its place if either needs it to
  perform that mapping, or to decide from the mapped row alone whether to act or to read further.
  The sweep's own key is the **Slack id** — an incoming message carries `<@U…>` and nothing else — so
  `slack-id` leads the row; a lookup that begins with an id cannot start from a handle. `handle`,
  `organisation` and `permission level` are what the mapped row is consulted for; `email` is there
  because nothing in Slack yields an address, so an unrecorded one stays unknown. A column earns its
  place by that criterion, so the criterion is what governs a later change to the list.
- rule: **Both identifiers are optional, and a row carries whichever were known when it was added.** A
  contact first met in Slack arrives with an id and no address; one who arrived by email arrives with an
  address and no id. `<unresolved>` is the normal state for either, and the row is updated with the
  missing one once it is resolved.
- rule: **The index is a fast path, not the authority.** It exists so a lookup is cheap: an incoming
  `<@U…>` is answered from one table, rather than by reading every record or asking Slack. A miss is an
  answer about the table, not about the person — the fast path did not have them yet, and the reader
  falls back to the slower routes below. That is why a missing identifier is an ordinary state and not a
  broken row.
- rule: **A stranger tags a member: the member builds an image of who they are, and that image becomes a
  row.** This is the investigate step of **non-owner-contact-tiers-and-escalation** in
  `magic-team/magic-team.conversations.md`, pointed at an unknown person — working out who tagged you is
  the investigating, not a procedure beside it. The routes, in the order they cost:
  read the conversation the tag arrived in, and its thread, with `--member-comms-slack-read`; search that
  conversation with `--member-comms-slack-search-messages`; read the surrounding history the same way for
  the channels already in hand. What that yields is written as a new contact: a row in `# Index` and a
  `## <slug>` record carrying the id the message brought, the handle, the organisation where it can be
  established, and `permission-level: unset`. The cycle closes there — a miss sends
  the reader to the slow route, the slow route produces knowledge, the knowledge becomes a row, and the
  next lookup is fast.
- rule: **The image is built from what the message and its own conversation carry, and the member says
  plainly what it could not establish.** A member reads and searches conversations it already has in hand;
  a search is scoped to a named conversation, so it covers those conversations rather than the whole
  workspace. Looking a stranger up in the roster, and listing the channels they belong to, are outside
  what a member can do at all. A fact out of reach is written as `<unresolved>` or `none recorded yet` and
  said plainly, rather than left to read as a route that was tried.
- rule: **A lookup by Slack id can miss a row that exists.** Where a contact was added from email and
  their id is still `<unresolved>`, an incoming `<@U…>` matches no row — the person is recorded, under
  identifiers the lookup did not use. A reader that finds no row checks the other identifiers before
  treating the person as new, and writes the resolved id into the row it finds. Same shape as the
  truncation rule above and the empty-index case: absence from one view is not absence from the note.
- rule: **On communicating with a recorded contact over Slack, the member writes the resolved id into
  their row.** The id arrived with the message, so it is known at that moment: a row reading
  `<unresolved>` is filled in there and then, in the same session as the exchange, rather than at a later
  audit. This is what keeps the fast path fast, and it covers the ordinary case as well as the miss —
  contact happening while the row is incomplete is itself the trigger.
- rule: **A truncated view is evidence about the view, not about the contacts.** The whole note is
  readable through the member inbox read path, and a cut body carries its own
  `body-truncated:` mark saying so. A contact absent from a cut view is not absent from the note, and a
  level not visible in a cut view is not `unset` — read the note before concluding either.
- rule: **Handled means re-upserted in place, under the note's own filename.** That filename is a dated
  constant — `note-20260904T190756Z-contacts.md` for the notes that exist today — fixed when the note is
  created and kept unchanged across every update, the way the other persistent notes here are named. This
  note is standing state: it stays in the live inbox root and each update rewrites it there.
