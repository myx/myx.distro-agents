#!/usr/bin/env bash
## Behavioural check on the duty keep-alive's kept-session drop: a duty whose session was killed, or that
## finished, is never rejoined. The next due pass opens a fresh session for the member. Held:
##   1. KILLED, THE SCHEDULE: a kept session id whose newest run carries `killed-at` is dropped by the kept-session
##      block of AgentsToolsScheduleSpawn, so the start carries no --join-session and the kept id file is gone.
##   2. FINISHED, THE SCHEDULE: the same, where the session folder holds the `handback.given` a delivered
##      handback writes.
##   3. THE CONTROL: a kept session id with neither mark, founded today, is joined and the kept id stays, so rows
##      1 and 2 are not a rule that never joins anything.
##   4. KILLED, THE SPAWN PROXY: the real --intern-op-agent-spawn-proxy opens a fresh session rather than joining
##      the killed one, and its own control joins the unmarked one.
##   5. THE MARK SURVIVES: AgentsToolsManagerKillMark writes `killed-at` on the record, and a second read of that
##      file still finds the same stamp.
## Offline: the workspace, the records and the board are this rig's own tree, the console and curl are stand-ins,
## and the schedule's own start is a stand-in that records its arguments.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's include is not at the origin this workspace resolves"
[ -f "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "the tooling's entry point is not at the origin this workspace resolves"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyKeptSessionDropCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap 'for rigEach in $rigPids ; do kill -9 "$rigEach" 2> /dev/null ; done ; chmod -R u+w -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigBin="$rigTmp/bin"
rigMember=magic-coordinator rigRoutine="$rigMember.work-duty.routine.md" rigKeptSession=keptsess-rig-01
rigSp="$rigWs/.local/agents/spawned" rigSessions="$rigWs/.local/agents/sessions" rigSchedule="$rigWs/.local/agents/schedule" rigKept="$rigSchedule/duty-session/$rigMember"
mkdir -p "${rigKept%/*}" "$rigSp" "$rigSessions" "$rigData" "$rigBin" "$rigHome" "$rigWs/.local/.agents" "$rigWs/.local/agents/members/$rigMember" || exit 1

## The stand-ins of the rig's own edge: a curl that reaches no socket and answers a Slack refusal, and a console
## that starts nothing and says so. The schedule's own start is replaced below, per row.
cat > "$rigBin/curl" <<'RIGCURL'
#!/bin/sh
cat > /dev/null
printf '{"ok":false,"error":"rig"}\n'
exit 0
RIGCURL
chmod +x "$rigBin/curl" || exit 1
cat > "$rigWs/DistroAgentsConsole.sh" <<'RIGCONSOLE'
#!/bin/sh
## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)
[ -z "$MDAT_SPAWN_LAUNCH_MARKER" ] || printf 'claude-native\n' > "$MDAT_SPAWN_LAUNCH_MARKER"
echo rig-child-output
exit 0
RIGCONSOLE
chmod +x "$rigWs/DistroAgentsConsole.sh" || exit 1
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf -- '---\nname: %s\ndescription: rig member\n---\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
printf 'rig\n' > "$rigWs/.local/agents/members/$rigMember/$rigMember.basic.md"
printf 'rig\n' > "$rigWs/.local/agents/members/$rigMember/$rigMember.armed.md"
printf -- '---\ntype: routine\nexecutors: %s\ninvitees: none\nrequires-session-kind: standalone\nreview-by: none\n---\n# rig work duty\n\n## Steps\n\n1. rig\n' \
	"$rigMember" > "$rigWs/.local/agents/members/$rigMember/$rigRoutine"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
	return 0
}
rigField(){ ## file, field
	LC_ALL=C awk -v want="$2: " 'NR == 1 { next ; } $0 == "---" { exit ; } index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; exit ; }' "$1" 2> /dev/null
}
## THE RIG'S OWN TREE, REBUILT FOR EACH ROW: the kept id, one run record of that session, and the two marks a row
## turns on. `killed` and `finished` are yes|no; `kept` writes the kept id file.
rigState(){ ## killed, finished, kept
	chmod -R u+w -- "$rigWs" 2> /dev/null
	## The records and every index derived from them, so a row never reads one the row before it left. The
	## member's own folder stays: it is the rig's edge, and no row measures it.
	rm -rf -- "$rigSp" "$rigSessions" "$rigSchedule" 2> /dev/null
	rm -f -- "$rigWs/.local/agents/spawned-sessions.registry" "$rigWs/.local/agents/pending-replies.registry" 2> /dev/null
	rm -rf -- "$rigWs/.local/agents/liveness" 2> /dev/null
	mkdir -p "$rigSp/$rigKeptSession" "$rigSessions/$rigKeptSession" "${rigKept%/*}" || exit 1
	[ "$3" = no ] || printf '%s\n' "$rigKeptSession" > "$rigKept"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\nstart-context: spawned\n' "$rigKeptSession" "$rigKeptSession"
		printf 'host: %s\nworkspace: ws\nowner: %s\nroutine: %s\nstatus: spawn-failed\n' "$( hostname -s 2> /dev/null )" "$rigMember" "$rigRoutine"
		printf 'started-at: %s\n' "$( date '+%Y-%m-%d %H:%M %z' )"
		[ "$1" = no ] || printf 'killed-by: human-owner\nkilled-at: %s\n' "$( date '+%Y-%m-%d %H:%M %z' )"
		printf -- '---\n\n# Spawn session: %s\n' "$rigKeptSession"
	} > "$rigSp/$rigKeptSession/$rigKeptSession.spawn.md"
	[ "$2" = no ] || { date +%s > "$( rigMarkPath )" ; }
	: > "$rigTmp/calls"
}
## THE FINISHED MARK, WHERE ITS OWN WRITER PUTS IT: a delivered handback writes `handback.given` beside the member's
## checklist, and that folder is the one locator's (AgentsSessionChecklistFileInto), never a path guessed here.
## WHAT THE MARK HOLDS: an epoch, `date +%s`, written by the handback. A fixture writes that epoch and never an empty
## file, and a reader that asks only whether the file exists cannot tell a finished session from a touched one.
## Measured 2026-11-23 against the real writer.
rigMarkPath(){
	local markFile=""
	markFile="$( env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_MEMBER="$rigMember" RIG_SESSION="$rigKeptSession" bash -c '
		set +e +u
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.CheckListSeed.include" > /dev/null 2>&1
		located=""
		AgentsSessionChecklistFileInto located "$RIG_SESSION" "$RIG_MEMBER" || exit 1
		printf "%s" "${located%/*}"
	' 2> /dev/null )"
	case "$markFile" in /*) ;; *) printf '⛔ ERROR: the checklist locator named no folder, so the finished mark has no place\n' >&2 ; exit 1 ;; esac
	printf '%s/handback.given\n' "$markFile"
}
rigRun(){ ## result file, command... -- one guarded command in the rig's own trees, the stand-ins first on PATH
	local runOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_CALLS="$rigTmp/calls" RIG_MEMBER="$rigMember" RIG_ROUTINE="$rigRoutine" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ "$( command -v curl )" = "$RIG_TMP/bin/curl" ] || exit 98
			cd "$MMDAPP" && exec "$@"
		' rig "$@" > "$runOut" 2>&1
	printf '%s' "$?" > "$runOut.rc"
}
## THE START THE SCHEDULE MAKES, with its own spawner stood in for: it records the arguments it was given and
## starts nothing, so the row reads the decision and not a launched run.
rigScheduleStart(){
	rigRun "$rigTmp/start.out" bash -c '
		set +e +u
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
		DistroAgentsTools(){ printf "%s\n" "$*" >> "$RIG_CALLS" ; return 0 ; }
		AgentsToolsScheduleDayFirst(){ printf "\n" ; return 0 ; }
		## The thread-ending guard and the team-data gate belong to other concerns, and they vary with the machine.
		AgentsToolsScheduleStartingAllowed(){ return 0 ; }
		AgentsToolsScheduleSpawn "work-duty.$RIG_MEMBER" --session-thread:event-track --routine "$RIG_ROUTINE" "$RIG_MEMBER"
	' || :
	## The start runs its spawner in a subshell of its own, so the call is waited for rather than assumed.
	local startLeft=100
	while [ ! -s "$rigTmp/calls" ] && [ "$startLeft" -gt 0 ] ; do sleep 0.1 ; startLeft=$(( startLeft - 1 )) ; done
}
rigStartJoined(){ ## -- the kept id the start was told to join, or `fresh`
	LC_ALL=C awk -v want="--join-session" '
		{ for ( i = 1 ; i <= NF ; i++ ) if ( $i == want && i < NF ) { print $( i + 1 ) ; found = 1 ; exit ; } ; }
		END { if ( ! found ) print "fresh" ; }
	' "$rigTmp/calls" 2> /dev/null
}
rigKeptNow(){ cat "$rigKept" 2> /dev/null || printf 'absent' ; }
## THE SPAWN PROXY, run for real against the rig: the session it says it started, from its own receipt.
rigProxy(){
	rigRun "$rigTmp/proxy.out" bash "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-agent-spawn-proxy "$rigMember" \
		--routine "$rigRoutine" --dispatch-doc:none || :
	LC_ALL=C awk -F= '$1 == "SESSION_ID" { print $2 ; exit ; }' "$rigTmp/proxy.out" 2> /dev/null
}
rigProxyEnded(){ ## -- the run the proxy started, ended, so no process outlives the row
	local proxyPid
	proxyPid="$( LC_ALL=C awk -F= '$1 == "PID" { print $2 ; exit ; }' "$rigTmp/proxy.out" 2> /dev/null )"
	case "$proxyPid" in ''|*[!0-9]*) return 0 ;; esac
	kill -9 "$proxyPid" 2> /dev/null || :
}

echo "-- 1. a killed session's kept id is dropped by the schedule's own start --"
rigState yes no yes
rigScheduleStart
rigAssert "the start joins no session, so it opens a fresh one" "$( rigStartJoined )" "fresh"
rigAssert "the kept id file is gone" "$( rigKeptNow )" "absent"

echo "-- 2. a finished session's kept id is dropped the same way --"
rigState no yes yes
rigScheduleStart
rigAssert "the start joins no session, so it opens a fresh one" "$( rigStartJoined )" "fresh"
rigAssert "the kept id file is gone" "$( rigKeptNow )" "absent"

echo "-- 3. the control: a kept session with neither mark, founded today, is joined --"
rigState no no yes
rigScheduleStart
rigAssert "the start joins the kept session" "$( rigStartJoined )" "$rigKeptSession"
rigAssert "the kept id stays" "$( rigKeptNow )" "$rigKeptSession"

echo "-- 4. the spawn proxy opens a fresh session rather than joining a killed one --"
rigState yes no yes
rigProxySession="$( rigProxy )"
rigProxyEnded
if [ -n "$rigProxySession" ] && [ "$rigProxySession" != "$rigKeptSession" ] ; then rigProxyVerdict=fresh ; else rigProxyVerdict=joined ; fi
rigAssert "the proxy starts a session, and it is not the killed one" "$rigProxyVerdict" "fresh"
## The fresh start keeps its own session for the next start, so the file names that one and never the killed one.
rigAssert "the kept id no longer names the killed session" \
	"$( [ "$( rigKeptNow )" = "$rigKeptSession" ] && printf kept || printf dropped )" "dropped"
rigState no no yes
rigAssert "the proxy's own control joins the unmarked kept session" "$( rigProxy )" "$rigKeptSession"
rigProxyEnded

echo "-- 5. the kill mark is written on the record and survives a read --"
rigState no no no
MDLT_ORIGIN="$MDLT_ORIGIN" MMDAPP="$rigWs" bash -c '
	set +e +u
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/run/AgentsTools.ManagerSessionKill.include"
	AgentsToolsManagerKillMark "$1" human-owner "2026-11-23 17:56 +0200"
' rig "$rigSp/$rigKeptSession/$rigKeptSession.spawn.md" || :
rigMarkOnce="$( rigField "$rigSp/$rigKeptSession/$rigKeptSession.spawn.md" killed-at )"
rigMarkTwice="$( rigField "$rigSp/$rigKeptSession/$rigKeptSession.spawn.md" killed-at )"
rigAssert "the mark names a stamp, not an empty field" "$( [ -n "$rigMarkOnce" ] && printf stamped || printf empty )" "stamped"
rigAssert "a second read of the same file finds the same stamp" "$rigMarkTwice" "$rigMarkOnce"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DUTY KEPT SESSION DROP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
printf 'DUTY_KEPT_SESSION_DROP: OK (%d assertions, offline)\n' "$rigPassCount"
