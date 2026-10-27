#!/usr/bin/env bash
## Behavioural check on the report a detached Bash process makes into the session thread (S3.1), run through the harness's own served
## entry point (`--intern-tool Bash`) against this check's own rig workspace, with a Slack-shaped fake curl first on PATH. Held:
##   1. a process that stops after a prompt with no newline is reported once as possibly waiting for input
##   2. a process that runs on is reported as still running, at the interval the run sets
##   3. the end is reported in the session thread: the handle, the exit status and the last lines of its output
##   4. a process the caller stops is not reported as ended, and its reporter posts nothing more
##   5. a session with no thread says so when the process starts, and posts nothing
## Offline: the fake curl is the only network there is.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigHarness="$rigOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh"
rigFixtures="$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures"
rigMember="rig-a"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
[ -f "$rigFixtures/session-address-first.curl.stub.sh" ] || rigRefuse "the fake curl fixture is missing: $rigFixtures/session-address-first.curl.stub.sh"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDetachedProcessReportCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/skills/$rigMember" "$rigTmp/home" "$rigTmp/work" "$rigTmp/bin" || exit 1
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf -- '---\nname: %s\n---\nmember skill\n' "$rigMember" > "$rigTmp/skills/$rigMember/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigTmp/ws/.local/.agents/$rigMember.agent.env"
cp "$rigFixtures/session-address-first.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "cannot place the fake curl"
rigPath="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
rigScenario="$rigTmp/scenario"
mkdir -p "$rigScenario"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCall(){ ## argument object, session, call name -- the Bash tool, served; its output in <name>.out
	local rigStatus=0
	( cd "$rigTmp/ws" && printf '%s' "$1" | env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="$2" RIG_SCENARIO="$rigScenario" \
		MDAT_WAIT_REMIND=off MDAT_PROCESS_POLL_SECONDS=0.5 MDAT_PROCESS_ALIVE_SECONDS=2 MDAT_PROCESS_INPUT_IDLE_SECONDS=1 \
		python3 -I -B "$rigFixtures/rig-exec.py" --alarm 120 -- bash "$rigHarness" --intern-tool Bash --access-read-root "$rigTmp" --access-write-root "$rigTmp" ) \
		> "$rigTmp/$3.out" 2> "$rigTmp/$3.err" || rigStatus=$?
	printf '%s' "$rigStatus" > "$rigTmp/$3.rc"
}
rigPosts(){ ## the number of messages posted so far
	cat "$rigScenario/posts" 2> /dev/null || printf 0
}
rigPostsHold(){ ## fixed text -- the number of posted messages that hold it
	local rigAt=1 rigHits=0 rigCount
	rigCount="$( rigPosts )"
	while [ "$rigAt" -le "$rigCount" ] ; do
		LC_ALL=C grep -q -F -- "$1" "$rigScenario/post.$rigAt" 2> /dev/null && rigHits=$(( rigHits + 1 ))
		rigAt=$(( rigAt + 1 ))
	done
	printf '%s' "$rigHits"
}
rigAwaitPost(){ ## fixed text, seconds -- yes once a posted message holds it
	local rigTry=0
	while [ "$rigTry" -lt $(( $2 * 2 )) ] ; do
		[ "$( rigPostsHold "$1" )" = 0 ] || { printf yes ; return 0 ; }
		rigTry=$(( rigTry + 1 )) ; sleep 0.5
	done
	printf no
}
rigSession(){ ## session id, thread (empty: none) -- the session folder, with its thread record where there is one
	mkdir -p "$rigTmp/ws/.local/agents/sessions/$1"
	[ -z "$2" ] || printf '%s\n' "$2" > "$rigTmp/ws/.local/agents/sessions/$1/session.thread"
	printf 0 > "$rigScenario/posts"
	rm -f "$rigScenario"/post.* "$rigScenario/calls"
}

echo "-- 1 to 3. a prompt, a long run and an end are reported into the session thread --"
rigSession rig-report-one "CRIG00001:1760000000.000100"
rigCall "{\"cwd\":\"$rigTmp/work\",\"command\":\"printf RIGPROMPT; sleep 5; echo; echo RIG-LAST-LINE; exit 3\",\"detach\":true}" rig-report-one start1
rigHandle="$( LC_ALL=C sed -n 's/^Process handle: //p' "$rigTmp/start1.out" | LC_ALL=C head -1 )"
rigAssert "the start names its handle" "$( printf '%s' "$rigHandle" | LC_ALL=C grep -c -E '^process-[0-9]+$' )" 1
rigAssert "the end is posted: the handle, the exit status" "$( rigAwaitPost "$rigHandle ended with exit status 3" 40 )" yes
rigAssert "the end carries the last line of the output" "$( rigPostsHold 'RIG-LAST-LINE' ):$( rigPostsHold "$rigHandle ended" )" "1:1"
rigAssert "a prompt with no newline is reported once as possibly waiting for input" "$( rigPostsHold "$rigHandle may be waiting for input" )" 1
rigAssert "a run that goes on is reported as still running" "$( [ "$( rigPostsHold "$rigHandle is still running" )" -ge 1 ] && printf yes || printf no )" yes
rigAssert "every post went into the session thread, and there were at least three" "$( LC_ALL=C grep -l -F '"thread_ts":"1760000000.000100"' "$rigScenario"/post.* 2> /dev/null | LC_ALL=C wc -l | tr -d ' ' ):$( [ "$( rigPosts )" -ge 3 ] && printf many )" "$( rigPosts ):many"

echo "-- 4. a process the caller stops is not reported as ended --"
rigSession rig-report-two "CRIG00001:1760000000.000200"
rigCall "{\"cwd\":\"$rigTmp/work\",\"command\":\"sleep 30\",\"detach\":true}" rig-report-two start2
rigHandle2="$( LC_ALL=C sed -n 's/^Process handle: //p' "$rigTmp/start2.out" | LC_ALL=C head -1 )"
rigAssert "control: before the stop, the running process is reported" "$( rigAwaitPost "$rigHandle2 is still running" 10 )" yes
rigCall "{\"handle\":\"$rigHandle2\",\"stop\":true}" rig-report-two stop2
sleep 1
rigPostedAtStop="$( rigPosts )"
sleep 4
rigAssert "no post says it ended" "$( rigPostsHold "$rigHandle2 ended" )" 0
rigAssert "and the reporter posts nothing more once the process is stopped" "$( rigPosts )" "$rigPostedAtStop"

echo "-- 5. no session thread: said at the start, nothing posted --"
rigSession rig-report-three ""
rigCall "{\"cwd\":\"$rigTmp/work\",\"command\":\"echo RIG-QUICK\",\"detach\":true}" rig-report-three start3
sleep 4
rigAssert "the start says no progress will be posted" "$( LC_ALL=C grep -c 'no session thread' "$rigTmp/start3.out" )" 1
rigAssert "nothing was posted" "$( rigPosts )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DETACHED PROCESS REPORT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DETACHED_PROCESS_REPORT: OK (%d assertions, offline, a fake curl)\n' "$rigPassCount"
