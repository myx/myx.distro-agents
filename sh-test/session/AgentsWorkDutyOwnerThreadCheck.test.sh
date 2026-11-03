#!/usr/bin/env bash
## Behavioural check on S23.4, run rather than read: A WORK-DUTY HAS A SESSION THREAD IN THE TEAM BOT'S CONVERSATION WITH THE OWNER,
## its tooling thread stays in event-track, and the day's first duty run carries the greeting's mark. Held through the real schedule
## and the real spawn proxy, on a rig of its own:
##   1. a duty's start opens its session thread in the conversation SLACK_CHANNEL_HUMAN_OWNER resolves to, and posts no session root in magic-team;
##   2. its record names session-thread in that conversation, and agent-log-thread in the event-track channel;
##   3. the session's own thread record holds that thread, and the thread is no event-track one, so session-current and a Wait on it reach the duty;
##   4. the first duty start of a day hands its run the day-first mark, and a later start that day does not;
##   5. the duty routine's first step posts one greeting of one line when that mark is there.
## Section 0 plants a positive through every reader this check decides with, so a reader answering the same thing either way is caught
## before its result is read. Offline: the fake curl opens no socket; the console is a stand-in that keeps its dispatch and hands back.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRoutine="$rigPackage/skillset/magic-team/magic-team/magic-team.work-duty.routine.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigRoutine" ] || rigRefuse "the work-duty routine is not in the package: $rigRoutine"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWorkDutyOwnerThreadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
## Everything this rig's schedule started, ended when the check ends: each run's own process, named in its spawn record as
## `run-process: <pid> <start>`, and the shell that supervises it. They are noted when they are read, and signalled only
## while they are still those processes, so a number another process has taken since is never signalled.
## A kill that runs no trap at all is covered above this check: run through sh-test/AgentsRunTests.sh, the test's whole
## process group and every process under it are ended by the runner's keeper, and the test fails for leaving them.
rigEndRigStarted(){
	local rigRecordFile rigRecordPid
	for rigRecordFile in "$rigWs/.local/agents/spawned"/*/*.spawn.md ; do
		[ -f "$rigRecordFile" ] || continue
		for rigRecordPid in $( LC_ALL=C awk '
			$0 == "---" { if ( ++fence > 1 ) exit ; next }
			fence != 1 { next }
			index( $0, "run-process: " ) == 1 || index( $0, "supervisor-process: " ) == 1 {
				split( substr( $0, index( $0, ": " ) + 2 ), beganAt, " " ) ; print beganAt[1]
			}' "$rigRecordFile" 2> /dev/null ) ; do
			rigProcNote "$rigRecordPid"
			rigProcSignalWithChildren KILL "$rigRecordPid"
		done
	done
	return 0
}
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigEndRigStarted ; rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigSkills="$rigTmp/skills" rigBin="$rigTmp/bin"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned" "$rigBin" "$rigData/board/pending" \
	"$rigSkills/magic-coordinator" "$rigSkills/keeper-rig-01" "$rigSkills/keeper-rig-02"
cp "$rigPackage/sh-test/check-fixtures/work-duty-owner-thread.curl.stub.sh" "$rigBin/curl" \
	|| rigRefuse "the check's fake curl is missing from the package: sh-test/check-fixtures/work-duty-owner-thread.curl.stub.sh"
chmod +x "$rigBin/curl"
PATH="$rigBin:$PATH"
[ "$( command -v curl )" = "$rigBin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
: > "$rigTmp/calls" ; : > "$rigTmp/post-channels" ; : > "$rigTmp/posts"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigHeader(){ ## record, field
	[ -n "$1" ] || return 0
	LC_ALL=C sed -n "s/^$2: //p" "$1" | head -1
}
rigPostedTo(){ ## channel id -- how many posts went to it
	LC_ALL=C awk -v want="$1" '$2 == want' "$rigTmp/post-channels" | LC_ALL=C wc -l | LC_ALL=C tr -d ' '
}
rigMarkIn(){ ## file, mark name -- its value, or none
	[ -f "$1" ] || { printf 'no-file' ; return 0 ; }
	rigMarkValue="$( LC_ALL=C sed -n "s/^$2: *//p" "$1" | head -1 )"
	printf '%s\n' "${rigMarkValue:-none}"
}

