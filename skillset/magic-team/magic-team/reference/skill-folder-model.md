# Skill-folder model

Read this for how skill folders, routines and skillset files are built and written.

## Contents

- Core idea
- Searching the skillset
- Identifier and identity
  - Identity marks
- Folder shape — the typed-suffix scheme
  - A skillset file is not automatically ours
  - Every typed file is reached by prose instruction
- Duty content only — tooling internals belong to the package, never the skillset
- Armed & Routine contracts
  - Routine
  - Partner / Client
- Nested-item grammar
- Access facts, maintainers and quorum
- Doc/disk mismatch repair loop

## Core idea

- A routine is a named procedure in one `<owning-member>.<short-name>.routine.md` file, hosted in its owner's folder. It is never a member or a skill folder of its own.
- Any member may execute a routine it is asked to run: it reads the procedure from the owner's file and applies its own identity.
- Acting members are the only skill folders: `magic-*`, `keeper-*`, `warden-*`, `partner-*`, `client-*`, `oncall-*`, `expert-*`.

## Searching the skillset

Member folders are symlinks. A bare `grep -R` or `find` returns a clean, false zero. Use `find -L <root> -type f -exec grep … {} +`, with a positive control in the same call.

## Identifier and identity

A member, or the team, may carry two names, and neither is corrected into the other.

- **Identifier** — folder, member id, channel, bot handle, config scope. Mechanical, lowercase, stable.
- **Identity** — the spoken name and mark an outsider sees.

The team's identifier is `magic-team`; its identity is The Conclave. A member's persona belongs to that member, never to the group.

### Identity marks

A member with a persona carries `## Identity marks` in its `.basic.md`; image files sit in its `resources/`. A member with its own mark keeps it. One with none is shown with the default icon of its prefix group instead. The rule is by group, never by one member.

- **Unicode character** — required; the fallback that works everywhere.
- **Slack shortcode** — `:name:`, optional, only together with the image.
- **Image file** — in the member's `resources/`.
- **Favourites** — optional reactions and emojis.

Each field is one list line; its value is the first whitespace-delimited token, ending at a closing wrapper or trailing punctuation. The rest of the line is commentary. The image and the character are one mark: a shortcode that does not match its fallback is a defect.

## Folder shape — the typed-suffix scheme

An acting member's folder holds:

- `SKILL.md` — the boot dispatcher. Its routine: read `<name>.basic.md` first; before any work, read `<name>.armed.md` with the skillset reader, in full, and obey it.
- `<name>.basic.md` — identity, loaded always. Never enough to work.
- `<name>.armed.md` — work-duty content. Its `Scope`, local rules, domain knowledge, tooling list and Maintainer Notes hold everything; no `.access.md`, `.reference.md` or `.tooling.md` exists.
- `<owning-member>.<short-name>.routine.md` — zero or more.
- `inbox/`, `resources/`, `reference/` — as needed.

A folder may be a symlink; resolve the real path before editing.

### A skillset file is not automatically ours

A member's folder may live in a client's or counterparty's repository. Before writing, resolve which repository owns the destination. A fact about an organisation may live in its own repository. Our internal record about them is held in a repository we own: assessments, intentions, what we have not told them. The member's file points to it.

**Every acting member's own files are sufficient on their own**, following their named cross-references. A routine file is sufficient without its owner's other files.

### Every typed file is reached by prose instruction

A member's skill is its `SKILL.md`, `.basic.md`, `.armed.md`, the routine a task uses, and the `magic-team/` files they name. Nothing loads them automatically. A session has not loaded the skill until it has read them and obeys them.

## Duty content only — tooling internals belong to the package, never the skillset

**A duty instruction says how to perform the duty. Nothing else belongs in a skill file.** The test, applied per sentence: can a member perform this step without this sentence? If yes, remove it.

Never in a skill file:
- What a tool does by itself: stamps, commits, garbage collection, retries, the paths and filenames it builds. Also file locations, output formats, and which account or identity it uses.
- Flags a stub forwards, internal operation names, `file:line` citations into package code.
- Unsettled design rationale, platform or vendor caveats, credential names.
- A count or tally. A count belongs in a dated report.

Where such a fact goes:
- Operation behaviour → the package's help pair, read with `--member-help`.
- Package architecture and conventions → the package's own `MAGIC.md`/`README.md`.
- Design rationale and open questions → the owning `keeper-*`'s reference material, or a board item.

