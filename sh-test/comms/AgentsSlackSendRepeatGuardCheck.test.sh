#!/usr/bin/env bash
## A run that sends the same first line to the same place twice within 30 minutes is refused the second time, with a reason that says a repeat is a loop,
## and nothing reaches Slack for it. The same send with --again goes through. A different first line goes through. A call with no session is not judged.
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
rigTmp="$( rigTempDir AgentsSlackSendRepeatGuardCheck )" || exit 1
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
	env -i ${2:+MDAT_SPAWN_SESSION_ID=$2} HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
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

## The run keeps its recent sends in its own session folder, which a real run has and the rig makes.
mkdir -p "$rigWs/.local/agents/sessions/rig-session-1" "$rigWs/.local/agents/sessions/rig-session-2"
echo "-- the first send of a line goes through --"
rigSend "$rigTmp/a" rig-session-1 "Same first line"
LC_ALL=C grep -q 'chat.postMessage' "$rigTmp/scenario/argv.log" 2>/dev/null || rigRefuse "no send reached the fake curl: $( tail -3 "$rigTmp/a" )"
rigAssert "rc 0 and one post reached Slack"                     "$( rigRc "$rigTmp/a" ) $( rigPosts )" "0 1"

echo "-- the same line to the same place again is refused --"
rigSend "$rigTmp/b" rig-session-1 "Same first line"
rigAssert "refused: rc not 0"                                    "$( [ "$( rigRc "$rigTmp/b" )" != 0 ] && printf refused || printf sent )" refused
rigAssert "it says a repeat is a loop"                           "$( LC_ALL=C grep -c 'a repeat is a loop' "$rigTmp/b" || : )" 1
rigAssert "it names --again"                                     "$( LC_ALL=C grep -c -e '--again' "$rigTmp/b" || : )" 1
rigAssert "nothing more reached Slack"                           "$( rigPosts )" 1

echo "-- --again lets the repeat through --"
rigSend "$rigTmp/c" rig-session-1 "Same first line" --again
rigAssert "rc 0 and a second post reached Slack"                 "$( rigRc "$rigTmp/c" ) $( rigPosts )" "0 2"

echo "-- a different first line, another session, and no session are not judged --"
rigSend "$rigTmp/d" rig-session-1 "Another first line"
rigAssert "a different first line goes through"                  "$( rigRc "$rigTmp/d" ) $( rigPosts )" "0 3"
rigSend "$rigTmp/e" rig-session-2 "Same first line"
rigAssert "the same line from another session goes through"      "$( rigRc "$rigTmp/e" ) $( rigPosts )" "0 4"
rigSend "$rigTmp/f" "" "Same first line"
rigSend "$rigTmp/g" "" "Same first line"
rigAssert "a call with no session is not judged, twice"          "$( rigRc "$rigTmp/f" ) $( rigRc "$rigTmp/g" ) $( rigPosts )" "0 0 6"

echo "-- the run keeps its last fifty sends --"
rigRecent="$rigWs/.local/agents/sessions/rig-session-1/sent.recent"
rigAssert "sent.recent of the run holds its sends, three columns each" "$( LC_ALL=C awk -F'\t' 'NF != 3 { bad++ } END { print NR " " bad + 0 }' "$rigRecent" )" "2 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK SEND REPEAT GUARD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_SEND_REPEAT_GUARD: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