echo "-- 0. each reader this check decides with is shown able to answer either way --"
printf -- '---\nsession-thread: DRIGOWNER01:1760000000.000100\nagent-log-thread: CRIGTRACK:1760000000.000200\n---\n' > "$rigTmp/planted.spawn.md"
rigAssert "the record reader finds a session thread when one is there" "$( rigHeader "$rigTmp/planted.spawn.md" session-thread | LC_ALL=C sed 's/:.*//' )" "DRIGOWNER01"
rigAssert "the record reader finds a tooling thread when one is there" "$( rigHeader "$rigTmp/planted.spawn.md" agent-log-thread | LC_ALL=C sed 's/:.*//' )" "CRIGTRACK"
rigAssert "the record reader answers nothing for a field the record does not hold" "$( rigHeader "$rigTmp/planted.spawn.md" no-such-field )" ""
printf '1 DRIGOWNER01\n2 CRIG00001\n' > "$rigTmp/post-channels"
rigAssert "the post counter counts a post to the owner's conversation" "$( rigPostedTo DRIGOWNER01 )" "1"
rigAssert "the post counter does not count one to the team channel as the owner's" "$( rigPostedTo CRIG00001 )" "1"
printf 'session-id: rig\nday-first: yes\n' > "$rigTmp/planted.dispatch"
rigAssert "the mark reader finds the mark when the file holds it" "$( rigMarkIn "$rigTmp/planted.dispatch" day-first )" "yes"
printf 'session-id: rig\n' > "$rigTmp/planted.bare"
rigAssert "the mark reader answers none when the file does not" "$( rigMarkIn "$rigTmp/planted.bare" day-first )" "none"
: > "$rigTmp/post-channels"

## The console the proxy launches: it keeps the dispatch it was handed, and hands back. It finds that
## dispatch by the sandbox root it is given (MDAT_SPAWN_SANDBOX_ROOT), never by its own working
## directory, and notes where it looked so a miss says which place was wrong.
printf '%s\n' '#!/usr/bin/env bash' '## --cli-configured stand-in: it keeps the dispatch and hands back.' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_AGENT"' \
	'sawDispatch=""' \
	'for tryPath in "${MDAT_SPAWN_SANDBOX_ROOT:-}/input/dispatch.md" "input/dispatch.md" ; do' \
	'	[ -f "$tryPath" ] || continue' \
	'	cat "$tryPath" > "$RIG_SCENARIO/dispatch.$MDAT_SPAWN_AGENT"' \
	'	sawDispatch="$tryPath"' \
	'	break' \
	'done' \
	'rigMark="$( sed -n "s/^day-first: *//p" "$RIG_SCENARIO/dispatch.$MDAT_SPAWN_AGENT" 2> /dev/null | head -1 )"' \
	'sawLaunch=$(( $( cat "$RIG_SCENARIO/launches" 2> /dev/null || echo 0 ) + 1 ))' \
	'printf "%s" "$sawLaunch" > "$RIG_SCENARIO/launches"' \
	'printf "%s\t%s\t%s\t%s\n" "$MDAT_SPAWN_AGENT" "$PWD" "${sawDispatch:-none}" "${rigMark:-none}" >> "$RIG_SCENARIO/console-ran"' \
	'printf "📦 SubagentHandback\n"' 'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
for rigMember in magic-coordinator keeper-rig-01 keeper-rig-02 ; do
	mkdir -p "$rigSkills/$rigMember" "$rigData/inboxes/$rigMember/incoming"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
	printf '# %s\n' "$rigMember" > "$rigSkills/$rigMember/SKILL.md"
	printf -- '---\nexecutors: %s\nmaintainers: %s\nrequires-session-kind: standalone\ninput-scan-def: none\nruns-at: none\nreports-to: none\n---\n# rig work-duty fixture\n' \
		"$rigMember" "$rigMember" > "$rigSkills/$rigMember/$rigMember.work-duty.routine.md"