A step the tooling cannot yet do is a tooling gap: close it in the tooling, never soften the doc. A gap needing an external account or infrastructure action is escalated as its own decision. A member is told what it passes and what it gets back, never what it cannot do with a mechanism it should not know.

## Armed & Routine contracts

Every `.basic.md`, `.armed.md` and `.routine.md` follows the contract for its kind, stated in full in its contract file's `# Contract`:

- Basic — `contracts/basic.contract.format.md`
- Routine — `contracts/routine.contract.format.md`
- Team-member (`magic-*`) — `contracts/team-member.contract.format.md`
- Keeper / Warden — `contracts/keeper-warden.contract.format.md`
- Partner / Client — `contracts/partner-client.contract.format.md`
- Oncall / Expert — `contracts/oncall-expert.contract.format.md`
- Human-owner — `contracts/human-owner.contract.format.md`

Document formats are all the tooling's own (`myx.distro-agents/sh-lib/templates/`), not the skillset's:
  - the ask templates of the `ConfirmReadback`, `EscalateDecision`, `RequestPermission` and `ProposeApprove` kinds.
  - `session-context.document.format.md`, the generated session sweep report.
  - `no-quorum.document.format.md`, the agreed-and-dissent document "The ladder: one rung at a time" names.

Every section a contract names is present, in contract order, with its lead-in, even when empty: write "none". Fix a gap when the file is next touched.

### Routine

`# Steps`, with its direct synchronous sub-calls, completes before any extended, dispatched or spawned run begins. `# Closure steps` run after all of that finishes. A board-tracked dispatch counts as finished once tracked. Its result still climbs to its own parent only as "The ladder: one rung at a time" directs.

### Partner / Client (`partner-*`/`client-*`)

A `client-*` member's comms are read by the client sweep scan (`client-sweep`), `client-*` only, which the spawner runs. `magic-coordinator.communication-sweep.routine` runs it for every `client-*` member. A `--client-*` operation naming a client runs only for that client in its own session -- nobody else, checked once where the operation is dispatched. `magic-coordinator` reaches it through `--client-operation-run` instead.

## Nested-item grammar

A line bundling two or more separately executable obligations — each with its own action verb and object — becomes a nested list. One action with conditions, details or arguments stays prose.

Three item kinds, in this order:
- `goal:` — intent, never executed.
- `rule:` — in force only inside this branch.
- `step:` — executed in written order.

A list of one kind drops the prefixes and declares the kind on the parent line (`, steps:`). A mixed list prefixes every line. Top-level steps are `<N>. **name-of-meaning**: …`. Moving a nested `rule:` into Local rules widens it; that is a change of meaning.

**Actor phrases**: every step is the executor's. A step naming other members is the executor commanding them, announced in the session thread. It is written inline (`- all participants: state blockers`), or as a prefix line with steps nested under it. A send a step instructs is the executor's unless the step names another actor. What a late joiner must do is a routine local rule.

## Access facts, maintainers and quorum

- **Who runs it**: an acting member states it in `Scope` and Local rules; a routine in its `executors:` frontmatter. An `executors:` entry is a member name, or a team-member contract token. `<type>-*` is all members of that type, selected, failing on none. `<type>-?` is one of that type, selected or specified. `*` or `magic-team` means any member. A `<type>-*` partitions the run into one session per member under one agent-less parent session.
- **Who changes it**: `maintainers:` — always a group. Default `magic-coordinator`, `magic-librarian`, `magic-architect`, adding the domain's keeper or partner where it fits. A change lands by the rule in "Rule/instruction/definition/description conventions": `quorum-all-agree`, in one coworking session.
- **Owner-guaranteed**: a file stating a rule that protects the human-owner's identity, consent and channel, or credential boundary carries `human-owner` in `maintainers:`.
- **Invitees**: routines with multi-member sessions declare `invitees:` — a floor, not a cap. Acting members never declare it. Its entries take the same member-name and `<type>-*`/`<type>-?` tokens as `executors:`, plus the standing-members keyword `all-present-members`. That keyword extends to every member whose `.basic.md` `attendance:` is `present`, and to every `magic-*` member where it says nothing.
- A routine's own executor notes and roster live in that routine's file. Which routines exist: each owner's `.armed.md` Domain knowledge index.

## Doc/disk mismatch repair loop

When a skillset file disagrees with what is on disk, the real source file is corrected. The installed or local tooling copy is never in scope.
