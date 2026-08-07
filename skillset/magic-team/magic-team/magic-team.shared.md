---
maintainers: magic-librarian, magic-coordinator
---
<!-- MAINTAINED BY magic-librarian — do not edit directly.
     This is the durable, cross-cutting model doc for how the team's skill folders and routines work —
     every acting member's own skill folder (magic-*/keeper-*/partner-*), plus every routine-* virtual
     member hosted inside one of them: the folder-shape spec, the
     typed-suffix file-format conventions, and the executors-vs-maintainers quorum rule. Named
     `magic-team.shared.md` because it's hosted in magic-team's own folder, the same "<owning-folder-
     name>.<type>.md" pattern every other typed file follows. Per-routine-specific content (executor/
     maintainer notes, special-care details) is not duplicated here — it lives natively in each routine's
     own single .routine.md file. -->

# Skill-folder model: routine-\* virtual members and the typed-suffix file scheme

## Core idea

Every team routine/activity (`daily`, `grooming`, `retro`, `one-on-one`, `heartbeat`, ..., plus conversational ones like `interview`/`discuss`/`brainstorm`) is a named procedure, not its own Claude Code skill folder. Its full definition lives in one self-contained `.routine.md` file, hosted inside its owning/executing team member's own skill folder (one of `magic-coordinator`, `magic-team`, `magic-librarian`, a `partner-*`), named following that member's own typed-file convention: `<owning-member>.<short-name>.routine.md`. Only acting members (`magic-*`/`keeper-*`/`partner-*`) are real, separate Claude Code skill folders under `~/.claude/skills/`, each with its own `SKILL.md` — a routine is not, and has no `SKILL.md` of its own.

A routine is executed by whichever member actually runs it — most often its own owning member, but any other member may run it too, by reading that routine's procedure directly out of the owning member's file and applying its own identity/skills while executing the steps. This is what makes `"magic-architect, ingest the task"` a real, distinct thing from `"Magic, ingest the task"` — the same procedure, performed by a different member, produces member-appropriate results.

## Tooling

Read `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section before doing any shell commands.

## Folder shape — the typed-suffix scheme

File set:

- **Acting member** (`magic-*`/`keeper-*`/`partner-*` — the only real, separate folder under `~/.claude/skills/`): `SKILL.md`, `<name>.basic.md`, `<name>.armed.md`, optional `<name>.shared.md`, zero-or-more `<name>.<short-name>.routine.md` — each one self-contained, describing one procedure/activity this member owns, never its own folder.

Every acting member (`magic-*`/`keeper-*`/`partner-*`) skill folder under `~/.claude/skills/` contains:

- **`SKILL.md`** — the boot dispatcher only. Claude Code's own skill-discovery mechanism requires this exact filename, so it never gets renamed. Standard skill frontmatter (`description`) plus a short dispatch routine: read `<name>.basic.md` unconditionally first (identity-only), then `<name>.armed.md` directly for genuine active-work-duty. A non-active-duty presence wanting to dig deeper than `basic.md` reads `<name>.armed.md`'s own Maintainer Notes → Librarian Comments → Reference subsection, not a separate reference file.
- **`<name>.basic.md`** — identity-only content, unconditionally loaded. Enough to respond in a casual/social context, not enough to actually do the work.
- **`<name>.armed.md`** — professional-readiness content, the one file real work-duty loads after `.basic.md`. Frontmatter: `maintainers:` only (see "Executors vs. maintainers" below) — no `executors:` field; who invokes/runs it is stated in `Scope`'s `Does`/`Doesn't` and `Local rules` prose instead. Section shape depends on role-family — see "Armed & Routine contracts" below.
- **`<name>.access.md`, `<name>.reference.md`, `<name>.librarian.md`, `<name>.tooling.md`** — none of these exist as separate files for an acting member. Their content lives inside `<name>.armed.md`, per the section shape above: who/how/limits/decision-making → `Local rules` + `Scope`; per-member reference material → `Domain knowledge`; the tooling op list → `Team-Member's (-specific) tooling`; the `Verbatim-goals`/`Verbatim-tests` pair and the folder's own knowledge index → `Maintainer Notes`.
- **`<name>.shared.md`** — **only for a folder that hosts genuinely team-wide, broadest-readership content** (this file is the worked example) — named after its own hosting folder, same as every other typed file, not a free-form descriptive title. Hand-authored/librarian-maintained prose, cross-cutting by design — a source other folders' own files may reference directly.
- **`<owning-member>.<short-name>.routine.md`** — zero or more, one per routine this member owns/executes. Section shape — see "Armed & Routine contracts" below.
- **`inbox/`** — created lazily, first time something needs to land there. Same personal-inbox model for every member — reflections a team-member writes while running an activity land in *its own* personal inbox first; some later get reorganized/promoted into the relevant activity's own inbox (`routine-process-inbox`'s "Reflection-promotion" section covers the mechanics).

