#!/usr/bin/env bash
## Differential check on the ONE JSON reader, sh-lib/AgentsHarnessJsonField.awk: every
## reader it replaced answers every fixture exactly as it did -- stdout, stderr and exit
## status byte for byte, and for the MCP request parser every file it writes. Each old
## reader is kept ONLY here, as check-fixtures/<name>.legacy.awk; nothing in sh-lib loads
## one. In a diagnostic the old file's own name reads as the reader's, the one change.
##   AgentsSlackJsonField          -> -v dialect=slack
##   AgentsAtlassianJsonField      -> -v dialect=atlassian (and -v raw=1)
##   AgentsHarnessJsonSlice        -> -v mode=raw | -v mode=keys
##   AgentsSlackListRecords        -> -v mode=records -v dialect=slack
##   AgentsAtlassianListRecords    -> -v mode=records -v dialect=atlassian (and -v raw=)
##   AgentsMcpJsonParseRequest, AgentsSlackMessagesFormat, ...ConversationCounterparty,
##   ...MessageSelect, ...SearchMatches, ...HistoryThreadTargets,
##   AgentsSessionContextCommsItems -> the same file, loaded after the reader
## The strict field mode and the jfParseText library have their own check,
## AgentsHarnessJsonFieldDiffCheck.test.sh; jfSliceText is held by AgentsWireStreamDiffCheck.
## Fixtures: hand-written edge cases plus a seeded, deterministic generator of Slack-,
## Atlassian- and MCP-shaped documents, every 3rd one mutated, some pages joined per line.
## Offline by construction: temp files only, no network, no credential.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigOld="${rigHere%/sh-lib}/sh-test/check-fixtures"
rigEngine="$rigHere/AgentsHarnessJsonField.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigEngine" ] || rigRefuse "the reader is not at the origin this workspace resolves: $rigEngine"
for rigName in AgentsSlackJsonField AgentsAtlassianJsonField AgentsHarnessJsonSlice AgentsSlackListRecords AgentsAtlassianListRecords AgentsMcpJsonParseRequest AgentsSlackMessagesFormat AgentsSlackConversationCounterparty AgentsSlackMessageSelect AgentsSlackSearchMatches AgentsSlackHistoryThreadTargets AgentsSessionContextCommsItems ; do
	[ -f "$rigOld/$rigName.legacy.awk" ] || rigRefuse "the legacy reader fixture is missing: $rigOld/$rigName.legacy.awk"
done

rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsJsonEngineDiffCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigFailShown=0
rigFail(){ ## what differed
	rigFailCount=$(( rigFailCount + 1 ))
	[ "$rigFailShown" -lt 25 ] || return 0
	rigFailShown=$(( rigFailShown + 1 ))
	printf '  FAIL  %s\n' "$1"
}

## One run, every observable kept; stderr with the old reader's name read as the new one's.
rigRun(){ ## stem, old name ("" for none), document, awk args...
	local runStem="$1" runName="$2" runDoc="$3" runRc=0
	shift 3
	LC_ALL=C awk "$@" < "$runDoc" > "$runStem.out" 2> "$runStem.raw" || runRc=$?
	printf '%s' "$runRc" > "$runStem.rc"
	if [ -n "$runName" ] ; then
		LC_ALL=C sed "s/$runName\\.awk/AgentsHarnessJsonField.awk/g" "$runStem.raw" > "$runStem.err"
	else
		cp "$runStem.raw" "$runStem.err"
	fi
}

rigSame(){ ## label -- compares the last old/new pair
	if cmp -s "$rigTmp/o.out" "$rigTmp/n.out" && cmp -s "$rigTmp/o.err" "$rigTmp/n.err" && cmp -s "$rigTmp/o.rc" "$rigTmp/n.rc" ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFail "$1: rc $( cat "$rigTmp/o.rc" ) -> $( cat "$rigTmp/n.rc" ), stdout $( cksum < "$rigTmp/o.out" | cut -d' ' -f1 ) -> $( cksum < "$rigTmp/n.out" | cut -d' ' -f1 ), stderr $( cksum < "$rigTmp/o.err" | cut -d' ' -f1 ) -> $( cksum < "$rigTmp/n.err" | cut -d' ' -f1 )"
	fi
}

