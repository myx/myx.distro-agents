#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the bounded retake a running communications reader makes of its own lost lock (S12.19).
## Held:
##   1. A READER WHOSE LOCK IS TAKEN AWAY RETAKES IT AND GOES ON RUNNING. Its lock is removed, and inside the retake bound the reader
##      is still its own process and the lock names it again.
##      The control on the same run: the lock reads as the reader's own process before it is taken away, so what is measured is
##      a regain and not a first take.
##   2. A READER THAT CANNOT WIN ITS LOCK BACK ENDS ONLY AFTER THE BOUND. Its lock is replaced by one naming another live
##      process, the reader is still alive partway through the one-second retakes, and it ends after them, its own log line
##      naming that the retakes did not win it back. The bound is read from the tree under test, never typed here.
##      The control on the same run: a third reader whose lock is left alone keeps running at the same moment, and at the moment the
##      other one ends, so the end is the lost lock's and not the clock's.
## Why the aliveness is sampled at 3 s and not later: the retake block sleeps one second a try and leaves after the fifth, so the
## fixed reader reaches its end about six seconds after its lock is taken. A sample past that would fail against the fixed code.
## What the bound is checked by is the same run's own measurement of when the reader ended.
## Red before the change: a reader whose lock is taken away ends at once with `its folder or its lock is gone`.
## Offline: no Slack call, no network and no model CLI. The package's fake curl stands first on PATH, every reader lives in a
## workspace of this rig's own, and every process this check starts is ended by it.
## Longest leg: about 55 s. Three readers run at once and the first two statements are measured together; the slow half is the
## watch for the second reader's end, which runs until it ends or for 45 s from its lock being taken. No second is asserted exactly:
## the bound is real seconds, and the pass that first sees the lost lock adds its own slack.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the team tooling is not at the origin: $rigTool"
[ -f "$rigPackage/sh-lib/session/AgentsTools.SessionComms.include" ] || rigRefuse "the comms session include is not at the origin: $rigPackage"
[ -f "$rigPackage/sh-lib/session/AgentsTools.InternSessionComms.include" ] || rigRefuse "the comms reader is not at the origin: $rigPackage"
. "$rigFixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing"
. "$rigFixtures/rig-temp.include.sh" || exit 1
## And the comms threads this check starts, by their logs and their locks, ended before the rig goes.
. "$rigFixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends threads is missing"
rigTmp="$( rigTempDir AgentsSessionCommsRetakeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignalWithChildren KILL $rigStarted ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
mkdir -p "$rigTmp/bin"
cp "$rigFixtures/session-comms.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing"
chmod +x "$rigTmp/bin/curl"
rigPath="$rigTmp/bin:$PATH"
[ "$( PATH="$rigPath" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on its PATH, so this check would issue real requests"

## The bound read from the tree this check runs against, never typed here: a check that carries the value it tests
## passes on the day the value changes.
rigBound="$( MDLT_ORIGIN="$rigOrigin" bash -c '. "$1" || exit 9 ; printf "%s\n" "$agentsSessionCommsLockRetries"' _ "$rigPackage/sh-lib/session/AgentsTools.SessionComms.include" 2> /dev/null )"
case "$rigBound" in ''|*[!0123456789]*) rigRefuse "the retake bound was not read from $rigPackage/sh-lib/session/AgentsTools.SessionComms.include, so this check would test a number it made up" ;; esac

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
		rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## A workspace the reader can live in, and nothing else: the three folders its own start and pass need.
