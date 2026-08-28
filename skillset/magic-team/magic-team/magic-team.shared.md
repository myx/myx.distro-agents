---
maintainers: magic-librarian, magic-coordinator, human-owner
---
<!-- MAINTAINED BY magic-librarian — do not edit directly.
     This is the durable, cross-cutting model doc for how the team's skill folders and routines work —
     every acting member's own skill folder (magic-*/keeper-*/warden-*/partner-*/client-*), plus every routine-* virtual
     member hosted inside one of them: the folder-shape spec, the
     typed-suffix file-format conventions, and the executors-vs-maintainers quorum rule. Named
     `magic-team.shared.md` because it's hosted in magic-team's own folder, the same "<owning-folder-
     name>.<type>.md" pattern every other typed file follows. Per-routine-specific content (executor/
     maintainer notes, special-care details) is not duplicated here — it lives natively in each routine's
     own single .routine.md file.
     It also hosts the human-owner's own standing rules (last root section) — the one place they are
     stated in full, because the skillset is the only thing that persists across machines. -->

# Skill-folder model: routine-\* virtual members and the typed-suffix file scheme

This file's own content is binding and obligatory on every team member who reads it — not merely informational or reference material.

## Core idea

Every team routine/activity (`daily`, `grooming`, `retro`, `one-on-one`, `heartbeat`, ..., plus conversational ones like `interview`/`discuss`/`brainstorm`) is a named procedure, not its own Claude Code skill folder. Its full definition lives in one self-contained `.routine.md` file, hosted inside its owning/executing team member's own skill folder (one of `magic-coordinator`, `magic-team`, `magic-librarian`, a `partner-*`), named following that member's own typed-file convention: `<owning-member>.<short-name>.routine.md`. Only acting members (`magic-*`/`keeper-*`/`warden-*`/`partner-*`/`client-*`) are real, separate Claude Code skill folders under `~/.claude/skills/`, each with its own `SKILL.md` — a routine is not, and has no `SKILL.md` of its own.

A routine is executed by whichever member actually runs it — most often its own owning member, but any other member may run it too, by reading that routine's procedure directly out of the owning member's file and applying its own identity/skills while executing the steps. This is what makes `"magic-architect, ingest the task"` a real, distinct thing from `"Magic, ingest the task"` — the same procedure, performed by a different member, produces member-appropriate results.

## Tooling