## A renamed reader: the old file with its own options, the reader with the new ones.
rigPair(){ ## label, old name, document, "old args" , "new args" (each word-split)
	local pairLabel="$1" pairName="$2" pairDoc="$3"
	# shellcheck disable=SC2086
	rigRun "$rigTmp/o" "$pairName" "$pairDoc" $4 -f "$rigOld/$pairName.legacy.awk"
	# shellcheck disable=SC2086
	rigRun "$rigTmp/n" "" "$pairDoc" $5 -f "$rigEngine"
	rigSame "$pairLabel $( basename "$pairDoc" )"
}

## A driver kept as a file: the old self-contained one against the new one after the reader.
rigDriver(){ ## name, document, args...
	local driverName="$1" driverDoc="$2"
	shift 2
	rigRun "$rigTmp/o" "" "$driverDoc" "$@" -f "$rigOld/$driverName.legacy.awk"
	rigRun "$rigTmp/n" "" "$driverDoc" "$@" -f "$rigEngine" -f "$rigHere/$driverName.awk"
	rigSame "$driverName [$*] $( basename "$driverDoc" )"
}

## The MCP request parser writes files: both trees compared, name by name and byte by byte.
rigMcp(){ ## document
	local mcpSide
	for mcpSide in o n ; do
		rm -rf "$rigTmp/mcp.$mcpSide" ; mkdir "$rigTmp/mcp.$mcpSide"
	done
	rigRun "$rigTmp/o" "" "$1" -v outDir="$rigTmp/mcp.o" -f "$rigOld/AgentsMcpJsonParseRequest.legacy.awk"
	rigRun "$rigTmp/n" "" "$1" -v outDir="$rigTmp/mcp.n" -f "$rigEngine" -f "$rigHere/AgentsMcpJsonParseRequest.awk"
	if [ "$( ls "$rigTmp/mcp.o" )" = "$( ls "$rigTmp/mcp.n" )" ] && diff -r "$rigTmp/mcp.o" "$rigTmp/mcp.n" >/dev/null 2>&1 ; then
		rigSame "AgentsMcpJsonParseRequest $( basename "$1" )"
	else
		rigFail "AgentsMcpJsonParseRequest $( basename "$1" ): the written files differ"
	fi
}

rigPaths='ok
error
channel.id
channel.user
channel.is_im
messages
messages.0
messages.0.ts
messages.0.text
messages.1.user
messages.__count
messages.0.reactions
messages.0.reactions.0.users
messages.matches.0.permalink
id
params
params.arguments
a
a.b
b
'

## Every comparison this check makes on one document file.
rigAll(){ ## document
	local allDoc="$1" allPath allTs
	while IFS= read -r allPath ; do
		[ -n "$allPath" ] || continue
		rigPair "slack field [$allPath]" AgentsSlackJsonField "$allDoc" "-v path=$allPath" "-v path=$allPath -v dialect=slack"
		rigPair "slack field opt+sentinel [$allPath]" AgentsSlackJsonField "$allDoc" "-v path=$allPath -v optional=1 -v sentinel=1" "-v path=$allPath -v optional=1 -v sentinel=1 -v dialect=slack"
		rigPair "atlassian field [$allPath]" AgentsAtlassianJsonField "$allDoc" "-v path=$allPath" "-v path=$allPath -v dialect=atlassian"
		rigPair "atlassian field raw [$allPath]" AgentsAtlassianJsonField "$allDoc" "-v path=$allPath -v raw=1 -v sentinel=1" "-v path=$allPath -v raw=1 -v sentinel=1 -v dialect=atlassian"
		rigPair "slice raw [$allPath]" AgentsHarnessJsonSlice "$allDoc" "-v path=$allPath -v mode=raw" "-v path=$allPath -v mode=raw"
		rigPair "slice keys [$allPath]" AgentsHarnessJsonSlice "$allDoc" "-v path=$allPath -v mode=keys" "-v path=$allPath -v mode=keys"
	done <<< "$rigPaths"
	rigPair "slack records" AgentsSlackListRecords "$allDoc" "-v array=messages -v want=ts,user,text,reactions.0.name" "-v array=messages -v want=ts,user,text,reactions.0.name -v mode=records -v dialect=slack"
	rigPair "slack records" AgentsSlackListRecords "$allDoc" "-v array=channel -v want=id,a,b,user" "-v array=channel -v want=id,a,b,user -v mode=records -v dialect=slack"
	rigPair "atlassian records" AgentsAtlassianListRecords "$allDoc" "-v array=messages -v want=ts,user,text,reactions" "-v array=messages -v want=ts,user,text,reactions -v mode=records -v dialect=atlassian"
	rigPair "atlassian records raw" AgentsAtlassianListRecords "$allDoc" "-v array=messages -v want=ts,text,reactions,blocks -v raw=reactions,blocks" "-v array=messages -v want=ts,text,reactions,blocks -v raw=reactions,blocks -v mode=records -v dialect=atlassian"
	rigMcp "$allDoc"
	rigDriver AgentsSlackMessagesFormat "$allDoc"
	rigDriver AgentsSlackConversationCounterparty "$allDoc"
	allTs="$( LC_ALL=C sed -n 's/.*"ts":"\([0-9.]*\)".*/\1/p' "$allDoc" | head -1 )"
	rigDriver AgentsSlackMessageSelect "$allDoc" -v wantTs="${allTs:-1.5}"
	rigDriver AgentsSlackSearchMatches "$allDoc" -v cutoff=2
	rigDriver AgentsSlackSearchMatches "$allDoc" -v cutoff=0 -v mode=meta
	rigDriver AgentsSlackHistoryThreadTargets "$allDoc" -v channel=C1 -v oldest=1 -v vaneId=U1
	rigDriver AgentsSessionContextCommsItems "$allDoc" -v kind=slack -v source=rig -v channel=C1
	rigDriver AgentsSessionContextCommsItems "$allDoc" -v kind=trello
}

