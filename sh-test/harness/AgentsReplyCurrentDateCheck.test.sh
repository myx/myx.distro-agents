#!/usr/bin/env bash
## Behavioural check on the server date in every tool reply (F2.3 of the refactorings epic): a labelled field,
## `current-date`, in the form `YYYY-MM-DD HH:MM +ZZZZ`, the host's local time with its UTC offset, the form every
## spawn record's started-at uses. It is added once, in the reply layer that serves every harness and MCP tool, not
## per operation. A labelled field is not a trailing line: the NEXT: part keeps the end of a result.
## Held, for replies of several tools, served by the harness (--intern-tool) and by the MCP server's tools/call:
##   1. each reply carries exactly one current-date field
##   2. its value is the host's local time now, with its offset, in that form
##   3. the offset follows the host's time zone: TZ=UTC gives +0000, TZ=Asia/Tokyo +0900
##   4. a reply that ends with a NEXT: part still ends with it, and current-date stands before it
##   5. the tool's own result is still there beside it
##   6. in the harness's own model loop, the tool result the model is given carries the field too
## Red before F2.3: no reply carries the field (1-4 and 6 fail).
## Offline: a Slack-shaped fake curl first on PATH answers the one Wait; the loop's model is a fake curl replaying
## one canned round; MMDAPP and HOME are this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] && [ -f "$rigTool" ] || rigRefuse "the harness or the tool is not at the origin this workspace resolves: $MDLT_ORIGIN"
rigTmp="$( mktemp -d -t AgentsReplyCurrentDateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
## The granted team work directory of the workspace: inside the access roots of the server and of a member's served call.
rigFix="$rigTmp/.local/temp/team/fix"
mkdir -p "$rigFix" "$rigTmp/.local/.agents" "$rigTmp/skills/magic-tester" "$rigTmp/bin" "$rigTmp/home"
printf 'rig line\n' > "$rigFix/a.txt"
printf 'rig\n' > "$rigTmp/skills/magic-tester/magic-tester.basic.md"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigTmp/.local/.agents/magic-team.agent.env"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
printf '{"ok":true,"messages":[{"ts":"1700000002.000202","user":"URIGBOT01","text":"opened"}],"has_more":false}\n' > "$rigTmp/replies.json"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigForm='current-date: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} [+-][0-9]{4}'
## One served call of a tool, under a time zone: its reply in <name>.out, and the host's time before and after it.
rigServe(){ ## name, time zone, tool, arguments JSON
	TZ="$2" date '+%Y-%m-%d %H:%M %z' > "$rigTmp/$1.before"
	( cd "$rigFix" && printf '%s' "$4" | env -u CLAUDE_CODE_SESSION_ID -u MDAT_DATA_ROOT TZ="$2" PATH="$rigTmp/bin:/usr/bin:/bin" RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" \
		MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" HOME="$rigTmp/home" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		MDAT_SPAWN_AGENT=magic-tester MDAT_SPAWN_SESSION_ID=rig-current-date-run MDAT_SESSION_THREAD=CRIG00001:1700000002.000202 \
		bash "$rigHarness" --intern-tool "$3" ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err"
	TZ="$2" date '+%Y-%m-%d %H:%M %z' > "$rigTmp/$1.after"
}
## The MCP server, one tools/call: its raw reply line in <name>.out, the host's time before and after it.
rigMcp(){ ## name, time zone, tool, arguments JSON
	TZ="$2" date '+%Y-%m-%d %H:%M %z' > "$rigTmp/$1.before"
	printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"%s","arguments":%s}}\n' "$3" "$4" \
		| ( cd "$rigFix" && env -u CLAUDE_CODE_SESSION_ID TZ="$2" MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" HOME="$rigTmp/home" \
		bash "$rigTool" --intern-mcp-server --run ) 2> "$rigTmp/$1.err" | LC_ALL=C grep '^{"jsonrpc":"2.0","id":2,' > "$rigTmp/$1.out"
	TZ="$2" date '+%Y-%m-%d %H:%M %z' > "$rigTmp/$1.after"
}
rigDates(){ ## name -- how many current-date fields its reply holds
	LC_ALL=C grep -o -E "$rigForm" "$rigTmp/$1.out" 2> /dev/null | LC_ALL=C grep -c . || :
}
rigNow(){ ## name -- whether the field holds the host's time at the call: now, or what it holds
	local nowValue
	nowValue="$( LC_ALL=C grep -o -E "$rigForm" "$rigTmp/$1.out" 2> /dev/null | head -1 | LC_ALL=C sed 's/^current-date: //' )"
	if [ -n "$nowValue" ] && { [ "$nowValue" = "$( cat "$rigTmp/$1.before" )" ] || [ "$nowValue" = "$( cat "$rigTmp/$1.after" )" ] ; } ; then printf now ; else printf '%s' "${nowValue:-none}" ; fi
}
rigOffset(){ ## name -- the offset the field carries
	LC_ALL=C grep -o -E "$rigForm" "$rigTmp/$1.out" 2> /dev/null | head -1 | LC_ALL=C awk '{ print $NF }'
}

rigServe glob UTC Glob "{\"pattern\":\"*.txt\",\"path\":\"$rigFix\"}"
rigServe read Asia/Tokyo Read "{\"file_path\":\"$rigFix/a.txt\"}"
rigServe wait UTC Wait '{"sources":"slack:session-current","since_utime":"1700000100","timeout":1}'
rigMcp mglob UTC Glob "{\"pattern\":\"*.txt\",\"path\":\"$rigFix\"}"
rigMcp mexec Asia/Tokyo execute '{"command":"echo rig-hello"}'
for rigName in glob read wait mglob mexec ; do
	[ -s "$rigTmp/$rigName.out" ] || rigRefuse "the $rigName call gave no reply, so nothing below would be measured: $( head -3 "$rigTmp/$rigName.err" | LC_ALL=C tr '\n' ' ' )"
