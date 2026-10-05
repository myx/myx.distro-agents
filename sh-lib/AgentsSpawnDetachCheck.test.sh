#!/usr/bin/env bash
## Behavioural check on backlog :229's detach half, run rather than read: a spawn made from
## inside a session (MDAT_SPAWN_SESSION_ID set) runs in its own process group, so a kill
## sent to its caller's group -- what the main loop's pass bound sends -- leaves it running,
## and a detached background spawn still records its own close when it ends. The control:
## a spawn with no parent session (the main loop's own pass) stays in its caller's group
## and dies with it, so the pass bound still reaches it. A fake console and a fake curl,
## no model, offline by construction.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsSpawnDetachCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPassPid=""
trap '[ -z "$rigPassPid" ] || kill -KILL -- "-$rigPassPid" 2>/dev/null ; for p in "$rigTmp"/*/console.pid ; do [ -f "$p" ] && kill -KILL "$( cat "$p" )" 2>/dev/null ; done ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin"
cp "$rigHere/check-fixtures/slack-send-identity-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

## The console: records its own pid, runs for RIG_RUN seconds as the "agent", then says so.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER, records its pid, sleeps.' \
	'cat > /dev/null' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'echo $$ > "$RIG_SCENARIO/console.pid"' \
	'sleep "$RIG_RUN"' \
	'echo finished > "$RIG_SCENARIO/console.done"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft="$1" ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigAlive(){ kill -0 "$( cat "$rigDir/console.pid" 2>/dev/null || echo 999999 )" 2>/dev/null && printf alive || printf gone ; }

## One spawn, started as "the pass": its own process group, as the main loop starts one.
## Then that group is ended the way the pass bound ends it: TERM, then KILL.
rigSpawnAndEndPass(){ ## scenario, parent session id or empty, --wait or empty, console seconds
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir"
	set -m
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID ${2:+MDAT_SPAWN_SESSION_ID="$2"} RIG_SCENARIO="$rigDir" RIG_RUN="$4" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --intern-op-agent-spawn-proxy keeper-myx --dispatch-doc:none $3 --context rig-spawn-detach <<< "RIG-BRIEF" > "$rigDir/proxy.out" 2>&1 ) &
	rigPassPid=$!
	set +m
	rigWaitFor 30 test -s "$rigDir/console.pid" || rigRefuse "the fake console never started in scenario $1: $( grep -m1 ERROR "$rigDir/proxy.out" )"
	sleep 1
	{ kill -TERM -- "-$rigPassPid" ; sleep 2 ; kill -KILL -- "-$rigPassPid" ; wait "$rigPassPid" ; } 2>/dev/null
	rigPassPid=""
	sleep 1
}

echo "-- a spawn from inside a session, --wait --"
rigSpawnAndEndPass nested-wait parent-rig-session --wait 6
rigAssert "it survives its caller's pass being ended"   "$( rigAlive )" alive
rigWaitFor 15 test -f "$rigDir/console.done"
rigAssert "and runs to its own end"                      "$( cat "$rigDir/console.done" 2>/dev/null )" finished

echo "-- a spawn from inside a session, background --"
rigSpawnAndEndPass nested-bg parent-rig-session "" 6
rigAssert "it survives its caller's pass being ended"   "$( rigAlive )" alive
rigPostsAtEnd="$( LC_ALL=C grep -c '^chat.postMessage ' "$rigDir/calls" 2>/dev/null || : )"
rigWaitFor 15 test -f "$rigDir/console.done"
rigAssert "and runs to its own end"                      "$( cat "$rigDir/console.done" 2>/dev/null )" finished
rigPostsNow(){ [ "$( LC_ALL=C grep -c '^chat.postMessage ' "$rigDir/calls" 2>/dev/null || : )" -gt "${rigPostsAtEnd:-0}" ] ; }
rigWaitFor 20 rigPostsNow
rigAssert "and records its own close after the pass ended" "$( rigPostsNow && printf yes || printf no )" yes

echo "-- control: the main loop's own pass spawn, no parent session --"
rigSpawnAndEndPass top-wait "" --wait 30
rigAssert "it dies with the pass, so the bound reaches it" "$( rigAlive )" gone
rigAssert "and never reaches its own end"                "$( [ -f "$rigDir/console.done" ] && printf finished || printf no )" no

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SPAWN DETACH CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_DETACH: OK (%d assertions, offline)\n' "$rigPasses"
