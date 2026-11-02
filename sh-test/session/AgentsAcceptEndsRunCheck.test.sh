#!/usr/bin/env bash
## Behavioural check on S27.1: accepting a handback ends the run it settles. The review's accept
## moves the item and sends the child its DISMISSED; this check holds that the run's own record
## is closed in that same step, so a settled run leaves no record reading started.
## Red before S27.1: the record still says `status: spawn-started` after the accept.
## Offline: a Slack-shaped fake curl answers the accept's sends and opens no socket; the run is a
## stand-in process carrying its own spawn id; the workspace and board are this rig's own temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
rigFixture="$rigPkg/sh-test/check-fixtures/harness-ask-check.curl.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the dispatcher is not at the origin: $rigFn"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsAcceptEndsRunCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap 'for rigOne in $rigPids ; do kill -KILL "$rigOne" 2> /dev/null ; done ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigData/board/review" "$rigData/board/processed" "$rigData/board/running" "$rigWs/.local/.agents" "$rigWs/.local/agents/sessions" "$rigSpawned" "$rigTmp/bin"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf '{"ok":true,"messages":[{"ts":"1700000002.000100","user":"URIGBOT01","text":"session opened"}],"has_more":false}\n' > "$rigTmp/replies.json"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

rigRun(){ ## result file, command...
	local rigOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" \
		bash -c 'cd "$MMDAPP" && exec "$@"' rig "$@" > "$rigOut" 2>&1
	printf '%s' "$?" > "$rigOut.rc"
}
rigStatus(){ ## record path
	LC_ALL=C awk 'NR > 1 && $0 == "---" { exit } NR > 1 { print }' "$1" 2> /dev/null | LC_ALL=C sed -n 's/^status: //p' | head -1
}
rigOutcomeLine(){ ## record path, header
	LC_ALL=C sed -n "s/^$2: //p" "$1" 2> /dev/null | head -1
}

echo "-- 1. an accept closes the run's own record in the same step (S27.1) --"
rigSpawn="rig-acc-run-$$"
mkdir -p "$rigSpawned/$rigSpawn"
printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: spawn-started\nsession-thread: CACC00001:1700000000.000300\nspawns: dispatch-20261101T2300Z-acc\n---\n' \
	"$rigSpawn" "$rigSpawn" "$rigSpawn" "$rigHost" > "$rigSpawned/$rigSpawn/$rigSpawn.spawn.md"
printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\nspawn-id: %s\nreview-by: magic-coordinator\nreview-reason: handback\nreview-since-epoch: %s\n---\n\n# rig dispatch\n\n## Decisions\n\n' \
	"$rigSpawn" "$( date +%s )" > "$rigData/board/review/dispatch-20261101T2300Z-acc.md"
mkdir -p "$rigWs/.local/agents/sessions/$rigSpawn"
: > "$rigTmp/tr-$rigSpawn.log"
printf '%s\n' "$rigTmp/tr-$rigSpawn.log" > "$rigWs/.local/agents/sessions/$rigSpawn/transcript"
python3 -I -B -c 'import time; time.sleep(600)' -- --session-id "$rigSpawn" > /dev/null 2>&1 &
rigPids="$rigPids $!" ; disown "$!" 2> /dev/null || :
sleep 2
rigRun "$rigTmp/acc" bash "$rigFn" --accept-review --team-member magic-coordinator dispatch-20261101T2300Z-acc --summary "good work"
rigAssert "the accept succeeds"                    "$( cat "$rigTmp/acc.rc" )" 0
rigAssert "the item is processed"                  "$( [ -f "$rigData/board/processed/dispatch-20261101T2300Z-acc.md" ] && printf processed || printf elsewhere )" processed
rigAssert "the run's record is no longer started"  "$( rigStatus "$rigSpawned/$rigSpawn/$rigSpawn.spawn.md" )" "spawn-succeeded"
rigAssert "its end-reason names the accept"        "$( rigOutcomeLine "$rigSpawned/$rigSpawn/$rigSpawn.spawn.md" end-reason )" "the accept of dispatch-20261101T2300Z-acc by magic-coordinator"
rigAssert "the verdict is recorded on the item"    "$( LC_ALL=C grep -c -E '^- [0-9TZ:-]+ [a-z-]+ verdict: accepted: good work' "$rigData/board/processed/dispatch-20261101T2300Z-acc.md" 2> /dev/null || : )" 1
rigAssert "the closing is recorded once"           "$( LC_ALL=C grep -c -E 'dismissed: accept: the run it settles is ended' "$rigData/board/processed/dispatch-20261101T2300Z-acc.md" 2> /dev/null || : )" 1

echo "-- 2. a control: a record that is already closed is left as it is --"
rigSpawn2="rig-acc-done-$$"
mkdir -p "$rigSpawned/$rigSpawn2"
printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: spawn-succeeded\nexit-code: 0\nsession-thread: CACC00002:1700000000.000400\nspawns: dispatch-20261101T2301Z-acc\n---\n' \
	"$rigSpawn2" "$rigSpawn2" "$rigSpawn2" "$rigHost" > "$rigSpawned/$rigSpawn2/$rigSpawn2.spawn.md"
printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\nspawn-id: %s\nreview-by: magic-coordinator\n---\n\n# rig dispatch\n\n## Decisions\n\n' \
	"$rigSpawn2" > "$rigData/board/review/dispatch-20261101T2301Z-acc.md"
rigRun "$rigTmp/acc2" bash "$rigFn" --accept-review --team-member magic-coordinator dispatch-20261101T2301Z-acc --summary "also good"
rigAssert "the accept of an ended run's item succeeds" "$( cat "$rigTmp/acc2.rc" )" 0
rigAssert "its record keeps the status it had"         "$( rigStatus "$rigSpawned/$rigSpawn2/$rigSpawn2.spawn.md" )" "spawn-succeeded"
rigAssert "and gains no second closing"                "$( LC_ALL=C grep -c -E 'dismissed: accept: the run it settles is ended' "$rigData/board/processed/dispatch-20261101T2301Z-acc.md" 2> /dev/null || : )" 0

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ ACCEPT ENDS RUN CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'ACCEPT_ENDS_RUN: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
