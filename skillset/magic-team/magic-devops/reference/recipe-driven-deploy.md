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

**The correct, narrow command for picking up a local source edit** is `DistroSourcePrepare.fn.sh --ingest-distro-index-from-source`. It is the same one the workspace's own "🛫 Ingest Source Changes..." VS Code task runs. It runs sync-from-source + index-publish in sequence, scoped to whatever actually changed. It prints `🔂 scan/sync: updated: <project>` per touched project. Use this first. Reach for the full pipeline only if this genuinely doesn't resolve the staleness.

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

- **The callable function is `DeployProjectsSsh` (plural "Projects") — the file/tool name (`DeployProjectSsh.fn.sh`) is singular.** Sourcing the file (`. ".../sh-scripts/DeployProjectSsh.fn.sh"`) defines the
  function. Plain console startup never auto-loads it, so a non-interactive
  invocation must source it explicitly first.
- **Project selection happens entirely through the `MDSC_SELECT_PROJECTS` environment variable**, set to the project's real full index path (e.g. a `container.*` instance under `infra/instances-<ns>/docker-containers/<name>`
  — the *full* path. A bare project name silently resolves to "no projects
  selected" rather than erroring. So a plausible-looking short name is not a
  safe fallback), then invoking `DeployProjectsSsh --select-from-env
  --non-interactive --prepare-full --deploy-full`. A bare project-name positional argument does nothing at all — silently ignored, not an error.
- **Which workspace root (`MMDAPP`) the console runs from matters, independent of correct selection syntax.** A workspace whose own `.local/source-cache`/`.local/output-cache` index covers
  only the myx.common/myx.distro-* tooling's bootstrap projects reports "no
  projects selected" for any real infra project. A small workspace kept for
  tooling-only use is one such case, and its failure persists even with
  exactly correct `MDSC_SELECT_PROJECTS` syntax. That project is simply not
  indexed there, so the syntax is right. Run the console from the workspace root that actually contains the target
  project under its own `source/<namespace>/...` tree. That root must also
  have a populated `.local/roots/` covering that namespace.
- **The console's own default mode reads from a cached "output" snapshot, not live source** (`DistroSystemContext --distro-from-output` — the console's own default setup). A same-session edit to a project's own install script is invisible to a deploy
  run this way. The cache must be refreshed through its own separate rebuild
  step first. The direct, immediate override for one shell is to run `DistroSystemContext
  --distro-from-source` first, before deploying. It switches lookups to the
  live `source/` tree directly, so a same-session edit deploys without the
  separate cache-rebuild step at all.
- `--prepare-full` = `--prepare-sync` (upload files) + `--prepare-exec` (prepare the exec script) together; `--deploy-full` runs both stages against the real target. Real success looks like `>>> script end: ...` then `>>> script done: ...` with
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
- Putting it together, this is a real one-shot non-interactive invocation from the correct workspace root. The console script is `DistroDeployConsole.sh`, at the workspace root. Its own `--non-interactive` flag is required for a scripted or piped invocation. Without it the script drops into an interactive `bash --rcfile` shell expecting a live TTY:
  ```
  MDSC_SELECT_PROJECTS='<full project index path>' \
    ./DistroDeployConsole.sh --non-interactive <<'EOF'
  DistroSystemContext --distro-from-source
  . "$MDLT_ORIGIN/myx/myx.distro-deploy/sh-scripts/DeployProjectSsh.fn.sh"
  DeployProjectsSsh --select-from-env --non-interactive --prepare-full --deploy-full
  EOF
  ```
