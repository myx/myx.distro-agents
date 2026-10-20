#!/usr/bin/env bash
## Behavioural check on the main loop starting the dead control threads of the sessions of its workspace at each
## iteration (--intern-main-loop, sh-lib/magic/AgentsTools.InternMainLoop.include, through the one check of
## sh-lib/session/AgentsTools.SessionControlStart.include). The real loop and spawn proxy run, as in
## AgentsMainLoopPassBoundCheck; the console, curl, ps and every setting are this rig's own. GUARD: every tooling
## call goes through one `env -i` whose child refuses to start unless MMDAPP and MDAT_DATA_ROOT sit under this
## rig's mktemp tree, and PATH holds no agent CLI.
## Held:
##   1. An iteration starts the thread of a session that has a live run and none, before its pass: one line on its
##      standard error says what was started, the thread runs after the iteration, detached, and the pass ran. The
##      session of the pass itself, which the loop waits on, gets none.
##   2. An iteration with nothing to start says nothing of it and goes on to its pass.
##   3. A thread that cannot be started is one line, and the pass runs.
##   4. A failure of the check is one line, and the iteration goes on to its pass.
## Red before the change: every assertion but the controls. Offline, rig tree only; every thread and stand-in this
## check starts is ended by it, through the rig's process helper.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRealTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/templates/spawn-brief.document.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigRealTemplate" ] || rigRefuse "the brief template is not in the package: $rigRealTemplate"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
## And the control threads the tooling starts in this rig are ended by it, each only while it is still the process that was started.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionControlMainLoopCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## The ids of this run's sessions carry the name mktemp gave it, so that a copy of this check that runs beside it never counts this one's threads.
rigTag="${rigTmp##*.}" ; rigTag="$( printf '%s' "$rigTag" | LC_ALL=C tr -c -d 'A-Za-z0-9' )"
[ -n "$rigTag" ] || rigRefuse "the rig has no name of its own to tell its sessions by"
rigDir="$rigTmp/loop"
rigStores="$rigDir/ws/.local/agents/sessions" ; rigSp="$rigDir/ws/.local/agents/spawned"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigRealPs="$( command -v ps )" || rigRefuse "no ps on PATH"

rigStarted=""
rigThreadsEnd(){ ## -- every thread an iteration of this rig started is ended
	chmod -R u+rwX -- "$rigTmp" 2> /dev/null
	rigControlThreadsEnd "$rigTmp"
	return 0
}
## A filled sandbox input/ loses its write bits: restored before any removal, final cleanup included.
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The workspace of AgentsMainLoopPassBoundCheck: settings, a fake console that ends at once, and a Slack-shaped
## curl that keeps every posted body. And a process list of the rig's own: the ps first on PATH answers the
## whole-host listing from the rig's list, each line only while its pid lives, and hands every other call to the
## real ps.
mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/data" "$rigDir/bin" "$rigDir/home/.claude/skills/magic-coordinator" "$rigDir/home/.claude/skills/magic-team" "$rigStores" "$rigSp"
printf '# magic-coordinator\n' > "$rigDir/home/.claude/skills/magic-coordinator/SKILL.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/home/.claude/skills/magic-coordinator/magic-coordinator.basic.md"
printf '# rig armed\n' > "$rigDir/home/.claude/skills/magic-coordinator/magic-coordinator.armed.md"
printf -- '---\nexecutors: magic-coordinator (light)\nmaintainers: rig\nrequires-session-kind: standalone\n---\n# rig heartbeat routine fixture\n' \
	> "$rigDir/home/.claude/skills/magic-coordinator/magic-coordinator.heartbeat.routine.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-not-a-token\nSPAWN_CLI_SERVICE=rig-cli\nSESSION_CONTROL_TICK_SECONDS=1\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
printf 'MAIN_LOOP_RESTART_DELAY_SECONDS=2\nMAIN_LOOP_PASS_TIMEOUT_SECONDS=0\n' > "$rigDir/ws/.local/.agents/magic-coordinator.agent.env"
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\necho "start $$" >> "%s/console.log"\necho "end $$" >> "%s/console.log"\n' "$rigDir" "$rigDir" > "$rigDir/ws/DistroAgentsConsole.sh"
printf '#!/bin/sh\ncat > /dev/null\necho "$*" >> "%s/curl.log"\nprintf %s\n' \
	"$rigDir" "'{\"ok\":true,\"channel\":\"CRIG00001\",\"ts\":\"1700000001.000100\",\"message\":{\"ts\":\"1700000001.000100\"}}\n'" > "$rigDir/bin/curl"
ln -s "$rigRealPs" "$rigDir/bin/ps.real"
: > "$rigDir/ps.list"
cat > "$rigDir/bin/ps" <<'RIGPS'
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
chmod +x "$rigDir/ws/DistroAgentsConsole.sh" "$rigDir/bin/curl" "$rigDir/bin/ps"

