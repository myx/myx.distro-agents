#!/usr/bin/env bash
## Check on --camunda-diagram-sync-stale (T9/T9e): the BPMN/DMN diagrams older than the newest definition file.
## Two layers are held here: the dispatcher's operation arm (sh-lib/session/AgentsTools.Dispatcher.include), its
## argument checks and what it prints, and, below it, the mtime comparison itself
## (sh-lib/member/AgentsTools.CamundaDiagramSync.include), called directly over a scratch tree of files at
## controlled mtimes. Sourced and called directly (unit check), offline, with no Slack and no camunda002.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPackage/sh-lib/session/AgentsTools.Dispatcher.include"
rigFails=0 rigPasses=0
rigAssert(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi ; }
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsCamundaDiagramSyncStaleCheck.XXXXXX" )" || exit 1 ; trap 'rm -rf -- "$rigTmp"' EXIT
rigDefs="$rigTmp/defs" rigDiags="$rigTmp/diags" ; mkdir -p "$rigDefs" "$rigDiags" "$rigTmp/empty"
printf 'routine def\n' > "$rigDefs/routine.md"
printf 'a\n' > "$rigDiags/one.bpmn" ; printf 'b\n' > "$rigDiags/two.dmn" ; printf 'c\n' > "$rigDiags/three.png"
touch -t 202601010000 "$rigDiags/one.bpmn"
touch -t 202612010000 "$rigDefs/routine.md"
touch -t 202701010000 "$rigDiags/two.dmn"
touch -t 202612020000 "$rigDiags/three.png"

echo "-- the dispatcher's arm: its argument checks, and the stale .bpmn it prints --"
rigOut="$( MDSC_CMD=DistroAgentsDispatcher AgentsToolsCamundaDiagramSyncStale --camunda-diagram-sync-stale "$rigDefs" "$rigDiags" )" ; rigRc=$?
rigAssert "the .bpmn older than the newest definition is printed, the newer .dmn and the .png are not" "$rigRc $( printf '%s\n' "$rigOut" | LC_ALL=C tr '\n' '|' )" "0 $rigDiags/one.bpmn|"
rigOut="$( MDSC_CMD=DistroAgentsDispatcher AgentsToolsCamundaDiagramSyncStale --camunda-diagram-sync-stale "$rigDefs" "$rigTmp/none" 2>&1 )" ; rigRc=$?
rigAssert "a missing diagrams directory is refused" "$rigRc $( printf '%s' "$rigOut" | LC_ALL=C grep -c 'no such diagrams directory' )" "1 1"
rigOut="$( MDSC_CMD=DistroAgentsDispatcher AgentsToolsCamundaDiagramSyncStale --camunda-diagram-sync-stale "$rigTmp/empty" "$rigDiags" 2>&1 )" ; rigRc=$?
rigAssert "a definitions directory with no file is refused" "$rigRc $( printf '%s' "$rigOut" | LC_ALL=C grep -c 'holds no file' )" "1 1"
rigOut="$( MDSC_CMD=DistroAgentsDispatcher AgentsToolsCamundaDiagramSyncStale --camunda-diagram-sync-stale "$rigDefs" "$rigDiags" stray 2>&1 )" ; rigRc=$?
rigAssert "a stray argument is refused" "$rigRc $( printf '%s' "$rigOut" | LC_ALL=C grep -c 'stray argument' )" "1 1"

## Below the arm: the function itself, over the two directories it takes.
. "$rigPackage/sh-lib/member/AgentsTools.CamundaDiagramSync.include"
echo "-- the comparison itself: the member function, called directly --"
rigMtime(){ ## file, epoch
	date -r "$2" +%Y%m%d%H%M.%S > /dev/null 2>&1 && touch -t "$( date -r "$2" +%Y%m%d%H%M.%S )" "$1" || touch -d "@$2" "$1"
}
rigMDefs="$rigTmp/mdefs" rigMDiags="$rigTmp/mdiags" ; mkdir -p "$rigMDefs/routine-rig" "$rigMDiags"
rigMBase="$( date +%s )"
rigMtime "$rigMDefs/routine-rig/rig.routine.md" $(( rigMBase + 300 ))
rigMtime "$rigMDiags/current.bpmn" $(( rigMBase + 400 ))
rigMtime "$rigMDiags/stale.bpmn" $(( rigMBase + 100 ))
rigMtime "$rigMDiags/stale-old.dmn" $(( rigMBase - 100 ))
rigOut="$( AgentsToolsCamundaDiagramSyncStale "$rigMDefs" "$rigMDiags" )"
rigAssert "only the diagrams older than the newest definition are printed, one a line, in find order" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^' )" 2
rigAssert "the current one is not stale" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'current.bpmn' )" 0
rigAssert "the stale ones are" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -E 'stale\.bpmn|stale-old\.dmn' )" 2
rigAssert "a missing directory is refused, rc not 0" "$( AgentsToolsCamundaDiagramSyncStale "$rigTmp/none" "$rigMDiags" >/dev/null 2>&1 ; echo $? )" 1

if [ "$rigFails" -ne 0 ] ; then echo "⛔ CAMUNDA_DIAGRAM_SYNC_STALE FAILED: $rigFails of $(( rigPasses + rigFails ))" >&2 ; exit 1 ; fi
printf 'CAMUNDA_DIAGRAM_SYNC_STALE: OK (%d assertions)\n' "$rigPasses"
