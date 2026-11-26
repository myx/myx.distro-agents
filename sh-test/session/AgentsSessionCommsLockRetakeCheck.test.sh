#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the lock a running reader loses, and the bound on its retakes
## (task-20261120T1710Z-comms-reader-drops-queued-posts, Done-when 2's second limb). Held:
##   1. A LOCK TAKEN AWAY IS RETAKEN, AND THE READER LIVES. A reader runs and holds its lock. The lock is then
##      removed under it. Inside the retake bound that same process holds the lock again, and its log carries no
##      ending line. Before the change the same removal ends it at once, on `its folder or its lock is gone`.
##   2. THE RETAKE IS BOUNDED, AND ITS LINE NAMES THE BOUND. A lock held by a live process is not taken. The
##      reader leaves on a line of its own naming the include's own agentsSessionCommsLockRetries, and only after
##      those retakes, never at the first lost pass.
##   3. THE LIVE HOLDER KEEPS ITS LOCK. A reader that gave up does not delete the lock it could not win.
## The control is the pair of arms: they differ only in whether the lost lock can be won back, so arm 1 passes on
## a loss the reader noticed, never on one it slept through.
## Red without the fix: arm 1's reader ends on the lost lock, having written its ending line, and arm 2 has no
## retake line at all because the include states no bound.
## Offline: a Slack-shaped fake curl first on PATH opens no socket, and every process this check starts is ended
## by its own trap.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## A caller's own origin pointer and session names reach neither this check nor the readers it starts.
for rigDrop in MDLT_OPTION MDLT_ARGS ${!MDAT_SPAWN_@} MDAT_SESSION_ID MDAT_SESSION_THREAD MDAT_CONVERSATION_THREADS MDAT_WAIT_REMIND harnessSessionId harnessAgent CLAUDE_CODE_SESSION_ID ; do
	unset "$rigDrop" 2> /dev/null || :
done
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigFixtures="$rigPackage/sh-test/check-fixtures"
. "$rigFixtures/rig-temp.include.sh" || exit 1
. "$rigFixtures/rig-processes.include.sh" || exit 1
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigInclude="$rigPackage/sh-lib/session/AgentsTools.SessionComms.include"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
for rigNeed in "$rigTool" "$rigInclude" "$rigFixtures/session-comms.curl.stub.sh" ; do
	[ -f "$rigNeed" ] || rigRefuse "the comms reader's own file is not at the origin this workspace resolves: $rigNeed"
done
rigTmp="$( rigTempDir AgentsSessionCommsLockRetakeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
## The processes this check started are ended by TERM, which the reader takes as its own end, and waited for, so
## the rig leaves nothing running and no job notice behind.
trap '{ rigProcSignalWithChildren TERM $rigStarted 2> /dev/null || : ; for rigLeft in $rigStarted ; do wait "$rigLeft" 2> /dev/null || : ; done ; rm -rf -- "$rigTmp" ; } 2> /dev/null' EXIT
trap 'exit 1' INT TERM

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## THE BOUND THESE ARMS ARE ABOUT, read from the include itself, so a change to the constant moves the assertion
## with it. An include that states none is read at the number its trigger uses, so the arms still measure the
## behaviour, and arm 2 reports the absence as its own failure.
rigBoundRead="$( MDLT_ORIGIN="$rigOrigin" bash -c '. "$1" || exit 9 ; printf "%s" "${agentsSessionCommsLockRetries:-}"' _ "$rigInclude" 2> /dev/null )" || rigBoundRead=""
case "$rigBoundRead" in
	''|*[!0123456789]*) rigBound=5 ; printf '  NOTE  the include states no agentsSessionCommsLockRetries: these arms take the trigger number, %s\n' "$rigBound" ;;
	*) rigBound="$rigBoundRead" ;;
esac

## ONE WORKSPACE OF THE RIG: the reader's folder, a temp folder, the data root, the skills root the tooling reads,
## and the fake curl first on PATH so no socket is opened. `<name>` names it, and rigDir, rigWs and rigLog follow.
rigScene(){ ## the workspace's name
	local sceneName="$1"
	rigDir="$rigTmp/$sceneName"
	rigWs="$rigDir/ws"
	rm -rf "$rigDir"
	mkdir -p "$rigWs/.local/agents/comms" "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigDir/data" "$rigDir/bin" "$rigTmp/skills/keeper-rig" || exit 1
	printf 'keeper-rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
	cp "$rigFixtures/session-comms.curl.stub.sh" "$rigDir/bin/curl" || rigRefuse "the fake curl fixture is missing"
	chmod +x "$rigDir/bin/curl"
	: > "$rigDir/api.log"
	rigLog="$rigWs/.local/agents/comms/log"
}

