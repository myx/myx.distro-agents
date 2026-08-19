# Deploy tooling: multiple distinct, purpose-specific tools — not one universal mechanism

Verified this session against real command output, not source-reading alone.

## `BuildDistroFromSource.fn.sh` has no project scoping — don't reach for it to refresh one project

Its own `--help`: "Orchestrates the full build pipeline from source ingest to final distro/export artifacts." Only takes `--continue`/`--only`/`--help*` — no project/selector argument at all, and neither do its two stage-scripts (`BuildCachedFromSource.fn.sh`, `BuildOutputFromCached.fn.sh`, both explicitly "Arguments: None"). Running it to pick up one project's local edit genuinely works, but processes the entire repository set (every namespace) and, at the final stage, spreads built artifacts out to remote hosts — real, unrelated side effects, not just slow.

**The correct, narrow command for picking up a local source edit** (confirmed via the real VS Code task "🛫 Ingest Source Changes..."): `DistroSourcePrepare.fn.sh --ingest-distro-index-from-source`. Runs sync-from-source + index-publish in sequence, scoped to whatever actually changed — real output confirms with `🔂 scan/sync: updated: <project>` per touched project. Use this first; reach for the full pipeline only if this genuinely doesn't resolve the staleness.

## This tooling family has multiple distinct, purpose-specific deploy tools — match the tool to the actual target category, don't assume one mechanism covers everything

There is no single universal "the deploy command." Different target categories have their own dedicated tool, each with its own real, native single-target interface:
- `DeployProjectSsh.fn.sh` — per-host/per-project deploys (install-script pipeline, `image-install:` directives).
- `DeployRouting.fn.sh` — routing/domain/cert config (`*-structure.json`, `image-execute:deploy-l6route-config:` directives) specifically. Confirmed this session: `DeployProjectSsh.fn.sh`'s normal flow never touches `image-execute:` directives at all — running it against a routing-config-bearing project does not also push the routing config, and isn't a substitute for `DeployRouting.fn.sh`.
- Likely others exist for other target categories not yet encountered — the pattern to expect is "a dedicated tool per category," not "one tool that eventually handles everything if you find the right flag."

**The actual skill is identifying which specific tool matches your actual target, not defaulting to whichever deploy tool is already familiar.** A `project.inf`'s own declarations (`image-install:`/`image-execute:`/`Declares:`, and any hook script a `Declares:` line points at) are one real way to discover which category a given target/config falls into and which tool owns it — worth checking before assuming — but that's a discovery aid, not evidence that "go through `project.inf` declarations" is itself the one mechanism. Once the right tool is identified, look for its own native single-target CLI form before working around it with a hand-assembled invocation.

Confirmed pattern found this session: a purpose-built deploy tool for one config category wasn't registered on the console's normal command PATH (unlike the regular `myx.distro-*` tools), needed a full-path invocation, and had its own explicit single-target flag — once found, it needed no environment-variable setup at all. Real customer/namespace specifics for that example (script path, host names, the actual mechanism) belong in the owning namespace `keeper-*`'s domain knowledge or the relevant repo's own `MAGIC.md`, not here — this file stays cross-customer/generic.
