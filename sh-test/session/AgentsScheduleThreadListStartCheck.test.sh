#!/usr/bin/env bash
## Behavioural check on a list of the sessions starting the schedule thread (AgentsToolsScheduleThreadAskDue with the word `view` in
## sh-lib/schedule/AgentsTools.ScheduleThread.include, asked by --manager-session-list and --manager-session-active-list). The screen reads
## the sessions on every refresh, so it starts a schedule thread that is dead and nobody starts it by hand.
## The ask's throttle and its two stamps are held on stand-ins by AgentsScheduleAskDueViewCheck. This check runs the lists as the console runs
## them and holds the thread they start, which is the tooling's own.
## A ps first on PATH lists no run, and a curl beside it only logs, which nothing may call.
## Held:
##   1. THE TWO LISTS START THE THREAD. Each, with the schedule thread dead, is answered and the thread runs after it. CONTROL, with the thread
##      switched off (MDAT_SCHEDULE_THREAD=off) the same call makes no log of a thread.
##   2. NOTHING IS LEFT RUNNING, and nothing was asked of the network.
## Red where the lists ask nothing: 1 fails.
## Offline: only the rig's own tree is read or written, and this check ends every thread it starts.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigHere/schedule/AgentsTools.ScheduleThread.include" ] || rigRefuse "the schedule thread's include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleThreadListStartCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
mkdir -p "$rigTmp/bin"
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

## THE RIG'S OWN PROCESS LIST. The ps first on PATH answers the whole-host listing from the rig's list. It holds no run. Every other call goes to the real ps.
## So the thread a list starts never reads the runs of this host.
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
rigWorld(){ ## name -- a fresh workspace of the rig, its folders in rigWorldDir
	rigWorldDir="$rigTmp/$1"
	rm -rf -- "$rigWorldDir"
	mkdir -p "$rigWorldDir/ws/.local/.agents" "$rigWorldDir/ws/.local/agents/spawned" "$rigWorldDir/ws/.local/agents/sessions" "$rigWorldDir/ws/.local/agents/schedule-thread" "$rigWorldDir/home" "$rigWorldDir/skills" "$rigWorldDir/data/audit"
	printf 'SESSION_CONTROL_TICK_SECONDS=1\n' > "$rigWorldDir/ws/.local/.agents/magic-team.agent.env"
	rigBoardStates "$rigWorldDir/data" running
}

echo "-- 1. the two lists ask --"
rigLockLive(){ ## -- the lock of the schedule thread of this world names a process that lives
	local lockLine=""
	{ IFS= read -r lockLine < "$rigWorldDir/ws/.local/agents/schedule-thread/thread.lock" || [ -n "$lockLine" ] ; } 2> /dev/null
	[ -n "$lockLine" ] && [ "$( rigProcBegan "${lockLine%% *}" )" = "$lockLine" ]
}
rigList(){ ## on|off, operation -- the operation as the console runs it in the world; its status in rigRc
	local listOff=""
	[ "$1" != off ] || listOff="MDAT_SCHEDULE_THREAD=off"
	rigRc=0
	( cd "$rigWorldDir/ws" && env -i ${listOff:+"$listOff"} MDAT_WORKSPACE_MODE=team-rig HOME="$rigWorldDir/home" PATH="$PATH" MMDAPP="$rigWorldDir/ws" MDAT_DATA_ROOT="$rigWorldDir/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigWorldDir/skills" \
		bash "$rigTool" "$2" ) > "$rigTmp/list.out" 2> "$rigTmp/list.err" < /dev/null || rigRc=$?
}
for rigOp in --manager-session-list --manager-session-active-list ; do
	rigWorld "off${rigOp#--manager-session}"
	rigList off "$rigOp"
	rigAssert "control, $rigOp with the thread switched off: answered, status 0, and no log of a thread is made" "$rigRc:$( [ -e "$rigWorldDir/ws/.local/agents/schedule-thread/thread.log" ] && echo log || echo none )" "0:none"
	rigWorld "on${rigOp#--manager-session}"
	rigList on "$rigOp"
	rigUpLeft=75
	while ! LC_ALL=C grep -q 'the thread runs as pid' "$rigWorldDir/ws/.local/agents/schedule-thread/thread.log" 2> /dev/null && [ "$rigUpLeft" -gt 0 ] ; do sleep 0.2 ; rigUpLeft=$(( rigUpLeft - 1 )) ; done
	rigAssert "$rigOp with the thread dead: answered, status 0, and the thread runs, its lock naming a process that lives" "$rigRc:$( rigLockLive && echo lives )" "0:lives"
	rigControlThreadsEnd "$rigTmp"
done

echo "-- 2. nothing is left running, and nothing was asked of the network --"
rigControlThreadsEnd "$rigTmp"
sleep 1
rigAssert "the thread of the last list is ended" "$( rigLockLive && echo lives || echo ended )" "ended"
rigAssert "no request was made" "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SCHEDULE THREAD LIST START CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULE_THREAD_LIST_START: OK (%d assertions, offline)\n' "$rigPasses"
