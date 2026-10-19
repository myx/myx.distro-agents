#!/usr/bin/env bash
## Behavioural check on long results (F2.4 of the refactorings epic): a command whose result is long writes it to a
## file in the session folder, reachable by the caller, and returns that path instead of the body. The first threshold
## is 8 KB. It is done in the one common place every tool reply passes through, so it covers every harness and MCP
## tool at once, and the long text is written to the file before the reply is encoded: the JSON of an MCP reply
## carries only the reference. A file is a printed value: the masking rule applies to it as to a reply.
## The reply holds the path, the size in bytes and lines, a preview -- the whole lines that fit in 2 KB, or the first
## 20 lines, whichever is bigger, never over 8 KB -- and a one-line hint to read the rest by line range. A native root caller over MCP has the folder of its client
## session id, .local/agents/sessions/<id>/, as the session store already does.
## Held, served by the harness (--intern-tool), by the MCP server's tools/call, and in the harness's own model loop,
## for a result of about 20 KB and one of about 2 KB:
##   1. the long result is not in the reply: the reply is short, and holds the path, the size in bytes and in lines,
##      a preview of the whole lines that fit in 2 KB or the first 20, whichever is more, never over 8 KB, and a
##      one-line hint to read the rest by line range
##   2. that file is in the session's folder, and holds the whole result
##   3. the caller reaches it: a served Read of it, by line range, gives its first line
##   4. through MCP, for a native root caller: the JSON reply carries only the reference, and the file is in the
##      folder of its client session id
##   5. in the harness's own model loop, the tool result the model is given is the reference too
##   6. control: a result below the threshold is returned whole, and no file is made for it
##   7. a credential in a long result is treated in the file as in a reply: a short result holding it and the file
##      of a long one show it alike
## Red before F2.4: every result is returned whole (1-5 and 7 fail).
## Offline: MMDAPP and HOME are this rig's own; the loop's model is a fake curl replaying one canned round.

set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] && [ -f "$rigTool" ] || rigRefuse "the harness or the tool is not at the origin this workspace resolves: $MDLT_ORIGIN"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReplyLongResultCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
## The granted team work directory of the workspace: inside the access roots of the server and of a served call.
rigFix="$rigTmp/.local/temp/team/fix"
rigSession="rig-long-run"
rigSecret="rig-bot-token-SECRET0123456789abcdef"
mkdir -p "$rigFix" "$rigTmp/.local/.agents" "$rigTmp/home"
printf 'SLACK_BOT_TOKEN=%s\n' "$rigSecret" > "$rigTmp/.local/.agents/magic-team.agent.env"
## The long file: 400 numbered lines of about 50 bytes, its first line marked; the short one: 40 such lines.
LC_ALL=C awk 'BEGIN { print "RIG-FIRST-LINE of the long result" ; for ( n = 2 ; n <= 400 ; n++ ) printf "rig line %04d of the long result, padded to length\n", n }' > "$rigFix/long.txt"
LC_ALL=C awk 'BEGIN { print "RIG-FIRST-LINE of the short result" ; for ( n = 2 ; n <= 40 ; n++ ) printf "rig line %04d of the short result, padded to length\n", n }' > "$rigFix/short.txt"
{ cat "$rigFix/long.txt" ; printf 'the token is %s\n' "$rigSecret" ; } > "$rigFix/long-secret.txt"
{ cat "$rigFix/short.txt" ; printf 'the token is %s\n' "$rigSecret" ; } > "$rigFix/short-secret.txt"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigServe(){ ## name, tool, arguments JSON -- one served call of the session; its reply in <name>.out
	( cd "$rigFix" && printf '%s' "$3" | env -u CLAUDE_CODE_SESSION_ID -u MDAT_DATA_ROOT -u MDAT_SKILLSET_ROOT MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" HOME="$rigTmp/home" \
		MDAT_SPAWN_AGENT=magic-tester MDAT_SPAWN_SESSION_ID="$rigSession" bash "$rigHarness" --intern-tool "$2" ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err"
}
## A native root caller: no spawn id, only the client session id its CLI gives it.
rigClient="rig-native-client-long"
rigMcp(){ ## name, tool, arguments JSON -- one tools/call of the MCP server; its raw reply line in <name>.out
	printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"%s","arguments":%s}}\n' "$2" "$3" \
		| ( cd "$rigFix" && env -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT CLAUDE_CODE_SESSION_ID="$rigClient" MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" HOME="$rigTmp/home" \
		bash "$rigTool" --intern-mcp-server --run ) 2> "$rigTmp/$1.err" | LC_ALL=C grep '^{"jsonrpc":"2.0","id":2,' > "$rigTmp/$1.out"
}
rigBytes(){ ## name -- the size of its reply
	LC_ALL=C wc -c < "$rigTmp/$1.out" | LC_ALL=C tr -d ' '
}
rigShort(){ ## name -- whether its reply is short: under 8 KB
	[ "$( rigBytes "$1" )" -lt 8192 ] && printf short || printf "long:$( rigBytes "$1" )"
}
rigHasBody(){ ## name, marker -- how many lines of its reply hold the marker
	LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.out" || :
}
## The file a reply names: the first absolute path in it that is a file and holds the marker.
rigNamed(){ ## name, marker
	local namedPath
	for namedPath in $( LC_ALL=C grep -o -E '/[^ "\\]+' "$rigTmp/$1.out" 2> /dev/null ) ; do
		[ -f "$namedPath" ] && LC_ALL=C grep -q -F -- "$2" "$namedPath" 2> /dev/null && { printf '%s' "$namedPath" ; return 0 ; }
	done
}

