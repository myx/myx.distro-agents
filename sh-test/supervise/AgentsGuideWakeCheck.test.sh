#!/usr/bin/env bash
## Behavioural check on THE WAKE A SUPERVISOR'S GUIDE CAUSES: a guide posted into a run's own session thread is read
## by that run now, not at the end of its wait's backoff.
##
## The owner reported a run left unread for minutes after a coordinator's message. Measured on the live rig at
## 2026-11-26 02:00 +0200: `--supervise-guide` to a waiting run wrote the message into its chat file and posted it,
## the run's wake marker was not written, and the run sat in its 600 s wait; a plain poke of its wait woke it in
## 18 ms. The copy is the run's mail and its session record names the run's member, so the guide's send wakes that
## member: the wait reads its thread at its next tick, and the ten-minute backoff is no longer the guide's latency.
##
## Held:
##   1. the guide is posted into the run's own thread, as the operation reports it
##   2. the run's member wake marker is written, and the instant it names is now
##   3. control: a second run, in the same workspace and not guided, has no marker touched -- the wake is the
##      guide's own and not the workspace writing every member's
## Offline: a Slack-shaped fake curl first on PATH, a rig workspace under this check's temp tree, no socket opened.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPkg="${rigHere%/sh-lib}"
rigFn="$rigPkg/sh-scripts/AgentDispatcherTools.fn.sh"
rigTest="$rigPkg/sh-test"
rigMember="rig-woken"
rigOther="rig-other"
rigSender="magic-coordinator"
rigRun="rig-guide-run-1"
rigRunOther="rig-guide-run-2"
rigChannel="CRIG00001"
rigThread="$rigChannel:1793000010.000100"
rigThreadOther="$rigChannel:1793000010.000200"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigFn"
[ -f "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" ] || rigRefuse "the fake curl fixture is missing from the package"
[ -f "$rigTest/check-fixtures/rig-owner-writes.include.sh" ] || rigRefuse "the store-writer fixture is missing from the package"

rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsGuideWakeCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/skills/$rigSender" "$rigTmp/skills/$rigMember" "$rigTmp/skills/$rigOther" || exit 1
printf '%s\n' "$rigSender" > "$rigTmp/skills/$rigSender/$rigSender.basic.md"
printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf '%s\n' "$rigOther" > "$rigTmp/skills/$rigOther/$rigOther.basic.md"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl could not be copied"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}

## The rig's workspace, data root and Slack-shaped stores: the team's env, the sender's, the addressee's account.
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigScen="$rigTmp/slack"
mkdir -p "$rigWs/.local/.agents" "$rigData" "$rigScen" || exit 1
printf 'SLACK_CHANNEL_MAGIC_TEAM=%s\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' "$rigChannel" \
	> "$rigWs/.local/.agents/magic-team.agent.env"
## The addressee HAS an account of its own: the live defect is that the wake was keyed on members without one
## (addressedMembers), so an addressee holding a Slack id woke nobody. Measured on the live rig at 02:20 +0200.
mkdir -p "$rigWs/.local/agents/cache" || exit 1
rigGen="$( LC_ALL=C cat "$rigData/inboxes/magic-coordinator/note-20260809T154715Z-advance-state-and-lock.md" "$rigData/inboxes/magic-coordinator/note-20260809T155000Z-heartbeat-state-and-lock.md" 2>/dev/null | cksum )"
printf '%s\n' "$rigGen" > "$rigWs/.local/agents/cache/slack-identities.cache"
printf '%s=URIGSELF1=test-er=Test Er=test-er=rig.example\n' "$rigMember" >> "$rigWs/.local/agents/cache/slack-identities.cache"
RIG_CURL_LOG="$rigScen/curl.log"
RIG_SCENARIO="$rigScen"
export RIG_CURL_LOG RIG_SCENARIO
: > "$RIG_CURL_LOG"

