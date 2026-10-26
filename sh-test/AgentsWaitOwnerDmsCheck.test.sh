#!/usr/bin/env bash
## Behavioural check: a default Wait reads EVERY direct conversation with the owner the member posts in -- the member's own (user identity) and the team bot's -- so a top-level
## message the owner types in the bot's DM, where every ask of the bot is posted, is returned like one typed in the other. SLACK_CHANNEL_HUMAN_OWNER is a user id; posting resolves
## it per identity (conversations.open), so the two identities have two conversations with him. A fake curl first on PATH answers by token and method; no request leaves the rig.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTools" ] || rigRefuse "DistroAgentsTools.fn.sh not found at the origin this workspace resolves: $rigTools"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to act under"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitOwnerDmsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScenario="$rigTmp/scenario"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigScenario"
cat > "$rigTmp/bin/curl" <<- 'EOF'
	#!/usr/bin/env bash
	set -u
	rigAuth="$( cat )"
	rigMethod="" rigChannel="" rigUsers="" rigTs="" rigName=""
	for rigArg in "$@" ; do
		case "$rigArg" in
			https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
			channel@*) rigChannel="$( cat "${rigArg#channel@}" 2> /dev/null )" ;;
			channel=*) rigChannel="${rigArg#channel=}" ;;
			users=*) rigUsers="${rigArg#users=}" ;;
			users@*) rigUsers="$( cat "${rigArg#users@}" 2> /dev/null )" ;;
			timestamp@*) rigTs="$( cat "${rigArg#timestamp@}" 2> /dev/null )" ;;
			name@*) rigName="$( cat "${rigArg#name@}" 2> /dev/null )" ;;
		esac
	done
	rigWho=user ; case "$rigAuth" in *rig-bot-*) rigWho=bot ;; esac
	printf '%s %s %s %s\n' "$rigMethod" "$rigWho" "$rigChannel" "$rigUsers" >> "$RIG_SCENARIO/calls"
	case "$rigMethod" in
		reactions.add)
			printf '%s %s %s %s\n' "$rigWho" "$rigChannel" "$rigTs" "$rigName" >> "$RIG_SCENARIO/reactions"
			if [ -f "$RIG_SCENARIO/react-fail" ] ; then printf '{"ok":false,"error":"missing_scope"}\n' ; else printf '{"ok":true}\n' ; fi
		;;
		auth.test) printf '{"ok":true,"user_id":"URIG%s"}\n' "$rigWho" ;;
		conversations.open) if [ "$rigWho" = bot ] ; then printf '{"ok":true,"channel":{"id":"DOWNERBOT01"}}\n' ; else printf '{"ok":true,"channel":{"id":"DOWNERUSER1"}}\n' ; fi ;;
		conversations.info) printf '{"ok":true,"channel":{"id":"%s","is_im":true,"user":"URIGOWNER"}}\n' "${rigChannel:-DOWNERUSER1}" ;;
		conversations.history)
			cat "$RIG_SCENARIO/history.$rigChannel.json" 2> /dev/null || printf '{"ok":true,"messages":[],"has_more":false}\n'
		;;
		*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
	esac
EOF
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH" ; export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigWs/.local/.agents/$rigMember.agent.env"
now="$( date +%s )"
printf '{"ok":true,"messages":[{"ts":"%s.000101","user":"URIGOWNER","text":"RIG-IN-USER-DM"}],"has_more":false}\n' "$(( now + 7 ))" > "$rigScenario/history.DOWNERUSER1.json"
printf '{"ok":true,"messages":[{"ts":"%s.000101","user":"URIGOWNER","text":"RIG-IN-BOT-DM"}],"has_more":false}\n' "$(( now + 8 ))" > "$rigScenario/history.DOWNERBOT01.json"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigDefault(){ ## session -- one Wait with no sources
	: > "$rigScenario/calls"
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		RIG_SCENARIO="$rigScenario" MDAT_WAIT_REMIND=off MMDAPP="$rigWs" \
		bash "$rigTools" --wait-for-input "$rigMember" --wait-default --wait-session-id "$1" --wait-timeout 16 --wait-poll-interval 1 ) > "$rigTmp/out" 2> "$rigTmp/err"
}
rigHas(){ LC_ALL=C grep -c -F -- "$1" "$rigTmp/out" || : ; }

echo "-- a default Wait and the two direct conversations with the owner --"
rigDefault rig-owner-dms
rigAssert "a message typed in the member's own DM with the owner is returned" "$( rigHas RIG-IN-USER-DM )" "1"
rigAssert "a message typed in the bot's DM with the owner, where the asks are posted, is returned as well" "$( rigHas RIG-IN-BOT-DM )" "1"
rigAssert "each conversation is named before its messages, so a reply goes back to the one it was read from" "$( LC_ALL=C grep -c -E '^# in DOWNER(USER1|BOT01)' "$rigTmp/out" || : )" "2"
rigAssert "every message a person wrote that the Wait returned got the eyes reaction at once, each in its own conversation, without the agent asking" "$( LC_ALL=C awk '$4 == "eyes" { printf "%s ", $2 }' "$rigScenario/reactions" 2> /dev/null | LC_ALL=C tr ' ' '\n' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "DOWNERBOT01 DOWNERUSER1 "
rigAssert "and no error in the header" "$( LC_ALL=C grep -c '^# ERROR: the seen reaction' "$rigTmp/out" || : )" "0"
rigDefault rig-owner-dms
rigAssert "the next Wait of the session returns neither again" "$( rigHas RIG-IN-USER-DM ) $( rigHas RIG-IN-BOT-DM )" "0 0"

echo "-- a reaction that fails is an error in the header, and the wait goes on --"
: > "$rigScenario/react-fail"
printf '{"ok":true,"messages":[{"ts":"%s.000101","user":"URIGOWNER","text":"RIG-SECOND"}],"has_more":false}\n' "$(( $( date +%s ) + 7 ))" > "$rigScenario/history.DOWNERUSER1.json"
printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigScenario/history.DOWNERBOT01.json"
rigDefault rig-owner-dms
rigAssert "the message is returned, and the header says its seen reaction failed" "$( rigHas RIG-SECOND ) $( LC_ALL=C grep -c '^# ERROR: the seen reaction (eyes) failed on DOWNERUSER1:' "$rigTmp/out" || : )" "1 1"

echo "-- a result that was emitted has its floors committed, whatever becomes of the caller --"
rm -f "$rigScenario/react-fail"
printf '{"ok":true,"messages":[{"ts":"%s.000101","user":"URIGOWNER","text":"RIG-COMMITTED"}],"has_more":false}\n' "$(( $( date +%s ) + 9 ))" > "$rigScenario/history.DOWNERUSER1.json"
( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
	RIG_SCENARIO="$rigScenario" MDAT_WAIT_REMIND=off MMDAPP="$rigWs" \
	bash "$rigTools" --wait-for-input "$rigMember" --wait-default --wait-session-id rig-owner-dms --wait-timeout 20 --wait-poll-interval 1 2> /dev/null | head -1 > "$rigTmp/out.first" )
rigAssert "the caller took the first line of the result and was gone (a client that moved the call away, or interrupted it)" "$( cat "$rigTmp/out.first" )" "WAIT-RESULT: RECEIVED"
rigDefault rig-owner-dms
rigAssert "the next Wait of the session does not return that message again: its floor was committed before the result was said" "$( rigHas RIG-COMMITTED )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ WAIT OWNER DMS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_OWNER_DMS: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