echo "-- 1. a long result is not in the reply, which names a file instead --"
rigServe long Read "{\"file_path\":\"$rigFix/long.txt\"}"
[ -s "$rigTmp/long.out" ] || rigRefuse "the served Read gave no reply, so nothing below would be measured: $( head -3 "$rigTmp/long.err" | LC_ALL=C tr '\n' ' ' )"
rigAssert "the reply is short"                                "$( rigShort long )" short
rigAssert "and holds none of the lines past the first screen" "$( rigHasBody long 'rig line 0399 of the long result' )" 0
rigLongFile="$( rigNamed long 'rig line 0399 of the long result' )"
rigAssert "it names a file holding the result"                "$( [ -n "$rigLongFile" ] && printf named || printf none )" named
rigAssert "it gives the file's size, in bytes and in lines"   "$( [ -n "$rigLongFile" ] && LC_ALL=C grep -q -w -- "$( LC_ALL=C wc -c < "$rigLongFile" | LC_ALL=C tr -d ' ' )" "$rigTmp/long.out" && LC_ALL=C grep -q -w -- "$( LC_ALL=C wc -l < "$rigLongFile" | LC_ALL=C tr -d ' ' )" "$rigTmp/long.out" && printf sized || printf not-sized )" sized
## The preview: the whole lines of the result that fit in 2 KB, or its first 20 lines, whichever is more, never over 8 KB.
rigPreviewLines(){ ## file -- how many lines the preview of that result holds
	LC_ALL=C awk '{ total += length( $0 ) + 1 ; if ( total <= 2048 ) fit = NR } END { print ( fit > 20 ) ? fit : 20 }' "$1"
}
rigPreviewEnds(){ ## reply name, result file -- `ends-right` where the reply holds the preview's last line and not the line after it
	local endsAt endsLast endsNext
	[ -f "$2" ] || { printf no-file ; return 0 ; }
	endsAt="$( rigPreviewLines "$2" )"
	endsLast="$( LC_ALL=C sed -n "${endsAt}p" "$2" )" ; endsNext="$( LC_ALL=C sed -n "$(( endsAt + 1 ))p" "$2" )"
	LC_ALL=C grep -q -F -- "$endsLast" "$rigTmp/$1.out" && ! LC_ALL=C grep -q -F -- "$endsNext" "$rigTmp/$1.out" && printf ends-right || printf "ends-wrong-at-$endsAt"
}
rigAssert "the preview: the first line, and the whole lines that fit in 2 KB or 20, whichever is more" "$( rigHasBody long 'RIG-FIRST-LINE of the long result' ) $( rigPreviewEnds long "${rigLongFile:-/nonexistent}" )" "1 ends-right"
rigAssert "and one line that names the file and says to read the rest by line range" "$( [ -n "$rigLongFile" ] && LC_ALL=C grep -F -- "$rigLongFile" "$rigTmp/long.out" | LC_ALL=C grep -c -i -E 'range|offset|start-line' || printf 0 )" 1

echo "-- 2. that file is in the session's folder, and holds the whole result --"
rigWhere(){ ## path, session (default: the served one) -- session-folder where it is in that session's folder, else the path, or none
	case "$1" in
		"$rigTmp/.local/agents/sessions/${2:-$rigSession}/"*) printf session-folder ;;
		'') printf none ;;
		*) printf '%s' "$1" ;;
	esac
}
rigAssert "in the session's folder"                           "$( rigWhere "$rigLongFile" )" session-folder
rigAssert "the whole result: its first and its last line"     "$( LC_ALL=C grep -c -e 'RIG-FIRST-LINE of the long result' -e 'rig line 0400 of the long result' "${rigLongFile:-/nonexistent}" 2> /dev/null || printf 0 )" 2

echo "-- 3. the caller reaches it --"
rigServe back Read "{\"file_path\":\"${rigLongFile:-/nonexistent}\",\"offset\":1,\"limit\":3}"
rigAssert "a served Read of it by line range gives its first line" "$( rigHasBody back 'RIG-FIRST-LINE of the long result' | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "reached" : "not-reached" }' )" reached

