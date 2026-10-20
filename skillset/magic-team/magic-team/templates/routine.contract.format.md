---
type: routine
executors: <team-member-or-magic-team>
maintainers: <group, e.g. magic-coordinator, magic-librarian, magic-architect>, human-owner
invitees: <only if this routine has genuine multi-member sessions>
requires-session-kind: <standalone|coworking>
---
# <owning-member>.<short-name>.routine — the actual procedure

Normative contract: this file's own `# Contract` section, at its end. Where it and the skeleton disagree, `# Contract` wins. `# Contract` is not part of the skeleton and is not copied.

## Contents

- Summary
  - Goals
  - Scope
- Opening steps
- Steps
- Closure steps
- Routine's local procedures
  - `<local-procedure-name>` — [goal+intent short summary]
- Routine's local rules
- Routine-specific tooling
  - DistroAgentsTools magic-tooling operations
  - `--operation-name` Operation Reference
- Maintainer Notes
  - Verbatim-goals (intents)
  - Verbatim-tests (benchmarks)
  - Librarian Comments
    - Reference
    - Conventions
- Contract

# Summary

[One short sentence, names the routine.]

## Goals

- [Compact narrative, still detailed.]

## Scope

- Does:
  - [...]
- Doesn't:
  - [...]

# Opening steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

[The steps that open this routine's run, before `# Steps`, in the same shape as `# Steps`. The Opening steps of the routine of this routine's session kind run before them.]

1. **[opening-step-one-name]**: [Opening step one.]

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate it, and never skip it silently.

1. **[step-one-name]**: [Step one. Every step carries a name in this shape — what it does, never where it sits; unique within the file.]
   - goal: [What this branch is for. Optional, may be several, goes first, never executed.]
   - rule: [A rule in force only inside this branch, only once it is entered. Order-independent, grouped before the steps.]
   - step: [Step-one sub-step 1, ordered.]
      - rule: [Same grammar at any depth.]
      - step: [Deeper sub-step, ordered.]
   - step: [Step-one sub-step 2, ordered.]
   ...
2. **[step-two-name]**: [Step two, whose nested lines are all the same kind — so the kind is declared once here instead of prefixing each line,] steps:
   - [Sub-step 1, ordered.]
   - [Sub-step 2, ordered.]

# Closure steps