rigScene(){ ## name -- makes the scene, and sets rigDir, rigWs and rigComms
	rigDir="$rigTmp/$1"
	rigWs="$rigDir/ws"
	rigComms="$rigWs/.local/agents/comms"
	rm -rf "$rigDir"
	mkdir -p "$rigWs/.local/temp" "$rigComms" "$rigWs/.local/agents/scratch" || return 1
}
## One start of the reader, in the workspace given, answering `started <pid>` on its standard output.
rigStartReader(){ ## workspace, answer file
	( cd "$1" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD \
		-u MDAT_CONVERSATION_THREADS -u MDAT_TEAM_MEMBER -u MDAT_SPAWN_AGENT -u MDAT_COMMS_READER -u MDAT_COMMS_IDLE_SECONDS \
		-u CLAUDE_CODE_SESSION_ID -u harnessSessionId -u harnessAgent \
		"PATH=$rigPath" "MMDAPP=$1" "MDLT_ORIGIN=$rigOrigin" MDAT_SCHEDULE_THREAD=off \
		bash "$rigTool" --intern-session-comms --start ) > "$2" 2> "$2.err"
}
rigStartPid(){ ## answer file -- the pid the start answered, or empty
	local startLine=""
	{ IFS= read -r startLine < "$1" ; } 2> /dev/null || :
	case "$startLine" in "started "*) printf '%s' "${startLine#started }" ;; esac
}
## The lock's own identity as the reader reads it: the target of a link an older release made, else the file's own text.
rigLock(){ ## lock path
	local lockLine=""
	[ -e "$1" ] || [ -L "$1" ] || { printf 'none' ; return 0 ; }
	if [ -L "$1" ] ; then
		readlink "$1" 2> /dev/null
	else
		{ IFS= read -r lockLine < "$1" ; } 2> /dev/null || :
		printf '%s' "$lockLine"
	fi
}
rigLockPid(){ ## lock path -- the process the lock names, or `none`
	local lockHeld
	lockHeld="$( rigLock "$1" )" || lockHeld=""
	case "$lockHeld" in ''|none) printf 'none' ;; *) printf '%s' "${lockHeld%% *}" ;; esac
}
## Alive by the tooling's own reading of a process, never by its number alone.
rigAlive(){ ## pid
	if [ -n "$1" ] && [ -n "$( rigProcStill "$1" )" ] ; then printf 'alive' ; else printf 'gone' ; fi
}
rigSleepTo(){ ## epoch second -- returns once that whole second has arrived
	local gateNow=""
	while : ; do
		gateNow="$( date +%s )"
		[ "$gateNow" -lt "$1" ] || return 0
		sleep 0.2
	done
}
rigAwaitLock(){ ## lock path, pid, seconds -- the seconds the lock took to name that pid, else `none`
	local awaitFrom awaitSpent
	awaitFrom="$( date +%s )"
	while : ; do
		[ "$( rigLockPid "$1" )" != "$2" ] || { printf '%s' "$(( $( date +%s ) - awaitFrom ))" ; return 0 ; }
		awaitSpent=$(( $( date +%s ) - awaitFrom ))
		[ "$awaitSpent" -lt "$3" ] || { printf 'none' ; return 0 ; }
		sleep 0.5
	done
}
rigLogHits(){ ## comms dir, text -- how many lines of the reader's log hold it
	local hitsFile="$1/log"
	[ -f "$hitsFile" ] || { printf 0 ; return 0 ; }
	LC_ALL=C awk -v want="$2" 'index( $0, want ) > 0 { hits++ ; } END { print hits + 0 ; }' "$hitsFile" 2> /dev/null
}
rigSayFailure(){ ## comms dir -- the reader's own log lines, and the lock's own text
	printf -- '-- the reader of %s --\n' "$1" >&2
	[ ! -f "$1/log" ] || { LC_ALL=C tail -n 12 "$1/log" 2> /dev/null | LC_ALL=C sed 's/^/    /' >&2 ; }
	printf '  the lock: %s\n' "$( rigLock "$1/lock" )" >&2
}

echo "-- the three readers are started together --"
rigScene regain || rigRefuse "the rig could not make the workspace of the first reader"
rigRegainWs="$rigWs" rigRegainComms="$rigComms" rigRegainDir="$rigDir"
rigStartReader "$rigRegainWs" "$rigRegainDir/start.out"
rigRegainPid="$( rigStartPid "$rigRegainDir/start.out" )"
case "$rigRegainPid" in ''|*[!0123456789]*) rigRefuse "the first start named no process, and answered: $( LC_ALL=C head -1 "$rigRegainDir/start.out" 2> /dev/null )" ;; esac
rigProcNote "$rigRegainPid" ; rigStarted="$rigStarted $rigRegainPid"
disown "$rigRegainPid" 2> /dev/null || :

rigScene taken || rigRefuse "the rig could not make the workspace of the second reader"
rigTakenWs="$rigWs" rigTakenComms="$rigComms" rigTakenDir="$rigDir"
rigStartReader "$rigTakenWs" "$rigTakenDir/start.out"
rigTakenPid="$( rigStartPid "$rigTakenDir/start.out" )"
case "$rigTakenPid" in ''|*[!0123456789]*) rigRefuse "the second start named no process, and answered: $( LC_ALL=C head -1 "$rigTakenDir/start.out" 2> /dev/null )" ;; esac
rigProcNote "$rigTakenPid" ; rigStarted="$rigStarted $rigTakenPid"
disown "$rigTakenPid" 2> /dev/null || :

rigScene alone || rigRefuse "the rig could not make the workspace of the control reader"
rigAloneWs="$rigWs" rigAloneComms="$rigComms" rigAloneDir="$rigDir"
rigStartReader "$rigAloneWs" "$rigAloneDir/start.out"
rigAlonePid="$( rigStartPid "$rigAloneDir/start.out" )"
case "$rigAlonePid" in ''|*[!0123456789]*) rigRefuse "the control start named no process, and answered: $( LC_ALL=C head -1 "$rigAloneDir/start.out" 2> /dev/null )" ;; esac
rigProcNote "$rigAlonePid" ; rigStarted="$rigStarted $rigAlonePid"
disown "$rigAlonePid" 2> /dev/null || :