rigId(){ ## short name -- the id of that session or run in this run of the check
	printf '%s-%s' "$1" "$rigTag"
}
rigRec(){ ## sandbox (short), record (short), session (short), host, status
	mkdir -p "$rigSp/$( rigId "$1" )"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: keeper-rig\nstatus: %s\nstarted-at: 2026-10-13 09:00 +0300\n---\n\n# Spawn session: %s\n' \
		"$( rigId "$3" )" "$( rigId "$2" )" "$4" "$5" "$( rigId "$3" )" > "$rigSp/$( rigId "$1" )/$( rigId "$2" ).md"
}
rigStand(){ ## short name of the run -- a stand-in under its own pid that only waits, the run of that spawn in the rig's process list
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigProcNote "$!" ; rigStarted="$rigStarted $!"
	printf '%s claude --verbose --session-id %s --agent rig-member the brief\n' "$!" "$( rigId "$1" )" >> "$rigDir/ps.list"
	disown "$!" 2> /dev/null || :
}
## The one way this rig runs tooling: a clean environment, and a child that checks where it is about to work
## before it starts. --one is a single iteration, run in the foreground.
rigOneRc=0
rigOneRun(){ ## name of its output files
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigDir/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigDir/home/.claude/skills" \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree: $MDAT_DATA_ROOT" >&2 ; exit 99 ;; esac
			! command -v claude > /dev/null 2>&1 || { echo "RIG-GUARD: an agent CLI is on PATH" >&2 ; exit 99 ; }
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-main-loop --one
		' > "$rigDir/$1.out" 2> "$rigDir/$1.err" < /dev/null
	rigOneRc=$?
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft=$(( $1 * 5 )) ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 0.2 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigEnded(){ ## pid -- it is no process any more, collected by its starter or not
	case "$( "$rigRealPs" -o stat= -p "$1" 2> /dev/null )" in ''|*Z*) return 0 ;; esac
	return 1
}
rigHolder(){ ## short name of a session -- the pid its pid file names, where that is a process that began when the file says
	local holderLine=""
	{ IFS= read -r holderLine < "$rigStores/$( rigId "$1" )/control/pid" ; } 2> /dev/null
	[ -n "$holderLine" ] && [ "$( rigProcBegan "${holderLine%% *}" )" = "$holderLine" ] || return 0
	printf '%s' "${holderLine%% *}"
}
rigHeld(){ ## short name of a session -- a live thread holds it
	[ -n "$( rigHolder "$1" )" ]
}
rigThreads(){ ## short name of a session -- how many processes of this host show as the thread of that session
	"$rigRealPs" -A -ww -o args= 2> /dev/null | LC_ALL=C grep -c -E -- "DistroAgentsTools\\.fn\\.sh --intern-session-control --run --session-id $( rigId "$1" )\$" || :
}
rigGroup(){ ## pid -- the process group it is in
	"$rigRealPs" -o pgid= -p "$1" 2> /dev/null | LC_ALL=C tr -d ' '
}
rigMade(){ ## short name of a session -- how many starts the log of its thread holds
	[ -f "$rigStores/$( rigId "$1" )/control/log" ] || { printf '0\n' ; return 0 ; }
	LC_ALL=C grep -c -E -- "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z a start of the control thread of session $( rigId "$1" ) is made: pid [0-9]+, begun [^ ]+\$" "$rigStores/$( rigId "$1" )/control/log" 2> /dev/null || :
}
rigSaid(){ ## name of a run, fixed text -- how many lines of its errors hold it
	LC_ALL=C grep -c -F -- "$2" "$rigDir/$1.err" || :
}
rigLineOf(){ ## name of a run, fixed text -- the number of the first line of its errors that holds it, 0 for none
	LC_ALL=C grep -n -F -- "$2" "$rigDir/$1.err" | LC_ALL=C sed -n '1s/:.*$//p' | LC_ALL=C grep . || printf '0\n'
}
rigPasses(){ ## -- how many passes the console of the rig was started for
	LC_ALL=C grep -c '^start ' "$rigDir/console.log" 2> /dev/null || printf '0\n'
}
rigTag2="# DistroAgentsTools --intern-main-loop:"

echo "-- 1. an iteration starts the thread of a session that has a live run and none --"
rigRec a a a "$rigHost" spawn-started ; rigStand a
rigOneRun first
[ "$( rigPasses )" -ge 1 ] || { tail -12 "$rigDir/first.err" >&2 ; rigRefuse "the iteration never started its pass, so nothing below would be measured" ; }
rigWaitFor 20 rigHeld a
rigA="$( rigHolder a )"
rigAssert "after --one a control thread runs for that session, one, in a process group of its own: the iteration did not wait for it" \
	"$( rigThreads a ):$( [ -n "$rigA" ] && [ "$( rigGroup "$rigA" )" = "$rigA" ] && echo own ):$( rigMade a )" "1:own:1"
rigAssert "one line on its standard error says what was started, before its pass" \
	"$( LC_ALL=C grep -c -x -F -- "$rigTag2 started the control thread of 1 session(s): $( rigId a )" "$rigDir/first.err" ):$( [ "$( rigLineOf first 'started the control thread of' )" -gt 0 ] && [ "$( rigLineOf first 'started the control thread of' )" -lt "$( rigLineOf first 'heartbeat iteration starting' )" ] && echo before )" "1:before"