[If `# Steps` already ends with an identifiable closing tail, relocate it here verbatim. If not, state that plainly plus a pointer to whatever actually closes this routine. Either way, a handback to the routine's own parent carries what was agreed, per "The ladder: one rung at a time".]

1. **[closure-step-one-name]**: [Closure step one — runs only after `# Steps` and everything it extended/dispatched/spawned have finished.]

# Routine's local procedures

Named procedure blocks. Steps above call them by name. Not separate routines — not visible outside this file.

## `<local-procedure-name>` — [goal+intent short summary]

Steps:
1. [...]

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- A participant's disagreement, where this routine needs the group's agreement, follows "The ladder: one rung at a time": no quorum becomes the no-quorum document, sent up the same way.
- [...]

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Behaviour is read with `--member-help`. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- [`--operation-name <args>`]

## `--operation-name` Operation Reference

[Only what the operation's own help, read with `--member-help`, does not carry. Omit this subsection where the help carries it all.]

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- [Abstract goal statement, for conflict testing.]

## Verbatim-tests (benchmarks)

- [Concrete edge-case test.]

## Librarian Comments

### Reference

- [...]

### Conventions

- [...]

# Contract

- Frontmatter: `type:`, `executors:`, `maintainers:`, `invitees:`, `requires-session-kind:` (mandatory), `allows:` (optional), the requirement keys `tracking-item:`, `operations:` and `start-context:` (optional), `routine-lock-document:` (optional), `input-scan-def:` (optional), `review-by:` (optional), `cache-prefix:` (optional), `skips-inherited:` (optional) and the autorun keys `runs-at:` and `runs-after:` (optional). No key says that a routine takes arguments. `--manager-routine-list` prints, per routine, its `executors:`, whether its `requires-session-kind:` is `coworking`, and the title line below -- nothing more.
- `type:`
  - `routine`: a routine is told from any other document by what it says of itself.
- `requires-session-kind:` (mandatory)
  - The session kind the routine runs inside, one entry of the list the tooling owns: `standalone` (one member's session) or `coworking` (members working together in one session). Both are sessions with a session thread. `ad-hoc`, a task with a handback, is a start and never a kind.
  - Absent is invalid, and nothing is guessed from silence: a routine without it is refused by the validator and by the spawner.
  - Naming a kind makes the routine inherit from the bundled routine that defines the kind (`magic-team.coworking.routine`, `magic-team.standalone.routine`): one level, never a chain, and no routine names another routine as its parent. The Opening steps of the kind's routine run first, then the routine's own; the routine's `# Steps` are its own and never inherited; the routine's own Closure steps run first, then the kind's. The kind's local rules and its tooling block apply too, and a key the routine leaves out takes the kind routine's value (`executors:` of the coworking routine is `magic-coordinator`, a default and not a rule).
  - `skips-inherited:` (optional) names, comma-separated, steps of the kind's routine that do not run for this routine. A step of a kind's routine is a section under its `# Opening steps` or `# Closure steps`, named as the step (`## session-start`, `### declare-session-type`), so that the tooling excludes it by its name. The mix-in never re-adds them; the declaration is read by the tooling, and prose in `# Routine's local rules` does not stand in for it.
- The requirement keys (all optional; a key left out means `any`). A requirement is one fact the tooling decides alone, with no agent judgement; a requirement it cannot decide is a comment and stays in the prose. One evaluator reads the declaration at three sites -- on save, at spawn, at routine start -- and returns, in this order, one of four dispositions, the four verbs: `validate` (the context supplies it, and the routine proceeds), `automate` (the tooling supplies it, with no judgement, and records what it did), `help` (the tooling asks the one party who can supply it) and `reject` (nothing above applies, and the refusal names what was missing and the route). Nothing falls through to ok.
  - `tracking-item: required | optional | forbidden`: decided from the item the dispatch record names. `validate`: the value is one of the three words. `automate`: at spawn, `required` with none attached creates the item and records its name on the dispatch. `help`: a start inside a session that is already running (joined, inline) cannot be given an item by the spawner, so the session's coordinator is asked to create it, by an inquiry in its inbox naming the routine, and the start goes on with a warning kept on the run's record as `start-warning: tracking-item ...`, counted from the records. `reject`: `forbidden` with an item attached.
  - `operations: <operation prefixes the steps need>`: decided against what the acting member holds, and REPORTED, NEVER ENFORCED. `validate`: each prefix exists and the declared executors can hold it. `automate`: nothing, as a permission is only ever passed by a holder. `help`: an executor that cannot hold a prefix; the finding names the operation, the member and the routine, and the permission ask that is the route. `reject`: a prefix no member session may hold, such as `--manager-*`, said plainly as a wall; the console runs it. A mismatch the routine's own tooling list narrows by an annotation (`— \`magic-coordinator\` only`) is not a fault. It is not overridable.
  - `start-context: inline | spawned | any`: `inline` runs only inside another run, `spawned` only as a run of its own, `any` either way; a joined start counts as `spawned`. `validate`: the value is one of the three words, and the Closure steps carry a closure line for each mode it allows, `Run inline:` and `Run as its own session:`. `reject`: at start, a start the routine does not allow, before any step runs, naming the start to use.
- `routine-lock-document:` (optional)
  - `inbox:<member>:<note>.md`, a note in the inbox of a named member, or of the member of the start where `<member>` is the macro `{{team-member}}` (the lock is then one for each member who runs the routine, never one note they contend on); a routine that runs another inline names that one's lock too, the documents separated by commas. The spawner locks it while it starts the routine, or the start fails; adds the document to the dispatch, with the instruction to update it; and gives it back when the session ends. Participants never lock or unlock: any participant of the locked session updates the locked document with `--update-routine-state` (ThisSession, `DistroAgentsSession.fn.sh`), which knows the session's routine and its locked document and takes no routine name or path; each update is committed, and pushed where a git remote is set, before the tool returns. A routine that locks lists that operation in its tooling block. It does not run in a workspace without team-data setup.
- `input-scan-def:` (optional)
  - One repeatable line for each scan: `input-scan-def: <scan> [--option value ...]`, or `input-scan-def: none` alone. `<scan>` is a scan of the tooling (`advance`, `client-sweep`, `grooming`, `heartbeat`, `member-work-session`, `morning-review`, `permission-escalation`, `routine-coworking-session`, `sweep`, `work-duty`); the spawner runs its `--intern-op-<scan>-input-scan` operation with the team member of the start and then the options as written. A value which exists only at session time is a macro, `{{<option-name>}}` over the five names of the common option set (`team-member`, `session-id`, `spawn-id`, `select-workspace`, `tooling-origin`). The spawner runs the scans at start, in the order written, with no instruction to an agent, after the routine's lock; saves the results to `input/input-scan.md` of the session sandbox (one scan as it is, several each under `## input scan: <scan>`); and names them in the brief. A routine declares only its own scans; a routine it runs inline brings its own. An explicit `none` runs no scan, where the routine's kind routine declares one. No routine calls its scan: an input scan is an operation of the tooling, not of an agent.
- `review-by:` (optional)
  - Whether the run's dispatch item is reviewed. `inherit`, the default and written explicitly, has the review follow where the run reports to (`reports-to:`); `none` disables it, and the item closes straight to processed with `review: none` in its Decisions; any other value names the reviewer, in the forms `--review-by` takes. A reviewer the caller of the spawn names stands, as the more specific.
- Overriding a refusal. An override is a permission, never a flag the acting member passes to itself: the grant of the tool `override` for the target `<requirement>:<routine file>`, asked through the chain that grants everything else, one requirement at a time. A member gives it only from what it holds, by an explicit pass, never wider or longer than its own. A start it lets through is kept on the run's record (`override:`) and on the dispatch item's `## Decisions`. `operations` is not overridable.
- `cache-prefix:` (optional)
  - How far the cacheable prefix of a spawn of this routine reaches: `armed`, the default, is the member's armed floor alone, for a routine that runs rarely; `routine` adds the routine's own instruction and reference, for a routine that runs often, so its runs share them. Any other value is refused by the validator, and the spawner writes the value on the run's record.
- `runs-at:` and `runs-after:` (optional)
  - The autorun keys. `runs-at: <days> <HH:MM>` or `runs-at: none`: days are `workdays`, `weekend`, `daily` or a list such as `mon,thu`, the time in the team schedule's zone. An explicit `none` says the routine never auto-runs, so a reader tells a routine that never auto-runs from one nobody has considered yet. `runs-after: <routine>` is a key of its own and names the one routine this one follows.
- `allows:` (optional)
  - Permissions the routine gives its participants while a session runs it, ending with that session: comma-separated `<member|executors|participants>:<tool>[:<target>]`, a path target relative to the workspace or absolute, %-escaped as a tracking document's `allows`.
  - Approved by its `maintainers:`. `cred:` and `spend:` entries stand only with `human-owner` among them; without him, any other entry stands only when a maintainer holds it.
  - It may also name the checkpoint operations, `executors:--executor-checkpoint-push`, `--executor-checkpoint-rewind` and `--executor-checkpoint-exit`, for a routine of a single participant. `validate`: only with `requires-session-kind: standalone`, one executor and no invitees, and no other `--executor-` operation.
- `# <owning-member>.<short-name>.routine — the actual procedure`
  - The file's own title line, before `# Summary` — every existing routine file carries one.
  - The title is the file's own name minus `.md`: a routine is named by its file, never by an identity of its own.
- `# Summary`
  - One short sentence, names the routine.
  - `## Goals`
    - Compact narrative, still detailed.
  - `## Scope`
    - What it does.
    - What it deliberately doesn't do.
- `# Opening steps`
  - Same shape/discipline as `# Steps`. Runs before `# Steps`, after the Opening steps of the routine of the session kind the routine names.
- `# Steps`
  - Exact instructions, execute in order, literally as written.
  - A step that can't execute as written: escalate it, and never skip it silently.
  - Exact steps as nested lists. Nested lines follow `magic-team/reference/skill-folder-model.md`'s nested-item grammar (`goal:`/`rule:`/`step:`).
  - Every root-level step carries a name, in the established shape: `<N>. **name-of-meaning**: …` — names what the step does, never where it sits. Unique within the file.
  - A step is referred to by its name, not its number alone — inside the file and from any other file. A step with no name can only be pointed at by position, and position is the first thing an edit changes.
  - Applied as each routine file is next touched, not as a sweep.
- `# Closure steps`
  - Same shape/discipline as `# Steps`.
  - Runs only after `# Steps`, and everything it extended/dispatched/spawned, have finished, ending with a handback to the routine's own parent carrying what was agreed, per "The ladder: one rung at a time". The Closure steps of the routine of the session kind the routine names follow its own.
  - An already-existing closing tail in `# Steps` relocates here verbatim — no invented content.
  - No closing tail of its own: state that plainly, plus a pointer to whatever actually closes it.
  - Sequencing: `magic-team/reference/skill-folder-model.md`'s own "Routine" entry.
- `# Routine's local procedures`
  - Named procedure blocks, `## <local-procedure-name>`, called by name from `# Steps`.
  - Not separate routines.
  - Not visible outside this file.
- `# Routine's local rules`
  - All statements apply simultaneously.
  - Override a participant's own general `.armed.md` rules while this routine is active.
  - Executor is permitted/obliged to execute every step as written.
  - Participants obey this routine's own rules over their normal ones.
  - A participant's disagreement, where the routine needs group agreement, follows "The ladder: one rung at a time".
  - Any other rules, exceptions, overrides.
- `# Routine-specific tooling`
  - Every `magic-tooling` operation this routine uses — not more, not less.
  - `## DistroAgentsTools magic-tooling operations`
    - List, with argument syntax.
  - `## <--operation-name> Operation Reference`
    - Only what that operation's own help, read with `--member-help`, does not carry. Absent where the help carries it all.
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