echo "-- 1. a reader whose lock is taken away retakes it --"
rigRegainHeld="$( rigAwaitLock "$rigRegainComms/lock" "$rigRegainPid" 30 )"
rigRegainBefore="$rigFailCount"
rigAssert "control: the lock reads as the reader's own process before it is taken away" \
	"$( [ "$rigRegainHeld" = none ] && printf unnamed || printf named )" "named"
rm -f "$rigRegainComms/lock"
rigRegainBack="$( rigAwaitLock "$rigRegainComms/lock" "$rigRegainPid" 10 )"
rigAssert "the reader whose lock was taken away is still its own process" "$( rigAlive "$rigRegainPid" )" "alive"
rigAssert "and the lock names it again, $rigRegainBack s after the lock was taken away" \
	"$( rigLockPid "$rigRegainComms/lock" )" "$rigRegainPid"
rigAssert "and it came back inside the $rigBound one-second retakes, with the pass's own slack" \
	"$( [ "$rigRegainBack" = none ] && printf late || { [ "$rigRegainBack" -le $(( rigBound + 3 )) ] && printf in-time || printf late ; } )" "in-time"
rigAssert "and its own log holds no end line, so the reader never ended over the lost lock" \
	"$( rigLogHits "$rigRegainComms" 'ends:' )" 0
[ "$rigFailCount" = "$rigRegainBefore" ] || rigSayFailure "$rigRegainComms"

echo "-- 2. a reader that cannot win its lock back ends only after the bound --"
## The other process the lock is given to: live for the length of the check, and named in the lock exactly as the tooling reads
## a process, `<pid> <start>`, so a lock naming it is one a reader may not take.
sleep 600 > /dev/null 2>&1 < /dev/null &
rigStandPid=$!
rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
disown "$rigStandPid" 2> /dev/null || :
rigStandBegan="$( rigProcBegan "$rigStandPid" )"
case "$rigStandBegan" in
	'') rigRefuse "the stand-in process was not read at all, so no lock could name it" ;;
	*' '*) ;;
	*) rigRefuse "the stand-in process was not read as <pid> <start>, so no lock could name it: '$rigStandBegan'" ;;
esac
rigTakenHeld="$( rigAwaitLock "$rigTakenComms/lock" "$rigTakenPid" 30 )"
rigTakenBefore="$rigFailCount"
rigAssert "control: the second reader holds its lock before another process is given it" \
	"$( [ "$rigTakenHeld" = none ] && printf unnamed || printf named )" "named"
## Replaced in one rename, never removed first: a pass that landed on an absent lock would retake it in the fixed reader, and the
## reader this statement is about would never reach its bound at all.
printf '%s' "$rigStandBegan" > "$rigTakenComms/lock.next"
mv -f "$rigTakenComms/lock.next" "$rigTakenComms/lock" || rigRefuse "the lock could not be given to the stand-in process"
rigTakenAt="$( date +%s )"
rigSleepTo $(( rigTakenAt + 3 ))
rigTakenAt3="$( rigAlive "$rigTakenPid" )"
rigAloneAt3="$( rigAlive "$rigAlonePid" )"
rigTakenSpent=0
while : ; do
	rigTakenSpent=$(( $( date +%s ) - rigTakenAt ))
	[ "$( rigAlive "$rigTakenPid" )" = alive ] || break
	[ "$rigTakenSpent" -lt 45 ] || break
	sleep 1
done
rigTakenEnded="$( rigAlive "$rigTakenPid" )"
rigAloneThen="$( rigAlive "$rigAlonePid" )"
rigAssert "the reader whose lock another live process holds is still alive 3 s into its retakes" "$rigTakenAt3" "alive"
rigAssert "and it ends, $rigTakenSpent s after the lock was taken, inside the 45 s watch" "$rigTakenEnded" "gone"
rigAssert "and the end came after the $rigBound one-second retakes, not before them" \
	"$( [ "$rigTakenSpent" -ge "$rigBound" ] && printf after || printf before )" "after"
rigAssert "and its own log line names that $rigBound retakes did not win the lock back" \
	"$( rigLogHits "$rigTakenComms" "its lock was taken by another process, and $rigBound retakes did not win it back" )" 1
rigAssert "control: the reader whose lock is left alone is still alive 3 s in" "$rigAloneAt3" "alive"
rigAssert "control: and still alive $rigTakenSpent s in, when the other reader ended, so the end is the lost lock's and not the clock's" \
	"$rigAloneThen" "alive"
[ "$rigFailCount" = "$rigTakenBefore" ] || rigSayFailure "$rigTakenComms"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COMMS RETAKE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS_RETAKE: OK (%d assertions, offline)\n' "$rigPassCount"