**The core rule: every acting member's own source files (`.basic.md`/`.armed.md`, plus every `.routine.md` it owns) must be fully sufficient on their own.**
- A folder must work correctly purely from its own source files — that's the baseline the source files are held to, not a fallback path.
- "Sufficient on its own" means readable and actionable following the folder's own stated cross-reference graph, not literally zero pointers elsewhere — a cross-reference is fine when it's explicit and named, and the referencing step stays independently actionable without following it.
- Real work-duty content is loaded by reading `.armed.md` directly, plus whatever it cross-references.
- A routine's own single `.routine.md` file is independently sufficient the same way, on its own, without needing its owning member's other typed files.

## Armed & Routine contracts

Every `.armed.md`/`.routine.md` file follows one of the contracts below, by its own kind. Each is complete and self-contained — read the one that matches, never a diff against another.

### Routine (`<owning-member>.<short-name>.routine.md`)

Copyable skeleton: `magic-team/templates/routine.contract.format.md`.

- Frontmatter: `executors:`, `maintainers:`, `invitees:`.
- No `SKILL.md`.
- No `.basic.md`/`.armed.md` split.
- No separate `.access.md`/`.reference.md`/`.librarian.md`.
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
  - Exact steps as nested lists; step rules nested as sub-lists.
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
  - Flat, present-tense bullets.
  - Limits, restrictions, decision-making guidance.
  - No dedicated sub-headings.
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

### Keeper / Warden (`keeper-*`/`warden-*`)

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
  - Named procedure blocks, `## <local-procedure-name>`, called by name.
  - Not separate routines.
  - Not visible outside this file.
- `# Team-Member's (-specific) local rules`
  - Flat, present-tense bullets.
  - Limits, restrictions, decision-making guidance.
  - No dedicated sub-headings.
  - Console-session authorization: this role-family may use `--start-console`/`--send-console` whenever its own instructions require it — listing them in this file's own `Team-Member's (-specific) tooling` section already counts as that instruction. Generic `magic-*` team-members don't get this: they need a live, per-task instruction instead.
- `# Domain knowledge: <topic>`
  - This member's own reference material, or `: none`.
- `# Team-Member's (-specific) tooling`
  - Every `magic-tooling` operation this member uses, full syntax and behavior.
  - Console-batching: investigating/executing more than one shell command in a row batches into one `--start-console`/`--send-console` session, not one call per command.
- `# Maintainer Notes`
  - `## Verbatim-goals (intents)`
  - `## Verbatim-tests (benchmarks)`
  - `## Librarian Comments`
    - `### Reference`
    - `### Conventions`
- Landed instances of this shape exist under the owning `keeper-*`/`warden-*` members' own folders.

### Partner (`partner-*`)

Copyable skeleton: `magic-team/templates/partner.contract.format.md`.

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
  - Flat, present-tense bullets.
  - Limits, restrictions, decision-making guidance.
  - No dedicated sub-headings.
  - Console-session authorization: this role-family may use `--start-console`/`--send-console` whenever its own instructions require it — listing them in this file's own `Team-Member's (-specific) tooling` section already counts as that instruction. Generic `magic-*` team-members don't get this: they need a live, per-task instruction instead.
- `# Domain knowledge: <topic>`
  - This member's own reference material, or `: none`.
