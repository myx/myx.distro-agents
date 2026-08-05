# myx.distro-* — AI assistant context

Applies to: myx.distro-.local, myx.distro-deploy, myx.distro-source, myx.distro-system, myx.distro-remote, myx.distro-agents.

Canonical human docs (don't restate here, read them instead):
- Each repo's `README.md` — pipeline stages, folders, variables, `project.inf` properties.
- `myx.distro-.local/sh-lib/help/Man.Project.Inf.file.help.md` — `project.inf` file-format grammar.

This file is reasoning aid + flagged issues, not a rewrite of those docs.

## Repo roles

- `myx.distro-system` — shared kernel (`Distro`/`Require`/`Action`/`DistroSystemContext` in `SystemContext.include`), used by nearly every `.fn.sh`.
- `myx.distro-source` — builds distro indices from source.
- `myx.distro-deploy` — package management/deploy tooling. Requires `myx/myx.distro-source`.
- `myx.distro-remote` — remote-host tooling.
- `myx.distro-agents` — starts a `claude`/`copilot` CLI console (`DistroAgentsConsole.sh`) instead of a bash session. No pipeline builders (console-launcher role, like `-remote`).
- `myx.distro-.local` — bootstraps a fresh workspace, installs the other subsystems. No pipeline builders (boot-only).

Only `myx.distro-source` and `myx.distro-deploy` have shell-side pipeline builders; `-system`/`-remote`/`-agents` don't (kernel/tooling roles).

## Command layout & help conventions

- `sh-scripts/<Name>.fn.sh` — entry point. Defines function `<Name>`, ends with `case "$0" in */sh-scripts/<Name>.fn.sh) ... esac`.
- `sh-lib/help/Help.<Name>.help.md` + `sh-lib/help/Help.<Name>.include` — help pair. Standard `.include` echoes `📘 syntax: ...` lines and, on `--help`, calls `myx.common lib/catMarkdown` on the `.help.md`. Standard `.help.md` sections: `##  Summary:`, `##  Arguments:`, `##  Options:`, `##  Examples:` (optionally `Notes:`/`Environment Variables:`), tab-indented body, examples as `# comment` + backtick command.
- `Man.<Topic>.help.md` — free-form reference doc (file formats, install guides), not paired with `.include`/`.fn.sh`. Different genre from `Help.*`.

Known inconsistencies — confirmed, not resolved, ask before touching:
- Some `Help.<Name>.include` (all `List*` in myx.distro-system; `ListSshTargets` in deploy; `DistroImageSync`/`ListProjectSequence`/`DistroSourceConsole` in source) duplicate Options/Examples as raw `echo` instead of calling `catMarkdown`. In `ListDistroDeclares` this duplicate has already drifted from its own `.help.md` (different options listed).
- `--help` vs `--help-syntax` wiring differs per command (inline in function body vs. only in the outer `case "$0"` dispatcher vs. `JumpTo`'s split behavior).
- `myx.distro-remote/sh-lib/Help.DistroRemoteTools.help.md` (sh-lib root) is a stale orphaned duplicate of `sh-lib/help/Help.DistroRemoteTools.help.md`; only the `help/` copy is referenced by code.
- The console-launcher role itself has no `sh-scripts/*.fn.sh` command: `DistroAgentsConsole.sh` is a workspace-root launcher script, generated the same way the sibling `DistroXConsole.sh` scripts are, plus its own install/Command-Palette wiring. None of the four sibling launcher scripts implement `--help` either. Separately, this package also owns `sh-scripts/DistroAgentsTools.fn.sh` — see "its own notes" below — which does have its own `Help.DistroAgentsTools.help.md`/`.include` pair.

Rule: follow the standard form for new/edited help. If touching a flagged exception, ask first — don't silently "fix" it or copy the divergent pattern elsewhere.

## Dispatchers (`SystemContext.include`)

- `Distro <CommandName> [args]` — resolves to a shell function, sourcing `<CommandName>.fn.sh` from PATH if needed, then calls it. Empty/`--*` first arg sources `SystemConsole.include` instead (interactive console).
- `Require <name>` — same lookup, searches `myx.distro-{system,source,deploy,remote,.local}/sh-scripts/<name>.fn.sh` in that fixed order, only sources (doesn't call). `myx.distro-agents` is not in this fixed list — `Require` won't find `sh-scripts/DistroAgentsTools.fn.sh` there even though the file now exists in this package.
- `Action <name>` — unrelated third dispatcher: runs `$MMDAPP/actions/<name>` (`.sh` executed, `.url` opened).

Recurring internal calling convention: `type <FunctionName> >/dev/null 2>&1 || . "$( myx.common which lib/<name> )"` — skip re-sourcing if the function is already defined in this shell, else resolve and source it. Unlike `myx.common`'s own internal convention (which hardcodes `.Common` and skips OS dispatch — see `myx.common/os-myx.common` CLAUDE.md), this one still calls `myx.common which`, so it stays OS-aware (one subprocess to resolve the path, none to run it) rather than assuming no OS variance.

Bare-script invocation of a `.fn.sh` that itself calls `Distro <other-name> ...` can fail even though the target file exists:
- `Distro`'s own lookup only tries `type` then `command -v <name>.fn.sh` on `PATH` — unlike `Require`, it does **not** search the fixed `myx.distro-{system,source,deploy,remote,.local}/sh-scripts/` list itself.
- That search only happens because a console's bashrc (`console-*-bashrc.rc`) puts all five `sh-scripts/` dirs on `PATH` before handing off to `Deploy`/`Source`/etc. (e.g. `myx.distro-deploy/sh-scripts/ExecuteParallel.fn.sh`, whose `--select-*` handling calls `Distro ListDistroProjects ...`).
- Outside a console — plain `bash sh-scripts/Foo.fn.sh` — any `Distro <name>` call to a command not already sourced fails with `unknown command: <name>`.

## Dependency/index engine

`BuildSequencesFromProvidesAndRequires.awk` topologically sorts the whole `Requires`/`Provides` project graph once into a flattened **sequence** file (`<project> <transitively-required-project>` lines, deps before the project; cycle-safe via an "unflushed" counter). Every "merged" view is that sequence joined against a raw per-project index (`IndexNoCacheDistroMerged.include`) — not a live graph walk per call.

Two independent axes in `system-context/IndexNoCache*.include`:
- **Owned vs Merged**: Owned = a project's own declared values only. Merged = owned + everything inherited transitively via the sequence join.
- **Distro vs Project scope**: Distro = all projects at once. Project = one named project (`$MDSC_PRJ_NAME`).

Raw index data fallback ladder: (1) cached flat file `$MDSC_CACHED/distro-index.env.inf` (`PRJ-<KEY>-<project>=v1:v2`, rebuilt via `BuildSingleIndex.awk` only when stale), else (2) legacy Java path (`Distro DistroSourceCommand --import-from-source ...`), else (3) in-shell awk build cached in `$MDSC_MEMORY` for the session. **The Java path is fallback/legacy only** — may need a patch to stay in sync, but reason about design from the shell (awk/bash) implementation, not from Java.

## Pipeline implementation notes

(Stage table, folders, and variable meanings are in each repo's README.md — this is what the README doesn't say.)

`MDSC_SOURCE`/`MDSC_CACHED`/`MDSC_OUTPUT` are **stage-scoped**, reassigned by each stage script to its own input/output dirs — not fixed constants:
- Stage 1 (`BuildCachedFromSource`): `MDSC_CACHED=.local/source-cache/prepare`
- Stage 2 (`BuildOutputFromCached`): `MDSC_CACHED=.local/output-cache/prepared`, `MDSC_OUTPUT=.local/output-cache`
- Outside an active stage (ad-hoc commands): `MDSC_CACHED` defaults to `.local/system-index`, the published steady-state index — what most day-to-day commands see.

Builder discovery (`ScanSourceBuilders.include`) isn't limited to the core repos — any project in the distro index may declare its own `builders/<stage>/<NNNN>-*.sh` and it's picked up automatically.

`source-publish` (reserved stage-3 alt name, see README) is matched by the discovery glob but not wired to any runner yet: stage 3 always runs via `BuildDistroFromSource.fn.sh → AllBuilders --executables image-prepare`, and `AllBuilders.fn.sh`'s own stage filter doesn't accept `source-publish` as a value either. Don't remove or repurpose it.

## myx.distro-agents — its own notes

5th console entry point. Package boundary: owns `DistroAgentsConsole.sh` (the
workspace-root launcher, generated the same way the four sibling `DistroXConsole.sh`
scripts are), its own install/Command-Palette wiring (`sh-lib/AgentsTools.Make.include`,
`sh-lib/AgentsTools.Make.VSCodeTasksFragment.include`, `sh-lib/AgentsContext.include` +
`AgentsContext.SetInputSpec.include`), and `sh-scripts/DistroAgentsTools.fn.sh` plus its
`sh-lib/Agent*`/`AgentsTools.*` support files and `sh-lib/help/Help.DistroAgentsTools.*`
pair (magic-* team Slack/email/board/console-session automation — unrelated to the console
launcher above, see the naming-collision note below).

**Not the same thing as `DistroAgentsConsole.sh`**: `sh-scripts/DistroAgentsTools.fn.sh`,
also owned by this package, is a separate, unrelated magic-* team automation tool
(Slack/email/board/console-session ops).

**Naming-collision note**: `myx.distro-.local/sh-lib/LocalTools.Make.include`'s install
loop mechanically builds a wrapper function named `Distro<ITEM>Tools` per subsystem; for
`ITEM="Agents"` this is literally `DistroAgentsTools` — the same name as the unrelated
tool above. Confirmed safe (subshell-scoped, install-time-only, never coexists at runtime
with the real tool) and deliberately kept rather than special-cased, per the
myx.distro-agents build session's own quorum review (magic-architect + magic-developer).
See `AgentsTools.Make.include`'s own header comment for the full reasoning.

`DistroAgentsConsole.sh` starts the selected CLI directly when `--cli` is given
explicitly, and hard-fails if that CLI is not on `PATH`. With no explicit `--cli`, it
defaults to `claude`; if that default CLI is not on `PATH`, the interactive launcher
falls back to a bash session instead of exiting immediately. `--non-interactive`
(headless-terminal) still exits with an error in that case — it has no bash-session
fallback. Remaining args in `--non-interactive` mode are joined into one prompt string
passed to the CLI's own `-p`/`--print`; with none given, that flag reads the prompt from
stdin instead. The exact `-p`/`--print` flag is verified real, documented behavior for
the Claude Code CLI; the equivalent for the standalone `copilot` CLI is a documented
assumption, not independently verified — neither binary exists on the workspace-build
host this package was authored on.