## The two runs, written by the store's own writers: the guided one and the control.
rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigTmp/skills"
rigOwnerLog="$rigTmp/owner.log"
. "$rigTest/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerThread="$rigThread"
rigOwnerSpawnPut "$rigRun" <<EOF || rigRefuse "the guided run's record could not be written"
---
spawn-id: $rigRun
session-id: $rigRun
owner: $rigMember
session-thread: $rigThread
status: spawn-started
reports-to: $rigSender
---
EOF
rigOwnerSessionThreadSet "$rigRun" "$rigThread" || rigRefuse "the guided run's session thread could not be written"
## The run spawned a member of its own, and that child's record is the NEWEST in the same folder. The wake is the
## SESSION's own member, never the child: measured on the live rig at 02:24 +0200, where the newest record named
## magic-developer and the session's own member was magic-coordinator.
rigOwnerThread="$rigThread"
rigOwnerSpawnPut "rig-child-run" <<EOF || rigRefuse "the child run's record could not be written"
---
spawn-id: rig-child-run
session-id: $rigRun
owner: $rigOther
session-thread: $rigThread
status: spawn-started
---
EOF
mkdir -p "$rigWs/.local/agents/spawned/$rigRun" || exit 1
mv -f "$rigWs/.local/agents/spawned/rig-child-run/rig-child-run.spawn.md" "$rigWs/.local/agents/spawned/$rigRun/rig-child-run.spawn.md" 2>/dev/null || :
rmdir "$rigWs/.local/agents/spawned/rig-child-run" 2>/dev/null || :
rigOwnerThread="$rigThreadOther"
rigOwnerSpawnPut "$rigRunOther" <<EOF || rigRefuse "the control run's record could not be written"
---
spawn-id: $rigRunOther
session-id: $rigRunOther
owner: $rigOther
session-thread: $rigThreadOther
status: spawn-started
reports-to: $rigSender
---
EOF
rigOwnerSessionThreadSet "$rigRunOther" "$rigThreadOther" || rigRefuse "the control run's session thread could not be written"

## The guide, through the real operation, as the coordinator posts it.
( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID \
	MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
	MDAT_SPAWN_AGENT="$rigSender" \
	bash "$rigFn" --supervise-guide "$rigRun" --text "RIG guidance to the run" ) \
	> "$rigScen/guide.out" 2> "$rigScen/guide.err"

rigMarkerOf(){ printf '%s' "$rigWs/.local/agents/wake/$1" ; }
rigMarkerAt(){ ## member -- the instant its marker names, or nothing
	[ -f "$( rigMarkerOf "$1" )" ] || return 0
	LC_ALL=C awk 'NR == 1 { print $1 ; }' "$( rigMarkerOf "$1" )" 2> /dev/null
}

rigAssert "the guide was posted into the run's own thread"  "$( rigHolds "$rigScen/guide.out" "guide	$rigRun	$rigMember	$rigThread" )" "yes"
rigAssert "the run's member wake marker is written"        "$( [ -f "$( rigMarkerOf "$rigMember" )" ] && printf marker-written || printf no-marker )" "marker-written"
rigMarkerNow="$( rigMarkerAt "$rigMember" )"
case "$rigMarkerNow" in ''|*[!0-9]*) rigMarkerNow=0 ;; esac
rigAssert "and it names now, so the wake is this guide's"  "$( [ $(( $( date +%s ) - rigMarkerNow )) -le 120 ] && printf this-call || printf not-this-call )" "this-call"
rigAssert "the wake is the session's own member, not its child's" "$( [ -f "$( rigMarkerOf "$rigOther" )" ] && printf child-woken || printf session-own )" "session-own"
rigAssert "control: the run that was not guided has no marker" "$( [ -f "$( rigMarkerOf "$rigOther" )" ] && printf marker-written || printf no-marker )" "no-marker"

echo
if [ "$rigFailCount" = "0" ] ; then
	printf 'OK: %s assertion(s); the guide woke %s through %s\n' "$rigPassCount" "$rigMember" "$( rigMarkerOf "$rigMember" )"
	exit 0
fi
printf '⛔ GUIDE WAKE CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))"
exit 1
