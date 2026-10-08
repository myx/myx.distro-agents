#!/usr/bin/env bash
## Behavioural check that the shared Slack call waits out a rate limit and retries:
## a 429 followed by a 200 succeeds after waiting the Retry-After, with a stated line;
## a 429 on every attempt fails with a stated rate-limit reason after the attempt
## bound. The control is a call never limited: one request, no wait.
## Offline: a temp workspace and a fake `curl` first on PATH.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsSlackRateLimitCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/magic-team"
cp "$rigTest/check-fixtures/slack-ratelimit-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing: $rigTest/check-fixtures/slack-ratelimit-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, fixed string
	LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}
## One call in the given mode; rc, seconds and calls are left behind. The call is a
## conversations.history form call unless other --intern-op-slack-call arguments follow.
rigCall(){ ## mode, call arguments...
	printf '%s\n' "$1" > "$rigTmp/mode"
	shift
	[ $# -gt 0 ] || set -- --api conversations.history --form channel=CRIG000001
	: > "$rigTmp/calls"
	rigRc=0
	local rigStart="$( date +%s )"
	( cd "$rigWs" && env -u MDAT_DATA_ROOT HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --intern-op-slack-call magic-team --identity bot "$@" ) \
		> "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
	rigSeconds=$(( $( date +%s ) - rigStart ))
	rigCalls="$( LC_ALL=C awk 'END { print NR ; }' "$rigTmp/calls" )"
}

echo "-- control: a call never rate-limited --"
rigCall none
[ "$rigCalls" -ge 1 ] || rigRefuse "no call reached the fake curl: $( grep -m1 ERROR "$rigTmp/err" )"
rigAssert "control: it succeeds"                        "$rigRc" 0
rigAssert "control: with one request"                   "$rigCalls" 1
rigAssert "control: and no rate-limit line"             "$( rigHolds "$rigTmp/err" 'rate-limited' )" no

echo "-- a 429, then a 200 --"
rigCall once
rigAssert "it succeeds"                                 "$rigRc" 0
rigAssert "after two requests"                          "$rigCalls" 2
rigAssert "the wait is stated, with the Retry-After"    "$( rigHolds "$rigTmp/err" 'rate-limited under bot identity -- waiting 1s as Retry-After asks' )" yes
rigAssert "and was actually waited"                     "$( [ "$rigSeconds" -ge 1 ] && echo yes || echo no )" yes
rigAssert "its answer is the 200's body"                "$( rigHolds "$rigTmp/out" '"ok":true' )" yes

echo "-- a 429 on every attempt --"
rigCall always
rigAssert "it fails"                                    "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigAssert "after the attempt bound, five requests"      "$rigCalls" 5
rigAssert "with a stated rate-limit reason"             "$( rigHolds "$rigTmp/err" 'rate-limited under bot identity: Slack still refused after 5 attempts' )" yes
rigAssert "no response-header file is left behind"      "$( ls -1 "$rigWs/.local/temp" 2>/dev/null | LC_ALL=C grep -c '^mdat-slack-' )" 0

echo "-- an upload: a 429, then a 200 --"
printf 'rig upload payload\n' > "$rigTmp/upload.txt"
rigCall once --api files.upload --upload-file "file=$rigTmp/upload.txt" --form channels=CRIG000001
rigAssert "the upload succeeds"                         "$rigRc" 0
rigAssert "after two requests"                          "$rigCalls" 2
rigAssert "the wait is stated"                          "$( rigHolds "$rigTmp/err" 'files.upload rate-limited under bot identity -- waiting 1s as Retry-After asks' )" yes
rigAssert "the last reported status is the 200"         "$( LC_ALL=C grep '^UPLOAD_HTTP_STATUS=' "$rigTmp/err" | tail -n 1 )" UPLOAD_HTTP_STATUS=200

echo "-- a raw authenticated GET: a 429, then a 200 --"
rigCall once --fetch-url "https://files.slack.com/files-pri/TRIG/rig.txt" --fetch-to "$rigTmp/fetched.txt"
rigAssert "the fetch succeeds"                          "$rigRc" 0
rigAssert "after two requests"                          "$rigCalls" 2
rigAssert "the wait is stated"                          "$( rigHolds "$rigTmp/err" 'raw authenticated GET of https://files.slack.com/files-pri/TRIG/rig.txt rate-limited under bot identity -- waiting 1s' )" yes
rigAssert "the destination holds the file, not the 429" "$( cat "$rigTmp/fetched.txt" 2>/dev/null )" RIG-FETCHED-FILE-CONTENT

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK RATE LIMIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_RATE_LIMIT: OK (%d assertions, offline)\n' "$rigPassCount"
