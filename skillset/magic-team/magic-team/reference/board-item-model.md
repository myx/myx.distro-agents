# Board item model: types, fields, vault and audit items

Read this when creating, moving or reading board, audit and vault items. The inbox types and the inbox frontmatter fields are in `magic-team.armed.md`.

## Contents

- Board types
- Audit and vault types
- Every board item is a tracking document
- Frontmatter fields
- Vault-items, audit-items, referencing and enveloping

**Board types** — only `magic-coordinator` creates or moves them:
- `project-*` — a container for related work (an epic). Children link by `spawns`/`spawned-by`.
- `task-*` — concrete, ready-to-execute work.
- `change-*` — record of a change: What changed / Why / Needs / Files touched.
- `idea-*` — a raw suggestion, below a proposal's bar.
- `proposal-*` — an undecided design: Goal / Approaches considered (two or more) / Recommendation / Open questions. `magic-team.proposal.routine` owns its state changes from the root post to the human-owner's closing reaction; `magic-team.discuss.routine` owns them while the team discusses it among itself. No quorum there follows "The ladder: one rung at a time".
- `interview-*` — work whose core is talking it through with the human-owner. Created in `board-running`; `magic-team.interview.routine` owns its state changes.
- `approval-*` — a live negotiation for the human-owner's go/no-go on another item, reached by "The ladder: one rung at a time". Created in `board-running`, carries `blocks` to the gated item, which waits in `board-blocked`.
- `dispatch-*` — the brief given to one spawned session, carried exactly, plus a dated log of its reports. Created in `board-running`.
- `warning-*` — an open risk, kept visible in an active state until mitigated, accepted or converted. Every spawn brief lists the open ones.

Not types: `talk-*` (use `interview-*`), `approve-*` (use `approval-*`), `epic-*` (use `project-*`), `assignment-*` and `session-*` (use `dispatch-*`), `pending-slack-reaction`/`pending-trello-update` (these are `note-*` records in `magic-coordinator`'s own inbox). A new type is added here first, then to every routine that creates or reads it.

**Audit and vault types**: `transcript-*` (audit; append-only through `--append-transcript`; verbatim messages, UTC stamps; never on the board), `incident-*` (audit), `verbatim-*` (vault).

**Every board item is a tracking document.** It records who worked on it (`participants`) and the state they left it in; a restart spawns that group at that state.

**Frontmatter fields:**
- `author` — task-creation author, where it differs from `from`.
- `blocks`/`blocked-by`, `spawns`/`spawned-by`, `supersedes`/`superseded-by` — relations. Bare item names, no folder, no `.md`, comma-separated without brackets. The dependency recompute keeps both directions of `blocks`/`blocked-by`.
- `approved-by`/`approved-at` — who gave the go, and when. The go is a header fact, not a folder.
- `status` — free-text state label; dropped when stale.
- `recheck-date`/`condition` — when to look again, and what for, on a blocked, parked or retained item.
- `owner-session`/`owner-session-since` — the live session kind holding the item, and since when.
- `session-id` — the active coworking session.
- `participants` — who worked on it, added as they join.
- `restart-session` — members to spawn as a coworking session instead of running inline.
- `review-by` — the reviewer of a `board-review` item. Unset, it is the run's `reports-to`. `none` means no review: the item closes straight to `board-processed`.
- `allows` — the approved permission set the tracked session carries: `session|task:<tool>:<target>:<granted-by>:<YYYYMMDD'T'HHmm'Z'>`, target %-escaped, `granted-by` a holder and not the session's own member. Written by tooling when the set is approved (`--request-permission-set`).
- `tracks` — on a `dispatch-*`, the item its session's work is tracked in.
- `archive: true` — keep this processed item permanently.
- `outcome`/`execution-receipt` — what an advance pass did, and the evidence. Written by `magic-coordinator`.

## Vault-items, audit-items, referencing and enveloping

- A board item is a job. A vault or audit item is not, even when it carries task text.
- Any item may reference another. A board item may reference vault and audit items; the reverse never happens.
- An item may be enveloped into another. An external warning not yet assessed is attached into an `inquiry-*`, the one document that persists and passes between members.
- Not implemented: saving a job's terminal state to the vault. Nothing enforces it yet, and no prefix is constrained. `warning-*` is never a job.
