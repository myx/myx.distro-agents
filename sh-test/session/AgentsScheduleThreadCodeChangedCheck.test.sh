#!/usr/bin/env bash
## Behavioural check on the ask for the schedule thread ending a thread that runs old code (AgentsToolsScheduleThreadAsk in
## sh-lib/schedule/AgentsTools.ScheduleThread.include). A thread runs the code it loaded at its start, for hours. So the ask ends a live thread whose code
## files are newer than its lock. It says which file changed. The next ask starts one on the current code.
## No hand is needed for a change of the schedule to reach a live rig.
## Run rather than read, in a rig workspace built here. The lock of the thread is the owner's own (AgentsToolsThreadLockTake) and names a
## stand-in process under its own pid. The three code files the ask compares are empty files of a stand-in origin, with times set by this
## check. The last leg starts a real thread.
## Held:
##   1. CONTROL, NO CODE FILE NEWER THAN THE LOCK: `alive <pid>`, and the stand-in lives.
##   2. EACH OF THE THREE CODE FILES, NEWER ALONE: `ending - its code changed: <that file>`, and the stand-in is ended.
##   3. THE NEXT ASK STARTS ONE, the lock naming a process that is gone. It says `started <pid>`. The lock names that process, which lives
##      and is not the one ended. The ask after it does not end it again, since its lock is newer than the code.
## Red where the ask does not compare the code: 2 fails, 3 fails with it since no thread was ended, and the control 1 holds.
## Offline: only the rig's own tree is read or written, and this check ends every process it starts.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/schedule/AgentsTools.ScheduleThread.include" ] || rigRefuse "the schedule thread's include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleThreadCodeChangedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigDir="$rigWs/.local/agents/schedule-thread"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sessions" "$rigHome" "$rigSkills" "$rigData/audit"
rigBoardStates "$rigData" running
rigStarted=""
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

## THE RIG'S OWN PROCESS LIST. The ps first on PATH answers the whole-host listing from the rig's list. It holds no run. Every other call goes to the real ps.
## So the thread the last leg starts never reads the runs of this host.
rigRealTool ps "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in *ppid=*) exec "${0%/*}/ps.real" "$@" ;; esac
		while read -r rigPsPid rigPsLine ; do
			kill -0 "$rigPsPid" 2> /dev/null || continue
			case "$*" in
				*pid=*) printf '%s %s\n' "$rigPsPid" "$rigPsLine" ;;
				*) printf '%s\n' "$rigPsLine" ;;
			esac
		done < "${0%/*}/../ps.list"
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl.calls"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps and curl are not first on PATH, so this check would read the host's process list or issue a real request"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigEnded(){ ## pid -- it is no process any more, collected by its starter or not
	case "$( "$rigTmp/bin/ps.real" -o stat= -p "$1" 2> /dev/null )" in ''|*Z*) return 0 ;; esac
	return 1
}
## The three files the ask compares with the lock are empty, in a stand-in origin. Their times are fixed ones, with the lock's between them.
rigFake="$rigTmp/stand-in-origin"
mkdir -p "$rigFake/myx/myx.distro-agents/sh-lib/schedule" "$rigFake/myx/myx.distro-agents/sh-lib/session"
rigFiles="schedule/AgentsTools.ScheduleThread.include schedule/AgentsTools.DispatcherSchedule.include session/AgentsTools.SessionControlStart.include"
rigPid=""
rigLeg(){ ## code file newer than the lock, as the ask names it (empty for none) -- a stand-in holds the lock, the ask of the stand-in origin is made, its answer is in ask.out
	local legNewer="$1" legFile
	rm -rf "$rigDir" ; mkdir -p "$rigDir"
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigPid=$!
	rigProcNote "$rigPid" ; rigStarted="$rigStarted $rigPid"
	disown "$rigPid" 2> /dev/null || :
	( . "$rigHere/common/AgentsTools.ThreadLock.include" && AgentsToolsThreadLockTake "$rigDir/thread.lock" "$( rigProcBegan "$rigPid" )" ) || rigRefuse "the lock of the stand-in could not be taken by the owner"
	touch -t 202101010000 "$rigDir/thread.lock"
	for legFile in $rigFiles ; do
		: > "$rigFake/myx/myx.distro-agents/sh-lib/$legFile"
		if [ "${legFile##*/}" = "$legNewer" ] ; then touch -t 202201010000 "$rigFake/myx/myx.distro-agents/sh-lib/$legFile" ; else touch -t 202001010000 "$rigFake/myx/myx.distro-agents/sh-lib/$legFile" ; fi
	done
	( cd "$rigWs" && env -i PATH="$PATH" HOME="$rigHome" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_FAKE="$rigFake" \
		bash -c '
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.ScheduleThread.include" || exit 90
			MDLT_ORIGIN="$RIG_FAKE"
			AgentsToolsScheduleThreadAsk
		' ) > "$rigTmp/ask.out" 2> "$rigTmp/ask.err" < /dev/null
}