rigAssert "and its pass ran: the console of the rig was started for it, and the iteration said how its pass ended" "$( [ "$( rigPasses )" -ge 1 ] && echo started ):$( rigSaid first 'heartbeat iteration starting' ):$( LC_ALL=C grep -c -E -- "^$rigTag2 (✅|⛔) pass " "$rigDir/first.err" )" "started:1:1"
rigAssert "the session of the pass itself, which the loop waits on, got no thread: the one control folder is that of the session with the live run" \
	"$( ls -d "$rigStores"/*/control 2> /dev/null | LC_ALL=C grep -c . ):$( ls -d "$rigStores/$( rigId a )/control" 2> /dev/null | LC_ALL=C grep -c . ):$( ls -d "$rigStores"/*/ 2> /dev/null | LC_ALL=C grep -c . | LC_ALL=C awk '{ print ( $1 >= 2 ) ? "stores-of-both" : $1 }' )" "1:1:stores-of-both"

echo "-- 2. an iteration with nothing to start goes on to its pass --"
rigBefore="$( rigPasses )"
rigOneRun second
rigAssert "every live session has its thread: the iteration starts no thread and says nothing of it, and starts its pass as before" \
	"$( rigSaid second 'control thread' ):$( rigThreads a ):$( rigMade a ):$( rigHolder a ):$( [ "$( rigPasses )" -gt "$rigBefore" ] && echo started ):$( rigSaid second 'heartbeat iteration starting' )" "0:1:1:$rigA:started:1"

echo "-- 3. a thread that cannot be started is one line, and the pass runs --"
rigRec i i i "$rigHost" spawn-started ; rigStand i
mkdir -p "$rigStores/$( rigId i )/control" ; chmod a-w "$rigStores/$( rigId i )/control"
rigBefore="$( rigPasses )"
rigOneRun third
rigAssert "the folder control/ of a session cannot be written: one line says so, no process is started for it, and the pass runs" \
	"$( LC_ALL=C grep -c -x -F -- "$rigTag2 the control thread of session $( rigId i ) could not be started: the log of the thread could not be written: $rigStores/$( rigId i )/control/log" "$rigDir/third.err" ):$( rigThreads i ):$( [ "$( rigPasses )" -gt "$rigBefore" ] && echo started )" "1:0:started"
chmod u+w "$rigStores/$( rigId i )/control" ; rm -rf "$rigStores/$( rigId i )" "$rigSp/$( rigId i )"

echo "-- 4. a failure of the check does not stop the iteration --"
## The check cannot rebuild the registry of the sessions: the folder it is written in takes no new file.
rigThreadsEnd
rigRec b b b "$rigHost" spawn-started ; rigStand b
chmod a-w "$rigDir/ws/.local/agents"
rigBefore="$( rigPasses )"
rigOneRun fourth
chmod u+w "$rigDir/ws/.local/agents"
rigAssert "the check ends with an error: the iteration logs one line, starts no thread, and goes on to its pass" \
	"$( LC_ALL=C grep -c -x -F -- "$rigTag2 the control threads of the sessions could not be checked -- the iteration goes on" "$rigDir/fourth.err" ):$( rigThreads b ):$( rigSaid fourth 'heartbeat iteration starting' ):$( [ "$( rigLineOf fourth 'could not be checked' )" -gt 0 ] && [ "$( rigLineOf fourth 'could not be checked' )" -lt "$( rigLineOf fourth 'heartbeat iteration starting' )" ] && echo before ):$( [ "$( rigPasses )" -gt "$rigBefore" ] && echo started )" "1:0:1:before:started"
rigOneRun fifth
rigWaitFor 20 rigHeld b
## The thread of the first session was ended a moment ago, with the others of this check: the check leaves it alone, in silence.
rigAssert "control: once the registry can be rebuilt again, the next iteration starts the thread that was needed, and not one that has just ended" \
	"$( rigThreads b ):$( LC_ALL=C grep -c -x -F -- "$rigTag2 started the control thread of 1 session(s): $( rigId b )" "$rigDir/fifth.err" ):$( rigThreads a ):$( rigMade a )" "1:1:0:1"

echo "-- 5. nothing is left running, and no request left for a real host --"
rigThreadsEnd
rigProcSignalWithChildren KILL $rigStarted
sleep 1
rigAssert "every thread an iteration of this check started is ended: no process of this host shows as a thread of one of its sessions" \
	"$( "$rigRealPs" -A -ww -o args= 2> /dev/null | LC_ALL=C grep -c -E -- "--intern-session-control --run --session-id [a-z0-9]+-$rigTag\$" || : )" "0"
rigAssert "no request left for a real host" "$( cat "$rigDir/curl.log" 2> /dev/null | LC_ALL=C grep -v -c 'slack.com/api/' || : )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION CONTROL MAIN LOOP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CONTROL_MAIN_LOOP: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
