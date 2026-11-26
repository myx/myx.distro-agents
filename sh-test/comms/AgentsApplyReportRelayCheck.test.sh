#!/usr/bin/env bash
## Behavioural check on the relay carrier of the apply-report gate (task-20261117T2241Z): a Slack send that declares
## --text-group relay and says a file was applied is refused unless it gives that file's place path and its
## read-back, and nothing reaches Slack for it. A send that claims no apply goes through, and so does a declared relay
## that names the path and the read-back. Temp workspace only, a fake curl first on PATH, under one `env -i` guard.
## Nothing leaves the machine. Held:
##   1. control: one post reaches the fake curl for an ordinary send
##   2. a relay naming a bare file and a line number is refused, names both faults, and posts nothing
##   3. a relay naming the place path with no read-back is refused, and names only that fault
##   4. a relay naming the path and cksum as its read-back goes through
##   5. a plain send that says fixed is not measured: it goes through
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigTest="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigFn"

. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsApplyReportRelayCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigScenario="$rigTmp/scenario"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/magic-team" "$rigScenario" "$rigData/audit"
printf 'the rig member\n' > "$rigTmp/skills/magic-team/magic-team.basic.md"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
## The member's own user token: a declared group is refused under the shared bot identity alone, and this check is
## about the relay gate rather than that refusal.
rigUserToken="rig-relay-user-token"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSend(){ ## result file, group (empty: none), body
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_WORKSPACE_MODE=team-rig \
		MDAT_DATA_ROOT="$rigData" MDAT_SEND_FLOOR=hold SLACK_USER_TOKEN="$rigUserToken" \
		RIG_SCENARIO="$rigScenario" RIG_CURL_LOG="$rigScenario/curl.log" RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_GROUP="$2" RIG_BODY="$3" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" || exit 99
			set -- --slack-send-message --team-member magic-team CRIGAPPLY01
			[ -z "$RIG_GROUP" ] || set -- "$@" --text-group "$RIG_GROUP"
			exec bash "$RIG_FN" "$@" "$RIG_BODY"
		' > "$1" 2>&1
	printf '%s' "$?" > "$1.rc"
}
rigPosts(){ ls "$rigScenario"/post.* 2>/dev/null | wc -l | tr -d ' ' ; }

echo "-- 1. control: an ordinary send reaches the fake curl --"
rigSend "$rigTmp/a" "" "The call-path sweep is done and the checks pass."
LC_ALL=C grep -q 'chat.postMessage' "$rigScenario/curl.log" 2>/dev/null || rigRefuse "no send reached the fake curl: $( tail -3 "$rigTmp/a" )"
rigAssert "rc 0 and one post reached Slack" "$( cat "$rigTmp/a.rc" ) $( rigPosts )" "0 1"

echo "-- 2. a relay naming a bare file and a line number is refused --"
rigSend "$rigTmp/b" relay "Applied the Show Detail fix in style.css.tpl:1314"
rigAssert "refused with its reason, and no new post" \
	"$( [ "$( cat "$rigTmp/b.rc" )" != 0 ] && printf refused || printf sent ):$( LC_ALL=C grep -c 'does not give that file its place path and its read-back' "$rigTmp/b" ):$( rigPosts )" "refused:1:1"
rigAssert "and it names both faults" \
	"$( LC_ALL=C grep -c -e '^applied-without-place-path: ' -e '^applied-without-read-back: ' "$rigTmp/b" )" "2"

echo "-- 3. a relay naming the place path with no read-back is refused --"
rigSend "$rigTmp/c" relay "Applied at ws-myx.ae3-devel:source/myx/style.css.tpl"
rigAssert "refused, and only the read-back is named" \
	"$( [ "$( cat "$rigTmp/c.rc" )" != 0 ] && printf refused || printf sent ):$( LC_ALL=C grep -c '^applied-without-place-path: ' "$rigTmp/c" ):$( LC_ALL=C grep -c '^applied-without-read-back: ' "$rigTmp/c" ):$( rigPosts )" "refused:0:1:1"

echo "-- 4. a relay naming the path and its read-back goes through --"
rigSend "$rigTmp/d" relay "Applied ws-myx.ae3-devel:source/myx/style.css.tpl, cksum 1234-99"
rigAssert "sent, and a post reached Slack" "$( cat "$rigTmp/d.rc" ):$( rigPosts )" "0:2"

echo "-- 5. a plain send that says fixed is not measured --"
rigSend "$rigTmp/e" "" "Fixed the Show Detail rule at style.css.tpl:1314 and the checks pass"
rigAssert "sent, and a post reached Slack" "$( cat "$rigTmp/e.rc" ):$( rigPosts )" "0:3"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ APPLY REPORT RELAY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'APPLY_REPORT_RELAY: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