echo "-- 4. through MCP, the JSON reply carries only the reference --"
rigMcp mlong execute "{\"command\":\"cat '$rigFix/long.txt'\"}"
[ -s "$rigTmp/mlong.out" ] || rigRefuse "the MCP server gave no reply, so nothing below would be measured: $( head -3 "$rigTmp/mlong.err" | LC_ALL=C tr '\n' ' ' )"
rigAssert "the JSON reply is short"                           "$( rigShort mlong )" short
rigAssert "and holds none of the body past its first lines"   "$( rigHasBody mlong 'rig line 0399 of the long result' )" 0
rigMcpFile="$( rigNamed mlong 'rig line 0399 of the long result' )"
rigAssert "it names the file holding the result"              "$( [ -n "$rigMcpFile" ] && printf named || printf none )" named
rigAssert "in the folder of the native caller's client session id" "$( rigWhere "$rigMcpFile" "$rigClient" )" session-folder

echo "-- 5. in the harness's own model loop, the model is given the reference too --"
rigLoopDir="$rigTmp/loop"
mkdir -p "$rigLoopDir/bin" "$rigTmp/skills/magic-tester" "$rigTmp/OUT"
printf 'rig\n' > "$rigTmp/skills/magic-tester/magic-tester.basic.md"
cp "${rigHere%/sh-lib}/sh-test/check-fixtures/harness-arm-gate.curl.stub.sh" "$rigLoopDir/bin/curl" && chmod +x "$rigLoopDir/bin/curl" || rigRefuse "the fake curl fixture of the model loop is missing from the package"
printf '0' > "$rigLoopDir/round"
: > "$rigLoopDir/curl.log"
printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call-1","type":"function","function":{"name":"Read","arguments":"{\\"file_path\\":\\"%s\\"}"}}]},"finish_reason":null}]}\ndata: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' "$rigFix/long.txt" > "$rigLoopDir/res.1"
printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-DONE"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' > "$rigLoopDir/res.2"
env -i HOME="$rigTmp/home" PATH="$rigLoopDir/bin:/usr/bin:/bin" MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_SESSION_ID=rig-long-loop MDAT_SPAWN_AGENT=magic-tester RIG_SCENARIO="$rigLoopDir" RIG_CURL_LOG="$rigLoopDir/curl.log" \
	HARNESS_PROVIDER_NAME="long-result rig" HARNESS_SELF_NAME="AgentsReplyLongResultCheck.test.sh" \
	HARNESS_ENDPOINT="https://reply-long-result-check.invalid/v1/chat/completions" HARNESS_HOST="reply-long-result-check.invalid" \
	HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none" HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" \
	HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 \
	bash -c 'cd "$MMDAPP" && exec bash "$0" --access-read-root "$MMDAPP" --access-read-root "$MDAT_SKILLSET_ROOT" --access-write-root "$MMDAPP/OUT" --agent magic-tester RIG-TASK' "$rigHarness" \
	> "$rigLoopDir/out" 2> "$rigLoopDir/err" < /dev/null || :
[ -s "$rigLoopDir/req.2" ] || rigRefuse "the loop never gave the model the tool's result, so nothing below would be measured: $( tail -3 "$rigLoopDir/err" | LC_ALL=C tr '\n' ' ' )"
rigAssert "the tool result the model is given holds none of the body past the preview" "$( LC_ALL=C grep -c -F 'rig line 0399 of the long result' "$rigLoopDir/req.2" || : )" 0
rigAssert "and names the file in the loop session's folder"    "$( LC_ALL=C grep -c -F "$rigTmp/.local/agents/sessions/rig-long-loop/" "$rigLoopDir/req.2" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "named" : "none" }' )" named

echo "-- 6. control: a result below the threshold is returned whole, with no file --"
rigServe short Read "{\"file_path\":\"$rigFix/short.txt\"}"
rigMcp mshort execute "{\"command\":\"cat '$rigFix/short.txt'\"}"
rigAssert "served: whole, its last line in the reply"         "$( rigHasBody short 'rig line 0040 of the short result' )" 1
rigAssert "through MCP: whole"                                "$( rigHasBody mshort 'rig line 0040 of the short result' )" 1
rigAssert "and no file was made for either"                   "$( [ -n "$( rigNamed short 'rig line 0040 of the short result' )$( rigNamed mshort 'rig line 0040 of the short result' )" ] && printf made || printf none )" none

echo "-- 7. a credential in a long result is shown in its file as in a reply --"
rigServe ssecret Read "{\"file_path\":\"$rigFix/short-secret.txt\"}"
rigServe lsecret Read "{\"file_path\":\"$rigFix/long-secret.txt\"}"
rigSecretFile="$( rigNamed lsecret 'rig line 0399 of the long result' )"
rigAssert "the long result went to a file"                    "$( [ -n "$rigSecretFile" ] && printf named || printf none )" named
rigAssert "the file shows the credential as the short reply does" \
	"$( LC_ALL=C grep -c -F -- "$rigSecret" "${rigSecretFile:-/nonexistent}" 2> /dev/null || printf none )" "$( rigHasBody ssecret "$rigSecret" )"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REPLY LONG RESULT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REPLY_LONG_RESULT: OK (%d assertions, offline)\n' "$rigPassCount"
