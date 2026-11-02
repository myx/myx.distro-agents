#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on ONE cached read path for the Slack read and the team channel's fan-out (S21's
## second unnumbered item, sketch 7.4): a Slack read of a conversation asks Slack once, and the next read
## of the same conversation inside the cache's TTL is served from the cache with no call to Slack at all.
## The `human-owner` fan-out is a read of its own, out of this check's reach with a fake curl.
## (AgentsTools.MemberCommsSlack.include --slack-read; AgentsTools.CommsCache.include)
##   1. THE CONTROL: a read with an empty cache reaches Slack, and the next read inside the TTL does not.
##   2. The second read returns the same messages as the first, so it is a cache and not an empty answer.
##   3. A read past the TTL reaches Slack again, so the cache is not a lie.
## Offline: a Slack-shaped fake curl first on PATH, which counts every call it answers.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTools="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTools"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackReadOneCachePathCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScn="$rigTmp/scn"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigScn" "$rigTmp/skills/keeper-rig"
printf 'keeper-rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
printf 'keeper-rig=URIGMEM01=m=M=M=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"

## A Slack-shaped fake curl of this check's own: it answers a conversation read with three messages and
## counts every call in $rigScn/calls, so a served-from-cache read is told by the count not moving.
cat > "$rigTmp/bin/curl" <<'FAKE'
#!/usr/bin/env bash
rigAuth="$( LC_ALL=C sed -n 's/^Authorization: Bearer //p' | head -1 )"
rigMethod="" rigUrl=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
	esac
done
printf '%s\n' "$rigMethod" >> "$RIG_SCN/calls"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"user_id":"URIGSELF1"}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n' ;;
	conversations.history)
		printf '{"ok":true,"messages":[{"ts":"1793600000.000001","user":"URIGOTHER","text":"RIG-FIRST"},{"ts":"1793600000.000002","user":"URIGOTHER","text":"RIG-SECOND"},{"ts":"1793600000.000003","user":"URIGOTHER","text":"RIG-THIRD"}],"has_more":false,"response_metadata":{"next_cursor":""}}\n'
	;;
	conversations.list) printf '{"ok":true,"channels":[],"response_metadata":{"next_cursor":""}}\n' ;;
	conversations.replies) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
FAKE
chmod +x "$rigTmp/bin/curl"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## How many calls the fake curl has answered so far.
rigCalls(){ LC_ALL=C wc -l < "$rigScn/calls" 2> /dev/null | LC_ALL=C tr -d ' ' ; }
## One --slack-read, its own cache, and the fake curl first on PATH.
rigRead(){ ## target -- the read's output
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_DATA_ROOT=$rigScn/data" "RIG_SCN=$rigScn" "MDAT_SPAWN_AGENT=keeper-rig" "MDAT_SESSION_ID=rig-session" \
		bash "$rigTools" --slack-read keeper-rig "$1" ) 2> /dev/null
}

echo "-- 1. the control: one read asks Slack, the next does not --"
rigRead CRIG00001 > "$rigTmp/read1.txt"
rigAfterFirst="$( rigCalls )"
rigRead CRIG00001 > "$rigTmp/read2.txt"
rigAssert "the first read reached Slack" "$( [ "${rigAfterFirst:-0}" -ge 1 ] && printf asked || printf no-call )" "asked"
rigAssert "the second read inside the TTL asked Slack nothing" "$( rigCalls )" "$rigAfterFirst"

echo "-- 2. the second read is what the first returned, not an empty answer --"
rigAssert "both reads hold the same messages" "$( LC_ALL=C grep -c -F -e 'RIG-FIRST' -e 'RIG-SECOND' -e 'RIG-THIRD' "$rigTmp/read1.txt" ):$( LC_ALL=C grep -c -F -e 'RIG-FIRST' -e 'RIG-SECOND' -e 'RIG-THIRD' "$rigTmp/read2.txt" )" "3:3"

echo "-- 3. a read past the TTL asks again --"
## The cache's own state file carries the moment it was filled: push it back past the TTL.
rigStateFile="$( LC_ALL=C find "$rigWs/.local/cache/comms" -name '.state.txt' 2> /dev/null | head -1 )"
rigAssert "the cache keeps its own state file for the conversation" "$( [ -n "$rigStateFile" ] && printf there || printf absent )" "there"
[ -z "$rigStateFile" ] || printf '%s %s\n' "$(( $( date +%s ) - 100000 ))" "$(( $( date +%s ) - 100000 ))" > "$rigStateFile"
rigRead CRIG00001 > /dev/null
rigAssert "a read past the TTL reaches Slack again" "$( [ "$( rigCalls )" -gt "$rigAfterFirst" ] && printf asked || printf served-old )" "asked"

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'SLACK_READ_ONE_CACHE_PATH: OK\n'