done

echo "-- 1. each reply carries exactly one current-date field --"
for rigName in glob read wait mglob mexec ; do
	rigAssert "$rigName: one current-date"                    "$( rigDates "$rigName" )" 1
done

echo "-- 2. its value is the host's local time at the call, with its offset --"
for rigName in glob read wait mglob mexec ; do
	rigAssert "$rigName: the time of the call"                "$( rigNow "$rigName" )" now
done

echo "-- 3. the offset follows the host's time zone --"
rigAssert "TZ=UTC: +0000, served and through MCP"            "$( rigOffset glob ) $( rigOffset mglob )" "+0000 +0000"
rigAssert "TZ=Asia/Tokyo: +0900, served and through MCP"     "$( rigOffset read ) $( rigOffset mexec )" "+0900 +0900"

echo "-- 4. a reply ending with NEXT: still ends with it, current-date before it --"
rigLastLine="$( LC_ALL=C grep . "$rigTmp/wait.out" | LC_ALL=C tail -n 1 )"
rigDateLine="$( LC_ALL=C grep -n -E "^$rigForm\$" "$rigTmp/wait.out" | head -1 | cut -d: -f1 )"
rigAssert "control: the Wait's reply has a NEXT: part"        "$( LC_ALL=C grep -c 'NEXT: ' "$rigTmp/wait.out" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "has" : "none" }' )" has
rigAssert "its last line still holds the NEXT: part"          "$( printf '%s\n' "$rigLastLine" | LC_ALL=C grep -q -F 'NEXT: ' && printf last || printf 'not-last: %s' "$rigLastLine" )" last
rigAssert "and current-date is a line of its own before it"   "$( [ -n "$rigDateLine" ] && [ "$rigDateLine" -lt "$( LC_ALL=C grep -c '' "$rigTmp/wait.out" )" ] && printf before || printf '%s' "${rigDateLine:-none}" )" before

echo "-- 5. the tool's own result is still there --"
rigAssert "Glob still lists the file, Read still gives its line, execute its output" \
	"$( LC_ALL=C grep -c -F "$rigFix/a.txt" "$rigTmp/glob.out" | LC_ALL=C awk '{ print ( $1 >= 1 ) }' ) $( LC_ALL=C grep -c -F 'rig line' "$rigTmp/read.out" | LC_ALL=C awk '{ print ( $1 >= 1 ) }' ) $( LC_ALL=C grep -c -F 'rig-hello' "$rigTmp/mexec.out" )" "1 1 1"

echo "-- 6. in the harness's own model loop, the model is given the field with the tool's result --"
rigLoopDir="$rigTmp/loop"
mkdir -p "$rigLoopDir/bin" "$rigTmp/OUT"
cp "$rigTest/check-fixtures/harness-arm-gate.curl.stub.sh" "$rigLoopDir/bin/curl" && chmod +x "$rigLoopDir/bin/curl" || rigRefuse "the fake curl fixture of the model loop is missing from the package"
printf '0' > "$rigLoopDir/round"
: > "$rigLoopDir/curl.log"
printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call-1","type":"function","function":{"name":"Glob","arguments":"{\\"pattern\\":\\"*.txt\\",\\"path\\":\\"%s\\"}"}}]},"finish_reason":null}]}\ndata: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' "$rigFix" > "$rigLoopDir/res.1"
printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-DONE"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' > "$rigLoopDir/res.2"
env -i HOME="$rigTmp/home" PATH="$rigLoopDir/bin:/usr/bin:/bin" TZ=UTC MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_SESSION_ID=rig-current-date-loop MDAT_SPAWN_AGENT=magic-tester RIG_SCENARIO="$rigLoopDir" RIG_CURL_LOG="$rigLoopDir/curl.log" \
	HARNESS_PROVIDER_NAME="current-date rig" HARNESS_SELF_NAME="AgentsReplyCurrentDateCheck.test.sh" \
	HARNESS_ENDPOINT="https://reply-current-date-check.invalid/v1/chat/completions" HARNESS_HOST="reply-current-date-check.invalid" \
	HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none" HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" \
	HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 \
	bash -c 'cd "$MMDAPP" && exec bash "$0" --access-read-root "$MMDAPP" --access-read-root "$MDAT_SKILLSET_ROOT" --access-write-root "$MMDAPP/OUT" --agent magic-tester RIG-TASK' "$rigHarness" \
	> "$rigLoopDir/out" 2> "$rigLoopDir/err" < /dev/null || :
[ -s "$rigLoopDir/req.2" ] || rigRefuse "the loop never gave the model the tool's result, so nothing below would be measured: $( tail -3 "$rigLoopDir/err" | LC_ALL=C tr '\n' ' ' )"
rigAssert "control: the model is given the Glob's result"     "$( LC_ALL=C grep -c -F "$rigFix/a.txt" "$rigLoopDir/req.2" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "given" : "not-given" }' )" given
rigAssert "and with it one current-date field"                "$( LC_ALL=C grep -o -E "$rigForm" "$rigLoopDir/req.2" | LC_ALL=C grep -c . || : )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REPLY CURRENT DATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REPLY_CURRENT_DATE: OK (%d assertions, offline)\n' "$rigPassCount"
