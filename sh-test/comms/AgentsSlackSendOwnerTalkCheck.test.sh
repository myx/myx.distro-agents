#!/usr/bin/env bash
## A member's own message to a channel that talks of the human-owner (names him, or what he said, wrote, asked or ruled) is refused with a reason, and nothing
## reaches Slack for it. A message that does not talk of him goes through.
## Temp workspace only, the credential exposure rig's fake curl first on PATH, under one `env -i` guard. Nothing leaves the machine.
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
rigTmp="$( rigTempDir AgentsSlackSendOwnerTalkCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/magic-team" "$rigTmp/scenario"
cp "$rigTest/check-fixtures/credential-exposure-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
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

rigFloor=hold ## the member stub sets it on every member send
echo "-- a plain message goes through --"
rigSend "$rigTmp/a" "" "The call-path sweep is done and the checks pass."
LC_ALL=C grep -q 'chat.postMessage' "$rigTmp/scenario/argv.log" 2>/dev/null || rigRefuse "no send reached the fake curl: $( tail -3 "$rigTmp/a" )"
rigAssert "rc 0 and one post reached Slack" "$( rigRc "$rigTmp/a" ) $( rigPosts )" "0 1"

echo "-- a message that talks of him is refused --"
n=1
for rigBody in "Tick record, and the human-owner has asked for less traffic." "He wrote at 20:54 slow down." "Human owner said stop." "His ruling is in the record." "He asked for one line." ; do
	n=$(( n + 1 ))
	rigSend "$rigTmp/r$n" "" "$rigBody"
	rigAssert "refused, says so, posts nothing: $rigBody" "$( [ "$( rigRc "$rigTmp/r$n" )" != 0 ] && printf refused || printf sent ) $( LC_ALL=C grep -c 'never who said what' "$rigTmp/r$n" || : ) $( rigPosts )" "refused 1 1"
done

echo "-- words that only look alike go through --"
rigSend "$rigTmp/s1" "" "The whole record was written by the tool and she wrote nothing."
rigAssert "no talk of him: sent" "$( rigRc "$rigTmp/s1" ) $( rigPosts )" "0 2"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK SEND OWNER TALK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_SEND_OWNER_TALK: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
