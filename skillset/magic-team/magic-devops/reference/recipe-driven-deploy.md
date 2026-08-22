# Deploy tooling: multiple distinct, purpose-specific tools — not one universal mechanism

Grounded in real command output, not source-reading alone.

## `BuildDistroFromSource.fn.sh` has no project scoping — don't reach for it to refresh one project

Its own `--help`: "Orchestrates the full build pipeline from source ingest to final distro/export artifacts." Only takes `--continue`/`--only`/`--help*` — no project/selector argument at all, and neither do its two stage-scripts (`BuildCachedFromSource.fn.sh`, `BuildOutputFromCached.fn.sh`, both explicitly "Arguments: None"). Running it to pick up one project's local edit genuinely works, but processes the entire repository set (every namespace) and, at the final stage, spreads built artifacts out to remote hosts — real, unrelated side effects, not just slow.

**The correct, narrow command for picking up a local source edit** (confirmed via the real VS Code task "🛫 Ingest Source Changes..."): `DistroSourcePrepare.fn.sh --ingest-distro-index-from-source`. Runs sync-from-source + index-publish in sequence, scoped to whatever actually changed — real output confirms with `🔂 scan/sync: updated: <project>` per touched project. Use this first; reach for the full pipeline only if this genuinely doesn't resolve the staleness.

## This tooling family has multiple distinct, purpose-specific deploy tools — match the tool to the actual target category, don't assume one mechanism covers everything

There is no single universal "the deploy command." Different target categories have their own dedicated tool, each with its own real, native single-target interface:
- `DeployProjectSsh.fn.sh` — per-host/per-project deploys (install-script pipeline, `image-install:` directives).
- `DeployRouting.fn.sh` — routing/domain/cert config (`*-structure.json`, `image-execute:deploy-l6route-config:` directives) specifically. `DeployProjectSsh.fn.sh`'s normal flow never touches `image-execute:` directives at all — running it against a routing-config-bearing project does not also push the routing config, and isn't a substitute for `DeployRouting.fn.sh`.
- Likely others exist for other target categories not yet encountered — the pattern to expect is "a dedicated tool per category," not "one tool that eventually handles everything if you find the right flag."

**The actual skill is identifying which specific tool matches your actual target, not defaulting to whichever deploy tool is already familiar.** A `project.inf`'s own declarations (`image-install:`/`image-execute:`/`Declares:`, and any hook script a `Declares:` line points at) are one real way to discover which category a given target/config falls into and which tool owns it — worth checking before assuming — but that's a discovery aid, not evidence that "go through `project.inf` declarations" is itself the one mechanism. Once the right tool is identified, look for its own native single-target CLI form before working around it with a hand-assembled invocation.

A purpose-built deploy tool for one config category is not necessarily registered on the console's normal command PATH the way the regular `myx.distro-*` tools are: it may need a full-path invocation, may carry its own explicit single-target flag, and may need no environment-variable setup at all. Real customer/namespace specifics for that example (script path, host names, the actual mechanism) belong in the owning namespace `keeper-*`'s domain knowledge or the relevant repo's own `MAGIC.md`, not here — this file stays cross-customer/generic.

## `DeployProjectSsh.fn.sh` real invocation — the pieces `--help` alone doesn't give you

Verified against real successful deploys against a real target, not source-reading alone.

- **The callable function is `DeployProjectsSsh` (plural "Projects") — the file/tool name (`DeployProjectSsh.fn.sh`) is singular.** Sourcing the file (`. ".../sh-scripts/DeployProjectSsh.fn.sh"`) defines the function; it is not auto-loaded by plain console startup and has to be sourced explicitly first in a non-interactive invocation.
- **Project selection happens entirely through the `MDSC_SELECT_PROJECTS` environment variable**, set to the project's real full index path (e.g. a `container.*` instance under `infra/instances-<ns>/docker-containers/<name>` — the *full* path; a bare project name silently resolves to "no projects selected" rather than erroring, so a plausible-looking short name is not a safe fallback), then invoking `DeployProjectsSsh --select-from-env --non-interactive --prepare-full --deploy-full`. A bare project-name positional argument does nothing at all — silently ignored, not an error.
- **Which workspace root (`MMDAPP`) the console runs from matters, independent of correct selection syntax.** A workspace whose own `.local/source-cache`/`.local/output-cache` index only covers the myx.common/myx.distro-* tooling's own bootstrap projects (confirmed real case: a small workspace kept for tooling-only use) reports "no projects selected" for any real infra project even with exactly correct `MDSC_SELECT_PROJECTS` syntax — because that project was simply never indexed there, not a syntax problem. Run the console from the workspace root that actually contains the target project under its own `source/<namespace>/...` tree and has a populated `.local/roots/` covering that namespace.
- **The console's own default mode reads from a cached "output" snapshot, not live source** (`DistroSystemContext --distro-from-output` — the console's own default setup). A same-session edit to a project's own install script is invisible to a deploy run this way until that cache is refreshed through its own separate rebuild step. The direct, immediate override for one shell, before deploying: run `DistroSystemContext --distro-from-source` first — switches lookups to the live `source/` tree directly; confirmed this makes a same-session edit actually deploy, without needing to find/run whatever separate cache-rebuild command would otherwise be required.
- `--prepare-full` = `--prepare-sync` (upload files) + `--prepare-exec` (prepare the exec script) together; `--deploy-full` runs both stages against the real target. Real success looks like `>>> script end: ...` then `>>> script done: ...` with no `⛔ ERROR:` line anywhere, followed by `ImageDeploy: 🏁 task finished.` A run that stops after `>>> script end:` without reaching `>>> script done:`, or that shows any `⛔ ERROR:` line, did not actually deploy — don't read partial output as success.
- Putting it together, a real one-shot non-interactive invocation from the correct workspace root — the console script is `DistroDeployConsole.sh` (at the workspace root; its own `--non-interactive` flag is required for a scripted/piped invocation, since without it the script instead drops into an interactive `bash --rcfile` shell expecting a live TTY):
  ```
  MDSC_SELECT_PROJECTS='<full project index path>' \
    ./DistroDeployConsole.sh --non-interactive <<'EOF'
  DistroSystemContext --distro-from-source
  . "$MDLT_ORIGIN/myx/myx.distro-deploy/sh-scripts/DeployProjectSsh.fn.sh"
  DeployProjectsSsh --select-from-env --non-interactive --prepare-full --deploy-full
  EOF
  ```