## THE READER, as the tooling starts it: the tooling script itself with the operation, in the workspace of the rig.
rigRun(){
	( cd "$rigWs" && exec env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD \
		-u MDAT_CONVERSATION_THREADS -u MDAT_TEAM_MEMBER -u MDAT_SPAWN_AGENT -u MDAT_COMMS_READER \
		"PATH=$rigDir/bin:$PATH" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigWs" "MDAT_DATA_ROOT=$rigDir/data" \
		"MDLT_ORIGIN=$rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" MDAT_WAIT_REMIND=off MDAT_WORKSPACE_MODE=team-rig \
		MDAT_SCHEDULE_THREAD=off MDAT_COMMS_IDLE_SECONDS=600 \
		bash "$rigTool" --intern-session-comms --run ) > "$rigDir/reader.out" 2>&1 &
	rigProcNote "$!" ; rigStarted="$rigStarted $!"
}

## THE LOCK of the current scene: its own text, or the target of a link an older release made.
rigLock(){
	local lockPath="$rigWs/.local/agents/comms/lock"
	if [ -L "$lockPath" ] ; then readlink "$lockPath" 2> /dev/null ; else cat "$lockPath" 2> /dev/null ; fi
}

## Waits, up to the seconds given, for the lock to read what the arm wants. rc 0 it did, and rigWaited says for
## how long it was waited for.
rigLockWaits(){ ## pattern the lock must read, seconds to wait
	local waitsLeft="${2:-30}" waitsText="" waitsAll="${2:-30}"
	rigWaited=0
	while [ "$waitsLeft" -gt 0 ] ; do
		waitsText="$( rigLock )"
		case "$waitsText" in $1) rigWaited=$(( waitsAll - waitsLeft )) ; return 0 ;; esac
		sleep 1 ; waitsLeft=$(( waitsLeft - 1 ))
	done
	rigWaited="$waitsAll"
	return 1
}

## The reader's own words from its log: the process line it wrote at its start, the number of ending lines, the
## first ending line, and whether it is still the process that took the lock.
rigSaidPid(){ LC_ALL=C sed -n 's/.*the communications reader runs as pid \([0-9][0-9]*\):.*/\1/p' "$rigLog" 2> /dev/null | LC_ALL=C sed -n 1p ; }
## Counted in awk, which prints one number: `grep -c` prints 0 and then exits 1 at no match, so a `|| printf 0`
## beside it answers with both, and an assertion comparing that to 0 can never pass.
rigEnds(){ LC_ALL=C awk 'BEGIN { c = 0 ; } /ends: / { c++ ; } END { print c ; }' "$rigLog" 2> /dev/null || printf 0 ; }
rigEndsText(){ LC_ALL=C sed -n 's/.*ends: //p' "$rigLog" 2> /dev/null | LC_ALL=C sed -n 1p ; }

echo "-- 1. a lock taken away is retaken, and the reader lives --"
rigScene retake
rigRun
rigLockWaits '[0-9]* *' 40
rigAssert "the reader takes the lock of its workspace" "$( [ -n "$( rigLock )" ] && printf yes || printf no )" yes
rigReaderName="$( rigLock )"
rigAssert "and the lock names the very process whose own line says it is the reader" "${rigReaderName%% *}" "$( rigSaidPid )"
## THE LOSS: the lock is removed under a reader that holds it, as a holder dying between two passes leaves it.
rm -f "$rigWs/.local/agents/comms/lock"
rigLockWaits "$rigReaderName" "$(( rigBound + 5 ))"
rigAssert "the same process holds the lock again, inside the retake bound" \
	"$( [ "$rigWaited" -le "$rigBound" ] && printf yes || printf "the lock read '%s' after ${rigWaited}s" "$( rigLock )" )" yes
rigAssert "the lock it retook names that same process, its own start included" "$( rigLock )" "$rigReaderName"
rigAssert "and it wrote no ending line, so a lost lock is no end" "$( rigEnds )" 0

echo "-- 2. the retake is bounded, and its line names the bound --"
rigScene bounded
rigRun
rigLockWaits '[0-9]* *' 40
rigAssert "the reader of arm 2 takes the lock of its workspace" "$( [ -n "$( rigLock )" ] && printf yes || printf no )" yes
## A LIVE HOLDER: a process of this check, named as <pid> <start> exactly as the tooling reads one, so the lock
## names a holder that lives and is not the reader.
sleep 600 > /dev/null 2>&1 &
rigProcNote "$!" ; rigStarted="$rigStarted $!"
rigHolderName="$( rigProcBegan "$!" )"
[ -n "$rigHolderName" ] || rigRefuse "the stand-in holder could not be read as <pid> <start>"
printf '%s' "$rigHolderName" > "$rigWs/.local/agents/comms/lock"
rigLostAt="$SECONDS"
while [ "$(( SECONDS - rigLostAt ))" -lt "$(( rigBound + 25 ))" ] && [ "$( rigEnds )" = 0 ] ; do sleep 1 ; done
rigAssert "the reader leaves with an ending line of its own" "$( rigEnds )" 1
rigAssert "and the line says the lock was taken, naming the retake bound the include states" \
	"$( rigEndsText | LC_ALL=C sed -n 's/^its lock was taken by another process, and \([0-9][0-9]*\) retakes did not win it back$/\1/p' )" "$rigBound"
rigAssert "it left only after the retakes that line names, never at the first lost pass" \
	"$( [ "$(( SECONDS - rigLostAt ))" -ge "$(( rigBound - 1 ))" ] && printf yes || printf "after $(( SECONDS - rigLostAt ))s" )" yes
rigAssert "and the lock of the live holder it could not win is left where it was" "$( rigLock )" "$rigHolderName"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ COMMS LOCK RETAKE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS_LOCK_RETAKE: OK (%d assertions, offline)\n' "$rigPass"
