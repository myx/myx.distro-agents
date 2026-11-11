#!/usr/bin/env bash
## Behavioural check on a rig being gone once the check that made it has ended (task-20261107T1905Z-testing-tools-clean-up-after-themselves):
## a scene's writer keeps writing into the rig's folder a second after the trap's rm, as the communications reader of a scene does,
## so the folder stands. Held:
##   1. THE REPRODUCTION, the positive test: a writer left running into the rm writes its log after it, and the rig stands. The
##      shape is the leak: `AgentsWorkDutyInputScanCheck` and `AgentsDmWakeLatencyCheck` each left such a rig on 2026-11-09.
##   2. THE REMEDY: the same writer, ended through rig-processes before the rm, leaves nothing standing. Row 2 is row 1's control,
##      so row 1 reads the writer and not the reader of what stands.
##   3. THE CONTROL BOTH WAYS: the reader of what a rig holds reports a folder left in place as standing, and a removed one as gone.
## Red recipe: with the writer's repeat taken away, row 1 reports no rig standing; with the writer not ended before the rm, row 2
## reports the rig standing. Both were run as mutated copies of this file.
## Offline: every tree is this check's own rig, and every writer it starts is ended by it.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" ] || rigRefuse "the rig's process helper is missing from the package"
## A writer this check starts and ends later is noted with when it began, and signalled only while its pid is still that process.
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper could not be sourced"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRigTeardownCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWriterPid=""
trap '[ -z "$rigWriterPid" ] || rigProcSignalWithChildren KILL "$rigWriterPid" ; chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
## What stands in a folder, as a reader outside the check sees it: empty where the folder is gone.
rigStanding(){ ## folder
	[ -d "$1" ] || return 0
	find "$1" -type f 2> /dev/null | LC_ALL=C sed "s|^$1||" | LC_ALL=C sort | LC_ALL=C tr '\n' ' '
}
## A scene's writer, as the communications reader of a rig is: once a second it makes its folder's log again and writes it.
rigLateWriter(){ ## folder
	( for rigBeat in 1 2 3 4 5 6 7 8 9 10 11 12 ; do sleep 1 ; mkdir -p "$1/comms" 2> /dev/null ; printf 'its log, a second after the one before\n' > "$1/comms/log" 2> /dev/null ; done ) &
	rigWriterPid=$!
	rigProcNote "$rigWriterPid"
}
rigWriterEnd(){
	[ -z "$rigWriterPid" ] || rigProcSignalWithChildren KILL "$rigWriterPid"
	wait "$rigWriterPid" 2> /dev/null || :
	rigWriterPid=""
}

echo "-- 1. the reproduction: a writer left running into the rm writes after it, and the rig stands --"
rigLateWriter "$rigTmp/reproduction"
rm -rf -- "$rigTmp/reproduction"
sleep 2
rigAssert "the file written a second after the rm is there, so the rig of a check that ends this way stands" \
	"$( rigStanding "$rigTmp/reproduction" )" "/comms/log "
rigWriterEnd
chmod -R u+w -- "$rigTmp/reproduction" 2> /dev/null ; rm -rf -- "$rigTmp/reproduction"

echo "-- 2. the remedy: the writer ended through the rig's process helper before the rm leaves nothing standing --"
rigLateWriter "$rigTmp/remedy"
sleep 2
rigWriterEnd
rm -rf -- "$rigTmp/remedy"
sleep 2
rigAssert "with the writer ended before the rm, no rig is left standing: row 1 reads the writer, not the reader" \
	"$( rigStanding "$rigTmp/remedy" )" ""

echo "-- 3. the control both ways --"
mkdir -p "$rigTmp/witness/comms" && printf 'x\n' > "$rigTmp/witness/comms/log"
rigAssert "a folder left in place is reported by what it holds" "$( rigStanding "$rigTmp/witness" )" "/comms/log "
rm -rf -- "$rigTmp/witness"
rigAssert "a folder removed is reported as holding nothing" "$( rigStanding "$rigTmp/witness" )" ""

if [ "$rigFails" -ne 0 ] ; then
	printf '⛔ RIG TEARDOWN CHECK FAILED: %d of %d assertion(s)\n' "$rigFails" "$(( rigPasses + rigFails ))" >&2
	exit 1
fi
printf 'RIG_TEARDOWN: OK (%d assertions, offline)\n' "$rigPasses"
