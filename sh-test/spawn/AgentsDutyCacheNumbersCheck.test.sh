#!/usr/bin/env bash
## Behavioural check on the cache numbers a duty run carries (S18.4): the spawner writes on the run's own record the three
## numbers the schedule's keep-or-stop rule reads, `duty-cache-round`, `duty-cache-life` and `duty-cache-turns`, taken from
## the CLI service that run started on. The schedule never reads the spawn concern's files, so the record is the only place
## the numbers meet. Held through the real spawn proxy, on a stand-in console that runs no model:
##   1. A RUN ON claude-native CARRIES ITS SERVICE'S THREE NUMBERS: the wait round, the seconds its cache lives, and the
##      wakes of that round that repay writing it again.
##   2. THE CONTROL: a run on a service whose cache prices were never read carries none of the three, so a reading that
##      wrote a fixed row for every service passes row 1 and fails this one.
##   3. THE TABLE ITSELF answers the same three numbers for each of its rows, and answers nothing at all for a service it
##      has no row for.
## Offline: a fake curl, a stand-in console that records the brief and hands back, and every tree the rig's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigCli="$rigPackage/sh-lib/harness/AgentsTools.CliService.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyCacheNumbersCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigSkills="$rigTmp/skills"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigSkills/magic-coordinator"
printf -- '---\nname: magic-coordinator\ndescription: rig member\n---\n' > "$rigSkills/magic-coordinator/SKILL.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf '# rig armed\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
cp "$rigPackage/sh-test/check-fixtures/work-duty.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIGTEAM1\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK1\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## The console the proxy launches: both marks it checks before launching, the brief recorded, and an immediate handback
## that keeps the missing-handback retry out of this rig.
printf '%s\n' '#!/bin/sh' \
	'## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)' \
	'cat > "$RIG_SCENARIO/brief"' \
	'printf "claude-native\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'printf "   📦 SubagentHandback rig-outcome\n"' \
	'exit 0' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
rigSpawn(){ ## cli service -- the path of the record the spawn wrote
	rm -rf "$rigWs/.local/agents/spawned"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		"MDLT_OPTION=--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash -c 'cd "$MMDAPP" && exec bash "$0" --intern-op-agent-spawn-proxy magic-coordinator --spawn-cli-service "$1" --dispatch-doc:create --wait --context rig-cache-numbers' \
		"$rigTool" "$1" <<< 'RIG-BRIEF-TEXT' > "$rigTmp/spawn.out" 2>&1 ) || :
	find "$rigWs/.local/agents/spawned" -name '*.spawn.md' 2> /dev/null | LC_ALL=C sed -n 1p
}
rigField(){ ## record, field name -- that field's value, empty where the record carries none
	LC_ALL=C sed -n "s/^$2: //p" "$1" 2> /dev/null | LC_ALL=C sed -n 1p
}
## The table read through the package's own function, one CLI service at a time.
rigTable(){ ## cli service -- its three numbers, or nothing where the table has no row for it
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" RIG_SERVICE="$1" bash -c '
			set +e
			. "$1" || exit 9
			AgentsToolsCliServiceDutyCache "$RIG_SERVICE"
		' rig "$rigCli" 2> /dev/null
}
## The wait round the same file answers for a service, which is a row's first number.
rigRound(){ ## cli service -- its wait round
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" RIG_SERVICE="$1" bash -c '
			set +e
			. "$1" || exit 9
			AgentsToolsCliServiceWaitRound "$RIG_SERVICE"
		' rig "$rigCli" 2> /dev/null
}

echo "-- 1. a claude-native run carries its service's three numbers --"
rigRecord="$( rigSpawn claude-native )"
rigAssert "the spawn started, and wrote its record"           "$( [ -n "$rigRecord" ] && printf yes || printf no )" "yes"
rigAssert "the run's service is the one asked for"            "$( rigField "$rigRecord" cli )" "claude-native"
rigAssert "duty-cache-round is that service's wait round"     "$( rigField "$rigRecord" duty-cache-round )" "2700"
rigAssert "duty-cache-life is the seconds its cache lives"     "$( rigField "$rigRecord" duty-cache-life )" "3600"
rigAssert "duty-cache-turns is the wakes that repay a rebuild" "$( rigField "$rigRecord" duty-cache-turns )" "20"

echo "-- 2. the control: a service with no cache prices carries none of the three --"
rigRecord="$( rigSpawn copilot-native )"
rigAssert "the spawn started on that service"                 "$( rigField "$rigRecord" cli )" "copilot-native"
rigAssert "and its record carries none of the three"          "$( LC_ALL=C grep -c '^duty-cache-' "$rigRecord" 2> /dev/null || : )" "0"

echo "-- 3. the table itself, row by row --"
rigAssert "claude-native: its round, its life, and the 20 wakes" "$( rigTable claude-native )" "2700 3600 20"
rigAssert "a service the table has no row for answers nothing"   "$( rigTable copilot-native ):" ":"
rigBadRow=""
for rigRow in $( LC_ALL=C sed -n 's/^agentsCliServiceCacheRegions="//p' "$rigCli" | LC_ALL=C sed 's/"$//' ) ; do
	rigService="${rigRow%%:*}"
	rigRest="${rigRow#*:}"
	rigLife="${rigRest%%:*}"
	rigRest="${rigRest#*:}"
	rigWake="${rigRest%%:*}"
	rigRebuild="${rigRest##*:}"
	case "$rigLife$rigWake$rigRebuild" in ''|*[!0123456789]*) rigBadRow="$rigBadRow $rigRow" ; continue ;; esac
	[ "$rigWake" -gt 0 ] || { rigBadRow="$rigBadRow $rigRow" ; continue ; }
	[ "$( rigTable "$rigService" )" = "$( rigRound "$rigService" ) $rigLife $(( rigRebuild / rigWake ))" ] || rigBadRow="$rigBadRow $rigRow"
done
rigAssert "each row answers its round, its life and its own wakes"  "$( [ -z "$rigBadRow" ] && printf yes || printf 'no:%s' "$rigBadRow" )" "yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DUTY CACHE NUMBERS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
printf 'DUTY_CACHE_NUMBERS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
