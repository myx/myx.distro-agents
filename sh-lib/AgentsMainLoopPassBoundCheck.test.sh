#!/usr/bin/env bash
## Behavioural check on --intern-main-loop's pass bound. A bound that fires ends the
## whole pass (its process group), records timed-out, tries to tell event-track, and the
## next pass proceeds; no bound never ends a pass and reports it running; a short pass
## says nothing. The real loop and spawn proxy run; the console, curl and every setting
## are this rig's own. GUARD: every tooling call goes through one `env -i` whose child
## refuses to start unless MMDAPP and MDAT_DATA_ROOT sit under this rig's mktemp tree,
## and PATH holds no agent CLI -- a probe once reached the real workspace without it.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
rigTmp="$( mktemp -d -t AgentsMainLoopPassBoundCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLoopPid=""
trap '[ -z "$rigLoopPid" ] || kill -KILL -- "-$rigLoopPid" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
## A rig stopped from outside still takes its loop with it.
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

## A fresh workspace per scenario: settings, a fake console that hangs on its first
## call only, and a Slack-shaped curl that keeps every posted body.
rigScenario(){ ## name, pass timeout seconds, first-pass seconds
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/data" "$rigDir/bin" "$rigDir/home/.claude/skills/magic-coordinator"
	## The sender is resolved from its skill folder, so the event-track post needs one.
	printf '# magic-coordinator\n' > "$rigDir/home/.claude/skills/magic-coordinator/SKILL.md"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/home/.claude/skills/magic-coordinator/magic-coordinator.basic.md"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-not-a-token\nSPAWN_CLI_SERVICE=rig-cli\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf 'MAIN_LOOP_RESTART_DELAY_SECONDS=2\nMAIN_LOOP_PASS_TIMEOUT_SECONDS=%s\n' "$2" > "$rigDir/ws/.local/.agents/magic-coordinator.agent.env"
	printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\nrigCall=$( ls "%s"/call.* 2>/dev/null | wc -l | tr -d " " )\n: > "%s/call.$$"\necho "start $$" >> "%s/console.log"\nif [ "$rigCall" = 0 ] ; then sleep %s ; fi\necho "end $$" >> "%s/console.log"\n' \
		"$rigDir" "$rigDir" "$rigDir" "$3" "$rigDir" > "$rigDir/ws/DistroAgentsConsole.sh"
	printf '#!/bin/sh\ncat > /dev/null\nfor a in "$@" ; do case "$a" in @-) ;; *@/*) cat "/${a#*@/}" >> "%s/posted" ; echo >> "%s/posted" ;; esac ; done\necho "$*" >> "%s/curl.log"\nprintf %s\n' \
		"$rigDir" "$rigDir" "$rigDir" "'{\"ok\":true,\"channel\":\"CRIG00001\",\"ts\":\"1700000001.000100\",\"message\":{\"ts\":\"1700000001.000100\"}}\n'" > "$rigDir/bin/curl"
	chmod +x "$rigDir/ws/DistroAgentsConsole.sh" "$rigDir/bin/curl"
}
## The one way this rig runs tooling: a clean environment, and a child that checks where
## it is about to work before it starts.
rigLoopStart(){
	set -m
	env -i HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" TMPDIR="$rigDir" \
		MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigDir/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigDir/home/.claude/skills" \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree: $MDAT_DATA_ROOT" >&2 ; exit 99 ;; esac
			! command -v claude > /dev/null 2>&1 || { echo "RIG-GUARD: an agent CLI is on PATH" >&2 ; exit 99 ; }
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-main-loop --run
		' > "$rigDir/loop.out" 2> "$rigDir/loop.err" &
	rigLoopPid=$!
	set +m
}
rigLoopStop(){
	{ kill -TERM -- "-$rigLoopPid" ; sleep 2 ; kill -KILL -- "-$rigLoopPid" ; wait "$rigLoopPid" ; } 2>/dev/null
	rigLoopPid=""
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft="$1" ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigStarts(){ LC_ALL=C grep -c '^start ' "$rigDir/console.log" 2>/dev/null || printf 0 ; }
rigAtLeast(){ [ "$( "$2" )" -ge "$1" ] ; }

echo "-- the guard refuses a workspace outside the rig tree --"
rigScenario guard 0 1
rigGuardOut="$( env -i PATH=/usr/bin:/bin MMDAPP=/nonexistent/real MDAT_DATA_ROOT="$rigDir/data" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
	bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" ; exit 99 ;; esac ; echo reached' )"
rigAssert "a workspace outside the tree is refused before any tooling runs" "$rigGuardOut" "RIG-GUARD: MMDAPP outside the rig tree: /nonexistent/real"

echo "-- a bound that fires --"
## The bound sits above the proxy's own start-up cost, or every pass ends before its console starts.
rigScenario bounded 20 90
rigLoopStart
rigWaitFor 60 rigAtLeast 1 rigStarts || { cat "$rigDir/loop.err" >&2 ; rigRefuse "the loop never started a pass" ; }
rigFirstPid="$( LC_ALL=C sed -n '1s/^start //p' "$rigDir/console.log" )"
rigWaitFor 60 env LC_ALL=C grep -q 'MAIN_LOOP_LAST_OUTCOME=timed-out' "$rigDir/ws/.local/agents/main-loop.state"
rigAssert "the state records timed-out"                "$( LC_ALL=C grep -c '^MAIN_LOOP_LAST_OUTCOME=timed-out$' "$rigDir/ws/.local/agents/main-loop.state" 2>/dev/null || printf 0 )" 1
rigAssert "the hung pass is gone, its whole group with it" "$( kill -0 "$rigFirstPid" 2>/dev/null && printf alive || printf gone )" gone
rigAssert "it never reached its own end"               "$( LC_ALL=C grep -c "^end $rigFirstPid$" "$rigDir/console.log" )" 0
rigAssert "the ending is said on stderr"               "$( LC_ALL=C grep -c 'passed MAIN_LOOP_PASS_TIMEOUT_SECONDS=20 -- ending it' "$rigDir/loop.err" )" 1
rigAssert "event-track is told"                        "$( LC_ALL=C grep -q -F 'Heartbeat pass timed out' "$rigDir/posted" 2>/dev/null && printf yes || printf no )" yes
rigWaitFor 60 rigAtLeast 2 rigStarts
rigAssert "the next pass proceeds"                     "$( [ "$( rigStarts )" -ge 2 ] && printf yes || printf no )" yes
rigLoopStop

echo "-- no bound: a long pass is reported, never ended --"
rigScenario unbounded 0 66
rigLoopStart
rigWaitFor 60 rigAtLeast 1 rigStarts || rigRefuse "the loop never started a pass"
rigFirstPid="$( LC_ALL=C sed -n '1s/^start //p' "$rigDir/console.log" )"
rigWaitFor 90 env LC_ALL=C grep -q "^end $rigFirstPid$" "$rigDir/console.log"
rigAssert "the long pass reached its own end"          "$( LC_ALL=C grep -c "^end $rigFirstPid$" "$rigDir/console.log" )" 1
rigAssert "it was said running, again at the loop's pace" "$( [ "$( LC_ALL=C grep -c 'heartbeat pass running for 1 min' "$rigDir/loop.err" )" -ge 2 ] && printf yes || printf no )" yes
rigAssert "nothing ended it"                           "$( LC_ALL=C grep -c 'ending it (TERM, then KILL)' "$rigDir/loop.err" )" 0
rigLoopStop

echo "-- control: a short pass --"
## A bound well above a pass's own start-up cost: the proxy alone takes seconds under load.
rigScenario short 120 1
rigLoopStart
rigWaitFor 60 rigAtLeast 2 rigStarts || rigRefuse "the loop never ran two passes"
rigAssert "no running line"                            "$( LC_ALL=C grep -c 'heartbeat pass running for' "$rigDir/loop.err" )" 0
rigAssert "no ending"                                  "$( LC_ALL=C grep -c 'ending it (TERM, then KILL)' "$rigDir/loop.err" )" 0
rigAssert "and no timed-out state"                     "$( LC_ALL=C grep -q 'timed-out' "$rigDir/ws/.local/agents/main-loop.state" 2>/dev/null && printf yes || printf no )" no
rigLoopStop

rigAssert "no request left for a real host"            "$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C grep -v -c 'slack.com/api/' || : )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MAIN LOOP PASS BOUND CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MAIN_LOOP_PASS_BOUND: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
