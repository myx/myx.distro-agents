#!/usr/bin/env bash
## Behavioural check on the close of a run starting the schedule thread (AgentsToolsSpawnProxyCloseSandbox in
## sh-lib/spawn/AgentsTools.SpawnProxyClose.include). A close changes the registry of the running.
## So the tooling that closes it starts the schedule thread where that is dead. Nobody starts it by hand.
## The ask alone, on stand-ins, is held by AgentsScheduleCloseAskCheck. This check holds the thread the real close starts.
## Run rather than read: the real close of a real record, written by the store's owner, in a rig workspace built here. A ps first on PATH lists
## no run, and a curl beside it only logs, which nothing may call. The thread the close starts is the tooling's own, and this check ends it.
## Held:
##   1. CONTROL, THE THREAD SWITCHED OFF (MDAT_SCHEDULE_THREAD=off): the run is closed and no folder of the thread is made.
##   2. THE CLOSE STARTS A DEAD THREAD. The run is closed. The lock of the schedule thread names a process that lives.
##      Its log says it runs, and that one start was made.
##   3. CONTROL, THE CLOSE OF ANOTHER RUN WHILE THE THREAD LIVES. The run is closed. The lock is as it was. The log holds the one start.
## Red where the close asks for nothing: 2 fails, the one-start count of 3 fails, and the control 1 holds.
## Offline: only the rig's own tree is read or written, and this check ends every thread it starts.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/spawn/AgentsTools.SpawnSandbox.include" ] || rigRefuse "the spawn sandbox include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleThreadCloseStartCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigSp="$rigWs/.local/agents/spawned"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigWs/.local/agents/sessions" "$rigHome" "$rigSkills" "$rigData/audit"
rigBoardStates "$rigData" running
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
printf 'SESSION_CONTROL_TICK_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

## THE RIG'S OWN PROCESS LIST. The ps first on PATH answers the whole-host listing from the rig's list. It holds no run. Every other call goes to the real ps.
## So the thread the close starts never reads the runs of this host.
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
rigRec(){ ## run -- its record, written by the store's owner: a run that is its own session, started
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: keeper-rig\nstatus: spawn-started\nstarted-at: 2026-10-13 09:00 +0300\n---\n\n# Spawn session: %s\n' \
		"$1" "$1" "$rigHost" "$1" | rigOwnerStore AgentsSpawnRecordWrite "$1" "$1"
}
rigClose(){ ## on|off, run -- the real close of that run's record, in a process of its own in the rig workspace, the schedule thread switched off or not
	local closeOff=""
	[ "$1" != off ] || closeOff="MDAT_SCHEDULE_THREAD=off"
	( cd "$rigWs" && env -i ${closeOff:+"$closeOff"} MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash -c '
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.SpawnSandbox.include" || exit 90
			AgentsToolsSpawnProxyCloseSandbox "$1" succeeded 0 "the rig ended it"
		' rig "$rigSp/$2/$2.spawn.md" ) > "$rigTmp/close.out" 2> "$rigTmp/close.err" < /dev/null
}
rigStatus(){ ## run -- the status its record says
	LC_ALL=C sed -n 's/^status: //p' "$rigSp/$1/$1.spawn.md" 2> /dev/null | LC_ALL=C sed -n '1p'
}
rigThreadDir="$rigWs/.local/agents/schedule-thread"
rigLockLive(){ ## -- the lock of the schedule thread names a process that lives
	local lockLine=""
	{ IFS= read -r lockLine < "$rigThreadDir/thread.lock" || [ -n "$lockLine" ] ; } 2> /dev/null
	[ -n "$lockLine" ] && [ "$( rigProcBegan "${lockLine%% *}" )" = "$lockLine" ]
}
rigThreadSays(){ ## fixed text -- how many lines of the log of the schedule thread hold it
	LC_ALL=C grep -c -F -- "$1" "$rigThreadDir/thread.log" 2> /dev/null || :
}

rigRun0="run0-${rigTmp##*.}" ; rigRun1="run1-${rigTmp##*.}" ; rigRun2="run2-${rigTmp##*.}"
rigRec "$rigRun0" || rigRefuse "the record of the first run could not be written"
rigRec "$rigRun1" || rigRefuse "the record of the second run could not be written"
rigRec "$rigRun2" || rigRefuse "the record of the third run could not be written"

echo "-- 1. control: the thread switched off --"
rigClose off "$rigRun0"
rigAssert "the run is closed, and no folder of the schedule thread is made" "$( rigStatus "$rigRun0" ):$( [ -e "$rigThreadDir" ] && echo folder || echo none )" "spawn-succeeded:none"

echo "-- 2. the close starts a dead thread --"
rigClose on "$rigRun1"
rigUpLeft=75
while [ "$( rigThreadSays 'the thread runs as pid' )" -lt 1 ] && [ "$rigUpLeft" -gt 0 ] ; do sleep 0.2 ; rigUpLeft=$(( rigUpLeft - 1 )) ; done
rigAssert "the run is closed, the lock names a process that lives, and the log says it runs, once" \
	"$( rigStatus "$rigRun1" ):$( rigLockLive && echo lives ):$( rigThreadSays 'the thread runs as pid' ):$( rigThreadSays 'a thread is started here' )" "spawn-succeeded:lives:1:1"

echo "-- 3. control: another close while the thread lives --"
rigLock1="$( cat "$rigThreadDir/thread.lock" 2> /dev/null )"
rigClose on "$rigRun2"
rigAssert "the run is closed, the lock is as it was, and the log still holds the one start" \
	"$( rigStatus "$rigRun2" ):$( [ "$( cat "$rigThreadDir/thread.lock" 2> /dev/null )" = "$rigLock1" ] && echo same || echo changed ):$( rigThreadSays 'a thread is started here' )" "spawn-succeeded:same:1"

echo "-- 4. nothing is left running, and nothing was asked of the network --"
rigControlThreadsEnd "$rigTmp"
sleep 1
rigAssert "the schedule thread this check started is ended" "$( rigLockLive && echo lives || echo ended )" "ended"
rigAssert "no request was made" "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SCHEDULE THREAD CLOSE START CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULE_THREAD_CLOSE_START: OK (%d assertions, offline)\n' "$rigPasses"