done
## The real duty routine under the team member's own name for it: its first step is what assertion 5 reads.
cp "$rigRoutine" "$rigSkills/magic-coordinator/magic-team.work-duty.routine.md" || rigRefuse "the work-duty routine could not be copied into the rig"
## Each member has something to work on, and worktime covers every hour: the flags and the inboxes decide the start, never the clock.
printf '# Note: rig work\n\nwork\n' > "$rigData/inboxes/keeper-rig-01/incoming/note-20261103T0900Z-rig-work.md"
printf '# Note: rig work\n\nwork\n' > "$rigData/inboxes/keeper-rig-02/incoming/note-20261103T0900Z-rig-work.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER01\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nMDAT_SCHEDULE_WORKTIME=00:00 23:59 daily\n' \
	> "$rigWs/.local/.agents/magic-team.agent.env"

## One round of the real schedule: it starts whatever duty its flags and its inboxes call for.
rigSchedule(){ ## name
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c 'cd "$MMDAPP" && . "$RIG_FN" && . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.DispatcherSchedule.include" && AgentsToolsScheduleWorkDuty' \
	) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" < /dev/null
	rigQuiet
	rigConsolesSettle
}
## A round's launches finish a moment after its own command returns, so the boundary between two
## rounds is drawn once the console log has stopped growing: otherwise a later round counts a run the
## earlier one started, and reads that run's mark as its own.
rigConsolesSettle(){ ## -- waits until the console log holds the same number of lines twice running
	local settleLeft=40 settleNow settleThen
	settleThen="$( LC_ALL=C wc -l < "$rigTmp/console-ran" 2> /dev/null | LC_ALL=C tr -d ' \n' )"
	while [ "$settleLeft" -gt 0 ] ; do
		sleep 0.5
		settleNow="$( LC_ALL=C wc -l < "$rigTmp/console-ran" 2> /dev/null | LC_ALL=C tr -d ' \n' )"
		[ "$settleNow" != "$settleThen" ] || return 0
		settleThen="$settleNow"
		settleLeft=$(( settleLeft - 1 ))
	done
	return 0
}
## A start is made in the background and closes its record a moment later: the tree is quiet once no start is under way.
rigQuiet(){
	local rigLeft=600
	while [ -n "$( LC_ALL=C ls "$rigWs/.local/agents/schedule/starting" 2> /dev/null | LC_ALL=C grep -v -e '\.rc$' -e '\.out$' )" ] && [ "$rigLeft" -gt 0 ] ; do sleep 0.2 ; rigLeft=$(( rigLeft - 1 )) ; done
	rigLeft=300
	while LC_ALL=C grep -l -x -F 'status: spawn-started' "$rigWs/.local/agents/spawned"/*/*.spawn.md > /dev/null 2>&1 && [ "$rigLeft" -gt 0 ] ; do sleep 0.2 ; rigLeft=$(( rigLeft - 1 )) ; done
}
rigDutyRecord(){ ## member -- its work-duty record
	local rigRecs rigRec
	rigRecs="$( LC_ALL=C grep -l -E '^routine: [A-Za-z0-9-]+\.work-duty\.routine\.md$' "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null )" || rigRecs=""
	[ -n "$rigRecs" ] || return 0
	rigRec="$( LC_ALL=C grep -l -x "owner: $1" $rigRecs 2> /dev/null | head -1 )" || rigRec=""
	[ -z "$rigRec" ] || printf '%s\n' "$rigRec"
}
rigStartSaid(){ ## key -- the first error of that start, where it made a record for none
	LC_ALL=C grep -m1 'ERROR' "$rigWs/.local/agents/schedule/starting/$1.out" 2> /dev/null | LC_ALL=C cut -c1-220 || :
}
## The dispatch a duty's run was handed, as that run itself saw it: the console starts in the run's
## sandbox and copies `input/dispatch.md` to $rigTmp/dispatch.<member>. Its stdin is a run note,
## never the dispatch, so a mark read there answered none whatever the tool did.
rigDutyMark(){ ## member, mark name -- its value in that member's kept dispatch, no-dispatch, or none
	[ -f "$rigTmp/dispatch.$1" ] || { printf 'no-dispatch' ; return 0 ; }
	rigMarkIn "$rigTmp/dispatch.$1" "$2"
}
## The mark a launch was handed, read in launch order off the console log the stand-ins keep:
## `first` is the rig day's very first launch, `last` the most recent one. The rule under test is
## that exactly one launch a day carries the mark, the day's first, so both ends are read.
rigLaunchMark(){ ## first|last -- the mark that launch carried, no-dispatch where there was none, or none
	local rigWhichLaunch="$1" rigLaunchLine=""
	case "$rigWhichLaunch" in
		first) rigLaunchLine="$( LC_ALL=C head -1 "$rigTmp/console-ran" 2> /dev/null )" ;;
		last) rigLaunchLine="$( LC_ALL=C tail -1 "$rigTmp/console-ran" 2> /dev/null )" ;;
	esac
	[ -n "$rigLaunchLine" ] || { printf 'no-dispatch' ; return 0 ; }
	printf '%s\n' "$rigLaunchLine" | LC_ALL=C cut -f4
}
## A planted dispatch, so the finder that turns a member into the dispatch it was handed is shown answering both ways too.
printf 'session-id: rig\nday-first: yes\n' > "$rigTmp/dispatch.rig-planted"
rigAssert "the dispatch finder finds a run's dispatch" "$( rigDutyMark rig-planted day-first )" "yes"
rigAssert "the dispatch finder names no dispatch for a member with none" "$( rigDutyMark rig-nobody day-first )" "no-dispatch"
rm -f "$rigTmp/dispatch.rig-planted"

echo "-- 1. a duty's start opens its session thread in the owner's conversation --"
rigSchedule first
rigRecordOne="$( rigDutyRecord keeper-rig-01 )"
rigAssert "the schedule started keeper-rig-01 its duty" "$( [ -n "$rigRecordOne" ] && printf yes || printf no )" "yes"
[ -n "$rigRecordOne" ] || printf '  NOTE  the start itself did not complete: %s\n' "$( rigStartSaid work-duty.keeper-rig-01 )"
rigAssert "the run was launched" "$( [ -f "$rigTmp/brief.keeper-rig-01" ] && printf yes || printf no )" "yes"
## One round starts a duty for every member that has work, so the count is read against the duty
## records this round made rather than against the one member the rest of this section follows.
rigStartedNow="$( LC_ALL=C grep -l -E '^routine: [A-Za-z0-9-]+\.work-duty\.routine\.md$' "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
printf '  NOTE  this round made %s duty record(s)\n' "$rigStartedNow"
rigAssert "its session root is posted in the owner's conversation, once for each duty started, and none in the team channel" "$( rigPostedTo DRIGOWNER01 ):$( rigPostedTo CRIG00001 )" "$rigStartedNow:0"
rigAssert "that post is made under the team bot's token" "$( LC_ALL=C awk '$1 == "chat.postMessage" { print $2 }' "$rigTmp/calls" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" "rig-bot-token-TEAM "

echo "-- 2. the record names both threads, each in its own conversation --"
rigAssert "its session thread is in the owner's conversation" "$( rigHeader "$rigRecordOne" session-thread | LC_ALL=C sed 's/:.*//' )" "DRIGOWNER01"
rigAssert "its tooling thread stays in event-track" "$( rigHeader "$rigRecordOne" agent-log-thread | LC_ALL=C sed 's/:.*//' )" "CRIGTRACK"

echo "-- 3. the session's own thread record holds that thread, and it is no event-track thread --"
rigSessionId="$( rigHeader "$rigRecordOne" session-id )"
rigSessionThread="$( cat "$rigWs/.local/agents/sessions/$rigSessionId/session.thread" 2> /dev/null )"
rigAssert "the session's thread record holds the record's own thread" "$rigSessionThread" "$( rigHeader "$rigRecordOne" session-thread )"
rigAssert "that thread is not the event-track conversation's" "$( [ "${rigSessionThread%%:*}" = CRIGTRACK ] && printf event-track || printf elsewhere )" "elsewhere"

echo "-- 4. the day's first duty start carries the greeting's mark, and a later one does not --"
rigAssert "the day's first duty start hands its run the day-first mark" "$( rigLaunchMark first )" "yes"
rigSchedule second
rigAssert "the other member's duty starts the same day" "$( [ -n "$( rigDutyRecord keeper-rig-02 )" ] && printf yes || printf no )" "yes"
rigAssert "a later start that day carries no mark, the greeting being owed already" "$( rigLaunchMark last )" "no"

echo "-- 5. the duty routine's first step is the gated greeting, one message of one line --"
rigGreetLine="$( LC_ALL=C grep -F 'greet-the-team' "$rigSkills/magic-coordinator/magic-team.work-duty.routine.md" | head -1 )"
rigAssert "the routine's Opening steps name the greeting" "$( [ -n "$rigGreetLine" ] && printf yes || printf no )" "yes"
rigAssert "the greeting is posted to magic-team" "$( printf '%s' "$rigGreetLine" | LC_ALL=C grep -c -F 'magic-team' )" "1"
rigAssert "the greeting is gated on the day-first mark" "$( printf '%s' "$rigGreetLine" | LC_ALL=C grep -c -F 'day-first' )" "1"
rigAssert "the greeting is one message of one line" "$( printf '%s' "$rigGreetLine" | LC_ALL=C grep -c -F 'one message' )" "1"

echo "-- 6. the day the greeting is owed on is the schedule's own zone --"
## The schedule reads its clock through date(1) with MDAT_SCHEDULE_TIMEZONE, and AgentsToolsScheduleDayFirst
## is the one place that turns that clock into the day a greeting is owed on: `ask` says yes until a
## start has opened the day, `record` opens it. Zoned to UTC+3, local 23:00 and local 00:00 are two
## days an hour apart, which a host-local or UTC reading would call one.
rigRealDate="$( command -v date )" || rigRefuse "no date on PATH"
mkdir -p "$rigTmp/binclock"
printf '%s\n' '#!/bin/sh' '## The rig clock: date +%s answers the instant in now.epoch; everything else is the real date.' \
	'case "$1" in +%s) cat "${0%/*}/../now.epoch" ; exit 0 ;; esac' "exec \"$rigRealDate\" \"\$@\"" > "$rigTmp/binclock/date"
chmod +x "$rigTmp/binclock/date"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER01\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nMDAT_SCHEDULE_WORKTIME=00:00 23:59 daily\nMDAT_SCHEDULE_TIMEZONE=Etc/GMT-3\n' \
	> "$rigWs/.local/.agents/magic-team.agent.env"
rigSlot(){ printf '%s' "$1" > "$rigTmp/now.epoch" ; }
rigDayFirst(){ ## verb -- the real function's answer, on the rig's own clock and zone
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/binclock:$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c 'cd "$MMDAPP" && . "$RIG_FN" && . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.DispatcherSchedule.include" && AgentsToolsScheduleDayFirst "$1"' rig-day-first "$1" \
	) 2> /dev/null
}
rm -f "$rigWs/.local/agents/schedule/day-first"
## UTC midnight of a day, then 20:00 UTC, which is 23:00 local in UTC+3.
rigDayMidnight=$(( $( date -u +%s ) / 86400 * 86400 ))
rigSlot $(( rigDayMidnight + 72000 ))
rigAssert "at local 23:00 the day's greeting is owed" "$( rigDayFirst ask )" "yes"
rigDayFirst record > /dev/null
rigAssert "at local 23:00, once a start has opened the day, it is owed no more" "$( rigDayFirst ask )" "no"
rigSlot $(( rigDayMidnight + 73800 ))
rigAssert "at local 23:30, the same local day, it is still owed no more" "$( rigDayFirst ask )" "no"
rigSlot $(( rigDayMidnight + 75600 ))
rigAssert "at local 00:00, the next local day, it is owed again" "$( rigDayFirst ask )" "yes"
rigSlot $(( rigDayMidnight + 90000 ))
rigAssert "at local 04:00, further into that new local day, it stays owed" "$( rigDayFirst ask )" "yes"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ WORK DUTY OWNER THREAD CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
echo "WORK_DUTY_OWNER_THREAD: OK ($rigPasses assertions, offline)"