echo "-- 1. control: no code file newer than the lock --"
rigLeg ''
rigAssert "the ask says alive with the process, and the stand-in lives" "$( LC_ALL=C sed -n '1p' "$rigTmp/ask.out" ):$( rigEnded "$rigPid" && echo ended || echo lives )" "alive $rigPid:lives"

echo "-- 2. each of the three code files, newer alone --"
for rigNewer in AgentsTools.ScheduleThread.include AgentsTools.DispatcherSchedule.include AgentsTools.SessionControlStart.include ; do
	rigLeg "$rigNewer"
	rigWaitLeft=25
	while ! rigEnded "$rigPid" && [ "$rigWaitLeft" -gt 0 ] ; do sleep 0.2 ; rigWaitLeft=$(( rigWaitLeft - 1 )) ; done
	rigAssert "$rigNewer newer: the ask says it ends the thread and names the file, and the stand-in is ended" \
		"$( LC_ALL=C sed -n '1p' "$rigTmp/ask.out" ):$( rigEnded "$rigPid" && echo ended || echo lives )" "ending - its code changed: $rigNewer:ended"
done

echo "-- 3. the next ask starts one on the current code --"
rigAskReal(){ ## -- the ask of the real origin, in the rig workspace; its answer is in ask.out
	( cd "$rigWs" && env -i PATH="$PATH" HOME="$rigHome" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_WORKSPACE_MODE=team-rig MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash -c '
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.ScheduleThread.include" || exit 90
			AgentsToolsScheduleThreadAsk
		' ) > "$rigTmp/ask.out" 2> "$rigTmp/ask.err" < /dev/null
}
rigAskReal
rigNewPid="$( LC_ALL=C sed -n '1s/^started \([0-9][0-9]*\)$/\1/p' "$rigTmp/ask.out" )"
rigLockLine="$( cat "$rigDir/thread.lock" 2> /dev/null )"
rigAssert "the ask after the end says started with a process that is not the one ended, and the lock names that process, alive" \
	"$( [ -n "$rigNewPid" ] && [ "$rigNewPid" != "$rigPid" ] && echo new ):$( [ "${rigLockLine%% *}" = "$rigNewPid" ] && [ "$( rigProcBegan "$rigNewPid" )" = "$rigLockLine" ] && echo lives )" "new:lives"
rigAskReal
rigWord="$( LC_ALL=C sed -n '1p' "$rigTmp/ask.out" | LC_ALL=C awk '{ print $1 ; }' )"
case "$rigWord" in alive|waiting) rigWord="alive-or-waiting" ;; esac
rigAssert "the ask after that does not end it again: its lock is newer than the code, so it says alive or waiting, and the thread lives" \
	"$rigWord:$( rigEnded "${rigNewPid:-99999999}" && echo ended || echo lives )" "alive-or-waiting:lives"

echo "-- 4. nothing is left running, and nothing was asked of the network --"
rigControlThreadsEnd "$rigTmp"
rigProcSignalWithChildren KILL $rigStarted
sleep 1
rigAssert "the thread the last leg started is ended" "$( rigEnded "${rigNewPid:-99999999}" && echo ended || echo lives )" "ended"
rigAssert "no request was made" "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SCHEDULE THREAD CODE CHANGED CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULE_THREAD_CODE_CHANGED: OK (%d assertions, offline)\n' "$rigPasses"
