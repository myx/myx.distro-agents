#!/usr/bin/env bash
## Behavioural check on the folder the runner's own lock stands in (S28.11): AgentsRunTests.sh makes the folder
## that lock lives in, so a workspace whose `.local/temp` is missing runs its tests instead of waiting for ever
## behind a lock nobody holds. Run rather than read, on a fixture machine built here: a HOME, a workspace holding
## `.local` and no `.local/temp`, and in its source a copy of the runner with one tiny test. Held:
##   1. the control: that workspace has no `.local/temp`, and the same run with that folder made ends, exits 0,
##      passes its test and says nothing of waiting -- so a run that stands still below is the runner's, not the rig's
##   2. with the folder gone again, the same run ends by itself within its bound, exits 0 and passes its test
##   3. it never says it waits behind a lock taken by hand, and the folder it needed is there afterwards
## A run that stands still is ended and failed, so the check reports it rather than hanging on it.
## Red before S28.11: the run at 2 stood still, saying the lock was taken by hand, and had to be ended.
## Offline, a rig tree of its own: no deploy, no ssh, no host, and no test of the package run.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRunner="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/AgentsRunTests.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
[ -f "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" ] || rigRefuse "myx.common lib/parallel, which the runner runs its tests with, is not at ${MYXROOT:-/usr/local/share/myx.common}"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunTestsLockParentCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignal TERM $rigStarted ; rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home"
rigWs="$rigTmp/ws"
rigTests="$rigWs/source/myx/myx.distro-agents/sh-test"
mkdir -p "$rigHome" "$rigWs/.local/.agents" "$rigTests/check-fixtures" || exit 1
cp "$rigRunner" "$rigTests/AgentsRunTests.sh" || rigRefuse "the runner could not be copied into the rig"
cp "$(dirname "$rigRunner")/check-fixtures"/runner-*.py "$rigTests/check-fixtures/" || rigRefuse "the runner's keepers could not be copied into the rig"
printf '#!/usr/bin/env bash\necho "RIG_TINY: OK"\n' > "$rigTests/RigTiny.test.sh"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## A child that has ended but is not yet waited for is still a process, so liveness is read from its state.
rigRunning(){ ## pid -- rc 0 while it is a process that has not ended
	case "$( PATH="$rigProcPath" ps -o stat= -p "$1" 2> /dev/null )" in ''|Z*) return 1 ;; esac
	return 0
}
rigEnded(){ ## name, bound seconds -- runs that copy's runner from the workspace, ending it at the bound where it stands still; rigStood=yes there
	local endedPid endedLeft="$2"
	( cd "$rigWs" && exec env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigWs/source" MYXROOT="${MYXROOT:-}" \
		bash "$rigTests/AgentsRunTests.sh" ) > "$rigTmp/$1.out" 2>&1 &
	endedPid=$!
	rigStarted="$rigStarted $endedPid"
	rigProcNote "$endedPid"
	rigStood=yes
	while [ "$endedLeft" -gt 0 ] ; do
		rigRunning "$endedPid" || { rigStood=no ; break ; }
		sleep 0.2 ; endedLeft=$(( endedLeft - 1 ))
	done
	rigRc=0
	rigRunning "$endedPid" && rigProcSignal TERM "$endedPid"
	wait "$endedPid" 2> /dev/null || rigRc=$?
}
rigPass(){ LC_ALL=C grep -c '^PASS  RigTiny ' "$rigTmp/$1.out" 2> /dev/null || : ; }
rigWaits(){ LC_ALL=C grep -c -e 'waits its turn behind' -e 'taken by hand' "$rigTmp/$1.out" 2> /dev/null || : ; }

echo "-- 1. the control: the rig runs the runner, and this workspace holds no .local/temp --"
rigAssert "the workspace the run starts in has .local and no .local/temp" "$( [ -d "$rigWs/.local" ] && printf local || printf none ) $( [ -d "$rigWs/.local/temp" ] && printf temp || printf no-temp )" "local no-temp"
mkdir -p "$rigWs/.local/temp"
rigEnded withFolder 300
rigAssert "with that folder made, the run ends by itself, exits 0, and passes its test" "$rigStood $rigRc $( rigPass withFolder )" "no 0 1"
rigAssert "and it says nothing of waiting, so the message below is this defect's alone" "$( rigWaits withFolder )" 0

echo "-- 2. the folder gone again: the run makes what it needs, and runs its test --"
rm -rf "$rigWs/.local/temp"
rigAssert "the folder is gone again" "$( [ -d "$rigWs/.local/temp" ] && printf temp || printf no-temp )" no-temp
rigEnded withoutFolder 300
rigAssert "the run ends by itself rather than waiting for ever" "$rigStood" no
rigAssert "it exits 0 and passes its test" "$rigRc $( rigPass withoutFolder )" "0 1"

echo "-- 3. it never blames a lock taken by hand, and leaves the folder it needed --"
rigAssert "nothing of it says it waits behind a lock taken by hand" "$( rigWaits withoutFolder )" 0
rigAssert "the folder its lock stands in is there afterwards" "$( [ -d "$rigWs/.local/temp" ] && printf temp || printf no-temp )" temp

echo "-- 4. the folder it cannot make: a file stands in its place --"
rm -rf "$rigWs/.local/temp"
: > "$rigWs/.local/temp"
rigEnded blockedFolder 120
rigAssert "the run ends at once rather than waiting for ever" "$rigStood" no
rigAssert "it exits 1 and runs no test" "$rigRc $( rigPass blockedFolder )" "1 0"
rigAssert "and it names the folder it could not make" "$( LC_ALL=C grep -c -F -- "⛔ ERROR: AgentsRunTests.sh: cannot create $rigWs/.local/temp, the folder of the lock a run takes at its turn" "$rigTmp/blockedFolder.out" || : )" 1
rm -f "$rigWs/.local/temp"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RUN TESTS LOCK PARENT CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_LOCK_PARENT: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
