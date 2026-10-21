#!/usr/bin/env bash
## Behavioural check on the blocks the agents console adds to `Locations (Places)` through the registry of `.local` (F11.10 of the refactorings epic, step 2), run rather than read.
## The places are `.local`'s (myx.distro-.local, sh-lib/places/LocalTools.Places.include, sh-lib/manager/LocalTools.ManagerPlace.include, LocalManagerPlaceRows.awk) and know no function,
## no variable and no registry of the agents; what the agents add -- the registry of the sessions that name a workspace, what stands in a place (the members whose home it is, the
## team data root) and the members that belong to it -- is registered in sh-lib/config/place-blocks.list and written by readers of the agents. Held:
##   1. `.local`'s three place files name no AgentsTools function and no MDAT_ variable in a line of code, and no function of them is called Agents*
##   2. the list names the three kinds, each reader is a function of the include the line names, and the console's arm gives the list to the include
##   3. the reader asked for by a kind: none registered (no list, or a list without the kind) gives none and ends 0; one registered is given by its name, its include read; one the list
##      names that is not defined is refused, rc 1, naming it
##   4. without a registered block the places are shown without it: the sessions column reads `-`, and the read of a workspace that is there prints its consoles and no member and no
##      member home; with the agents' blocks the same call prints them (the byte-for-byte case is AgentsManagerPlaceCheck)
## Offline; only the rig's own tree is written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigLocal="$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
for rigFile in "$rigLocal/places/LocalTools.Places.include" "$rigLocal/manager/LocalTools.ManagerPlace.include" "$rigLocal/manager/LocalManagerPlaceRows.awk" "$rigHere/config/place-blocks.list" "$rigHere/manager/AgentsTools.ManagerPlaceBlocks.include" "$rigHere/manager/AgentsTools.ManagerPlaceMembers.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerPlaceBlocksCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}

echo "-- 1. .local knows nothing of the agents --"
rigBad=""
for rigFile in "$rigLocal/places/LocalTools.Places.include" "$rigLocal/manager/LocalTools.ManagerPlace.include" "$rigLocal/manager/LocalManagerPlaceRows.awk" ; do
	rigCode="$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigFile" )"
	[ "$( printf '%s\n' "$rigCode" | LC_ALL=C grep -c -e 'AgentsTools' -e 'MDAT_MANAGER_PLACE' -e 'agentsPlaces' || : )" = 0 ] || rigBad="$rigBad [code ${rigFile##*/}]"
	[ "$( printf '%s\n' "$rigCode" | LC_ALL=C grep -c -E '^Agents[A-Za-z]*\(\)' || : )" = 0 ] || rigBad="$rigBad [function ${rigFile##*/}]"
done
## the only variable of the agents the places still read is the skillset root, which names the built-in place of the member set (LocalToolsPlacesBuiltinRows)
rigAssert "the three place files of .local name no AgentsTools function, no variable of the places by the agents' prefix, and define no Agents* function" "${rigBad:- clean}" " clean"

## one field formatter for every console: .local's (LocalTools.ManagerField.include); the agents' readers call it and define none
rigAssert "the field of a row is written once: LocalToolsManagerField is defined by one file of .local, and no file of the agents' manager folder or of .local's defines or calls another (ManagerPlaceField, ManagerWorkspaceField)" "$( LC_ALL=C grep -l -e '^LocalToolsManagerField(){' "$rigLocal"/manager/*.include "$rigHere"/manager/*.include | LC_ALL=C sed 's#.*/##' | LC_ALL=C tr '\n' ' ')$( LC_ALL=C grep -l -e 'ManagerPlaceField' -e 'ManagerWorkspaceField' "$rigLocal"/manager/*.include "$rigHere"/manager/*.include | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "LocalTools.ManagerField.include 0"

echo "-- 2. the list and the arm --"
rigList="$rigHere/config/place-blocks.list"
rigAssert "the list names the three kinds in order, each reader a function of the include the line names" "$( LC_ALL=C awk -F'\t' '$1 == "block" { printf "%s=%s ", $2, $3 }' "$rigList" )" "sessions=AgentsToolsManagerPlaceSessions stands=AgentsToolsManagerPlaceStands members=AgentsToolsManagerPlaceMembers "
rigBad=""
while IFS=$'\t' read -r rigLine rigKind rigReader rigInclude ; do
	[ "$rigLine" = "block" ] || continue
	( . "$MDLT_ORIGIN/myx/$rigInclude" ; type "$rigReader" > /dev/null 2>&1 ) || rigBad="$rigBad [$rigKind]"
done < "$rigList"
rigAssert "each reader is defined by the include its line names" "${rigBad:- all defined}" " all defined"
rigAssert "the arm of the places gives the list to the include" "$( LC_ALL=C grep -c -F -e 'local managerConsolePlaceList="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/place-blocks.list"' "$rigHere/manager/AgentsTools.Manager.include" || : )" "1"

