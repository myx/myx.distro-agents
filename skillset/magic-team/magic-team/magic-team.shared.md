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

## Human-owner conversations: two identities

- The team bot and a member's own IM account are two separate conversations with the human-owner. A member with no account of its own reaches the human-owner in the bot's conversation — today only `magic-coordinator` has its own.
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

**The core rule: every acting member's own source files (`.basic.md`/`.armed.md`, plus every `.routine.md` it owns) must be fully sufficient on their own.**
- A folder must work correctly purely from its own source files — that's the baseline the source files are held to, not a fallback path.
- "Sufficient on its own" means readable and actionable following the folder's own stated cross-reference graph, not literally zero pointers elsewhere — a cross-reference is fine when it's explicit and named, and the referencing step stays independently actionable without following it.
- Real work-duty content is loaded by reading `.armed.md` directly, plus whatever it cross-references.
- A routine's own single `.routine.md` file is independently sufficient the same way, on its own, without needing its owning member's other typed files.

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
  cannot be done, never the vendor-specific setting that would fix it. Human-owner: "WHY THIS DETAIL? IT
  IS HIDDEN BY TOOLING - IT CAN LATER RUN ON OTHER MESSAGING PLATFORM AS WELL!!!! ALL HIDDEN BY TOOLING -
  NO need-to-know here at all!"

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
limitation is worded. Human-owner: "FILLING GAP IN TOOLING TO NOT MENTION DETAILS IN SKILLSET".

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
    - "`DistroAgentsTools.fn.sh` always executes via the `myx.common` MCP tool `mcp__myx_common__lib_execShStdin` (command `lib/execShStdin`) — never Bash, a Python/notebook execution tool, or any other tool that runs a process directly. Any non-mutating, read-only shell command also executes via `lib/execShStdin` the same way." The MCP tool name is stated literally, not abstracted, so a member drifting onto a wrong tool name is detectable by comparison.
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

Which side a member sits on: the keeper side is that organisation's own — non-private, knowing their assets and conventions. The client side is ours and private — it holds our credentials for work with them. Same distinction restated under Partner / Client below.

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
    - "`DistroAgentsTools.fn.sh` always executes via the `myx.common` MCP tool `mcp__myx_common__lib_execShStdin` (command `lib/execShStdin`) — never Bash, a Python/notebook execution tool, or any other tool that runs a process directly. Any non-mutating, read-only shell command also executes via `lib/execShStdin` the same way." The MCP tool name is stated literally, not abstracted, so a member drifting onto a wrong tool name is detectable by comparison.
    - "Console-session requirement: doing an actual task with this role-family's own workspace/workspace tooling requires a `--console-start`/`--console-send` session, regardless of command count. Just answering a question or looking at files (not a task) may skip it."
    - Decision authority: this keeper relays between `magic-coordinator` and the task, never deciding design/approach independently unless explicitly granted — cross-references `magic-team.authority.keeper.contract.md`, never restated in full.
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

Which side a member sits on: the client side is ours and private — it holds our credentials for work with that organisation. The keeper side is that organisation's own — non-private, knowing their assets and conventions. Same distinction restated under Keeper / Warden above.

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
      - Represents the external party inside our own coworking sessions.
      - Represents our own team inside the external party's own corporate systems, at the same time.
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
    - "`DistroAgentsTools.fn.sh` always executes via the `myx.common` MCP tool `mcp__myx_common__lib_execShStdin` (command `lib/execShStdin`) — never Bash, a Python/notebook execution tool, or any other tool that runs a process directly. Any non-mutating, read-only shell command also executes via `lib/execShStdin` the same way." The MCP tool name is stated literally, not abstracted, so a member drifting onto a wrong tool name is detectable by comparison.
    - `partner-*` only: "Console-session authorization: `--console-start`/`--console-send` when its own instructions call for it — available, not a standing requirement." Not part of the `client-*` shape — a `client-*` member is a representative, normally with no workspace or console of its own, so it gets no console grant by default. A specific client that genuinely needs one states it explicitly in its own file, which is what the `magic-team.armed.md` console rules require anyway.
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

They are stated here, in full, because the skillset is the only thing that carries them forward — an agent's own private memory does not.

Every quoted line below is his own wording, kept character-for-character, including its typos. A quote is trimmed of surrounding narration, never reworded. Another file may state a compact form of a rule from this section and point back here; it never restates it in different words.

## Recheck before reporting

Before reporting any negative or surprising result, establish that the test itself was valid — environment set, right tree, the code actually under test really loaded. A first run that looks like a defect is frequently a broken harness, and reporting it declares a correct thing broken. State residual caveats explicitly rather than rounding a partial pass up to a clean one.

"skip - I've seen it done, always recheck defore report"

## Atomic move edits

Moving or regrouping existing content inside a file: one block at a time, each move a single edit that removes it from its old place and inserts it at its new place in the same diff. Never one large rewrite covering many moves at once, and never a deletion whose matching insertion is not visible in the same diff — that reads as data loss.

"NO - ATOMIC MOVE EDITS ONLY. DO NOT APPROVE DELETION."

## Never re-touch approved content

Once the human-owner has confirmed a specific piece of code or content as good, it is never touched again as a side effect of unrelated work nearby — not for a different bug, not for a rename, not for a comment cleanup. Incremental change is the right way to work; the failure is the collateral edit. Scope every diff to the lines actually implicated, and if a fix genuinely requires touching approved content, say so before doing it rather than doing it silently.

"NO - incremental - good / random fucking of approved code that was not to touch - bad."

Distinct from `magic-team.conversations.md` rule 8 (replacing an already-approved *point* needs approval first) and rule 10c (no-regress): those govern what is proposed, this one governs what an unrelated edit quietly touches.

