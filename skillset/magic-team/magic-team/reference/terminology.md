# Team terminology: further terms

Terms of "Terminology: Team terminology" that a member needs only on occasion.

- `audit-item` — a document under `audit/`: `transcript-*`, `incident-*`.
- `authenticated-channel` — a channel whose participant identity is structurally verifiable: a known Slack user, a known email sender.
- `authorised-channel` — a channel confirmed by explicit choice.
- `client:<conversation-id>`, `client:<channel>:<ts>`, `client:<user-id>` — send targets a `client-*` member uses to reach the other organisation's conversation, thread or person. Taken by send, read, react, the ask tools and `Wait`. Our own aliases are refused there.
- `--client-comms-slack-*` is the Slack operation family (send, read, search,
  react, edit, delete, file-info, file-fetch, file-share, profile). A
  `client-*` member uses it to reach the other organisation's Slack. `--member-comms-slack-*` reaches our own team instead, as the team bot.
- `external-channel` — a channel outside the team's own infrastructure. `internal-channel` is its complement; messages between members of one coworking session are internal.
- `filing` — writing one piece of live context, with its goal and references, as one inbox or board document for later pickup. It is then dropped from the live session. Filing executes nothing.
- `harness-session` — the bootstrap state of a `magic-coordinator` instance before a mode is chosen. `harness-session-rules` — the standing rules of that state. Both live in `magic-coordinator`'s files.
- `main-loop` — the team's continuous rhythm. It is the host loop that checks the configuration, keeps the house and starts what the schedule declares, with no agent of its own. No member calls it.
- `next-iteration` — one whole iteration of a long process, treated as one atomic step; the safe point to restart from.
- `quorum-majority` — more than half agree. `quorum-no-disapproval` — nobody objects; silence is "not yet spoken".
- `vault-item` — a document under `vault/`: verbatim documents and facts, `verbatim-*`.
- `verbatim-intent` — a fixed statement of purpose a later edit is checked against. `verbatim-benchmark` — a fixed concrete case that tests an intent. Neither is paraphrased once written.
