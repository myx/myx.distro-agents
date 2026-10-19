#!/usr/bin/env bash
## Behavioural check on the bare `--manager` operation (F2.5 of the refactorings epic): `DistroAgentsTools.fn.sh
## --manager` starts the console app. A direct rename with no shim: `--intern-manager` becomes the official operation,
## and nothing keeps answering to the old name. `--manager` does not match the `--manager-*` glob: it is the console
## app, and `--manager-*` the shell console user's fallback and internals. NO SCREEN IS STARTED: a `python3` of the rig
## stands first on the rig's PATH, writes down how it was started, and ends with the status the rig gives it.
## Held:
##   1. --manager starts the screen, with its workspace and its tools, and ends with the screen's own status
##   2. --manager --style <name> hands the style on, as the start did before
##   3. a word --manager does not take is refused before anything is started, naming --manager
##   4. --intern-manager is no operation any more: refused as an invalid option, and nothing is started
##   5. --manager admits exactly the callers --intern-manager admitted, measured 2026-10-19: every one -- the console,
##      a member's session, magic-coordinator's session, a native client's session -- starts the screen
## NOTE for the builder: AgentsManagerStartStyleCheck, AgentsConsoleDefaultStartCheck, AgentsConsoleInteractiveEntryCheck
## and AgentsBashPathProofCheck name --intern-manager, and are reconciled in the same feature.
## Red before F2.5: --manager is no operation, and --intern-manager still starts the screen (every case fails).
## Offline; only the rig's own tree is read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigScreen="$rigHere/manager/AgentsManagerScreen.py"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] && [ -f "$rigScreen" ] || rigRefuse "the tool or the screen is not at the origin this workspace resolves: $rigPackage"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerBareOpCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigTmp/home" "$rigTmp/skills"
## The rig's python3: no Python; it writes down how it was started and ends with RIG_SCREEN_RC, 0 where none is given.
printf '#!/bin/sh\n{ printf "start" ; for rigArg in "$@" ; do printf "\\t%%s" "$rigArg" ; done ; printf "\\n" ; } >> "%s/starts"\nexit "${RIG_SCREEN_RC:-0}"\n' "$rigTmp" > "$rigTmp/bin/python3"
chmod +x "$rigTmp/bin/python3"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
for rigMember in keeper-myx magic-coordinator ; do
	mkdir -p "$rigTmp/skills/$rigMember"
	printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md" ; printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.armed.md"
done
rigCaller=()
rigStart(){ ## words... -- one call from the rig workspace, as the console user unless rigCaller names another; rc in rigRc
	rigRc=0
	: > "$rigTmp/starts"
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" ${RIG_SCREEN_RC:+RIG_SCREEN_RC="$RIG_SCREEN_RC"} ${rigCaller[@]+"${rigCaller[@]}"} bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
## How the screen was started by the last call: `none`, or `screen` and the words after its workspace and tools.
rigStarted(){
	LC_ALL=C awk -F'\t' -v wantScreen="$rigScreen" -v wantWs="$rigWs" -v wantTool="$rigTool" '
		$1 == "start" { starts++ ; if ( $4 == wantScreen && $5 == "--workspace" && $6 == wantWs && $7 == "--tools" && $8 == wantTool ) { said = "screen" ; for ( f = 9 ; f <= NF ; f++ ) said = said " " $f } else said = "other-start" }
		END { print ( starts == 0 ) ? "none" : ( starts == 1 ? said : "starts:" starts ) }' "$rigTmp/starts"
}

echo "-- 1. --manager starts the screen, and ends with its status --"
rigStart --manager
rigAssert "it starts the screen with its workspace and its tools, exit 0" "$rigRc:$( rigStarted )" "0:screen"
RIG_SCREEN_RC=3 rigStart --manager
rigAssert "the screen's own status is the operation's"        "$rigRc:$( rigStarted )" "3:screen"

echo "-- 2. --manager --style <name> hands the style on --"
rigStart --manager --style tv-blue
rigAssert "the style is handed on as it was given"           "$rigRc:$( rigStarted )" "0:screen --style tv-blue"

echo "-- 3. a word --manager does not take is refused before anything starts --"
rigStart --manager --rig-no-such-word
rigAssert "refused, naming --manager, and nothing started"   "$( [ "$rigRc" -ne 0 ] && printf refused || printf accepted ):$( LC_ALL=C grep -c -F -- '--manager' "$rigTmp/err" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "named" : "unnamed" }' ):$( rigStarted )" "refused:named:none"

echo "-- 4. --intern-manager is no operation any more --"
rigStart --intern-manager
rigAssert "refused as an invalid option, and nothing started" "$( [ "$rigRc" -ne 0 ] && printf refused || printf accepted ):$( LC_ALL=C grep -c -x -F 'DistroAgentsTools: ⛔ ERROR: invalid option: --intern-manager' "$rigTmp/err" ):$( rigStarted )" "refused:1:none"

echo "-- 5. --manager admits the callers --intern-manager admitted: every one --"
rigCaller=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-run-keeper )
rigStart --manager
rigAssert "a member's session starts it"                       "$rigRc:$( rigStarted )" "0:screen"
rigCaller=( MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID=rig-run-coordinator )
rigStart --manager
rigAssert "magic-coordinator's session starts it"              "$rigRc:$( rigStarted )" "0:screen"
rigCaller=( CLAUDE_CODE_SESSION_ID=rig-native-client )
rigStart --manager
rigAssert "a native client's session starts it"               "$rigRc:$( rigStarted )" "0:screen"
rigCaller=()

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER BARE OP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_BARE_OP: OK (%d assertions, offline, no screen started)\n' "$rigPassCount"
