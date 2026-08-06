# Verifying changes with real side effects (network/filesystem/live execution)

Read this when a change needs verification but running the real thing means real
consequences — git clone/pull across repos, remote SSH execution, anything that
touches the network or filesystem for real rather than in a sandbox. Distinct from
ordinary unit/integration test running: there's no fixture to reset, so the
verification technique itself has to manage the blast radius.

Confirmed live 2026-07-18, from moving `DistroImageSync.fn.sh` (+ exclusive
includes) from `myx.distro-source` to `myx.distro-system` and then executing it
live to pull real sources.

## Preview mode beats grepping for blast radius

Before running anything that does real clone/pull/write across a workspace's
repos, run its preview/dry-run flag first if one exists (`myx.distro-*`'s
convention: a `--print-*` twin next to the `--execute-*` verb, e.g.
`DistroImageSync --all-tasks --print-source-prepare-pull` before
`--execute-source-prepare-pull`). **A static grep for the declare/config pattern
is not the same as the tool's actual resolved task list** — confirmed case: a
`project.inf` grep estimated ~5 target repos, but the real preview showed 12,
because `util.workspace-myx.devops`'s `project.inf` re-declares 11 of the 15
sync-task lines itself. Declares can be transitively re-asserted by other
projects, not just self-registered by the project they describe. When blast
radius matters, ask the tool (preview mode), don't trust a grep-based estimate.

## Timeout-guard every live-execution reproduction attempt

When a user reports "it hangs," the reflex to just re-run it is a trap: an
unguarded re-run of something that might genuinely hang blocks the debugging
session with zero diagnostic output. Wrap every reproduction attempt in a hard
wall-clock limit before doing anything else, so a real hang fails loud and fast
instead of stalling the session.

**Gotcha confirmed on at least one dev box: no `timeout`/`gtimeout` binary
available.** Working substitute:
```
perl -e 'alarm shift; exec @ARGV' <secs> <cmd...>
```
Check for `timeout`/`gtimeout` first; fall back to the perl-alarm form if
neither exists. Unconfirmed whether this gap is host-specific or general across
the estate's dev machines — don't assume either way without checking.

## Know the codebase's verbose-tracing lever before reaching for ad hoc debugging

For diagnosing exactly where a pipeline stalls, check whether the codebase
already has a tracing env var before adding `set -x` or print statements.
`myx.distro-*`'s shell codebase: `MDSC_DETAIL=full` gates verbose `>&2` tracing
throughout — grep any `sh-scripts/*.fn.sh` for `[ -z "$MDSC_DETAIL" ] ||` to see
the pattern live. Check the equivalent for whatever codebase is actually in
front of you (AE3, AxiomCMS, ndm/knt/ncz services each likely have their own) —
ask the owning keeper/partner if it's not obvious from a quick grep.

## Stale background state is a false-positive class for "hang"

Before concluding anything about a suspected hang's root cause, check for
orphaned background state that can *look* exactly like an application hang:
- orphaned SSH control-master processes (`ssh -MNf ... -o ControlPersist=3m
  ...`, set up by `DistroImage.SyncScriptMaker.include` for multiplexed
  git-over-SSH in `myx.distro-*`)
- stale control sockets (workspace-local `.local/temp/ssh/` in this tool
  family)

A self-expiring session from an interrupted earlier run (e.g. a
`ControlPersist=3m` master) can present as a fresh hang if you don't know to
check process/socket state first. This generalizes beyond SSH multiplex
sockets — any codebase with backgrounded/persistent helper processes has an
equivalent class of stale-state false positive; ask what the equivalent is
before diagnosing a "hang" as a code bug.

## Clean diff + static audit is necessary, not sufficient

A thorough static audit (no stale path self-references to the old location
after a file move, correct file permissions matching git-tracked mode and
sibling convention, clean additive-only `git diff --stat`) catches what it can
catch, but **only a real end-to-end run is actual proof a change didn't break
runtime behavior.** Static/diff-level checks can't catch a runtime-only issue by
construction. For anything with real side effects, budget for the live run (run
twice if a fluke is plausible) as part of "done," not as an optional extra past
the diff review.

## "Ruled out" vs "couldn't reproduce" — say which one you mean

When a reported issue doesn't reproduce, don't stop at "works for me" and
report that as if it settled the question. Distinguish, out loud, in the report
back to the user:
- **Weak**: "I couldn't reproduce it." (tried once or twice, nothing happened)
- **Strong**: "I checked the specific mechanisms that would cause this and
  ruled them out." (e.g. traced every path reference in the changed files to
  confirm none pointed at a stale location, confirmed no stale process/socket
  state existed) — before concluding the change itself wasn't the mechanism.

A user who hit something that then stops reproducing needs to know which claim
they're getting; conflating the two erodes trust in the next report even if
this one happened to be right.
