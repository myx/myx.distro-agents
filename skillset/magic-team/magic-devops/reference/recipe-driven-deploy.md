---
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# Deploy tooling: multiple distinct, purpose-specific tools — not one universal mechanism

## Contents

- `BuildDistroFromSource.fn.sh` has no project scoping — don't reach for it to refresh one project
- This tooling family has multiple distinct, purpose-specific deploy tools — match the tool to the actual target category, don't assume one mechanism covers everything
- `DeployProjectSsh.fn.sh` real invocation — the pieces `--help` alone doesn't give you

## `BuildDistroFromSource.fn.sh` has no project scoping — don't reach for it to refresh one project

Its own `--help`: "Orchestrates the full build pipeline from source ingest to
final distro/export artifacts." It takes only `--continue`/`--only`/`--help*`.
It allows no project or selector argument at all, nor do its two stage-scripts
(`BuildCachedFromSource.fn.sh`, `BuildOutputFromCached.fn.sh`, both explicitly
"Arguments: None"). Running it to pick up one project's local edit works, but processes the entire
repository set (every namespace). At its final stage it rewrites the
workspace's own `distro/` and `export/` trees wholesale (`rsync --delete`) —
real, unrelated side effects, not just slow. Nothing in it carries either tree off the machine (`myxdistro-pipeline.md`, "What publish currently means").

**The correct, narrow command for picking up a local source edit** is `DistroSourcePrepare.fn.sh --ingest-distro-index-from-source`. It is the same one the workspace's own "🛫 Ingest Source Changes..." VS Code task runs. It prints `🔂 scan/sync: updated: <project>` per touched project. Use this first. A value that still reads old afterwards goes to the workspace task `📥 Re-Build Source Index Snapshot (cached from source)...`, which is `BuildCachedFromSource.fn.sh`.

## This tooling family has multiple distinct, purpose-specific deploy tools — match the tool to the actual target category, don't assume one mechanism covers everything

There is no single universal "the deploy command." Different target categories have their own dedicated tool, each with its own real, native single-target interface:
- `DeployProjectSsh.fn.sh` — per-host/per-project deploys (install-script pipeline, `image-install:` directives).
- `DeployRouting.fn.sh` — routing/domain/cert config (`*-structure.json`, `image-execute:deploy-l6route-config:` directives) specifically. `DeployProjectSsh.fn.sh`'s normal flow never touches `image-execute:`
  directives at all. Running it against a routing-config-bearing project does
  not also push the routing config, and isn't a substitute for
  `DeployRouting.fn.sh`.
- Likely others exist for other target categories not yet encountered. Expect
  the pattern "a dedicated tool per category," not "one tool that eventually
  handles everything if you find the right flag."

**The actual skill is identifying which specific tool matches your actual target, not defaulting to whichever deploy tool is already familiar.** A `project.inf`'s own declarations are one real way to discover a target's
category and the tool that owns it. Those declarations are
`image-install:`/`image-execute:`/`Declares:`, plus any hook script a
`Declares:` line points at. That check is worth making before assuming. It is
a discovery aid, not evidence that "go through `project.inf` declarations" is
itself the one mechanism. Once the right tool is identified, look for its own native single-target CLI form before working around it with a hand-assembled invocation.

A purpose-built deploy tool for one config category may be absent from the
console's normal command PATH, unlike the regular `myx.distro-*` tools. It may
need a full-path invocation, its own explicit single-target flag, and no
environment-variable setup at all. Real customer or namespace specifics for that example belong elsewhere. They
are the script path, host names and the actual mechanism. Name them in the
owning namespace `keeper-*`'s domain knowledge, or in the relevant repo's own
`MAGIC.md`. This file stays cross-customer and generic.

## `DeployProjectSsh.fn.sh` real invocation — the pieces `--help` alone doesn't give you

- **`--project` and `--select-projects` are two entrypoints, not two spellings.** The sourced caller calls `DeployProjectsSsh`, defined at `DeployProjectSsh.fn.sh:348`. Its `--*)` arm sends the arguments to `Distro ListDistroProjects` at `:380`, which refuses options after `--project`. So a direct `--project <p> --prepare-full --save-full-script` works only through the command-line caller. That caller runs `DeployProjectSsh.fn.sh`, whose executable tail at `:783` calls `DeployProjectSsh`, defined at `:488`.
- By hand the tool is called as `DeployProjectSsh.fn.sh`. A deploy needs no knowledge of how the scripts work inside: read the command's `--help` and its examples, and run it.
- Project selection takes the project selector with the project's own name: `DeployProjectSsh.fn.sh --select-projects <name> --prepare-full --deploy-full`. The `--help` example is an example, never a ceiling.
- **Which workspace root (`MMDAPP`) the console runs from matters, independent of correct selection syntax.** A console run from a workspace that does not hold the target project under its own `source/<namespace>/...` tree reports "no projects selected" for it, even with exactly correct `MDSC_SELECT_PROJECTS` syntax. Run the console from the workspace root that contains the target project.
- The tool has two entrypoints and one worker. By hand, `DeployProjectSsh.fn.sh` takes a project selector and hands it to `ListDistroProjects`, which calls `DeployProjectsSsh --select-from-env` with the selection in `MDSC_SELECT_PROJECTS`. A console or piped script that sources the file calls `DeployProjectsSsh --select-from-env` directly, with the projects named in `MDSC_SELECT_PROJECTS`. `--select-from-env` is no selector, so copied into the executable form it is refused by `ListDistroProjects` before a deploy begins.
- A source edit reaches a deploy only after the workspace task `🛫 Ingest Source Changes...` has run, which is `DistroSourcePrepare.fn.sh --ingest-distro-index-from-source`. No other command ingests changes.
- `--prepare-full` = `--prepare-sync` (upload files) + `--prepare-exec` (prepare the exec script) together. `--deploy-full` runs both stages against the real target. Real success looks like `>>> script end: ...` then `>>> script done: ...` with
  no `⛔ ERROR:` line anywhere, followed by `ImageDeploy: 🏁 task finished.` The
  `⛔ ERROR:` clause is the whole of that test. A failed fragment prints `⛔
  ERROR: deploy fragment failed: <fragment>` from its own return-code test and
  exits the exec script there. The `>>> script end:`/`>>> script done:` pair
  is emitted between the return-code capture and that test, so neither line is
  conditional on the outcome. A `done` line is not evidence of success. `ImageDeploy: 🏁 task finished.` is not evidence either. The generated remote
  payload carries no top-level `set -e`, so a failed `bash ./exec` does not
  stop it and the line prints anyway. Don't read partial output as success.
- `DeployProjectSsh.fn.sh --project <p> --prepare-full --save-full-script` builds `output/deploy/<p>/{exec,sync,deploy-script.full.txt}` without ssh. A workspace carrying its own copy of `source/myx` builds from that copy. So a
  source edit made elsewhere does not reach its bundle until the copy is
  updated.
- A deploy is two hand commands, run from the workspace root that holds the project: `DistroSourcePrepare.fn.sh --ingest-distro-index-from-source`, then `DeployProjectSsh.fn.sh --select-projects <name> --prepare-full --deploy-full`.