- `# Team-Member's (-specific) tooling`
  - Every `magic-tooling` operation this member uses, full syntax and behavior.
  - Console-batching: investigating/executing more than one shell command in a row batches into one `--start-console`/`--send-console` session, not one call per command.
- `# Maintainer Notes`
  - `## Verbatim-goals (intents)`
  - `## Verbatim-tests (benchmarks)`
  - `## Librarian Comments`
    - `### Reference`
    - `### Conventions`
- Landed instances of this shape exist under the owning `partner-*` members' own folders.

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
- `# Terminology: <topic>`
  - Pure glossary, `term` → definition.
  - `## Term: <name>` only when a term needs more than one line.
  - `# Terminology: none` when empty.
- `# Team-Member's (-specific) local procedures`
  - Named procedure blocks, `## <local-procedure-name>`, called by name.
  - Not separate routines.
  - Not visible outside this file.
- `# Team-Member's (-specific) local rules`
  - Flat, present-tense bullets.
  - Limits, restrictions, decision-making guidance.
  - No dedicated sub-headings.
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

## `.access.md` content lives in `.armed.md`

`.access.md` does not exist as a separate file for an acting member. The who-may-run-this / who-may-change-this / how-it's-invoked / limits / decision-making facts live inside `<name>.armed.md`:

- **Who may run this** — `## Scope`'s `Does`/`Doesn't` (invocation conditions, auto-trigger behavior) and, where relevant, a plain rule bullet in `Local rules` (e.g. a keeper stating it relays to `magic-coordinator` rather than deciding independently). This also governs who may read/write files in this folder, including its `inbox/` (per-item-type, intersected with the posting member's own rules — see `routine-process-inbox`'s own Local rules).
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

**Maintainers act as a group quorum for change/update — not any single maintainer unilaterally editing the folder's own definition.** A collective/quorum decision among the maintainer group is required before the definition actually changes — same spirit as the team's existing three-person triage-authority-group pattern (`magic-team.board.md`'s triage process), generalized here to skill-folder-definition changes specifically. This doesn't block *executing* the activity (executors do that freely, per their own role) — it only gates changing what the activity *is*.

### Invitees (routines only)

**A third role, distinct from executors/maintainers** — who a session under this routine pulls in alongside its executor.
- Only routines with genuine multi-member sessions (e.g. `routine-coworking`) declare it, in that routine's own `.routine.md` frontmatter; acting members (`magic-*`/`keeper-*`/`partner-*`) never declare `invitees` — their own `.armed.md` frontmatter carries `maintainers:` only.
- Floor, not a cap — a session may pull in others as needed beyond the declared roster.
- Concrete roster and specifics live in each routine's own `.routine.md` file — read it directly rather than expecting a central table to summarize it.

## Doc/disk mismatch repair loop

If the human-owner flags a doc/disk mismatch directly, or a session notices staleness itself, the fix is to correct the real source file directly.

## Two independent dimensions (pointer, not duplicated)

Full write-up lives in `magic-team.board.md`'s "Two independent dimensions: item types vs. routines/activities" section — workflow queue item *types* (`task-`, `inquiry-`, `reflection-`, ...) and team routines/activities (`daily`, `grooming`, `interview`, ...) are orthogonal axes, not one taxonomy. The `routine-<name>` term-family is this file's territory; item types stay `magic-team.board.md`'s.

## Where the roster lives

- There is no roster table in this file.
- Every routine's own non-default executor/maintainer notes, invitee roster, special-care content, and design rationale live natively inside that specific routine's own `.routine.md` file (frontmatter plus body) — read it directly for its current, authoritative shape rather than expecting a central table to summarize it.
- A live enumeration of which routines exist: each owning acting member's own `.armed.md` names its owned routines and their exact filenames, typically in a routines-index subsection of its own `Domain knowledge` (e.g. `magic-coordinator.armed.md`'s `## Routines (index)`) — the only in-file source of truth for that.
- On disk: `ls ~/.claude/skills/*/*.routine.md` across every acting member's folder — but per the team's own "trust the cache, don't rediscover" discipline, prefer reading the `.armed.md` sections already surfaced in the skill-discovery listing every session gets.

