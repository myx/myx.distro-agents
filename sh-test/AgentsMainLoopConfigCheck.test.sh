#!/usr/bin/env bash
## Behavioural check on the configuration check of --intern-main-loop (F7.12 step 4 of the refactorings epic: the heartbeat pass is out of the loop, its
## configuration check runs as a script). The real loop (--one and --run) runs; the console, curl and every setting are this rig's own. Held:
##   1. A passing check: the iteration passes, says so in one line, keeps the answer and the time in main-loop.config-check.last, writes state ok, and
##      starts no agent (the console of the rig is never called) and says nothing of a heartbeat or a pass.
##   2. At most once in 30 minutes while it passes: an iteration within them does not run it again (no line, the kept answer as it was); one after them does.
##   3. A failing check: the iteration fails (rc 1, state failed, one failure counted), says each FAIL line with its reason, says that the schedule's starts are
##      skipped; and it is run again in each iteration until it passes. Once it passes, the iteration passes and the failure count is back to 0.
##   4. The loop (--run) with a failing check backs off as it did for a failed pass (the delay doubles), and one interrupt ends it with nothing left running.
## GUARD: every tooling call goes through one `env -i` whose child refuses to start unless MMDAPP and MDAT_DATA_ROOT sit under this rig's mktemp tree,
## and PATH holds no agent CLI -- a probe once reached the real workspace without it. Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMainLoopConfigCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLoopPid=""
trap '[ -z "$rigLoopPid" ] || rigProcGroupSignal KILL "$rigLoopPid" ; chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
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