## No rephrasing him, no annotation without readback and approval

Two rules, given together.

**His own words are used literally.** Restating or confirming an instruction back to him uses his wording, not a summary of it in different words — quote it back verbatim, or ask a direct yes/no question. Every rephrase attempt drifts a little from what was actually said, and the drift has to be walked back afterwards.

**A comment or annotation is never written into a file** as part of an edit unless its exact wording was read back to him and approved first. Never bundle an explanatory comment into a substantive change and let acceptance of the change stand as approval of the comment.

"STOP REPHRASING ME - IT ALWAYS BREAKS EVERYTHING / NO ANNOTATIONS UNLESS READBACK AND APPROVED"

"When you relay my commands, clarifications, comments, decisions - NEVER REPHRASE. RELAY VERBATIM. WHAT I SAID OR WHAT YOU READBACK AND I APPROVED."

Open conflict, his to rule on, both sides deliberately left standing: `magic-team.conversations.md` rule 5 ("Rephrase-and-confirm before acting on correction") and rule 4 of its checkpoint loop, plus `magic-team.interview.routine`'s "Rephrase and confirm before acting, every time", all instruct the opposite move. Rule 9a reconciles it for a *relayed* message only, not for confirming his own instruction back to him. Nobody on the team resolves this one.

## Naming goes via approval, with siblings shown

Every new name — operation, flag, file, key, document type — is approved by the human-owner before it lands, internal ones nobody can invoke included: a name is user-visible interface, and approval is how intent gets confirmed.

This covers new operation/method *syntax*, not only the name. A new mode, flag pair or call shape is approved before it is built. Having been asked only to propose it is not an exemption, and neither is needing to build it in order to test it — say that it cannot be validated without building, and ask.

The request shows the sibling names it would join **and** the adjacent sets that are deliberately not the same thing, so the boundary is visible too. A name is only judgeable against the set it joins. Preferred shape: self-describing `--verb-noun` or `--noun-verb`, never a bare single word.

**An operation carries its owner's namespace; a flag does not.** An operation is prefixed by the member or routine owning it — `--member-comms-<platform>-<verb>`, `--magic-<routine>-<verb>`, `--intern-op-<verb>` for internal ones — however long that makes the name. A flag is not an operation: it modifies one, keeps its own shorter prefix (the `--comms-*` scope selectors and cut-off arguments), and an operation-renaming pass leaves it untouched.

"`--member-comms-*` all - namespace."

"FLAGS ARE NOT TO REMOVE. I ASKED FOR OPERATIONS."

"All naming questions - always via approval - showing the siblings and similar but distinctly other sets we are using. So while deciding it was possible to see the picture and notice that not the best suitable (for our intents) name chosen"

"DONT DO THAT AGAIN - NEW METHOD/OPERATION SYNTAX - ONLY VIA APPROVAL/CONFIRMATION/COMMENTS"

## Conflicts and ambiguities go to the human-owner

Any conflict or ambiguity between two instruction files or conventions goes to the human-owner for the decision — real ambiguity about what the rules mean or how they apply, not only literally contradictory text. Dispatching a member to investigate one is fine; that dispatch is never authorization to reconcile it. Both sides stay intact, unedited, until he rules.

"ALL RULE CONFLICTS TO BE REVIEWED BY human-owner - not just librarian"

"CONFLICTS/AMBIGUOSITY - NOT JUST TEXT"

## We build software, not fixes for one workspace

The tool family is software with other clients. Any member can be set up in any other workspace, and those workspaces use the features *they* need — including features this one has no use for. Completeness is judged against what the software must offer generally, never against what is exercised here. Having no caller in this tree is not evidence that an operation is unneeded, an obviously incomplete operation family is itself the defect, and an operation's parameters are never narrowed to only what the local caller passes.

"SOMEONE ELSE CAN BE SETUP IN ANY OTHER WORKSPACE / CAN YOU REMEMBER IT FOREVER / WE DO SOFT / OTHER CLIENTS USE IT / THEY USE FEATURES THEY NEED / FEATURES NOT NEEDED IN THIS WORKSPACE"

## The team works in one workspace; the others are clients

The team does its own work only inside the workspace containing the team's own source tree — every other tracked workspace is a client, read for reference but never directly edited by the team, even when a board item names files living there. Surface the boundary and ask, rather than requesting a one-off access grant. Workspaces are named, never pathed (see "Workspace" in `magic-team.armed.md`).

"Team is in this workspace only - others are clients."

Distinct from "We build software, not fixes for one workspace" above: that one is about what the team *builds*, this one about where the team *edits*.

## A rule statement stays a rule statement

In a backlog document, a `CONVENTION`/`INTENT`/`TASK` body is a clean, timeless statement of the rule or the task itself. No investigative facts, no status or progress notes, no dates or temporal framing beyond the one standard assessment line every item already carries. All of that goes in the document's own Context Detail section instead.

A convention exists to be checked against later, as a standing rule. Narrative and facts mixed into its body make that check noisy and date an item that should not age.

"convention is not a task - set of statements to stay and be checked against"

"NO STATUS UPDATES AND TEMPORAL FACTS IN ITEMS - USE LAST SECTIONS"

## Never mention local-cache sync staleness

Never raise whether an installed/local copy of the tooling is stale, or whether a source-to-local sync needs running — not as a flag, a caveat, a note for awareness, or a suggested next step. It is the human-owner's own separate workflow. A spawned session's own report carrying such a note has it dropped, not forwarded. This is the one kind of staleness "Doc/disk mismatch repair loop" above does not reach.

"YOU BEEN TOLD NEVER TO THINK ABOUT IT"