## ---- hand-written fixtures -----------------------------------------------------
rigCase=0
rigFixture(){ ## document text (written verbatim, no newline added)
	rigCase=$(( rigCase + 1 ))
	printf '%s' "$1" > "$rigTmp/hand.$rigCase.json"
}
rigFixture '{}'
rigFixture ''
rigFixture '   '
rigFixture '[1,2]'
rigFixture '[{"id":"n1","type":"t","data":{"text":"hi","card":{"name":"c"}},"memberCreator":{"username":"u"}}]'
rigFixture 'not json at all'
rigFixture '{"ok":true} x'
rigFixture '{"ok":true}'$'\n\n'
rigFixture '{"ok":true,"a":"é😀\ud800A\ud800x\udc00😀"}'
rigFixture '{"ok":true,"a":"\uZZZZ"}'
rigFixture '{"ok":true,"a":"\u12"}'
rigFixture '{"ok":true,"a":"\ud800\udc1Z"}'
rigFixture '{"ok":true,"a":"\ud800\uzzzz"}'
rigFixture '{"ok":true,"a":"abc'
rigFixture '{"ok":true,"a":"abc\'
rigFixture '{"ok":true,"a" 1}'
rigFixture '{"ok":true,"a":}'
rigFixture '{"ok":true,"a":txyz}'
rigFixture '{"ok":true,"a":nul}'
rigFixture '{"ok":true,a":1}'
rigFixture '{"":{"ok":true},"b":3}'
rigFixture '{"ok":{"x":1},"a":1}'
rigFixture '{"ok":[],"a":1}'
rigFixture '{"ok":true,"a":1,"a":2,"ok":false}'
rigFixture '{"ok":false,"error":"invalid_auth"}'
rigFixture '{"ok":true,"messages":[1,[2,3],{"ts":"1.5","text":"x\ty\nz\\w","user":"U1"}],"b":{"__count":"x"}}'
rigFixture '{"ok":true,"a":[1 2]}'
rigFixture '{"ok":true,"a"::1}'
rigFixture '{"ok":true,"a":1,}'
rigFixture '{"ok":true,"x":{"a":[1}, "b":2}}'
rigFixture '{"ok":true,"messages":[{"ts":"1.1","blocks":[{"t":"a]}\"{["}],"reactions":[{"name":"+1","count":2,"users":["U1","U2"]}]}]}'
rigFixture '{"ok":true,"messages":[{"ts":"1.1","blocks":[{"t":"unclosed}]}'
rigFixture '{"ok":true,"messages":[{"ts":"1.1","blocks":{]}]}'
rigFixture '{"jsonrpc":"2.0","id":"7","method":"tools/call","params":{"name":"execute","arguments":{"command":"echo \"hi\"\n","args":["a","b"],"env":{"A_B":"1","bad-name":"2"},"bad.arg":1,"timeout":30}}}'
rigFixture '{"jsonrpc":"2.0","id":12,"method":"notifications/cancelled","params":{"requestId":"abc","clientInfo":{"name":"c","version":"1"}}}'
rigFixture '{"method":"x","params":{"arguments":{"args":[]}}}'
rigFixture '{"ok":true,"messages":{"total":3,"paging":{"page":1,"pages":2,"count":20},"matches":[{"ts":"3.5","text":"m","user":"U2","permalink":"https://x/p?thread_ts=1.2&cid=C"},{"ts":"1.0","username":"bot"}]}}'
rigFixture '{"ok":true,"channel":{"id":"D1","is_im":true,"user":"U9","latest":{"user":"U3"}}}'
rigFixture $'{"ok":true,"messages":[{"ts":"5.000001","user":"U1","reply_count":2,"latest_reply":"9","reply_users":["U1","U2"],"text":"<@U1> hi"}]}\n## dm=D2 identity=user x\n{"ok":true,"messages":[{"ts":"6","bot_id":"U1","reply_count":1,"latest_reply":"0.5"}]}\n'
rigFixture $'## page 1\n{"ok":true,"messages":[{"ts":"1"},{"ts":"2"}]}\n## page 2\n{"ok":true,"messages":[{"ts":"3","text":"a\\tb"}]}\n'
## More than ninety elements: the atlassian records row loop compares as strings.
rigMany="" ; rigI=0
while [ "$rigI" -lt 120 ] ; do rigMany="${rigMany}${rigMany:+,}{\"ts\":\"$rigI\",\"text\":\"t$rigI\"}" ; rigI=$(( rigI + 1 )) ; done
rigFixture '{"ok":true,"messages":['"$rigMany"']}'
## Values and runs that cross the 256-byte chunk boundary in every way the walk handles.
rigLong="" ; rigI=0
while [ "$rigI" -lt 300 ] ; do rigLong="${rigLong}ab\\u00e9\\ud83d\\ude00\\n\\\"" ; rigI=$(( rigI + 1 )) ; done
rigFixture '{"ok":true,"a":"'"$rigLong"'","messages":[{"ts":"1","text":"'"$rigLong"'","blocks":["'"$rigLong"'"]}]}'
rigSpaces="$( printf '%600s' '' )"
rigFixture '{'"$rigSpaces"'"ok"'"$rigSpaces"':'"$rigSpaces"'true'"$rigSpaces"',"a":{"b":"v"'"$rigSpaces"'}}'"$rigSpaces"
rigFixture '{"ok":true,"a":"'"$( printf '%300s' '' | tr ' ' 'x' )"'\'

