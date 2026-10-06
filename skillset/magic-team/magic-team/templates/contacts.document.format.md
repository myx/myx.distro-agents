---
maintainers: [magic-coordinator, magic-librarian, magic-architect, human-owner]
---
# contacts document — `note-20260904T190756Z-contacts.md` format

Normative contract: this file's own `# Rules` section. Not a member or routine contract: the shape of a standing inbox note, one per member that is in contact with people, written with `--member-inbox-note-upsert` and read before any exchange with a non-owner.

## Contents

- Summary
- Skeleton
- Rules

# Summary

Records every person a member is in contact with, the permission level the human-owner set for each, and his standing comments on how to meet them. Its fields are the ones a future `partner-*` member would need, so a conversion promotes the record.

# Skeleton

Three sections, in this order: `# Index`, `# Contacts`, `# Maintainer Context Data`.

```
---
type: note
from: <member>
date: <date-time>
owner: <member>
last-audit: <date-time of the comms read this note was last populated from>
---

# Index

| slack-id | contact | handle | email | organisation | permission level |
| --- | --- | --- | --- | --- | --- |
| <U…, or <unresolved>> | <stable-slug> | @<handle> | <email, or <unresolved>> | <organisation> | unset |

# Contacts

## <stable-slug>

slack-id: <U…, or <unresolved>>
handle: <@handle, or <unresolved>>
email: <address, or <unresolved>>
display-name: <as the service shows it, or <unresolved>>
organisation: <organisation, or none recorded yet>
role: <role, or none recorded yet>
relationship: <what connects them to us, one line>
conversations: <conversation ids, comma-separated, or none recorded yet>
is-owner: no
permission-level: unset
permission-set-by: <human-owner, or -- >
permission-set-at: <date-time, or -- >
permission-source: <communication-channel-id of his answer, or -- >
prospective-member-id: partner-<organisation>-<role|person>
converted-to: <member id and date, once converted>

### How to meet them well

[His standing comments on this person, or `none recorded yet`.]

### Escalations

- <date-time> -- asked: <the one case> -- answered: <his answer> -- level after: <level or unchanged>

# Maintainer Context Data

[What the last audit covered and what it did not.]
```

# Rules

- rule: Only the human-owner sets `permission-level:`. `unset` is every contact's default: tiers 1-2 are open, tier 3 escalates, per `magic-team.conversations.md`'s **non-owner-contact-tiers-and-escalation**.
- rule: Contacts are not owners unless `is-owner:` says so.
- rule: Every escalation is appended under `### Escalations` the same session; entries are never removed. A case he resolves once stays one case; a level comes only from him setting one.
- rule: One person reached by two members is two records, one in each member's note.
- rule: An unknown value is written out: `<unresolved>` for an identifier, `none recorded yet` for a fact. Every key stays present.
- rule: `# Index` comes first and `# Maintainer Context Data` last, because a cut view keeps the start.
- rule: The index is the fast lookup from an incoming id to a person. A miss is not proof the person is unknown: check the other identifiers and the records first.
- rule: An unknown sender is looked up in the conversation it arrived in, its thread, and that conversation's history (`--member-comms-slack-read`, `--member-comms-slack-search-messages`), then recorded as a new row and record with `permission-level: unset`. What could not be established is written out.
- rule: When exchanging with a recorded contact, fill any `<unresolved>` identifier the exchange brings, in the same session.
- rule: A truncated view is not the note; read the whole note before concluding a contact or level is absent.
- rule: The note is standing state: it stays in the inbox root, rewritten in place under its fixed filename.
- rule: It holds identifiers only, never credentials.