## A fresh workspace per scenario: settings, a console that only logs its calls, and a Slack-shaped curl.
rigScenario(){ ## name
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/data" "$rigDir/bin" "$rigDir/home/.claude/skills/magic-coordinator" "$rigDir/home/.claude/skills/magic-team"
	printf '# magic-coordinator\n' > "$rigDir/home/.claude/skills/magic-coordinator/SKILL.md"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/home/.claude/skills/magic-coordinator/magic-coordinator.basic.md"
	printf '# rig armed\n' > "$rigDir/home/.claude/skills/magic-coordinator/magic-coordinator.armed.md"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-not-a-token\nSPAWN_CLI_SERVICE=rig-cli\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf 'MAIN_LOOP_RESTART_DELAY_SECONDS=2\n' > "$rigDir/ws/.local/.agents/magic-coordinator.agent.env"
	printf '#!/bin/sh\ncat > /dev/null\necho "start $$" >> "%s/console.log"\n' "$rigDir" > "$rigDir/ws/DistroAgentsConsole.sh"
	printf '#!/bin/sh\ncat > /dev/null\nfor a in "$@" ; do case "$a" in @-) ;; *@/*) cat "/${a#*@/}" >> "%s/posted" ; echo >> "%s/posted" ;; esac ; done\necho "$*" >> "%s/curl.log"\nprintf %s\n' \
		"$rigDir" "$rigDir" "$rigDir" "'{\"ok\":true,\"channel\":\"CRIG00001\",\"ts\":\"1700000001.000100\",\"message\":{\"ts\":\"1700000001.000100\"}}\n'" > "$rigDir/bin/curl"
	chmod +x "$rigDir/ws/DistroAgentsConsole.sh" "$rigDir/bin/curl"
}
rigEnv(){ ## words... -- the one way this rig runs tooling: a clean environment, and a child that checks where it is about to work before it starts
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigDir/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigDir/home/.claude/skills" \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree: $MDAT_DATA_ROOT" >&2 ; exit 99 ;; esac
			! command -v claude > /dev/null 2>&1 || { echo "RIG-GUARD: an agent CLI is on PATH" >&2 ; exit 99 ; }
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@"
}
rigLoopStart(){
	set -m
	rigEnv --intern-main-loop --run > "$rigDir/loop.out" 2> "$rigDir/loop.err" < /dev/null &
	rigLoopPid=$!
	set +m
	rigProcNote "$rigLoopPid"
}
rigLoopStop(){
	{ rigProcGroupSignal TERM "$rigLoopPid" ; sleep 2 ; rigProcGroupSignal KILL "$rigLoopPid" ; wait "$rigLoopPid" ; } 2>/dev/null
	rigLoopPid=""
}
rigOneRc=0
rigOneRun(){ ## name of its output files -- one iteration of the real loop
	rigEnv --intern-main-loop --one > "$rigDir/$1.out" 2> "$rigDir/$1.err" < /dev/null
	rigOneRc=$?
}
rigSaid(){ ## name of a run, fixed text -- how many lines of its errors hold it
	LC_ALL=C grep -c -F -- "$2" "$rigDir/$1.err" || :
}
rigState(){ ## key -- the value in the state file of the loop
	LC_ALL=C sed -n "s/^$1=//p" "$rigDir/ws/.local/agents/main-loop.state" 2>/dev/null | tail -1
}
rigKept(){ cat "$rigDir/ws/.local/agents/main-loop.config-check.last" 2>/dev/null || printf none ; }
rigWaitFor(){ ## seconds, test command...
	local waitLeft="$1" ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigStateIs(){ [ "$( rigState MAIN_LOOP_LAST_OUTCOME )" = "$1" ] ; }

echo "-- the guard refuses a workspace outside the rig tree --"
rigScenario guard
rigGuardOut="$( env -i MDAT_WORKSPACE_MODE=team-rig PATH=/usr/bin:/bin MMDAPP=/nonexistent/real MDAT_DATA_ROOT="$rigDir/data" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
	bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" ; exit 99 ;; esac ; echo reached' )"
rigAssert "a workspace outside the tree is refused before any tooling runs" "$rigGuardOut" "RIG-GUARD: MMDAPP outside the rig tree: /nonexistent/real"

echo "-- 1. a passing check --"
rigScenario main
rigOneRun first
rigAssert "the iteration passes, says in one line that the check passed, and the state is ok" "$rigOneRc:$( rigSaid first 'configuration check passed' ):$( rigState MAIN_LOOP_LAST_OUTCOME )" "0:1:ok"
rigKeptFirst="$( rigKept )"
rigAssert "the answer and the time are kept: 0 and an epoch" "$( printf '%s' "$rigKeptFirst" | LC_ALL=C grep -c -E '^0 [0-9]+$' )" "1"
rigAssert "no agent was started: the console of the rig was never called" "$( [ -e "$rigDir/console.log" ] && printf called || printf never )" "never"
rigAssert "nothing is said of a heartbeat or of a pass" "$( LC_ALL=C grep -c -i -e 'heartbeat' -e ' pass ' "$rigDir/first.err" || : )" "0"
rigAssert "the housekeeping ran: the children lists were rebuilt" "$( [ "$( rigSaid first 'children lists rebuilt' )" -ge 1 ] && [ -f "$rigDir/ws/.local/agents/children/.indexed" ] && printf yes || printf no )" "yes"

echo "-- 2. at most once in 30 minutes while it passes --"
rigOneRun second
rigAssert "an iteration right after runs no check: it passes, says nothing of it, and the kept answer is as it was" "$( printf '%s:%s:%s' "$rigOneRc" "$( rigSaid second 'configuration check' )" "$( [ "$( rigKept )" = "$rigKeptFirst" ] && printf same || printf changed )" )" "0:0:same"
rigNow="$( date +%s )"
printf '0 %s\n' "$(( rigNow - 1900 ))" > "$rigDir/ws/.local/agents/main-loop.config-check.last"
rigOneRun third
rigAssert "one after 31 minutes runs it again: said once, and the kept time is now" "$( printf '%s:%s:%s' "$rigOneRc" "$( rigSaid third 'configuration check passed' )" "$( [ "$( rigKept | cut -d' ' -f2 )" -ge "$rigNow" ] && printf now || printf old )" )" "0:1:now"
printf '0 %s\n' "$(( rigNow + 100000 ))" > "$rigDir/ws/.local/agents/main-loop.config-check.last"
rigOneRun future
rigAssert "a kept time in the future is not trusted: the check runs" "$( rigSaid future 'configuration check passed' )" "1"

echo "-- 3. a failing check --"
## Without a Slack token the loop's floor is met (it probes the channels) and the check is not: every send of a pass would fail.
LC_ALL=C sed -i.bak -e '/^SLACK_BOT_TOKEN=/d' "$rigDir/ws/.local/.agents/magic-team.agent.env" && rm -f "$rigDir/ws/.local/.agents/magic-team.agent.env.bak"
## A change within the 30 minutes of a pass is seen at their end, so the kept answer is put away for this look.
rm -f "$rigDir/ws/.local/agents/main-loop.config-check.last"
rigOneRun fail1
rigAssert "the iteration fails: rc 1, state failed, one failure counted" "$rigOneRc:$( rigState MAIN_LOOP_LAST_OUTCOME ):$( rigState MAIN_LOOP_CONSECUTIVE_FAILURES )" "1:failed:1"
rigAssert "it says that the check failed, and each FAIL line with its reason" "$( rigSaid fail1 'configuration check FAILED' ):$( LC_ALL=C grep -c -F -e 'SLACK_TOKEN: FAIL' "$rigDir/fail1.err" ):$( LC_ALL=C grep -c -e 'fail: no SLACK_USER_TOKEN or SLACK_BOT_TOKEN' "$rigDir/fail1.err" | tr -d ' ' )" "1:1:1"
rigAssert "it says that the schedule's starts are skipped, and the housekeeping ran all the same" "$( rigSaid fail1 "the schedule's starts are skipped" ):$( rigSaid fail1 'children lists rebuilt' )" "1:1"
rigAssert "the failure is kept: 1 and the time" "$( rigKept | LC_ALL=C grep -c -E '^1 [0-9]+$' )" "1"
rigOneRun fail2
rigAssert "it is run again in the next iteration, whatever the time: said again, and failed again" "$( rigSaid fail2 'configuration check FAILED' ):$( rigState MAIN_LOOP_LAST_OUTCOME )" "1:failed"
printf 'SLACK_BOT_TOKEN=rig-not-a-token\n' >> "$rigDir/ws/.local/.agents/magic-team.agent.env"
rigOneRun fixed
rigAssert "once it passes the iteration passes, and the failure count is back to 0" "$rigOneRc:$( rigSaid fixed 'configuration check passed' ):$( rigState MAIN_LOOP_LAST_OUTCOME ):$( rigState MAIN_LOOP_CONSECUTIVE_FAILURES )" "0:1:ok:0"
rigAssert "through all of it no agent was started" "$( [ -e "$rigDir/console.log" ] && printf called || printf never )" "never"

echo "-- 4. the loop backs off on a failing check, and one interrupt ends it --"
rigScenario loop
LC_ALL=C sed -i.bak -e '/^SLACK_BOT_TOKEN=/d' "$rigDir/ws/.local/.agents/magic-team.agent.env" && rm -f "$rigDir/ws/.local/.agents/magic-team.agent.env.bak"
rigLoopStart
rigWaitFor 90 rigStateIs failed || { cat "$rigDir/loop.err" >&2 ; rigRefuse "the loop never wrote a failed state" ; }
rigAssert "the first failure doubles the delay: 4 seconds, from the 2 of the setting" "$( rigState MAIN_LOOP_CURRENT_DELAY_SECONDS ):$( rigState MAIN_LOOP_CONSECUTIVE_FAILURES )" "4:1"
rigStoppedPid="$rigLoopPid"
rigProcGroupSignal TERM "$rigLoopPid"
rigWaitFor 10 eval '! kill -0 "$rigStoppedPid" 2>/dev/null'
rigAssert "one interrupt ends the loop: nothing of it is left running" "$( kill -0 "$rigStoppedPid" 2>/dev/null && printf alive || printf gone )" "gone"
rigLoopStop

rigAssert "no request left for a real host" "$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C grep -v -c 'slack.com/api/' || : )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MAIN LOOP CONFIG CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MAIN_LOOP_CONFIG_CHECK: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