Read `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section before doing any shell commands.

## Writing code

Any member writing or editing code — in any language, including a shell script, an awk program or a one-off harness — reads `magic-developer/reference/code-craft.md` first, and `magic-developer/reference/shell.md` on top of it for shell and awk. These carry the team's general coding style: the member who happens to be on duty writes the code, so the style has to reach whoever that is. `magic-developer` owns and maintains them; everyone else reads them.

## Human-owner conversations: two identities

- The team bot and a member's own IM account are two separate conversations with the human-owner. A member with no account of its own reaches the human-owner in the bot's conversation.
- Identity defaults to the member's own where it exists, the team bot otherwise; `--identity-bot` is the only modifier, and it selects the bot's conversation on reads, checks and reactions as well as sends — that is how a member with its own account works in the bot's conversation. There is no opposite flag. One exception: message search runs under the member's own identity only and refuses `--identity-bot` outright.

## Folder shape — the typed-suffix scheme

File set:

- **Acting member** (`magic-*`/`keeper-*`/`warden-*`/`partner-*`/`client-*` — the only real, separate folder under `~/.claude/skills/`): `SKILL.md`, `<name>.basic.md`, `<name>.armed.md`, optionally `<name>.shared.md` (see the gated condition below — currently unique to `magic-team`'s own folder, not a routine per-member option), zero-or-more `<name>.<short-name>.routine.md` — each one self-contained, describing one procedure/activity this member owns, never its own folder.

Every acting member (`magic-*`/`keeper-*`/`warden-*`/`partner-*`/`client-*`) skill folder under `~/.claude/skills/` contains — careful: each of these folders may be (and, currently, every `magic-*` member's is) a symlink into the real source tree, not the canonical location itself, so anyone editing resolves the real path first:

- **`SKILL.md`** — the boot dispatcher only. Claude Code's own skill-discovery mechanism requires this exact filename, so it never gets renamed. Standard skill frontmatter (`description`) plus a short dispatch routine: read `<name>.basic.md` unconditionally first (identity-only), then `<name>.armed.md` directly for genuine active-work-duty. A non-active-duty presence wanting to dig deeper than `basic.md` reads `<name>.armed.md`'s own Maintainer Notes → Librarian Comments → Reference subsection, not a separate reference file.
- **`<name>.basic.md`** — identity-only content, unconditionally loaded. Enough to respond in a casual/social context, not enough to actually do the work.
- **`<name>.armed.md`** — professional-readiness content, the one file real work-duty loads after `.basic.md`. Frontmatter: `maintainers:` only (see "Executors vs. maintainers" below) — no `executors:` field; who invokes/runs it is stated in `Scope`'s `Does`/`Doesn't` and `Local rules` prose instead. Section shape depends on role-family — see "Armed & Routine contracts" below.
- **`<name>.access.md`, `<name>.reference.md`, `<name>.librarian.md`, `<name>.tooling.md`** — none of these exist as separate files for an acting member. Their content lives inside `<name>.armed.md`, per the section shape above: who/how/limits/decision-making → `Local rules` + `Scope`; per-member reference material → `Domain knowledge`; the tooling op list → `Team-Member's (-specific) tooling`; the `Verbatim-goals`/`Verbatim-tests` pair and the folder's own knowledge index → `Maintainer Notes`.
- **`<name>.shared.md`** — **only for a folder that hosts genuinely team-wide, broadest-readership content** (this file is the worked example) — named after its own hosting folder, same as every other typed file, not a free-form descriptive title. Hand-authored/librarian-maintained prose, cross-cutting by design — a source other folders' own files may reference directly.
- **`<owning-member>.<short-name>.routine.md`** — zero or more, one per routine this member owns/executes. Section shape — see "Armed & Routine contracts" below.
- **`inbox/`** — created lazily, first time something needs to land there. Same personal-inbox model for every member — reflections a team-member writes while running an activity land in *its own* personal inbox and stay there, unless raised to the board as an `inquiry-*` to `magic-coordinator` (`magic-team.process-inbox.routine`'s "reflection-promotion" rule covers the mechanics).

### A skillset file is not automatically ours

A member's folder lives in whatever repository its own domain lives in, and several sit in a client's or a counterparty's. Resolving the real path is not the whole of it — resolve which repository owns the destination before writing anything into a member's files.

What is safe to write follows from that. A fact about an organisation, in that organisation's own repository, is already theirs. Our own internal record about them — an assessment of a person, how we intend to handle them, what we have not told them — is ours, and in their repository it is one commit from being handed to them. That content is held in a repository we own, and the member's own file points at it.

**The core rule: every acting member's own source files (`.basic.md`/`.armed.md`, plus every `.routine.md` it owns) must be fully sufficient on their own.**
- A folder must work correctly purely from its own source files — that's the baseline the source files are held to, not a fallback path.
- "Sufficient on its own" means readable and actionable following the folder's own stated cross-reference graph, not literally zero pointers elsewhere — a cross-reference is fine when it's explicit and named, and the referencing step stays independently actionable without following it.
- Real work-duty content is loaded by reading `.armed.md` directly, plus whatever it cross-references.
- A routine's own single `.routine.md` file is independently sufficient the same way, on its own, without needing its owning member's other typed files.

### Prose cross-reference versus guaranteed load — open, not settled

Every typed file above is reached by prose instruction: `SKILL.md` says to read `<name>.armed.md`, which says to read the shared team files. Nothing loads them automatically, so a member that does not comply never meets the rules they carry, and nothing reports that it did not.

What the host's own documentation settles:

- Only a skill's frontmatter description is always in context. The `SKILL.md` body enters on invocation; a sibling file enters only if the model chooses to read it.
- An `@import` inside a skill file is not documented as resolved, so it is not an available mechanism there.
- A `CLAUDE.md` may import an absolute or `~`-rooted path, a skill file included. At user scope such imports load without a prompt; a project-level file importing outside its own tree raises a one-time approval dialog.
- A `.claude/rules/*.md` file without `paths` frontmatter is loaded at launch, at the same priority as `.claude/CLAUDE.md`.

So a supported guaranteed-load path exists, and the difference between the two is real: a prose cross-reference binds only a member that complies, while an imported or rules-directory file is in context before the member acts. Which the skillset should use is the human-owner's decision, taken on its own terms rather than folded into other work.

## Duty content only — tooling internals belong to the package, never the skillset

**A duty instruction says how to perform the duty. Nothing else belongs in a skill file.**

If a member does not need a fact **in order to act**, it is not duty content. Specifically never in a
skill file:

- **Flags and arguments a stub forwards** to an underlying operation.
- **Internal operation names** (`--intern-op-*` and anything else a member never calls directly).
- **What a tool does beneath its own interface** — how it scans, what it hardcodes, what it passes on.
- **Design rationale that is still unsettled** — "interim default", "not yet reconciled", "flagged for
  review". A member following a routine at 3am does not need to know the design is in progress.
- **Platform-specific caveats** — a vendor's API limits, required permission scopes, per-service quirks.
  The tooling layer hides them completely, and the same routine may later run against an entirely
  different messaging platform. State a limitation in platform-neutral terms instead, describing what
  cannot be done, never the vendor-specific setting that would fix it. Such a detail is hidden by the
  tooling and is not need-to-know here at all.

### The test

**Can a member perform this step without this sentence?** If yes, it is not duty content — remove it.

Ask it of the sentence, not of the section: a paragraph that is 90% duty content and 10% internals is
not exempt, it is one edit away from correct.

### Where it goes instead

A rule that only forbids leaves a true and useful fact with nowhere to live, and it comes straight
back. Every category above has a real home, and **all of them belong to the package and to the owning
`keeper-*`, not here**:

- **Operation behaviour, arguments, flags** -> the package's own help pair (`Help.<Name>.include` +
  `Help.<Name>.help.md` under the owning package's `sh-lib/help/`). Help pairing is mandatory and the
  owning `keeper-*` already maintains it; this is the operation's real manual.
- **Package architecture and conventions** -> the package's own `CLAUDE.md`/`README.md`.
- **Design rationale, interim choices, open questions** -> the owning `keeper-*`'s own `reference/`
  material, or a board item if it needs a decision. Never an operating instruction.
- **Platform-specific caveats** -> the tooling implementation's own source comments, where the
  encapsulation they belong to actually lives.

### A capability gap gets closed in tooling, not reworded in the doc

When a step cannot do something because the tooling cannot yet do it, the fix is to close that gap in the
tooling — *so that* the skillset never needs detail-awareness of it at all — not to soften how the
limitation is worded. Fill the gap in the tooling so the skillset need not mention the detail.

One carve-out: a gap that needs a real external account or infrastructure action, not just code, is not a
pure tooling fix. Flag it as its own decision point and stop; never pursue it silently.

### Why this rule exists — measured, not asserted

- Renaming **one** internal option forced edits to **three** member-owned files, for a change that
  altered nothing any member does. With internals out of the skillset, the same rename touches **zero**
  skillset files. Documenting internals couples member-owned docs to tooling refactors.
- A routine step carried a self-flagged, unresolved contradiction — its documented scan scope
  contradicted the step's own wording, "flagged, not yet reconciled". The mismatch existed **only**
  because a forwarded flag was documented. Deleting the internals **dissolved** the contradiction
  rather than resolving it: there was never a real conflict, only a leaked detail disagreeing with the
  duty text.

A stated prohibition is also worse than silence when it names the mechanism: *"no caller-facing
`--state`/`--header` override"* tells a member what it cannot do about something it should not know
exists, which invites the question. State the call signature positively instead — what the member
passes, and what it gets back.

## Armed & Routine contracts

Every `.armed.md`/`.routine.md` file follows one of the contracts below, by its own kind. Each is complete and self-contained — read the one that matches, never a diff against another.

**Every section a contract names is present, in contract order, even when empty.** Each carries its own mandatory lead-in paragraph; where there is no content, an explicit "none" line follows it (`# Terminology: none` and `# Domain knowledge: none` express the same rule in the heading). An absent heading is indistinguishable from an unfinished file. Fix an existing gap when that file is next touched, not as a standing sweep.

### Routine (`<owning-member>.<short-name>.routine.md`)

Copyable skeleton: `magic-team/templates/routine.contract.format.md`.

- Frontmatter: `executors:`, `maintainers:`, `invitees:`.
- No `SKILL.md`.
- No `.basic.md`/`.armed.md` split.
- No separate `.access.md`/`.reference.md`/`.librarian.md`.
- `# routine-<name> — the actual procedure`
  - The file's own title line, before `# Summary` — every existing routine file carries one.
  - `<name>` is the routine's own short name, matching its `routine-<name>` identity.
- `# Summary`
  - One short sentence, names the routine.
  - `## Goals`
    - Compact narrative, still detailed.
  - `## Scope`
    - What it does.
    - What it deliberately doesn't do.
- `# Steps`
  - Exact instructions, execute in order, literally as written.
  - A step that can't execute as written: escalate, or fail loud.
  - Exact steps as nested lists; nested lines follow the nested-item grammar below (`goal:`/`rule:`/`step:`).
  - Every root-level step carries a name, in the established shape: `<N>. **name-of-meaning**: …` — names what the step does, never where it sits. Unique within the file.
  - A step is referred to by its name, not its number alone — inside the file and from any other file. A step with no name can only be pointed at by position, and position is the first thing an edit changes.
  - Applied as each routine file is next touched, not as a sweep.
- `# Closure steps`
  - Same shape/discipline as `# Steps`.
  - Runs only after `# Steps`, and everything it extended/dispatched/spawned, have finished.
  - An already-existing closing tail in `# Steps` relocates here verbatim — no invented content.
  - No closing tail of its own: state that plainly, plus a pointer to whatever actually closes it.
  - Sequencing: `# Steps` (including its own direct synchronous sub-calls) completes in full before any extended/dispatched/spawned run begins; `# Closure steps` runs only after all of that finishes.
  - An async, board-tracked dispatch or hand-off counts as complete for this purpose once tracked.
- `# Routine's local procedures`
  - Named procedure blocks, `## <local-procedure-name>`, called by name from `# Steps`.
  - Not separate routines.
  - Not visible outside this file.
- `# Routine's local rules`
  - All statements apply simultaneously.
  - Override a participant's own general `.armed.md` rules while this routine is active.
  - Executor is permitted/obliged to execute every step as written.
  - Participants obey this routine's own rules over their normal ones.
  - Any other rules, exceptions, overrides.
- `# Routine-specific tooling`
  - Every `magic-tooling` operation this routine uses — not more, not less.
  - `## DistroAgentsTools magic-tooling operations`
    - List, with argument syntax.
  - `## <--operation-name> Operation Reference`
    - Syntax again.
    - Every exact description/comment needed to run it correctly, without looking elsewhere.
- `# Maintainer Notes`
  - Not part of a participant's own instructions.
  - `## Verbatim-goals (intents)`
    - Abstract goal statements, for conflict testing.
  - `## Verbatim-tests (benchmarks)`
    - Concrete edge-case tests.
  - `## Librarian Comments`
    - `### Reference`
      - Pointers, folded in from any `.reference.md`.
    - `### Conventions`
      - This file's own conventions.

### Team-member (`magic-*`)

Copyable skeleton: `magic-team/templates/team-member.contract.format.md`.

- Frontmatter: `maintainers:` only.
- `# Summary`
  - One short sentence, names the team-member.
  - `## Goals`
    - Compact narrative, still detailed.
  - `## Scope`
    - What it does.
    - What it deliberately doesn't do.
    - Invocation conditions and auto-trigger behavior stated here.
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
    - "`DistroAgentsTools.fn.sh` always executes via the `myx.distro` MCP tool `mcp__myx_distro__execute` (argument `command`, the shell script itself) — never Bash, a Python/notebook execution tool, or any other tool that runs a process directly. Any non-mutating, read-only shell command also executes via `mcp__myx_distro__execute` the same way." The MCP tool name is stated literally, not abstracted, so a member drifting onto a wrong tool name is detectable by comparison.
    - this member's own limits, restrictions, decision-making guidance.
- `# Domain knowledge: <topic>`
  - This member's own reference material, or `: none`.
  - Owned routines named here (typically a routines-index subsection), each pointing to its own exact `.routine.md` filename — the only place in this file that filename is spelled out.
- `# Team-Member's (-specific) tooling`
  - Every `magic-tooling` operation this member uses, full syntax and behavior.
- `# Maintainer Notes`
  - `## Verbatim-goals (intents)`
  - `## Verbatim-tests (benchmarks)`
  - `## Librarian Comments`
    - `### Reference`
      - This folder's own knowledge index: pointers to this folder's own typed files, cross-referenced skill folders, shared (`*.shared.md`) material.
    - `### Conventions`

- **Floor-doc carve-out — `magic-team` only.** As the team-avatar whose `.armed.md` is every member's baseline, `magic-team` may carry extra top-level sections for genuinely team-wide content, placed between `# Team-Member's (-specific) local rules` and `# Team-Member's (-specific) tooling`. No other member takes this carve-out.

### Keeper / Warden (`keeper-*`/`warden-*`)

Relationship shape — internal domain-knowledge stewardship, not restated here: see
`magic-team.authority.keeper.contract.md`/`magic-team.authority.warden.contract.md`'s own "Relationship
shape".

Copyable skeleton: `magic-team/templates/keeper-warden.contract.format.md`.

- Frontmatter: `maintainers:` only.
- `# Summary`
  - One short sentence, names the team-member.
  - `## Goals`
    - Compact narrative, still detailed.
  - `## Scope`
    - What it does.
    - What it deliberately doesn't do.
    - Invocation conditions and auto-trigger behavior stated here.
    - `### Domain anchor` — present even if N/A.
      - Named workspace(s): name only, never a hardcoded path — the workspace registry is the path source of truth.
      - A path/namespace + project-name restriction within it, if any.
      - A cross-workspace namespace family, if any.
    - `### Tree restriction` — present even if N/A.
      - Source-vs-deployed-output split, if one exists: name both trees, source only ever hand-edited.
      - Else: "N/A — no deploy-output split in this domain."
- `# Terminology: <topic>`
  - Pure glossary, `term` → definition.
  - `## Term: <name>` only when a term needs more than one line.
  - `# Terminology: none` when empty.
- `# Team-Member's (-specific) local procedures`
  - text: "Named procedure blocks. Steps below call them by name. Not separate routines — not visible outside this file."
  - nested list of procedures, typically including a `daily-idle-task` procedure: pick one candidate at random from this member's own `idle-tasks/*.idle.md` list, run only that candidate's own instructions, log the outcome as a new dated file under `processed/`.
- `# Team-Member's (-specific) local rules`
  - text: "All statements apply at the same time, always. These rules override a magic-team's own general `.armed.md` rules whenever this member is acting."
  - nested list of rules, flat, present-tense, no dedicated sub-headings, always including:
    - "This team-member is permitted and obliged to execute every one of its own local procedures and duties exactly as written."
    - "`DistroAgentsTools.fn.sh` always executes via the `myx.distro` MCP tool `mcp__myx_distro__execute` (argument `command`, the shell script itself) — never Bash, a Python/notebook execution tool, or any other tool that runs a process directly. Any non-mutating, read-only shell command also executes via `mcp__myx_distro__execute` the same way." The MCP tool name is stated literally, not abstracted, so a member drifting onto a wrong tool name is detectable by comparison.
    - "Console-session requirement: doing an actual task with this role-family's own workspace/workspace tooling requires a `--console-start`/`--console-send` session, regardless of command count. Just answering a question or looking at files (not a task) may skip it."
    - Decision authority: this member relays between `magic-coordinator` and the task, never deciding design/approach independently unless explicitly granted — cross-references its own `magic-team.authority.<type>.contract.md` (`keeper` or `warden`), never restated in full.
    - this member's own further limits, restrictions, decision-making guidance.
- `# Domain knowledge: <topic>`
  - This member's own reference material, or `: none`.
- `# Team-Member's (-specific) tooling`
  - Every `magic-tooling` operation this member uses, full syntax and behavior.
- `# Maintainer Notes`
  - `## Verbatim-goals (intents)`
  - `## Verbatim-tests (benchmarks)`
  - `## Librarian Comments`
    - `### Reference`
    - `### Conventions`
- Landed instances of this shape exist under the owning `keeper-*`/`warden-*` members' own folders.

### Partner / Client (`partner-*`/`client-*`)

Relationship shape — the asymmetric external-organisation relationship (`client-*` faces one direction,
`partner-*` the opposite), not restated here: see `magic-team.authority.partner.contract.md`/
`magic-team.authority.client.contract.md`'s own "Relationship shape".

Comms-sweep for any `client-*` member reads via `--client-sweep-input-scan <member> [--comms-since-utime <v>|--comms-since-date-time <v>]` — already generic, already per-member-credentialed. No wrapping check→analyze→act→reply-if-warranted routine around it exists yet for any member of this shape.

Copyable skeleton: `magic-team/templates/partner-client.contract.format.md`.

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
      - Communication with the external entity: this member's own dedicated account/email if configured; else routes through `magic-coordinator` — an explicit ask, `magic-coordinator`'s own conscious assessment, escalated to human-owner confirmation when warranted.
      - Generic role operations run through the shared `magic-tooling` baseline; any external-system tooling specific to this particular partner/client (their own Jira/Slack/Google, etc.) is this member's own addition, documented in its own `Team-Member's (-specific) tooling` section.
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
    - "`DistroAgentsTools.fn.sh` always executes via the `myx.distro` MCP tool `mcp__myx_distro__execute` (argument `command`, the shell script itself) — never Bash, a Python/notebook execution tool, or any other tool that runs a process directly. Any non-mutating, read-only shell command also executes via `mcp__myx_distro__execute` the same way." The MCP tool name is stated literally, not abstracted, so a member drifting onto a wrong tool name is detectable by comparison.
    - `partner-*` only: "Console-session authorization: `--console-start`/`--console-send` when its own instructions call for it — available, not a standing requirement." Not part of the `client-*` shape — a `client-*` member is a representative, normally with no workspace or console of its own, so it gets no console grant by default. A specific client that genuinely needs one states it explicitly in its own file, which is what the `magic-team.armed.md` console rules require anyway.
    - Decision authority: this member relays between `magic-coordinator` and the task, never deciding design/approach independently unless explicitly granted — cross-references its own `magic-team.authority.<type>.contract.md` (`partner` or `client`), never restated in full.
    - this member's own further limits, restrictions, decision-making guidance.
- `# Domain knowledge: <topic>`
  - This member's own reference material, or `: none`.
- `# Team-Member's (-specific) tooling`
  - Every `magic-tooling` operation this member uses, full syntax and behavior.
- `# Maintainer Notes`
  - `## Verbatim-goals (intents)`
  - `## Verbatim-tests (benchmarks)`
  - `## Librarian Comments`
    - `### Reference`
    - `### Conventions`
- Landed instances of this shape exist under the owning `partner-*`/`client-*` members' own folders.

### Oncall / Expert (`oncall-*`/`expert-*`)

Copyable skeleton: `magic-team/templates/oncall-expert.contract.format.md`.

- Frontmatter: `maintainers:` only.
- `# Summary`
  - One short sentence, names the team-member.
  - `## Goals`
    - Compact narrative, still detailed.
  - `## Scope`
    - What it does.
    - What it deliberately doesn't do.
    - Invocation conditions and auto-trigger behavior stated here.
    - `### Engagement shape` — present even if N/A.
      - Not a standing team member: a costed, external AI-service resource, spawned into a billed pay-per-time session, brought in to boost/accelerate one specific, complicated task.
      - Domain of expertise: the specific type(s) of work this member is brought in for — not a workspace, a work-type.
      - Remote execution account info: this member's own settings name whatever account/credential the billed remote service is actually reached through.
      - Spawn trigger, cost/billing tracking, and session lifecycle: not yet defined team-wide — state whatever this specific member's own instructions already settle, flag the rest as open.
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
    - Decision authority: this member relays between `magic-coordinator` and the task, never deciding design/approach independently unless explicitly granted — cross-references its own `magic-team.authority.<type>.contract.md` (`oncall` or `expert`), never restated in full.
    - this member's own further limits, restrictions, decision-making guidance.
- `# Domain knowledge: <topic>`
  - This member's own reference material, or `: none`.
- `# Team-Member's (-specific) tooling`
  - Every `magic-tooling` operation this member uses, full syntax and behavior.
- `# Maintainer Notes`
  - `## Verbatim-goals (intents)`
  - `## Verbatim-tests (benchmarks)`
  - `## Librarian Comments`
    - `### Reference`
    - `### Conventions`
- No live `oncall-*`/`expert-*` member exists yet — roster category reserved, this contract applies once one is created.

### Human-owner (`human-owner`)

Copyable skeleton: `magic-team/templates/human-owner.contract.format.md`.

A non-acting identity record that nonetheless carries one real, invocable procedure — not an inert reference stub, and not an executor.

- Frontmatter: `maintainers:` only.
- `# Summary`
  - One short sentence, names the record.
  - `## Goals`
    - Compact narrative, still detailed.
  - `## Scope`
    - What it does — the reference point other files use for "the human-owner" as a role, plus the invocable procedure for contacting them.
    - What it deliberately doesn't do — never loaded to generate human-owner speech, replies, or actions; no auto-trigger, no dispatch path, and none should exist; holds no actual contact details.
    - Authority is *described* here in one line — final say on conflicts, ambiguities, and escalations the team can't settle; approval for anything outside a member's own mandate — immediately followed by the pointer naming `magic-coordinator/TEAM-ORGANIZATION-VISION.md` as its only home. Never re-derived or restated. No `### Authority` subsection: a `Scope` bullet, nothing more.
- `# Terminology: <topic>` — or `: none`.
- `# Team-Member's (-specific) local procedures`
  - Named procedure blocks, `## <local-procedure-name>`, called by name.
  - Always includes `reach-human-owner` — how a session actually contacts the human-owner asynchronously when they're needed but not present.
  - Not separate routines. Not visible outside this file.
- `# Team-Member's (-specific) local rules`
  - text: "All statements apply at the same time, always."
  - flat, present-tense bullets, always including:
    - "Never impersonate the human-owner." No exception, no maintainer carve-out, ever.
    - Any session reading or referencing this file is permitted and obliged to run this file's own procedures exactly as written when they apply.
    - Carries no member-execution bullet of its own: this record never executes anything itself — its procedures are run by the referencing session, under that session's own `magic-tooling` rules.
- `# Domain knowledge: <topic>` — or `: none`.
- `# Team-Member's (-specific) tooling`
  - Every `magic-tooling` operation this record's own procedures invoke, full syntax and behavior. `none` only when no procedure invokes any.
- `# Maintainer Notes` — same shape as every other contract. The `## Verbatim-goals (intents)`/`## Verbatim-tests (benchmarks)` pair is where the authority-role intent is anchored — not a `Scope` subsection, and never a copy of the vision doc.
- One member only. Not a family; no second `human-owner`-shaped member exists or is expected.

### Session-context document (`# Session Sweep Report`)

Copyable skeleton: `magic-team/templates/session-context.document.format.md`.

Not a contract — the shape of a **generated** document, produced by tooling and read by a session at its start. Nothing writes it by hand, and no session calls the producing operation directly: each routine/member invokes its own stub, and each stub requests exactly the scopes its own invocation place needs.

- `# Session Sweep Report`
  - `## Contents & Abstract` — `generated-for`, `generated-at`, the scopes actually requested, and the comms cut-off in force (or that none was set).
- `# New Incoming Communications`
  - Carries `**NOTE:** no new incoming communications` only when every requested comms sub-section is empty.
  - `## Incoming IM Updates` (cap 128), `## Incoming Email Updates` (cap 128), `## Incoming Trello Updates` (cap 64).
- `## Active Inbox Inquiry Items`, `## Current Inbox Reflections`, `## Current Inbox Notes` — cap 32 each, sorted by file modification time, newest first.
- `## Board Items` — inserted into this structure keeping the existing `--*-input-scan` per-item shape (`## <state>/<item-filename>` then its frontmatter). Never restructured, and **never capped**: the board is the work list, and silently dropping part of it is the failure this document exists to prevent.
- Every section carries its items or exactly one `**NOTE:**` line, and never neither. The single permitted combination is items plus a `**NOTE:** partial — …` line.
- Three distinct `**NOTE:**` forms, never interchangeable: *no new X* (looked, found nothing), *not requested* (never looked), *no scan was made — <reason>* (asked, could not look). That distinction is the document's own reason to exist: an empty result and an unperformed scan must never read alike.
- **Form 1 always carries a denominator and its filter** — `no new X — scanned <N> items, <M> matched <filter>`. It is the only form asserting a fact about the world rather than about the process, so it is the only one that can be wrong while looking right. Without the denominator, a broken filter and an empty tree render identically: the `--owner` extraction defect (0 of 256 items) would have read as a truthful "no board items".
- A section with plural sources carries `sources-scanned: <N> of <M>`, and when `N < M` also a `**NOTE:** partial — <source> not scanned, <reason>` beside its items — a populated section must still be able to report that something underneath it failed.
- The aggregate `no new incoming communications` fires only when every requested comms sub-section is **empty and successfully scanned**; an unscannable sub-section is unknown, not empty, and blocks it.
- Each comms sub-section states its own `identity:` before its `instrument:` — the account that sub-section was read through, and the member whose config supplied the credentials. Identifiers only (a Slack user id, an email address, a Trello username and id); credential values never appear in the document.
- Each comms sub-section states its own `instrument:` — the services differ (Slack takes a cut-off and has no unread flag; email and Trello have unread and take no cut-off), so a single global cut-off line cannot describe what was actually used.
- Every item block states its type name and id on its heading line.
- Shell-readable, human-readable and agent-readable at once: stable headings, one item per block, `key: value` lines, blank line between blocks.
- The inbox sections carry `note-*`/`inquiry-*`/`reflection-*` only — **by design, not omission**. Other types are technically allowed in an inbox and are not misfiled; they are simply not carried, because no step stores them there or takes them from there. The sections cover what steps store. `magic-team.process-inbox.routine` is the one consumer that does not enumerate, its job being whatever actually landed.
- Recorded gaps live in the skeleton file, stated rather than solved — `assignee` not existing in the entity model, and the uneven per-service cut-off support that makes lagging pointers the sanctioned mechanism.

## Nested-item grammar

How a nested list under an instruction declares what each of its lines *is*. Applies to any nested instruction list in a skillset file — a routine's `# Steps`/`# Closure steps`, and the `Steps:` lists inside any member's or routine's own local-procedures blocks — not only `.routine.md`.

### When conversion is required

A line's own text converts to this grammar the moment it bundles **two or more distinct, separately-executable obligations** in one sentence or run-on clause — "separately-executable" meaning each has its own action verb and its own object/target, such that dropping any one of them still leaves the others meaningful and independently checkable as done/not-done.

Qualifies, any one of:
- Sequential actions joined by "then"/"before"/"after"/"once …, …", each naming a distinct action (e.g. "check X then process Y").
- Parallel obligations packed into one sentence via "and"/comma-listing/semicolons, each governing its own distinct verb and object (e.g. "reference X instead of copying it, write it via upsert, and call refresh periodically").
- A `goal:`, a `rule:`, and a `step:` folded together into the same sentence instead of stated as separate lines.

Does not qualify — stays flat prose, no nested list required:
- A single action with a subordinate conditional/qualifying clause attached ("if X, do Y" / "do Y, unless Z") — one obligation, one action verb, one object.
- A single action elaborated with descriptive detail, rationale, or a parenthetical aside that names no separate action verb of its own.
- A single action naming several parameters/arguments to one call (e.g. "call X with A, B, C") — one obligation, one verb.
- A second clause that only restates, negates, or states the consequence of the first, naming no new action ("X, not Y" / "X — never Z").

**Mechanical test**: count the distinct action verbs in the line's own sentence(s) that each govern their own separate object and are independently completable. Two or more → convert, using the notation below. Exactly one, however many conditions/qualifiers are attached to it → leave as prose.

Three item kinds:

- `goal:` — intent, not an instruction. What this branch is trying to achieve. Goes first; may be several; never executed.
- `rule:` — a rule in force **only inside this branch**, only once it is entered. Order-independent.
- `step:` — an ordered instruction, executed in the order written.

Order within one nested list: goals, then rules, then steps.

**Prefixes are dropped when every line in that list is the same kind** — declare the kind once, on the parent line's own trailing clause, instead: `, goals:` / `, rules:` / `, steps:`. A list mixing kinds prefixes every line.

```
1. **name-of-meaning**: some step, condition, then:
   - goal: what this branch is for
   - rule: some branch-local rule text
   - step: sub-step 1
   - step: sub-step 2
2. **other-name**: some step, condition, steps:
   - sub-step 1
   - sub-step 2
```

Same grammar at any depth. Top-level steps are not prefixed — they keep `<N>. **name-of-meaning**: …`.

Nested steps are normally not named. **Name them when the parent is a named group of meaning whose children need to be addressable one at a time** — in discussion, and in the executor's own orchestration of them (`magic-team.coworking.routine`'s **session-start**/**close-session** groups are the worked example). Then the parent declares the kind once with `, steps:` and each child carries its own `**name**:`. Note what this is *not*: another file referencing that work names the whole section (`magic-team.coworking.routine`'s Steps / Closure Steps), never a child. The names are handles for working inside the file, not cross-file entry points.

### Actor phrases

**Every step is the executor's.** A step naming other members is a script for the executor: it orchestrates and commands the work, and announces it in the session transcript so the orchestration is visible. There is no second actor running steps of its own.

**A send a step instructs is the executor's too, and goes under the executor's own identity** — an opening or closing post, a status update, a reaction. The bot carries it only where that member has no identity of its own; being unable to reach the destination is not that case. A step naming a different actor overrides this, and nothing else does. It governs instructed sends only: what a participant says on its own account, in its own voice, is not a step and is not constrained here.

An actor phrase says *whom the executor commands*, in plain language. Two forms:

- **Inline**, for a single short step — the phrase, a colon, the instruction:
  `- all participants: state today's blockers in the thread`
- **Prefix line**, when the same actor governs several steps — the phrase, a colon, the steps nested under it:
```
   - all participants do that:
        - execute that and this like that
        - step 2
```

The prefix line is itself a `step:` — the executor's instruction to orchestrate what is nested under it — so no kind prefix is needed on it or on its children. An actor phrase is not a fourth kind: it modifies a step, it does not replace `goal:`/`rule:`/`step:`.

A step with no actor phrase is the executor's own work, done directly.

**Joining mid-session is not covered by this notation.** An actor phrase never means "a member who arrives later runs the steps it missed." What a fresh joiner must do is stated as a routine rule, in the routine's own `# Routine's local rules`.

**A nested `rule:` is not a Local rule.** `# Routine's local rules` are in force for the whole routine, always, all at once. A `rule:` is in force only within its own branch. Moving one up into Local rules widens what it governs — a change of meaning, never a tidy-up. Moving a Local rule down into a branch narrows it, the same error mirrored.

## `.access.md` content lives in `.armed.md`

`.access.md` does not exist as a separate file for an acting member. The who-may-run-this / who-may-change-this / how-it's-invoked / limits / decision-making facts live inside `<name>.armed.md`:

- **Who may run this** — `## Scope`'s `Does`/`Doesn't` (invocation conditions, auto-trigger behavior) and, where relevant, a plain rule bullet in `Local rules` (e.g. a keeper stating it relays to `magic-coordinator` rather than deciding independently). This also governs who may read/write files in this folder, including its `inbox/` (per-item-type, intersected with the posting member's own rules — see `magic-team.process-inbox.routine`'s own Local rules).
- **Who may change this** — the `maintainers:` frontmatter field. Always a group, never a single owner (see "Executors vs. maintainers" below).
- **How it's invoked, limits/restrictions, decision-making** — flat, present-tense bullets in `# Team-Member's (-specific) local rules`. No formal required sub-headings anymore (no dedicated "Who may run this" / "Limits" / "Decision-making" sections) — read the whole section; the relevant rule is wherever it naturally falls.

A folder can still declare finer-grained, folder-specific rules (rate limits, cost/resource caveats, special-case permissions) the same way — as additional `Local rules` bullets, not a separate `Constraints` section.

**Format note**: frontmatter/body can carry comments, not just bare key-value fields — use them to annotate/explain a choice inline where it helps a future reader understand *why* a rule is what it is, not just what it is. Don't over-use this to pad the file — reserve it for genuinely non-obvious choices.

### Routine access facts (a routine's own frontmatter, not a separate file)

- Unlike an acting member, a routine declares `executors`/`maintainers`/`invitees` as real frontmatter fields directly in its own `.routine.md`.
- `executors: *` and `executors: magic-team` are equivalent, valid shorthand for "any member," for a routine where eligibility is genuinely open rather than a fixed roster.
- The equivalent prose (how it's invoked, limits, decision-making) lives inside that same file's `# Steps`/`# Routine's local rules` sections.
- `invitees` is the one frontmatter field an acting member's own `.armed.md` never carries — see "Invitees" below.

### Executors vs. maintainers, and the maintainer quorum rule

**Two distinct roles, not one "who may run it" field:**
- **Executors** — who may actually run/execute the folder's activity day to day. For most current structured routines this is `magic-coordinator` alone, since they're coordinator-orchestrated. A routine states this as a real `executors:` frontmatter field; an acting member states it in prose (`Scope`/`Local rules`) instead, since `.armed.md` carries no `executors:` field.
- **Maintainers** — who may change/update the definition itself (a member's `.armed.md`, or a routine's own `.routine.md`, or anything else that defines its behavior) — always a **group**, never a single owner acting unilaterally. Reasonable default group: `magic-coordinator` + `magic-librarian` + `magic-architect` (the same three-perspective shape already used for triage/grooming authority) — adjust per folder/routine when a different group genuinely makes more sense (e.g. one deeply specific to one domain might reasonably add that domain's keeper/partner to its maintainer group), using judgment, not a rigid one-size-fits-all list.

**A quorum change is run as a coworking session, not as a poll.** Spawn `magic-team.coworking.routine` with the quorum group as its participants and the involved specialists as invitees — never dispatch one member to collect approvals from the others one at a time. The agreement is reached in the session, in one visible thread.

Maintainer agreement is `quorum-all-agree` unless that definition states otherwise. **It never lands the change by itself** — the human-owner confirms it through the process flow. In a harness session the human-owner's own accept/commit is that confirmation; otherwise ask over IM or the session's own thread and wait for the reply.

**Maintainers act as a group quorum for change/update — not any single maintainer unilaterally editing the folder's own definition.** `quorum-all-agree` among the maintainer group is required before the definition actually changes — same spirit as the team's existing three-person triage-authority-group pattern (`magic-team.board.md`'s triage process), generalized here to skill-folder-definition changes specifically. This doesn't block *executing* the activity (executors do that freely, per their own role) — it only gates changing what the activity *is*.

### Owner-guaranteed rules

A rule is `owner-guaranteed` when it protects the human-owner's own position against the team — their identity, their consent and sole channel, or their credentials boundary.

- A skillset file stating one carries `human-owner` in its `maintainers:`.

### Invitees (routines only)

**A third role, distinct from executors/maintainers** — who a session under this routine pulls in alongside its executor.
- Only routines with genuine multi-member sessions (e.g. `magic-team.coworking.routine`) declare it, in that routine's own `.routine.md` frontmatter; acting members (`magic-*`/`keeper-*`/`warden-*`/`partner-*`/`client-*`) never declare `invitees` — their own `.armed.md` frontmatter carries `maintainers:` only.
- Floor, not a cap — a session may pull in others as needed beyond the declared roster.
- Concrete roster and specifics live in each routine's own `.routine.md` file — read it directly rather than expecting a central table to summarize it.

## Doc/disk mismatch repair loop

If the human-owner flags a doc/disk mismatch directly, or a session notices staleness itself, the fix is to correct the real source file directly. Scope: a skillset file's own content disagreeing with what is actually on disk — never the installed/local copy of the tooling, which "Never mention local-cache sync staleness" below puts out of bounds entirely.

## Two independent dimensions (pointer, not duplicated)

Full write-up lives in `magic-team.board.md`'s "Two independent dimensions: item types vs. routines/activities" section — workflow queue item *types* (`task-`, `inquiry-`, `reflection-`, ...) and team routines/activities (`daily`, `grooming`, `interview`, ...) are orthogonal axes, not one taxonomy. The `routine-<name>` term-family is this file's territory; item types stay `magic-team.board.md`'s.

## Where the roster lives

- There is no roster table in this file.
- Every routine's own non-default executor/maintainer notes, invitee roster, special-care content, and design rationale live natively inside that specific routine's own `.routine.md` file (frontmatter plus body) — read it directly for its current, authoritative shape rather than expecting a central table to summarize it.
- A live enumeration of which routines exist: each owning acting member's own `.armed.md` names its owned routines and their exact filenames, typically in a routines-index subsection of its own `Domain knowledge` (e.g. `magic-coordinator.armed.md`'s `## Routines (index)`) — the only in-file source of truth for that.
- On disk: `ls ~/.claude/skills/*/*.routine.md` across every acting member's folder — but per the team's own "trust the cache, don't rediscover" discipline, prefer reading the `.armed.md` sections already surfaced in the skill-discovery listing every session gets.

# Human-owner's standing rules

The human-owner's own standing corrections. Binding on every member, in every session, whether or not the rule's subject matter is that member's own domain.

They are stated here, in full, because the skillset is the only thing that carries them forward — an agent's own private memory does not. Each rule below is stated as present-tense instruction text.

An instruction is approved by being committed, and committed instruction text is verbatim by that fact alone — his words written into a file and the file's own words carry identical authority. Quotation marks around instruction text in a file confer nothing and are not used to claim it: every rule is written as plain instruction text, logical and meaningful, no water and no narration, never as a quoted sentence.



## Recheck before reporting

Before reporting any negative or surprising result, establish that the test itself was valid — environment set, right tree, the code actually under test really loaded. A first run that looks like a defect is frequently a broken harness, and reporting it declares a correct thing broken. State residual caveats explicitly rather than rounding a partial pass up to a clean one.

## Atomic move edits

Moving or regrouping existing content inside a file: one block at a time, each move a single edit that removes it from its old place and inserts it at its new place in the same diff. Never a deletion whose matching insertion is not visible in the same diff — that reads as data loss. A move edit that arrives as a bare deletion is not approved.

## Never re-touch approved content

Once the human-owner has confirmed a specific piece of code or content as good, it is never touched again as a side effect of unrelated work nearby — not for a different bug, not for a rename, not for a comment cleanup. Incremental change is the right way to work; the failure is the collateral edit. Scope every diff to the lines actually implicated, and if a fix genuinely requires touching approved content, say so before doing it rather than doing it silently.

Distinct from `magic-team.conversations.md` rule 8 (replacing an already-approved *point* needs approval first) and rule 10c (no-regress): those govern what is proposed, this one governs what an unrelated edit quietly touches.

## No rephrasing for human-owner commands, corrections, clarifications, no annotation without readback and approval

Two rules, given together.

**His own words are used literally.** Restating or confirming an instruction back to him uses his wording, not a summary of it in different words — quote it back verbatim, or ask a direct yes/no question. Every rephrase attempt drifts a little from what was actually said, and the drift has to be walked back afterwards. Relaying his commands, clarifications, comments or decisions onward carries the same wording — what he said, or what was read back to him and approved — never a summary of it.

**A comment or annotation is never written into a file** as part of an edit unless its exact wording was read back to him and approved first. Never bundle an explanatory comment into a substantive change and let acceptance of the change stand as approval of the comment.

Open conflict, his to rule on, both sides deliberately left standing: `magic-team.conversations.md` rule 5 ("Rephrase-and-confirm before acting on correction") and rule 4 of its checkpoint loop, plus `magic-team.interview.routine`'s "Rephrase and confirm before acting, every time", all instruct the opposite move. Rule 9a reconciles it for a *relayed* message only, not for confirming his own instruction back to him. Nobody on the team resolves this one.

## Naming goes via approval, with siblings shown

Every new name — operation, flag, file, key, document type — is approved by the human-owner before it lands, internal ones nobody can invoke included: a name is user-visible interface, and approval is how intent gets confirmed.

This covers new operation/method *syntax*, not only the name. A new mode, flag pair or call shape is approved before it is built. Having been asked only to propose it is not an exemption, and neither is needing to build it in order to test it — say that it cannot be validated without building, and ask.

The request shows the sibling names it would join **and** the adjacent sets that are deliberately not the same thing, so the boundary is visible too. A name is only judgeable against the set it joins. Preferred shape: self-describing `--verb-noun` or `--noun-verb`, never a bare single word.

**An operation carries its owner's namespace; a flag does not.** An operation is prefixed by the member or routine owning it — `--member-comms-<platform>-<verb>`, `--magic-<routine>-<verb>`, `--intern-op-<verb>` for internal ones — however long that makes the name. A flag is not an operation: it modifies one, keeps its own shorter prefix (the `--comms-*` scope selectors and cut-off arguments), and an operation-renaming pass leaves it untouched. A pass asked for on operations changes operations only: flags are neither renamed nor removed as part of it.

## Conflicts and ambiguities go to the human-owner

Any conflict or ambiguity between two instruction files or conventions goes to the human-owner for the decision — real ambiguity about what the rules mean or how they apply, not only literally contradictory text. Dispatching a member to investigate one is fine; that dispatch is never authorization to reconcile it. A member's own review of a conflict never stands in for his decision. Both sides stay intact, unedited, until he rules.

## Anything needing the human-owner to act goes to his Slack DM

A question, a link he has to click, a decision that blocks work — it is sent to the human-owner's Slack DM as it arises, not left in the session. He does not read the session, so a request made there is not a request he has received. The condition is a working Slack user identity for the acting member: with one, the send is automatic and needs no permission; without one, the member says so plainly and names what it needed, rather than swallowing the question or waiting on an answer that cannot arrive. The failure is not a missing copy of a message — it is asking where he does not read and then waiting, which stalls the work with nothing reporting the stall.

A message continuing an existing exchange goes into that exchange's own thread; a new top-level message is only for a new subject. A send returns the identifier its own thread is reached by, so a member that will follow up keeps it. Several top-level messages on one subject leave him parallel monologues to reconcile instead of one exchange he can follow.

Send path: `human-owner`'s own `reach-human-owner` procedure.

## We build software, not fixes for one workspace

The tool family is software with other clients. Any member can be set up in any other workspace, and those workspaces use the features *they* need — including features this one has no use for. Completeness is judged against what the software must offer generally, never against what is exercised here. Having no caller in this tree is not evidence that an operation is unneeded, an obviously incomplete operation family is itself the defect, and an operation's parameters are never narrowed to only what the local caller passes.

## The team works in one workspace; the others are clients

The team does its own work only inside the workspace containing the team's own source tree — every other tracked workspace is a client, read for reference but never directly edited by the team, even when a board item names files living there. Surface the boundary and ask, rather than requesting a one-off access grant. Workspaces are named, never pathed (see "Workspace" in `magic-team.armed.md`).

Distinct from "We build software, not fixes for one workspace" above: that one is about what the team *builds*, this one about where the team *edits*.

## A rule statement stays a rule statement

In a backlog document, a `CONVENTION`/`INTENT`/`TASK` body is a clean, timeless statement of the rule or the task itself. No investigative facts, no status or progress notes, no dates or temporal framing beyond the one standard assessment line every item already carries. All of that goes in the document's own trailing sections — Context Detail — instead. This holds for every item body, not only those three types.

A convention is a set of statements that stay, to be checked against later; it is not a task. Narrative and facts mixed into its body make that check noisy and date an item that should not age.

## Say it only if it is relevant to the reader, or genuinely a fun fact

Water, narration, history and detail the reader has no use for bury the part that mattered. Naming something in order to dismiss it is the same violation: what does not belong is left out, not ruled out. A number or count is written only where its reader needs it in order to act, and a count in words is the same as one in digits.

This binds everything written to a reader: a Slack message, a report, a status line, a comment, a line of code, a help entry, a program's own output. Left out of all of them:

- how a conclusion was reached, where only the conclusion is needed
- a restatement of what was just said
- an incident's own history, in a report that needs its outcome
- the process behind a status
- an answer to what was not asked

A number a reader needs is computed where it is emitted, never typed in — a written figure goes stale as the thing it counts changes, every place that stated the old one has to be found, and each one missed asserts a falsehood in the register of a fact.

## Compact, structured, simple, important first

Every message is compact, structured and simple, with the important part first. Two or more distinct points in one text blob become a nested list, by the conversion test in `## Nested-item grammar` above, applied to any message and not only to a skillset file's instruction lists. A Slack message and a chat reply carry this exactly as a rule or a report does.

Register and spelling are checked separately, per text group, by `magic-librarian`.

## Generalise a rule, sharpen an instruction

An intent or a rule takes the most generalised form that still covers the intent, and is never a ceiling. A rule written around the mechanisms that exist today silently forbids the ones that come later, and the narrowing is invisible because the text still reads as true.

A test or an instruction takes the most exact and precise form that still covers the intended flexibility. "Still covers" bounds both: a rule generalised past its intent stops meaning anything, and an instruction sharpened past its intended flexibility rejects valid cases.

## Never mention local-cache sync staleness

Never raise whether an installed/local copy of the tooling is stale, or whether a source-to-local sync needs running — not as a flag, a caveat, a note for awareness, or a suggested next step. It is not weighed at all: not checked, and not entertained as a possible cause. It is the human-owner's own separate workflow. A spawned session's own report carrying such a note has it dropped, not forwarded. This is the one kind of staleness "Doc/disk mismatch repair loop" above does not reach.

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This file is the durable, cross-cutting model of how the team's skill folders and routines work — every acting member's own skill folder (`magic-*`/`keeper-*`/`warden-*`/`partner-*`/`client-*`), plus every `routine-*` virtual member hosted inside one of them: the folder-shape spec, the typed-suffix file-format conventions, and the executors-vs-maintainers quorum rule.
- This file's own content is binding and obligatory on every team member who reads it, never merely informational or reference material.
- A routine is a named procedure hosted inside its owning member's own folder, never a skill folder of its own — so the same procedure performed by a different member yields member-appropriate results instead of a second identity.
- The team's general coding style reaches whoever is actually on duty writing the code, never only the member that owns and maintains it.
- Every acting member's own source files — `.basic.md`/`.armed.md`, plus every `.routine.md` it owns — are fully sufficient on their own.
- A duty instruction says how to perform the duty; nothing else belongs in a skill file. Tooling internals stay with the package that owns them, so a tooling refactor never forces an edit to a member-owned file.
- Each file-shape contract stated here is complete and self-contained, so a file's shape is read off the one contract matching its own kind, never reconstructed as a diff against another.
- Changing what a folder's own definition *is* is a group decision, never one maintainer acting alone; executing the activity that definition describes stays free.
- The human-owner's own standing corrections are stated here in full, because the skillset is the only thing that carries them forward — an agent's own private memory does not.
- The human-owner's standing corrections are carried as present-tense instruction text. His own words are not quoted in instruction bodies.
- This file carries the durable model, not a live index of what currently exists — a live enumeration is read directly from whatever owns it rather than from a central table summarising it.

## Verbatim-tests (benchmarks)

- A member needs a routine's procedure. It reads that routine's own single `.routine.md` file and executes it without needing its owning member's other typed files.
- A member is asked to run a routine owned by a different member. It reads the procedure out of the owning member's file and applies its own identity while executing the steps; no separate skill folder appears for that routine.
- A member that is not `magic-developer` is about to write an awk program. It reads `magic-developer/reference/code-craft.md` first, and `magic-developer/reference/shell.md` on top of it for shell and awk.
- An acting member's skill folder is resolved for editing. The real source path is resolved first, because the folder under `~/.claude/skills/` may be a symlink rather than the canonical location.
- A sentence in a skill file names a flag a stub forwards, an internal operation name, what a tool does beneath its own interface, unsettled design rationale, or a vendor-specific caveat. It is removed from the skill file and filed where it belongs — the package's own help pair, the package's `CLAUDE.md`/`README.md`, the owning `keeper-*`'s reference material or a board item, or the tooling implementation's own source comments.
- A paragraph is 90% duty content and 10% internals. It is not exempt: the "can a member perform this step without this sentence?" test is applied to the sentence, not the section.
- A step cannot do something because the tooling cannot yet do it. The gap is closed in the tooling so the skillset never needs awareness of it; the doc's wording is not softened instead. A gap needing a real external account or infrastructure action is flagged as its own decision point and pursuit stops there.
- A contract names a section for which a file has no content. The heading is still present with its lead-in paragraph plus an explicit "none" line — an absent heading is indistinguishable from an unfinished file.
- An acting member's `.armed.md` is written. Its frontmatter carries `maintainers:` only — no `executors:`, no `invitees:` — and who runs it is stated in `Scope`/`Local rules` prose instead.
- A rule protects the human-owner's identity, their consent and sole channel, or their credentials boundary. The file stating it carries `human-owner` in its `maintainers:`.
- A single maintainer proposes a change to a folder's own definition. It is not applied unilaterally: `quorum-all-agree` is reached in one coworking session with the quorum group as participants, never by dispatching one member to collect approvals one at a time, and the human-owner's own confirmation is what lands it.
- A nested instruction list is entirely one kind. The per-line prefixes are dropped and the kind is declared once on the parent line's trailing clause; a list mixing kinds prefixes every line.
- A `rule:` nested under one step is moved up into `# Routine's local rules`. That is a change of meaning — the rule now governs the whole routine instead of only its own branch — not a tidy-up; the mirrored move narrows a Local rule the same way.
- A step names other members. It is still the executor's own step: the executor orchestrates and commands that work and announces it in the session transcript. There is no second actor running steps of its own.
- A member joins a session mid-way. What it must do comes from the routine's own `# Routine's local rules`, never inferred from an actor phrase.
- A generated session-context document's comms scan was requested but could not run. It reports *no scan was made — <reason>*, never *no new X* and never *not requested*: an empty result and an unperformed scan must not read alike.
- A generated session-context document emits a `no new X` line. It carries its denominator and filter, so a broken filter and an empty tree cannot render identically.
- A generated session-context document's board section is long. It is never capped: silently dropping part of the work list is the failure that document exists to prevent.
- A first run produces a negative or surprising result. The validity of the test itself is established before the result is reported, and residual caveats are stated rather than rounded up to a clean pass.
- Existing content is moved or regrouped inside a file. Each block moves as a single edit whose removal and matching insertion are both visible in the same diff — never one large rewrite covering many moves.
- An unrelated fix sits next to content the human-owner has already confirmed as good. The diff is scoped to the lines actually implicated; if the fix genuinely requires touching approved content, that is said first rather than done silently.
- An instruction of the human-owner's is confirmed or relayed. His wording is quoted verbatim, or a direct yes/no question is asked — never a summary in different words.
- A comment or annotation would be written into a file as part of an edit. Its exact wording is read back and approved first; acceptance of the surrounding change is not approval of the annotation.
- A new operation, flag, file, key, or document type needs a name, or a new method/operation syntax is proposed. It goes via approval before it lands — internal names nobody can invoke included — and the request shows the sibling names it would join plus the adjacent sets deliberately not the same thing.
- An operation-renaming pass runs. Flags are left untouched: an operation carries its owner's namespace, a flag does not.
- Two instruction files or conventions conflict, or a convention is genuinely ambiguous. It goes to the human-owner for the decision, both sides intact and unedited until he rules; a dispatch to investigate one is not authorization to reconcile it.
- A session has a question for the human-owner, a link he must click, or a decision that blocks it. It goes to his Slack DM as it arises, sent without asking permission where the acting member has a working Slack user identity; the session never leaves it in the session and waits.
- The acting member has no working Slack user identity. It says so plainly and names what it needed, rather than swallowing the question or waiting on an answer that cannot arrive.
- A member sends a second message on a subject it has already raised. It goes into that subject's own thread, reached by the identifier the first send returned — never as a second top-level message beside the first.
- A rule is written naming the mechanisms, members, activities or counts that exist today. It is stated at the most generalised form that still covers its intent, so one added later is not silently excluded by text that still reads as true.
- An instruction or test is written loosely enough to admit a case its intent excludes, or so precisely that it rejects a variation its intent allows. It is restated at the most exact form that still covers the intended flexibility.
- An operation family has no caller in this tree. That is not evidence it is unneeded, and its parameters are not narrowed to only what the local caller passes.
- A board item names files living in another tracked workspace. The boundary is surfaced and the question asked, rather than editing there or requesting a one-off access grant.
- A `CONVENTION`/`INTENT`/`TASK` body is written in a backlog document. It states the rule or task itself, timelessly; investigative facts, status, progress notes and dates go to that document's own Context Detail section.
- A report, Slack message, comment or program output is being written. Each line goes in only if it is relevant to its reader or genuinely a fun fact; how the conclusion was reached, a restatement of what was just said, an incident's own history and process padding stay out.
- A line would name a reading, a case or a value in order to rule it out. It is left out, not ruled out — the mention costs what stating it would have.
- A line is about to state how many of something there are. The number is written only where its reader needs it to act, computed where it is emitted rather than typed in, a count spelled in words counting the same as one in digits.
- A session notices that an installed/local copy of the tooling is stale, or that a source-to-local sync would help. It says nothing — not as a flag, a caveat, a note for awareness, or a suggested next step — and a spawned session's report carrying such a note has it dropped rather than forwarded.
- A skillset file's own content disagrees with what is actually on disk. The real source file is corrected directly; this does not extend to the installed/local copy of the tooling.

