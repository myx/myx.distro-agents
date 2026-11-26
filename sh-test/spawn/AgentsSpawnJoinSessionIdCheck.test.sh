#!/usr/bin/env bash
## Behavioural check on a joined spawn's identity (sh-lib/spawn/AgentsTools.InternOpAgentSpawnProxy.include): a spawn that joins a
## session keeps that session as the session of the run it starts, and records the run's own new id beside it as the spawn id.
## Held, against the real proxy, in a rig tree whose console runs no model:
##   1. THE JOINED SPAWN KEEPS THE SESSION: its record's session-id is the session it joined.
##   2. AND ITS OWN SPAWN ID IS ANOTHER ONE: the spawn id is not that session id.
##   3. THE CONTROL: a fresh spawn records one id as both, so row 1 is about the join and not about the record writer.
## RED RECIPE, measured live 2026-11-25 23:40 +0200 before the change: the proxy exported a fresh uuid as MDAT_SPAWN_SESSION_ID
## whatever session was named, so a join's record read session-id and spawn-id as one new uuid (a restart of session 00569208
## recorded 8b066c82), and the run it started then wrote to another session than the one addressed.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTool" ] || { echo "⛔ ERROR: no $rigTool" >&2 ; exit 1 ; }
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnJoinSessionIdCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rigSpawnLeftEnd ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-devops" "$rigData/board" "$rigWs/WORK" || exit 1
cp "$rigPackage/sh-test/check-fixtures/spawn-tracking-place.curl.stub.sh" "$rigTmp/bin/curl" || { echo "⛔ ERROR: the fake curl fixture is missing" >&2 ; exit 1 ; }
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || { echo "⛔ ERROR: the fake curl is not first on PATH" >&2 ; exit 1 ; }
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIGTEAM1\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK1\nSLACK_CHANNEL_EVENT_ALERT=CRIGALERT\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
	> "$rigWs/.local/.agents/magic-team.agent.env"
printf -- '---\nname: magic-devops\ndescription: rig member\n---\n' > "$rigSkills/magic-devops/SKILL.md"
printf '# rig armed\n' > "$rigSkills/magic-devops/magic-devops.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-devops/magic-devops.basic.md"
## The console the proxy launches: it names --cli-configured in its own source (the proxy reads that word there before it
## launches), records the session it was given, and hands back at once, so nothing is started and no retry runs.
cat > "$rigWs/DistroAgentsConsole.sh" <<'RIGCONSOLE'
#!/usr/bin/env bash
## --cli-configured stand-in: it writes MDAT_SPAWN_LAUNCH_MARKER and records the session it was given.
cat > "$RIG_SCENARIO/brief"
printf 'rig-cli\n' > "$MDAT_SPAWN_LAUNCH_MARKER"
printf '%s\n' "$MDAT_SPAWN_SESSION_ID" > "$RIG_SCENARIO/last-spawn"
printf '   📦 SubagentHandback rig-outcome\n'
RIGCONSOLE
chmod +x "$rigWs/DistroAgentsConsole.sh"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n        spawn output: %s\n' "$1" "$2" "$3" "$( LC_ALL=C tr '\n' '|' < "$rigTmp/spawn.out" 2> /dev/null | cut -c1-400 )" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSpawnRunning(){ ## -- the pids of this check's own spawn proxies still running, one a line
	ps -A -ww -o pid=,args= 2> /dev/null | LC_ALL=C awk -v self="$$" '$1 != self && /DistroAgentsTools.fn.sh --intern-op-agent-spawn-proxy/ && /--context rig-join-identity/ { print $1 ; }'
}
rigSettle(){
	local settleLeft=450
	while [ "$settleLeft" -gt 0 ] ; do
		if [ -z "$( rigSpawnRunning )" ] ; then return 0 ; fi
		sleep 0.2 ; settleLeft=$(( settleLeft - 1 ))
	done
	return 0
}
rigSpawnLeftEnd(){
	local leftPids="$( rigSpawnRunning )"
	[ -z "$leftPids" ] || rigProcSignalWithChildren KILL $leftPids
	return 0
}
rigSpawn(){ ## extra proxy arguments...
	rm -f "$rigTmp/brief" "$rigTmp/last-spawn" "$rigTmp/spawn.out"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash -c '
			case "$MMDAPP" in "$RIG_SCENARIO"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$0" --intern-op-agent-spawn-proxy magic-devops --dispatch-doc:create --wait --context rig-join-identity "$@"
		' "$rigTool" "$@" <<< "RIG-JOIN-BRIEF" > "$rigTmp/spawn.out" 2>&1 ) || :
	rigSettle
}
rigNewestRecord(){ ## -- the record of the spawn just made: the newest *.spawn.md in the rig's store
	local rec
	rec="$( ls -t "$rigWs"/.local/agents/spawned/*/*.spawn.md 2> /dev/null | head -1 )"
	printf '%s' "$rec"
}
rigField(){ ## record, field
	LC_ALL=C awk -v want="$2" 'NR == 1 && $0 != "---" { exit } $0 == "---" { d++ ; if ( d == 2 ) exit ; next } index( $0, want ": " ) == 1 { print substr( $0, length( want ) + 3 ) ; f = 1 ; exit } END { if ( ! f ) print "-" }' "$1"
}
echo "-- 1. a fresh spawn: one id is both, the control --"
rigSpawn
rigFirst="$( rigNewestRecord )"
rigAssert "it started and wrote a record" "$( [ -n "$rigFirst" ] && echo yes || echo no )" "yes"
rigFirstSession="$( rigField "$rigFirst" session-id )"
rigAssert "a fresh spawn has one id as both" "$( rigField "$rigFirst" spawn-id )" "$rigFirstSession"
echo "-- 2. a joined spawn keeps the session and records its own id --"
rigSpawn --session-id "$rigFirstSession"
rigJoined="$( rigNewestRecord )"
rigAssert "the joined spawn's session is the session it joined" "$( rigField "$rigJoined" session-id )" "$rigFirstSession"
rigAssert "and its own spawn id is another one" "$( [ "$( rigField "$rigJoined" spawn-id )" != "$rigFirstSession" ] && echo yes || echo no )" "yes"
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN JOIN SESSION ID CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SPAWN_JOIN_SESSION_ID: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
