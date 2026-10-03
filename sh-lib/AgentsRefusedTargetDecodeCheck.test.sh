#!/usr/bin/env bash
## Behavioural check: a refused call's target is always natural. The refusal record
## escapes only what its one-line format needs (%, newline, CR, edge whitespace), a
## grant escapes the comma and colon besides, and reading back materialises the
## natural value, so a person never sees a percent-escape. The permission
## question AgentsUniversalHarness.sh sends is also the dispatch to whoever may grant
## the call, so one check on that posted text covers both. Offline: a Slack-shaped
## fake curl is first on PATH, the refusal record is written directly rather than
## produced by a real refused call, and the ask is killed right after it posts, since
## a typed kind always waits for an answer the fake curl never supplies. Never sends
## real mail, never calls curl for real, never posts to Slack.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"

rigTmp="$( mktemp -d -t AgentsRefusedTargetDecodeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

mkdir -p "$rigTmp/bin"
cp "$rigHere/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigHere/check-fixtures/harness-ask-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}

## One scenario directory per case, each with its own workspace and curl log, so the
## fake curl's own post counter starts fresh and post.1/post.2 never carry over.
rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}

## Writes a refusal record directly, the same shape --intern-op-permission-refusal-log
## writes, so this check never needs a real refused call to produce one.
rigRecord(){ ## session id, refusal id, target (already escaped, as the record stores it)
	local recordDir="$rigScenarioDir/ws/.local/agents/sessions/$1"
	mkdir -p "$recordDir"
	{
		printf '%s\n' "---"
		printf 'status: %s\n' "refused"
		printf 'owner: %s\n' "$rigMember"
		printf 'host: %s\n' "rig-host"
		printf 'session-id: %s\n' "$1"
		printf 'tool: %s\n' "WebFetch"
		printf 'target: %s\n' "$3"
		printf 'refused-at: %s\n' "2026-01-01 00:00 +0000"
		printf '%s\n' "---"
		printf '\n# Refused\n\nno reason given\n'
	} > "$recordDir/$2.md"
}

