#!/usr/bin/env bash
## Behavioural check on S27.3: a handback left without a verdict past the review limit is a problem
## the rig supervisor's own scan finds, from outside, by listing and checking. Until `supervised`
## runs, the root coordinator's scan finds it.
## Red before S27.3: a review item past the limit raised nothing, and its reviewer was told nothing.
## Offline: a Slack-shaped fake curl logs each post and opens no socket; the workspace and board are
## this rig's own temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"
rigHouse="$rigPkg/sh-lib/magic/AgentsTools.SpawnHousekeeping.include"
rigFixture="$rigPkg/sh-test/check-fixtures/harness-ask-check.curl.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHouse" ] || rigRefuse "the spawn housekeeping include is not at the origin: $rigHouse"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsUnseenHandbackCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigData/board/review" "$rigData/board/running" "$rigData/board/processed" "$rigTmp/bin"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nREVIEW_WAIT_LIMIT=60\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf '{"ok":true,"messages":[{"ts":"1700000002.000100","user":"URIGBOT01","text":"opened"}],"has_more":false}\n' > "$rigTmp/replies.json"
for rigMember in magic-coordinator magic-tester keeper-myx ; do
	mkdir -p "$rigWs/.local/agents/members/$rigMember"
	printf -- '---\nname: %s\n---\nrig member\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
done
## The mention cache the member send reads, keyed by the same lock generation it computes.
rigCache="$rigWs/.local/.agents/slack-mention-ids.cache"
{ LC_ALL=C cat "$rigData/inboxes/magic-coordinator/note-20260809T154715Z-advance-state-and-lock.md" \
	"$rigData/inboxes/magic-coordinator/note-20260809T155000Z-heartbeat-state-and-lock.md" 2> /dev/null | cksum
  printf 'magic-tester=URIGTEST1\nmagic-coordinator=URIGCOORD1\nkeeper-myx=URIGKEEP1\n'
} > "$rigCache"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigItem(){ ## item stem, review-by, review-since-epoch
	printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-review\nreview-by: %s\nreview-since-epoch: %s\n---\n\n# rig dispatch\n\n## Decisions\n\n' \
		"$2" "$3" > "$rigData/board/review/$1.md"
}
rigScan(){ ## the scan the advance pass runs, as one call
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" MDAT_SPAWN_AGENT=magic-coordinator \
		bash -c '. "$1" ; AgentsToolsReviewUnseenEscalate magic-coordinator' rig "$rigHouse" 2>&1
}

echo "-- 1. a handback past the limit is raised to the reviewer that should have read it (S27.3) --"
rigNow="$( date +%s )"
rigItem dispatch-20261102T0030Z-unseen magic-tester "$(( rigNow - 600 ))"
: > "$rigTmp/curl.log"
rigOut="$( rigScan )"
rigAssert "the scan raises it, once"                   "$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'REVIEW-UNSEEN: dispatch-20261102T0030Z-unseen.md waited' )" 1
rigAssert "the line names the reviewer told"           "$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'told to magic-tester' )" 1
rigAssert "the reviewer was sent one message"          "$( LC_ALL=C awk 'index( $0, "chat.postMessage" ) { found++ } END { print found + 0 }' "$rigTmp/curl.log" )" 1
rigAssert "the item stays in review"                   "$( [ -f "$rigData/board/review/dispatch-20261102T0030Z-unseen.md" ] && printf review || printf moved )" review

echo "-- 2. a control: a handback inside the limit is left alone, and a raised one is not raised twice --"
rigItem dispatch-20261102T0030Z-fresh magic-tester "$rigNow"
: > "$rigTmp/curl.log"
rigOut2="$( rigScan )"
rigAssert "the fresh handback raises nothing"          "$( printf '%s' "$rigOut2" | LC_ALL=C grep -c 'REVIEW-UNSEEN: dispatch-20261102T0030Z-fresh' )" 0
rigAssert "the raised one is not raised again"         "$( printf '%s' "$rigOut2" | LC_ALL=C grep -c 'REVIEW-UNSEEN: dispatch-20261102T0030Z-unseen' )" 0
rigAssert "and nothing more was sent"                  "$( LC_ALL=C awk 'index( $0, "chat.postMessage" ) { found++ } END { print found + 0 }' "$rigTmp/curl.log" )" 0

echo "-- 3. an item whose reviewer is a person is raised to the coordinator --"
rigItem dispatch-20261102T0030Z-person human-owner "$(( rigNow - 600 ))"
: > "$rigTmp/curl.log"
rigOut3="$( rigScan )"
rigAssert "it is raised to magic-coordinator"          "$( printf '%s' "$rigOut3" | LC_ALL=C grep -c 'REVIEW-UNSEEN: dispatch-20261102T0030Z-person.md waited .* told to magic-coordinator' )" 1

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ UNSEEN HANDBACK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'UNSEEN_HANDBACK: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
