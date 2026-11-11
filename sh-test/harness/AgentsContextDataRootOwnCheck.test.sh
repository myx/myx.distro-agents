#!/usr/bin/env bash
## AgentsContextDataRootOwnCheck -- the context load keeps one rig's team data to that rig (S12.19): an inherited
## MDAT_DATA_ROOT that is another workspace's own default root (`<other>/.local/agents/team-data-root`) is re-resolved for
## this MMDAPP and said once (AgentsContext.UseAgentsTools.include, as the spawn proxy does for a spawn).
## Guards: an inherited root of another workspace's default shape becomes this workspace's own; this workspace's own
## default root is kept, and nothing is said; in a workspace with no configured directory a root of another shape (a rig's
## `<tmp>/data`, a configured directory) is kept as given; with no root set, the workspace's own is resolved as before; in a
## workspace configured with a team data directory (a rig) an inherited root that is not it becomes it, said once, and the
## configured one itself is kept with nothing said.
## Red: a context load that keeps the inherited root fails `another workspace's default root is re-resolved`; one that
## keeps another rig's configured directory in a rig fails `a rig uses its configured directory`.
## Offline: a temp folder of this check alone, removed at its end; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.UseAgentsTools.include"
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsContextDataRootOwnCheck.XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
mkdir -p "$rigTmp/wsA/.local/agents" "$rigTmp/wsB/.local/agents" "$rigTmp/data"
## One context load as a tooling call makes it, with the root given (or none), printing the root it resolved and its own line.
rigLoad(){ ## MDAT_DATA_ROOT value or `unset`, MDAT_DATA_ROOT_OF value (optional)
	( cd "$rigTmp/wsA" && if [ "$1" = unset ] ; then unset MDAT_DATA_ROOT ; else export MDAT_DATA_ROOT="$1" ; fi
	  if [ -n "${2:-}" ] ; then export MDAT_DATA_ROOT_OF="$2" ; else unset MDAT_DATA_ROOT_OF ; fi
	  MMDAPP="$rigTmp/wsA" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_WORKSPACE_MODE=just-agents bash -c '. "$0" --rig-op 2> "$1" ; printf "%s" "$MDAT_DATA_ROOT"' "$rigInc" "$rigTmp/load.err" ) 2> /dev/null
}
rigLoadOf(){ ## MDAT_DATA_ROOT value, MDAT_DATA_ROOT_OF value -- prints the MDAT_DATA_ROOT_OF the load leaves
	( cd "$rigTmp/wsA" && export MDAT_DATA_ROOT="$1" && if [ -n "${2:-}" ] ; then export MDAT_DATA_ROOT_OF="$2" ; else unset MDAT_DATA_ROOT_OF ; fi
	  MMDAPP="$rigTmp/wsA" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_WORKSPACE_MODE=just-agents bash -c '. "$0" --rig-op 2> /dev/null ; printf "%s" "${MDAT_DATA_ROOT_OF:-}"' "$rigInc" ) 2> /dev/null
}

echo "-- 1. another workspace's default root is re-resolved --"
rigAssert "another workspace's default root is re-resolved" "$( rigLoad "$rigTmp/wsB/.local/agents/team-data-root" )" "$rigTmp/wsA/.local/agents/team-data-root"
rigAssert "and said once"                                   "$( LC_ALL=C grep -c 'is another workspace.s, so this call uses' "$rigTmp/load.err" )" 1

echo "-- 2. what is kept --"
rigAssert "this workspace's own default root is kept"       "$( rigLoad "$rigTmp/wsA/.local/agents/team-data-root" ):$( LC_ALL=C grep -c 'another workspace' "$rigTmp/load.err" )" "$rigTmp/wsA/.local/agents/team-data-root:0"
rigAssert "a root of another shape is kept as given"        "$( rigLoad "$rigTmp/data" ):$( LC_ALL=C grep -c 'another workspace' "$rigTmp/load.err" )" "$rigTmp/data:0"
rigAssert "with none set, the workspace's own is resolved"  "$( rigLoad unset )" "$rigTmp/wsA/.local/agents/team-data-root"

echo "-- 3. a rig, configured with a team data directory, works on it alone --"
mkdir -p "$rigTmp/wsA/.local/.agents" "$rigTmp/dataA"
printf 'TEAM_DATA_DIRECTORY=%s\n' "$rigTmp/dataA" > "$rigTmp/wsA/.local/.agents/magic-coordinator.agent.env"
rigAssert "a rig uses its configured directory"             "$( rigLoad "$rigTmp/data" )" "$rigTmp/dataA"
rigAssert "and says so once"                                "$( LC_ALL=C grep -c 'is not the team data .* is configured with, so this call uses its own' "$rigTmp/load.err" )" 1
rigAssert "the configured directory itself is kept, quietly" "$( rigLoad "$rigTmp/dataA" ):$( LC_ALL=C grep -c 'so this call uses' "$rigTmp/load.err" )" "$rigTmp/dataA:0"
rigAssert "another workspace's default root becomes it too"  "$( rigLoad "$rigTmp/wsB/.local/agents/team-data-root" )" "$rigTmp/dataA"
rigAssert "with none set, the configured one is resolved"   "$( rigLoad unset ):$( LC_ALL=C grep -c 'so this call uses' "$rigTmp/load.err" )" "$rigTmp/dataA:0"

echo "-- 4. the read is made once per workspace: the mark beside the root --"
rigAssert "a resolution marks the workspace it is for"      "$( rigLoadOf "$rigTmp/data" )" "$rigTmp/wsA"
rigAssert "a call marked for this workspace keeps its root and reads nothing" "$( rigLoad "$rigTmp/data" "$rigTmp/wsA" ):$( LC_ALL=C grep -c 'so this call uses' "$rigTmp/load.err" )" "$rigTmp/data:0"
rigAssert "a call marked for another workspace resolves its own" "$( rigLoad "$rigTmp/data" "$rigTmp/wsB" ):$( LC_ALL=C grep -c 'so this call uses' "$rigTmp/load.err" )" "$rigTmp/dataA:1"
rigAssert "and marks it for its children"                   "$( rigLoadOf "$rigTmp/data" "$rigTmp/wsB" )" "$rigTmp/wsA"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ CONTEXT DATA ROOT OWN CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  warn: a call made under another workspace's data root writes that workspace's team data" >&2
	echo "  fix:  the data-root resolution in sh-lib/harness/AgentsContext.UseAgentsTools.include" >&2
	exit 1
fi
echo "CONTEXT_DATA_ROOT_OWN: OK ($rigPass assertions, offline)"
