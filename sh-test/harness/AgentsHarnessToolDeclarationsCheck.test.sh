#!/usr/bin/env bash
## Behavioural check: the tool declarations parse the way each reader takes them (AgentsOpenAiChatWire.sh). The harness
## sources the file, so the literal is a single-quoted shell string; the MCP mirror reads its text with awk
## (AgentsHarnessMcpMirror.sh), which no quote can break. A quote that closes the string early, an ASCII apostrophe in a
## description above all, breaks the harness alone, while the mirror still answers. Held:
##   1. SOURCED: the file sources with nothing on stderr, and its declarations parse as a JSON list of tools
##   2. MIRRORED: the mirror's answer parses too
##   3. THE TWO AGREE: the same tool names, in the same order
##   4. THE CONTROL: a copy with one apostrophe written ASCII instead of ’ (U+2019) fails 1, so this check can fail
## Offline: nothing outside this rig's own temp folder is written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigWire="$rigHere/harness/AgentsOpenAiChatWire.sh"
rigMirror="$rigHere/harness/AgentsHarnessMcpMirror.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigWire" ] || rigRefuse "the tool declarations are not at the origin: $rigWire"
[ -f "$rigMirror" ] || rigRefuse "the MCP mirror is not at the origin: $rigMirror"
command -v python3 > /dev/null 2>&1 || rigRefuse "no python3 on this machine, which reads the JSON"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessToolDeclarationsCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 )) ; printf '  PASS  %s\n' "$1"
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigSourced(){ ## wire file, result name -- sources the file as the harness does, in a shell of its own; the JSON and stderr to files
	env -i PATH="/usr/bin:/bin" MDLT_ORIGIN="$MDLT_ORIGIN" harnessHere="$rigHere" bash -c '. "$1" ; printf "%s" "${harnessToolsJson:-}"' _ "$1" > "$rigTmp/$2.json" 2> "$rigTmp/$2.err"
}
rigNames(){ ## json file -- the tool names, one a line, or the word broken; a tool is the wire's {"function":{"name"}} or the mirror's {"name"}
	python3 -I -c 'import json, sys
try:
    tools = json.load( open( sys.argv[1] ) )
    print( "\n".join( ( t["function"] if "function" in t else t )["name"] for t in tools ) if tools else "broken" )
except Exception:
    print( "broken" )' "$1"
}

echo "-- 1. sourced, as the harness takes it --"
rigSourced "$rigWire" sourced
rigAssert "the declarations source with nothing on stderr" "$( wc -c < "$rigTmp/sourced.err" | tr -d ' ' )" "0"
rigNames "$rigTmp/sourced.json" > "$rigTmp/sourced.names"
rigAssert "they parse as a JSON list of tools" "$( LC_ALL=C grep -c -x -F broken "$rigTmp/sourced.names" || : ):$( [ "$( wc -l < "$rigTmp/sourced.names" )" -gt 0 ] && printf some || printf none )" "0:some"

echo "-- 2. mirrored, as the MCP server takes it --"
bash "$rigMirror" "$rigWire" > "$rigTmp/mirror.json" 2> "$rigTmp/mirror.err"
rigNames "$rigTmp/mirror.json" > "$rigTmp/mirror.names"
rigAssert "the mirror's answer parses" "$( LC_ALL=C grep -c -x -F broken "$rigTmp/mirror.names" || : )" "0"

echo "-- 3. the two readers agree --"
rigAssert "the same tool names, in the same order" "$( cmp -s "$rigTmp/sourced.names" "$rigTmp/mirror.names" && printf same || printf differ )" "same"

echo "-- 4. the control: one ASCII apostrophe breaks the sourced form --"
LC_ALL=C awk 'done == 0 && index( $0, "\342\200\231" ) { sub( /\342\200\231/, "\047" ) ; done = 1 ; } { print ; }' "$rigWire" > "$rigTmp/broken-wire.sh"
rigAssert "the copy holds one ASCII apostrophe more than the file" "$(( $( tr -cd "'" < "$rigTmp/broken-wire.sh" | wc -c ) - $( tr -cd "'" < "$rigWire" | wc -c ) ))" "1"
rigSourced "$rigTmp/broken-wire.sh" broken
rigAssert "the sourced copy no longer parses" "$( rigNames "$rigTmp/broken.json" | LC_ALL=C sed -n 1p )" "broken"

printf 'RESULT: %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
