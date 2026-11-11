#!/usr/bin/env bash
## In a one-to-one direct message an account the caller names as the addressee must be the other party of that conversation (a reply to one person went
## out headed for another). The refusal posts nothing and names the right account. The right account, no address at all, and a team member's name go through.
## Temp workspace only, a fake curl of this check's own that answers conversations.info as a direct message with one other party. Nothing leaves the machine.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackDmAddresseeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/magic-team" "$rigTmp/scenario"
cat > "$rigTmp/bin/curl" <<'STUB'
#!/bin/sh
## The fake curl of this check: it logs the method it was asked for and answers the three the send makes.
for a in "$@" ; do case "$a" in https://slack.com/api/*) m="${a#https://slack.com/api/}" ;; esac ; done
printf '%s
' "$m" >> "$RIG_SCENARIO/calls.log"
case "$m" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}
' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"DRIGJULIA1","is_im":true,"is_mpim":false,"user":"URIGJULIA1"}}
' ;;
	conversations.replies|conversations.history) printf '{"ok":true,"messages":[{"ts":"1700000000.000001","user":"URIGJULIA1","text":"hi"}],"has_more":false}\n' ;;
	chat.postMessage) printf '{"ok":true,"channel":"DRIGJULIA1","ts":"1.000001","message":{"ts":"1.000001","user":"URIGBOT01"}}
' ;;
	*) printf '{"ok":true}
' ;;
esac
STUB
chmod +x "$rigTmp/bin/curl"
rigSentinel="rig-sentinel-$$-TOKEN"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=%s\n' "$rigSentinel" > "$rigWs/.local/.agents/magic-team.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSend(){ ## result file, session id (empty: none), body, [extra option]
	env -i ${2:+MDAT_SPAWN_SESSION_ID=$2} MDAT_SEND_FLOOR="${rigFloor:-}" HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		RIG_SCENARIO="$rigTmp/scenario" RIG_WS="$rigWs" RIG_MODE=ok RIG_SENTINEL="$rigSentinel" RIG_SENTINEL_B64=none RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_BODY="$3" RIG_OPT="${4:-}" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --slack-send-message --team-member magic-team magic-team --identity-bot ${RIG_OPT:+"$RIG_OPT"} "$RIG_BODY"
		' > "$1" 2>&1
	printf '%s' "$?" > "$1.rc"
}
rigPosts(){ LC_ALL=C grep -c 'chat.postMessage' "$rigTmp/scenario/argv.log" 2>/dev/null || :; }
rigRc(){ cat "$1.rc"; }

rigFloor=hold
## rigSend takes a body and an --address-to word through RIG_OPT, the channel being the direct message.
## The other party is a person outside the team, so the send also asks that the person be a known contact (the outside-person rule): the rig
## holds a contact record of URIGJULIA1 in its own data root. Its one message in the fake thread is the last word, so one reply is due.
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-contacts.include.sh" || exit 1
rigContactSeed "$rigTmp/data" magic-team julia URIGJULIA1 - || exit 1
rigDm(){ ## result file, the address-to word (may be empty)
	printf '%s' 'Спасибо, сообщение получено.' | ( cd "$rigWs" && env -i MDAT_SEND_FLOOR="hold" HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" RIG_SCENARIO="$rigTmp/scenario" \
		bash "$rigFn" --slack-send-message --team-member magic-team DRIGJULIA1:1700000000.000001 --identity-bot ${2:+--address-to "$2"} --from-stdin ) > "$1" 2>&1
	printf '%s' "$?" > "$1.rc"
}
rigCount(){ LC_ALL=C grep -c '^chat.postMessage$' "$rigTmp/scenario/calls.log" 2> /dev/null || :; }
rigDm "$rigTmp/a" URIGLENA001
rigAssert "an account that is not the other party: posted, addressed to the other party instead, and the send says so" "$( cat "$rigTmp/a.rc" ) $( LC_ALL=C grep -c 'addressed to that party in place of URIGLENA001' "$rigTmp/a" ) $( rigCount )" "0 1 1"
rigAssert "the swapped header names the party, never the account the caller gave" "$( LC_ALL=C grep -c 'URIGLENA001' "$rigTmp/scenario/calls.log" 2> /dev/null || : )" "0"
rigDm "$rigTmp/b" URIGJULIA1
rigAssert "the other party itself: posted" "$( cat "$rigTmp/b.rc" ) $( rigCount )" "0 2"
rigDm "$rigTmp/c" ""
rigAssert "no address at all: posted, the other party inferred" "$( cat "$rigTmp/c.rc" ) $( rigCount )" "0 3"
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK DM ADDRESSEE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_DM_ADDRESSEE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