echo "-- $rigCase hand-written fixtures, every reader --"
rigI=1
while [ "$rigI" -le "$rigCase" ] ; do
	rigAll "$rigTmp/hand.$rigI.json"
	rigI=$(( rigI + 1 ))
done
printf '  %d compared so far, %d failing\n' "$(( rigPassCount + rigFailCount ))" "$rigFailCount"

## ---- generated fixtures ----------------------------------------------------------
## Park-Miller, exact in a double on every awk, so the same seed is the same set
## everywhere. Every 3rd document is mutated: cut short, a byte dropped, or one added;
## every 5th carries a second page on its own line, after a `## ` marker.
cat > "$rigTmp/gen.awk" <<'EOF'
function rnd(n) { seed = (seed * 16807) % 2147483647 ; return seed % n ; }
function pick(list,   parts, n) { n = split(list, parts, " ") ; return parts[1 + rnd(n)] ; }
function genStr(   n, i, out, k) {
	n = rnd(4) == 0 ? rnd(300) : rnd(10)
	out = ""
	for (i = 0 ; i < n ; i++) {
		k = rnd(28)
		if (k == 0) out = out "\\n"
		else if (k == 1) out = out "\\\""
		else if (k == 2) out = out "\\\\"
		else if (k == 3) out = out "\\u00e9"
		else if (k == 4) out = out "\\ud83d\\ude00"
		else if (k == 5) out = out "\\ud800"
		else if (k == 6) out = out "\\t\\r\\b\\f\\/"
		else if (k == 7) out = out "\\q"
		else if (k == 8) out = out "\\u20AC"
		else if (k == 9) out = out " "
		else if (k == 10) out = out "<@U1>"
		else if (k == 11) out = out "?thread_ts=1.5&x=y"
		else if (k == 12) out = out "]}{["
		else out = out substr("abcdefghijklmnop", k - 12, 1)
	}
	return "\"" out "\""
}
function ws() { k = rnd(6) ; return k == 0 ? " " : (k == 1 ? "\n  " : "") ; }
function genTs() { return "\"" rnd(10) "." rnd(1000000) "\"" ; }
function genScalar(   k) {
	k = rnd(7)
	if (k == 0) return genStr()
	if (k == 1) return rnd(2) ? "true" : "false"
	if (k == 2) return "null"
	if (k == 3) return (rnd(2) ? "-" : "") rnd(100000) (rnd(3) == 0 ? ".5e" rnd(9) : "")
	if (k == 4) return genTs()
	return genStr()
}
function genVal(depth,   k, n, i, out, key) {
	k = rnd(depth > 3 ? 4 : 9)
	if (k <= 3) return genScalar()
	if (k <= 6) {
		n = rnd(6) ; out = "{" ws()
		for (i = 0 ; i < n ; i++) {
			key = pick("ts ts user text bot_id reply_count latest_reply reply_users thread_ts reactions name count users blocks id is_im type permalink username metadata event_payload sender a b __count ok error args env command")
			out = out (i ? "," ws() : "") "\"" key "\"" ws() ":" ws() genVal(depth + 1)
		}
		return out ws() "}"
	}
	n = rnd(5) ; out = "[" ws()
	for (i = 0 ; i < n ; i++) out = out (i ? "," ws() : "") genVal(depth + 1)
	return out ws() "]"
}
function genMessages(   n, i, out) {
	n = rnd(5) ; out = "["
	for (i = 0 ; i < n ; i++) out = out (i ? "," : "") "{\"ts\":" genTs() ",\"user\":" genStr() ",\"text\":" genStr() (rnd(2) ? ",\"reply_count\":" rnd(3) ",\"latest_reply\":" genTs() : "") (rnd(2) ? ",\"reactions\":" genVal(3) : "") (rnd(3) == 0 ? ",\"x\":" genVal(2) : "") "}"
	return out "]"
}
function genDoc(   k, n, i, text) {
	k = rnd(6)
	if (k == 0) return "{\"ok\":" (rnd(4) ? "true" : "false") ",\"messages\":" genMessages() "}"
	if (k == 1) return "{\"ok\":true,\"channel\":{\"id\":\"D1\",\"is_im\":" (rnd(2) ? "true" : "false") ",\"user\":" genStr() ",\"latest\":" genVal(2) "}}"
	if (k == 2) return "{\"ok\":true,\"messages\":{\"total\":" rnd(9) ",\"paging\":{\"page\":1,\"pages\":" rnd(4) "},\"matches\":" genMessages() "}}"
	if (k == 3) return "{\"jsonrpc\":\"2.0\",\"id\":" (rnd(2) ? rnd(99) : genStr()) ",\"method\":" genStr() ",\"params\":{\"name\":" genStr() ",\"arguments\":" genVal(2) "}}"
	text = "{" ws()
	n = 1 + rnd(4)
	for (i = 0 ; i < n ; i++) text = text (i ? "," : "") "\"" pick("ok error messages channel a b id params") "\":" ws() genVal(1)
	return text "}"
}
BEGIN {
	seed = 20261007
	for (doc = 1 ; doc <= count ; doc++) {
		text = genDoc()
		if (doc % 3 == 0) {
			k = rnd(3) ; at = 1 + rnd(length(text))
			if (k == 0) text = substr(text, 1, at)
			else if (k == 1) text = substr(text, 1, at - 1) substr(text, at + 1)
			else text = substr(text, 1, at) substr("\"\\{}[],: tx0u", 1 + rnd(13), 1) substr(text, at + 1)
		}
		if (doc % 5 == 0) text = text "\n## dm=D" doc " identity=bot\n" genDoc()
		printf("%s\n", text) > (dir "/gen." doc ".json")
		close(dir "/gen." doc ".json")
	}
}
EOF
rigGenCount="${AGENTS_JSON_DIFF_COUNT:-150}"
LC_ALL=C awk -v dir="$rigTmp" -v count="$rigGenCount" -f "$rigTmp/gen.awk" || rigRefuse "the fixture generator did not run"
echo "-- $rigGenCount generated documents (every 3rd mutated, every 5th two pages), every reader --"
rigI=1
while [ "$rigI" -le "$rigGenCount" ] ; do
	rigAll "$rigTmp/gen.$rigI.json"
	rigI=$(( rigI + 1 ))
done

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ JSON ENGINE DIFF CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) comparison(s)" >&2 ; exit 1
fi
printf 'JSON_ENGINE_DIFF: OK (%d comparisons against the readers it replaced, offline)\n' "$rigPassCount"
