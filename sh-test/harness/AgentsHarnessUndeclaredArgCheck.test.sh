#!/usr/bin/env bash
## Behavioural check: a harness tool refuses a parameter its declaration does not name, and does nothing (AgentsHarnessRunTool,
## AgentsHarnessToolArgNames.awk). Through the real served tool (--intern-tool), in a session of the rig's own. Held:
##   1. CHECKLIST: operation and text are refused by name, with the tool's own parameters, and no item is written
##   2. ITS CONTROL: append and member, declared, with nested items, still write the item
##   3. A TOOL NOT AN ASK: ListAgents refuses an undeclared key by name; the same call without it is answered
##   4. THE CACHE: the first call writes the names to $MMDAPP/.local/temp/mdat-harness-tool-args, the wire's path first
##   5. A FRESH CACHE IS READ AS IT STANDS, and one older than the wire, or of another origin, is built again
## Offline: every tree is this rig's own; no network is reached.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessUndeclaredArgCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/data" "$rigTmp/skills/keeper-rig" || exit 1
printf '%s\n' keeper-rig > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"

rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 )) ; printf '  PASS  %s\n' "$1"
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigCall(){ ## tool, the JSON arguments -- the tool's whole answer
	( cd "$rigWs" && printf '%s' "$2" | env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SESSION_ID=rig-session MDAT_SPAWN_SESSION_ID=rig-session \
		MDAT_SPAWN_AGENT=keeper-rig MDAT_SKILLSET_ROOT="$rigTmp/skills" bash "$rigHarness" --intern-tool "$1" 2> /dev/null )
}
rigCount(){ ## text, fixed string -- the lines of the text holding it
	printf '%s\n' "$1" | LC_ALL=C awk -v want="$2" 'BEGIN { c = 0 ; } index($0, want) { c++ ; } END { print c ; }'
}

echo "-- 1. CheckList: operation and text are refused --"
rigOut="$( rigCall CheckList '{"operation":"append","text":"write the check"}' )"
rigAssert "the call is refused, naming both keys" "${rigOut%%:*}:$( rigCount "$rigOut" 'ERROR: CheckList: operation is not a parameter of CheckList. Nor are: text.' )" "ERROR:1"
rigAssert "the refusal names the tool's own parameters" "$( rigCount "$rigOut" 'todos member append session' )" 1
rigOut="$( rigCall CheckList '{}' )"
rigAssert "no item was written" "$( rigCount "$rigOut" 'write the check' ):$( rigCount "$rigOut" '(empty)' )" "0:1"

echo "-- 2. its control: declared keys still write --"
rigOut="$( rigCall CheckList '{"append":["write the check"],"member":"keeper-rig"}' )"
rigAssert "append with member is answered OK" "${rigOut%%:*}" "OK"
rigOut="$( rigCall CheckList '{}' )"
rigAssert "the item stands on the list" "$( rigCount "$rigOut" '- [ ] write the check' )" 1

echo "-- 3. a tool that is not an ask: ListAgents --"
rigOut="$( rigCall ListAgents '{"view":"agents","bogus":"1"}' )"
rigAssert "an undeclared key is refused by name" "${rigOut%%:*}:$( rigCount "$rigOut" 'ERROR: ListAgents: bogus is not a parameter of ListAgents. Its parameters are:' )" "ERROR:1"
rigOut="$( rigCall ListAgents '{"view":"agents"}' )"
rigAssert "the same call without it is answered" "$( rigCount "$rigOut" 'is not a parameter of' ):$( rigCount "$rigOut" 'ERROR' )" "0:0"

echo "-- 4. the cache --"
rigCache="$rigWs/.local/temp/mdat-harness-tool-args"
rigCacheFrom="" ; [ ! -f "$rigCache" ] || { IFS= read -r rigCacheFrom < "$rigCache" ; } || :
rigAssert "the cache names the wire it was read from, first" "$rigCacheFrom" "$rigHere/harness/AgentsOpenAiChatWire.sh"
rigAssert "and holds the CheckList row" "$( [ -f "$rigCache" ] && LC_ALL=C awk -F '\t' '$1 == "CheckList" { print $2 ; }' "$rigCache" )" "background timeout timeout_action sync async todos member append session description"

echo "-- 5. a fresh cache is read; an old one, or another origin's, is built again --"
printf '%s\n%s\t%s\n' "$rigHere/harness/AgentsOpenAiChatWire.sh" ListAgents "view bogus" > "$rigCache"
rigOut="$( rigCall ListAgents '{"view":"agents","bogus":"1"}' )"
rigAssert "a fresh cache that names bogus lets bogus through" "$( rigCount "$rigOut" 'is not a parameter of' )" 0
printf '%s\n%s\t%s\n' "$rigHere/harness/AgentsOpenAiChatWire.sh" ListAgents "view bogus" > "$rigCache"
touch -t 200001010000 "$rigCache"
rigOut="$( rigCall ListAgents '{"view":"agents","bogus":"1"}' )"
rigAssert "the same cache, older than the wire, is built again and bogus refused" "$( rigCount "$rigOut" 'ERROR: ListAgents: bogus is not a parameter of ListAgents.' )" 1
printf '%s\n%s\t%s\n' "/elsewhere/AgentsOpenAiChatWire.sh" ListAgents "view bogus" > "$rigCache"
rigOut="$( rigCall ListAgents '{"view":"agents","bogus":"1"}' )"
rigAssert "a fresh cache of another origin is built again and bogus refused" "$( rigCount "$rigOut" 'ERROR: ListAgents: bogus is not a parameter of ListAgents.' )" 1
rigAssert "and the cache it wrote is this origin's" "$( IFS= read -r rigCacheFrom < "$rigCache" ; printf '%s' "$rigCacheFrom" )" "$rigHere/harness/AgentsOpenAiChatWire.sh"

printf 'RESULT: %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
