#!/usr/bin/env bash
## Behavioural check on S6.26: an accepted run reads as accepted.
## An accept ends the run it settles and closes its record as succeeded. The run's supervising shell
## closes that record afterwards, as it always does, and must not overwrite a record that has settled.
## And an accept is no provider refusal: the run's store gains no usage-limit flag for it, and the line
## the tooling posts about the end never says the run stopped on a provider refusal.
## Red before S6.26: the second close rewrote the status to `spawn-failed`, and the accept's end reason was
## turned into `stopped by a provider refusal: the accept of ...` in the run's store and in the session thread.
## Offline: a Slack-shaped fake curl logs each post and opens no socket; the workspace and the board are
## this rig's own temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"
rigSandbox="$rigPkg/sh-lib/session/AgentsTools.SpawnSandbox.include"
rigFixture="$rigPkg/sh-test/check-fixtures/harness-ask-check.curl.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSandbox" ] || rigRefuse "the spawn sandbox include is not at the origin: $rigSandbox"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsAcceptReadsAcceptedCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
rigSessions="$rigWs/.local/agents/sessions"
mkdir -p "$rigWs/.local/.agents" "$rigSessions" "$rigSpawned" "$rigTmp/bin" "$rigTmp/data/board/processed"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigTmp/replies.json"
for rigName in magic-coordinator keeper-myx ; do
	mkdir -p "$rigWs/.local/agents/members/$rigName"
	printf -- '---\nname: %s\n---\nrig member\n' "$rigName" > "$rigWs/.local/agents/members/$rigName/SKILL.md"
done
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
rigHeader(){ ## record path, header
	LC_ALL=C sed -n "s/^$2: //p" "$1" 2> /dev/null | head -1
}
rigInRig(){ ## the function, then its arguments
	local rigFn="$1"
	shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" MDAT_SPAWN_AGENT=magic-coordinator \
		bash -c '. "$1" ; shift ; "$@"' rig "$rigSandbox" "$rigFn" "$@" 2>&1
}
rigClose(){ ## record path, outcome, exit code, end reason
	rigInRig AgentsToolsSpawnProxyCloseSandbox "$@"
}
rigNotice(){ ## record path
	rigInRig AgentsToolsSpawnProxyEndNotice "$1"
}
rigState(){ ## record path, header, or `none`
	LC_ALL=C sed -n "s/^$2: //p" "$1" 2> /dev/null | head -1
}
rigRunRecord(){ ## run id, session thread, the reports-to address, the dispatch item (may be empty)
	mkdir -p "$rigSpawned/$1" "$rigSessions/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: spawn-started\nreports-to: %s\nsession-thread: %s\n%sspawns: %s\n---\n' \
		"$1" "$1" "$1" "$rigHost" "$3" "$2" "" "${4:-rig-item}" > "$rigSpawned/$1/$1.spawn.md"
}
rigNoticedText(){ ## every line of the thread the fake curl kept, one text
	LC_ALL=C cat "$rigTmp"/post.* 2> /dev/null || :
}

echo "-- 1. an accept closes the run it settles --"
rigThread="CACC00001:1700000000.000300"
rigItem="dispatch-20261103T0900Z-acc"
rigRun="rig-acc-$$"
rigRunRecord "$rigRun" "$rigThread" "$rigThread" "$rigItem"
printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\nspawn-id: %s\n---\n\n# rig dispatch\n\n## Decisions\n\n' \
	"$rigRun" > "$rigTmp/data/board/processed/$rigItem.md"
: > "$rigTmp/curl.log" ; rm -f "$rigTmp"/post.*
rigOut="$( rigClose "$rigSpawned/$rigRun/$rigRun.spawn.md" succeeded unknown "the accept of $rigItem by magic-coordinator" )"
rigAssert "the accept's close settles the record"      "$( rigState "$rigSpawned/$rigRun/$rigRun.spawn.md" status )" "spawn-succeeded"
rigAssert "and names the accept as its end reason"     "$( rigState "$rigSpawned/$rigRun/$rigRun.spawn.md" end-reason )" "the accept of $rigItem by magic-coordinator"

