#!/usr/bin/env bash
## Behavioural check on the step of the schedule pass that keeps the control threads (AgentsToolsScheduleThreadControlKeep in
## sh-lib/schedule/AgentsTools.ScheduleThread.include). The pass starts the control thread of each session that is not finished and has none
## alive. It uses the one check the main loop makes (AgentsToolsSessionControlCheckWorkspace). So a rig that runs the schedule thread alone
## never leaves a session unwatched.
## The step is called here directly, and its control threads are the real ones. The pass's own call of the step is held by AgentsScheduleControlKeepCheck.
## Run rather than read, against a rig workspace built here. The store's owner writes the records. A ps first on PATH lists the rig's own runs.
## Stand-in processes have their own pids. A curl beside it only logs, and nothing may call it. The threads the step starts are the
## tooling's own, and this check ends them.
## Held:
##   1. THE STEP STARTS A THREAD FOR EACH SESSION THAT NEEDS ONE, status 0. It prints one line, `control: started the thread of session <id>`,
##      for each such session and for no other. A session needs one while its run is alive, or while its record of this host is open and
##      its run is gone. Each start is one line in the log of its thread, with the process it made.
##   2. CONTROL, A FINISHED SESSION GETS NONE: no line, and no folder made for it.
##   3. CONTROL, A SECOND STEP RIGHT AFTER STARTS NOTHING: no line, status 0, and the log of each thread still holds its one start.
## Red where the step does nothing: 1 fails, the one-start counts of 3 fail, and the control 2 holds.
## Offline: only the rig's own tree is read or written, and this check ends every thread and stand-in it starts.
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
rigTmp="$( rigTempDir AgentsScheduleThreadControlStartCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## The ids of this run's sessions carry the name mktemp gave it. A copy of this check beside it then never counts this one's threads.
rigTag="${rigTmp##*.}" ; rigTag="$( printf '%s' "$rigTag" | LC_ALL=C tr -c -d 'A-Za-z0-9' )"
[ -n "$rigTag" ] || rigRefuse "the rig has no name of its own to tell its sessions by"
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigSp="$rigWs/.local/agents/spawned" ; rigStores="$rigWs/.local/agents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigStores" "$rigHome" "$rigSkills" "$rigData/audit"
rigBoardStates "$rigData" running
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
printf 'SESSION_CONTROL_TICK_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigStarted=""
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

## THE RIG'S OWN PROCESS LIST. The ps first on PATH answers the whole-host listing from the rig's list. A line is `<pid> <command line>`, listed only while it lives. Every other call goes to the real ps.
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
rigRec(){ ## run, session, status, closing lines (may be empty) -- the run's record, written by the store's owner into the folder of its session
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: keeper-rig\nstatus: %s\nstarted-at: 2026-10-13 09:00 +0300\n%s---\n\n# Spawn session: %s\n' \
		"$2" "$1" "$rigHost" "$3" "${4:-}" "$2" | rigOwnerStore AgentsSpawnRecordWrite "$1" "$2"
}
rigRc=0
rigKeep(){ ## -- the step, in a process of its own in the rig workspace; rc in rigRc, stdout in out
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash -c '
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.ScheduleThread.include" || exit 90
			AgentsToolsScheduleThreadControlKeep
		' ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft=$(( $1 * 5 )) ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 0.2 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigHeld(){ ## session -- its pid file names a process that began when the file says
	local heldLine=""
	{ IFS= read -r heldLine < "$rigStores/$1/control/pid" ; } 2> /dev/null
	[ -n "$heldLine" ] && [ "$( rigProcBegan "${heldLine%% *}" )" = "$heldLine" ]
}
rigMade(){ ## session -- how many starts the log of its thread holds
	[ -f "$rigStores/$1/control/log" ] || { printf '0\n' ; return 0 ; }
	LC_ALL=C grep -c -E -- "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z a start of the control thread of session $1 is made: pid [0-9]+, begun [^ ]+\$" "$rigStores/$1/control/log" 2> /dev/null || :
}

## a: a run alive. b: finished. d: no run alive, and the record of this host still open.
rigSessionLive="a-$rigTag" ; rigSessionDone="b-$rigTag" ; rigSessionOpen="d-$rigTag"
rigRec "$rigSessionLive" "$rigSessionLive" spawn-started '' || rigRefuse "the record of session a could not be written"
rigRec "$rigSessionDone" "$rigSessionDone" spawn-succeeded 'resolved-at: 2026-10-13 09:30 +0300
' || rigRefuse "the record of session b could not be written"
rigRec "$rigSessionOpen" "$rigSessionOpen" spawn-started '' || rigRefuse "the record of session d could not be written"
sleep 600 > /dev/null 2>&1 < /dev/null &
rigStandPid=$!
rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
disown "$rigStandPid" 2> /dev/null || :
printf '%s claude --verbose --session-id %s --agent rig-member the brief\n' "$rigStandPid" "$rigSessionLive" >> "$rigTmp/ps.list"

echo "-- 1. the step starts a thread for each session that needs one --"
rigKeep
rigAssert "one line for the session with a live run and one for the session whose open record has no run alive, status 0, and none for another" \
	"$rigRc:$( LC_ALL=C sort "$rigTmp/out" | LC_ALL=C tr '\n' '|' )" "0:control: started the thread of session $rigSessionLive|control: started the thread of session $rigSessionOpen|"
rigAssert "each start is one line in the log of its thread" "$( rigMade "$rigSessionLive" ):$( rigMade "$rigSessionOpen" )" "1:1"

echo "-- 2. control: a finished session gets none --"
rigAssert "no line for it above, and no folder of a session made for it" "$( LC_ALL=C grep -c -F -- "$rigSessionDone" "$rigTmp/out" || : ):$( [ -e "$rigStores/$rigSessionDone" ] && echo folder || echo none )" "0:none"

echo "-- 3. control: a second step right after starts nothing --"
rigWaitFor 10 rigHeld "$rigSessionLive" ; rigWaitFor 10 rigHeld "$rigSessionOpen"
rigKeep
rigAssert "no line, status 0, and the log of each thread still holds its one start" "$rigRc:$( LC_ALL=C sed -n '$=' "$rigTmp/out" ):$( rigMade "$rigSessionLive" ):$( rigMade "$rigSessionOpen" )" "0::1:1"

echo "-- 4. nothing is left running, and nothing was asked of the network --"
rigControlThreadsEnd "$rigTmp"
rigProcSignalWithChildren KILL $rigStarted
sleep 1
rigAssert "no process of this host shows as a thread of a session of this check" \
	"$( "$rigTmp/bin/ps.real" -A -ww -o args= 2> /dev/null | LC_ALL=C grep -c -E -- "--intern-session-control --run --session-id [a-z0-9]+-$rigTag\$" || : )" "0"
rigAssert "no request was made" "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SCHEDULE THREAD CONTROL START CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULE_THREAD_CONTROL_START: OK (%d assertions, offline)\n' "$rigPasses"