echo "-- 3. the reader asked for by a kind --"
mkdir -p "$rigTmp/inc"
printf 'RigPlaceReaderOne(){ echo one ; }\n' > "$rigTmp/inc/reader.include"
rigRig="$rigTmp/rig-origin/myx"
mkdir -p "$rigRig" && cp "$rigTmp/inc/reader.include" "$rigRig/reader.include"
printf 'block\tsessions\tRigPlaceReaderOne\treader.include\nblock\tmembers\tRigPlaceReaderMissing\treader.include\n' > "$rigTmp/blocks.list"
printf '# a comment\n\nblock\tstands\tRigPlaceReaderOne\treader.include\n' > "$rigTmp/comment.list"
rigAsk(){ ## list file or -, kind -- placeReader, rc and the error line of LocalToolsManagerPlaceReader, in a shell that has read the include of .local
	local askList="$1" askKind="$2"
	( MDSC_CMD=rig MMDAPP="$rigTmp/ws" ; set -- --rig-no-such-option
	  . "$rigLocal/manager/LocalTools.ManagerPlace.include" > /dev/null 2>&1 || :
	  MDLT_ORIGIN="$rigTmp/rig-origin"
	  if [ "$askList" = "-" ] ; then unset managerConsolePlaceList ; else managerConsolePlaceList="$askList" ; fi
	  LocalToolsManagerPlaceReader "$askKind" 2> "$rigTmp/ask.err" ; rigAskRc=$?
	  printf '[%s] rc=%s [%s]' "$placeReader" "$rigAskRc" "$( LC_ALL=C sed 's/^.*the reader/the reader/;s/ -- nothing is shown$//' "$rigTmp/ask.err" )" )
}
rigAssert "no list: no reader, rc 0" "$( rigAsk - sessions )" "[] rc=0 []"
rigAssert "a list that does not name the kind: no reader, rc 0" "$( rigAsk "$rigTmp/comment.list" sessions )" "[] rc=0 []"
rigAssert "comment lines and blank lines are left alone, and a kind that is named gives its reader by its name" "$( rigAsk "$rigTmp/comment.list" stands )" "[RigPlaceReaderOne] rc=0 []"
rigAssert "a registered reader is given by its name, its include read" "$( rigAsk "$rigTmp/blocks.list" sessions )" "[RigPlaceReaderOne] rc=0 []"
rigAssert "one the list names that is not defined is refused, rc 1, naming it and its include" "$( rigAsk "$rigTmp/blocks.list" members )" "[] rc=1 [the reader RigPlaceReaderMissing of the block members is not defined in reader.include]"

echo "-- 4. the places without a block --"
mkdir -p "$rigTmp/ws/.local/agents" "$rigTmp/home/.agents/magic-team" "$rigTmp/skills"
printf 'ws-rig\tworkspace\tread-write\t%s\tworkspace\n' "$rigTmp/ws" > "$rigTmp/ws/.local/agents/directories.registry"
printf 'ws-rig\t%s\n' "$rigTmp/ws" > "$rigTmp/home/.agents/magic-team/directories.registry"
: > "$rigTmp/ws/DistroAgentsConsole.sh"
printf 'keeper-rig\t%s\tsource-symlink\trig/skills/keeper-rig\t%s\n' "$rigTmp/ws" "$rigTmp/skill-source/keeper-rig" > "$rigTmp/home/.agents/magic-team/members.registry"
printf 's1 s1 - h keeper-rig spawn-succeeded 0 sp-1 - - ws 2026-10-01_10:00_+0000 2026-10-01_10:30_+0000 - - -\n' > "$rigTmp/ws/.local/agents/spawned-sessions.registry"
rigOp(){ ## op words -- the operation from the rig workspace; with the agents' blocks (the dispatcher) or with none (the include alone)
	( cd "$rigTmp/ws" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" "$@" 2> /dev/null < /dev/null )
}
rigBare(){ ## op words -- the same include run with no list at all
	( cd "$rigTmp/ws" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDSC_CMD=rig \
		bash -c 'set -- "$@" ; f() { . "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/manager/LocalTools.ManagerPlace.include" ; } ; f "$@"' rig "$@" 2> /dev/null < /dev/null )
}
rigAssert "with the agents' blocks the workspace counts its session and the read prints its member and its consoles" "$( rigOp --manager-place-list | LC_ALL=C awk -F'\t' '$2 == "ws-rig" { printf "sessions=%s ", $9 }' ) $( rigOp --manager-place-read ws-rig | LC_ALL=C awk -F'\t' '$1 == "member" || ( $1 == "stands" && $2 == "console" ) { what = $2 ; if ( $2 == "console" ) what = $3 ; printf "%s:%s ", $1, what }' )" "sessions=1  stands:DistroAgentsConsole.sh member:keeper-rig "
rigAssert "with none: the sessions column reads -, and the read prints the consoles of the workspace and no member and no member home" "$( rigBare --manager-place-list | LC_ALL=C awk -F'\t' '$2 == "ws-rig" { printf "sessions=%s ", $9 }' ) $( rigBare --manager-place-read ws-rig | LC_ALL=C awk -F'\t' '$1 == "member" || ( $1 == "stands" && $2 == "console" ) { what = $2 ; if ( $2 == "console" ) what = $3 ; printf "%s:%s ", $1, what }' )" "sessions=-  stands:DistroAgentsConsole.sh "

printf '\nTOTAL: %d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