echo "-- 2. the run's own shell closes it afterwards, and a settled record is left as it is --"
rigOut="$( rigClose "$rigSpawned/$rigRun/$rigRun.spawn.md" failed 143 )"
rigAssert "the status stays the accept's"              "$( rigState "$rigSpawned/$rigRun/$rigRun.spawn.md" status )" "spawn-succeeded"
rigAssert "the exit code stays the accept's"           "$( rigState "$rigSpawned/$rigRun/$rigRun.spawn.md" exit-code )" "unknown"
rigAssert "and the end reason is not replaced"         "$( rigState "$rigSpawned/$rigRun/$rigRun.spawn.md" end-reason )" "the accept of $rigItem by magic-coordinator"
rigAssert "the second close says it left it alone"      "$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'is already settled as spawn-succeeded' )" "1"

echo "-- 3. an accept is no provider refusal --"
rigAssert "the run's store holds no provider flag"     "$( [ -f "$rigSessions/$rigRun/usage-limit" ] && cat "$rigSessions/$rigRun/usage-limit" || printf 'none' )" "none"
: > "$rigTmp/curl.log" ; rm -f "$rigTmp"/post.*
rigOut="$( rigNotice "$rigSpawned/$rigRun/$rigRun.spawn.md" )"
rigAssert "the end of the run was told in its session thread" "$( LC_ALL=C grep -c '^chat.postMessage' "$rigTmp/curl.log" )" "1"
rigAssert "and says nothing of a provider refusal"     "$( printf '%s' "$( rigNoticedText )" | LC_ALL=C grep -c 'provider refusal' )" "0"

echo "-- 4. a control: a refusal the harness kept is still flagged, and still ends the run as failed --"
rigRun2="rig-ref-$$"
rigRunRecord "$rigRun2" "CREF00001:1700000000.000400" "CREF00001:1700000000.000400" ""
printf 'rate_limit_error: slow down, too many requests\n' > "$rigSpawned/$rigRun2/$rigRun2.refused"
: > "$rigTmp/curl.log" ; rm -f "$rigTmp"/post.*
rigOut="$( rigClose "$rigSpawned/$rigRun2/$rigRun2.spawn.md" failed 1 )"
rigAssert "a refused run closes as failed"             "$( rigState "$rigSpawned/$rigRun2/$rigRun2.spawn.md" status )" "spawn-failed"
rigAssert "and its store is flagged with the refusal"  "$( [ -f "$rigSessions/$rigRun2/usage-limit" ] && LC_ALL=C head -1 "$rigSessions/$rigRun2/usage-limit" || printf 'none' )" \
	"stopped by a provider refusal: rate_limit_error: slow down, too many requests"
rigOut="$( rigNotice "$rigSpawned/$rigRun2/$rigRun2.spawn.md" )"
rigAssert "and the end notice says it stopped on one"  "$( printf '%s' "$( rigNoticedText )" | LC_ALL=C grep -c 'provider refusal' )" "1"

echo "-- 5. a run that went on after a refusal is not refused at its close --"
## A context refusal is kept beside the record, and the harness goes on with a summarise round. A run that ends
## later, by its own hand or by an accept, must not carry that stale marker into its ending.
rigRun3="rig-rec-$$"
rigRunRecord "$rigRun3" "CREC00001:1700000000.000500" "CREC00001:1700000000.000500" ""
printf 'rig-host refused the request -- invalid_request_error: this model has a maximum context length of 1000000 tokens\n' > "$rigSpawned/$rigRun3/$rigRun3.refused"
printf '1 664576 2026-11-03T10:00:00Z\n' > "$rigSpawned/$rigRun3/$rigRun3.restarts"
: > "$rigTmp/curl.log" ; rm -f "$rigTmp"/post.*
rigOut="$( rigClose "$rigSpawned/$rigRun3/$rigRun3.spawn.md" succeeded 0 "the accept of rig-item by magic-coordinator" )"
rigAssert "the run that went on closes as succeeded"   "$( rigState "$rigSpawned/$rigRun3/$rigRun3.spawn.md" status )" "spawn-succeeded"
rigAssert "its store holds no provider flag"           "$( [ -f "$rigSessions/$rigRun3/usage-limit" ] && cat "$rigSessions/$rigRun3/usage-limit" || printf 'none' )" "none"
rigAssert "its end reason is the caller's, not the stale refusal" "$( rigState "$rigSpawned/$rigRun3/$rigRun3.spawn.md" end-reason )" "the accept of rig-item by magic-coordinator"
rigOut="$( rigNotice "$rigSpawned/$rigRun3/$rigRun3.spawn.md" )"
rigAssert "and the end notice says nothing of a refusal" "$( printf '%s' "$( rigNoticedText )" | LC_ALL=C grep -c 'provider refusal' )" "0"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ ACCEPT READS ACCEPTED CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'ACCEPT_READS_ACCEPTED: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