## One AskUserQuestion kind=permission call. A typed kind always waits for its answer
## regardless of wait=false (AgentsUniversalHarness.sh's own escalation rule), and the
## fake curl holds no reply, so this runs in the background and is killed once its
## question is posted -- the post is all this check needs. Each scenario uses its own
## address_to, so no scenario's question can thread into another's open ask-thread and
## shift the post numbering.
rigAsk(){ ## session id, refusal id, question, address-to
	local askPid askLeft=10
	set -m
	( cd "$rigScenarioDir/ws" && printf '{"to":"magic-team","question":"%s","address_to":"%s","kind":"permission","refusal_id":"%s","reason":"r","task_ref":"t","wait":"false"}' \
			"$3" "$4" "$2" \
		| env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID MDAT_SPAWN_SESSION_ID="$1" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" \
			MDAT_HARNESS_WAIT_TIMEOUT=1 bash "$rigHarness" --intern-tool AskUserQuestion ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	askPid=$!
	set +m
	while kill -0 "$askPid" 2>/dev/null && [ ! -f "$rigScenarioDir/post.2" ] && [ "$askLeft" -gt 0 ] ; do
		sleep 1
		askLeft=$(( askLeft - 1 ))
	done
	if kill -0 "$askPid" 2>/dev/null ; then
		{ kill -TERM -- "-$askPid" ; sleep 1 ; kill -KILL -- "-$askPid" ; wait "$askPid" ; } 2>/dev/null
	fi
	wait "$askPid" 2>/dev/null || :
}

echo "-- a record's own escapes reach the decider decoded --"
rigStart record-escaped
rigRecord rig-session-1 refusal-rig1 "100%25 sure%0Asecond line"
rigAsk rig-session-1 refusal-rig1 "May that be allowed" URIGOWNER1
rigAssert "the question was posted"                "$( [ -f "$rigScenarioDir/post.2" ] && printf yes || printf no )" yes
rigAssert "the percent is shown as a percent"      "$( rigHolds "$rigScenarioDir/post.2" "target: 100% sure" )" yes
rigAssert "the escaped percent is gone"            "$( rigHolds "$rigScenarioDir/post.2" "%25" )" no
rigAssert "the escaped newline is gone"            "$( rigHolds "$rigScenarioDir/post.2" "%0A" )" no

echo "-- a URL target reaches the decider as it is --"
rigStart url-target
rigRecord rig-session-6 refusal-rig6 "https://api.slack.com/reference/block-kit/blocks"
rigAsk rig-session-6 refusal-rig6 "May api.slack.com be added to the allowlist" URIGOWNER6
rigAssert "the URL is shown readable"              "$( rigHolds "$rigScenarioDir/post.2" "target: https://api.slack.com/reference/block-kit/blocks" )" yes
rigAssert "no colon escape is shown"               "$( rigHolds "$rigScenarioDir/post.2" "%3A" )" no

echo "-- a target with no escapes is unchanged --"
rigStart plain-target
rigRecord rig-session-2 refusal-rig2 "plain/target/no-escapes"
rigAsk rig-session-2 refusal-rig2 "plain case" URIGOWNER2
rigAssert "a plain target is shown exactly as it was" "$( rigHolds "$rigScenarioDir/post.2" "target: plain/target/no-escapes" )" yes

echo "-- a malformed escape, a lone percent, does not break the message --"
rigStart malformed-escape
rigRecord rig-session-3 refusal-rig3 "weird%target"
rigAsk rig-session-3 refusal-rig3 "malformed case" URIGOWNER3
rigAssert "the question was still posted"                  "$( [ -f "$rigScenarioDir/post.2" ] && printf yes || printf no )" yes
rigAssert "the question text survives beside the target"   "$( rigHolds "$rigScenarioDir/post.2" "malformed case" )" yes
rigAssert "the lone-percent target is shown, not dropped"  "$( rigHolds "$rigScenarioDir/post.2" "weird" )" yes

echo "-- the record itself is stored presentable, and a grant still matches the natural target --"
rigStart stored-natural
rigNaturalTarget="https://api.slack.com/reference/block-kit/blocks"
rigFn(){ ## args for the tooling entry point, run in the scenario workspace
	( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT MMDAPP="$rigScenarioDir/ws" \
		bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ) 2>> "$rigScenarioDir/fn.err"
}
rigStoredId="$( rigFn --intern-op-permission-refusal-log "$rigMember" --session-id rig-session-4 --tool WebFetch --target "$rigNaturalTarget" | head -1 )"
rigStoredFile="$rigScenarioDir/ws/.local/agents/sessions/rig-session-4/$rigStoredId.md"
rigAssert "a refusal id was issued"                      "$( [ "${rigStoredId#refusal-}" != "$rigStoredId" ] && printf yes || printf no )" yes
rigAssert "the record holds the readable target"         "$( rigHolds "$rigStoredFile" "target: $rigNaturalTarget" )" yes
rigAssert "the record holds no escaped colon"            "$( rigHolds "$rigStoredFile" "%3A" )" no
rigFn --intern-op-permission-grant-open rig-granter --session-id rig-session-4 --refusal-id "$rigStoredId" --kind session > /dev/null
rigAssert "the grants file keeps its colon-delimited shape" "$( awk -F: '{ print NF }' "$rigScenarioDir/ws/.local/agents/sessions/rig-session-4/grants" | head -1 )" 6
rigAssert "a grant matches the natural target" \
	"$( rigFn --intern-op-permission-grant-read "$rigMember" --session-id rig-session-4 --tool WebFetch --target "$rigNaturalTarget" | cut -c1-14 )" "GRANT: session"

## The grants line must survive a target made of every character its format treats as special,
## and an escaped-looking natural target must not match the target it merely looks like.
rigStart nasty-target
rigNastyTarget='a:b,c%3Ad e|f'
rigNastyId="$( rigFn --intern-op-permission-refusal-log "$rigMember" --session-id rig-session-5 --tool Bash --target "$rigNastyTarget" | head -1 )"
rigFn --intern-op-permission-grant-open rig-granter --session-id rig-session-5 --refusal-id "$rigNastyId" --kind session > /dev/null
rigAssert "a nasty target keeps the grants line at six fields" \
	"$( awk -F: '{ print NF }' "$rigScenarioDir/ws/.local/agents/sessions/rig-session-5/grants" | head -1 )" 6
rigAssert "a grant matches the nasty natural target" \
	"$( rigFn --intern-op-permission-grant-read "$rigMember" --session-id rig-session-5 --tool Bash --target "$rigNastyTarget" | cut -c1-14 )" "GRANT: session"
rigAssert "it does not match the target its escaped text looks like" \
	"$( rigFn --intern-op-permission-grant-read "$rigMember" --session-id rig-session-5 --tool Bash --target 'a%3Ab%2Cc%253Ad e|f' | cut -c1-14 )" ""

echo "-- control: no request left this box, across every scenario above --"
rigAssert "no non-Slack URL was ever called" \
	"$( LC_ALL=C awk '/^url:/ { hitCount++ ; } END { print hitCount + 0 ; }' "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '{ s += $1 ; } END { print s + 0 ; }' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REFUSED TARGET DECODE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REFUSED_TARGET_DECODE: OK (%d assertions, offline)\n' "$rigPassCount"
