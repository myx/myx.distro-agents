#!/usr/bin/env bash
## Behavioural check that Write and Edit keep the end of a file byte for byte, AS THE MCP
## SERVER SERVES THEM: every call goes through the real server's tools/call. Covers content
## ending in one newline, in none and in two, and Edits on a file's last line that add,
## remove or keep its final newline. Offline: MMDAPP and HOME are this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

for rigFile in "$rigHere/AgentsUniversalHarness.sh" "$rigTool" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

rigTmp="$( mktemp -d -t "AgentsHarnessWriteExactCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"

## `.local/temp` is a write root the server computes for a workspace.
rigDir="$rigTmp/.local/temp/team"
mkdir -p "$rigDir"
printf 'a\nlast\n' > "$rigDir/e-keep"
printf 'a\nlast' > "$rigDir/e-add"
printf 'a\nlast\n' > "$rigDir/e-drop"

## Values are passed already JSON-escaped, so the format itself carries no backslash.
rigWrite(){ ## request id, file name, JSON-escaped content
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"Write","arguments":{"path":"%s","content":"%s"}}}\n' "$1" "$rigDir/$2" "$3"
}
rigEdit(){ ## request id, file name, JSON-escaped old_text, JSON-escaped new_text
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"Edit","arguments":{"path":"%s","old_text":"%s","new_text":"%s"}}}\n' "$1" "$rigDir/$2" "$3" "$4"
}
{
	rigWrite 2 w-inner 'a\nb'
	rigWrite 3 w-probe '# probe\nline two\n'
	rigWrite 4 w-none 'a'
	rigWrite 5 w-two 'a\n\n'
	rigEdit 6 e-keep 'last' 'LAST'
	rigEdit 7 e-add 'last' 'LAST\n'
	rigEdit 8 e-drop 'last\n' 'LAST'
} | ( cd "$rigTmp" && MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" HOME="$rigTmp/home" \
	bash "$rigTool" --intern-mcp-server --run ) > "$rigTmp/wire" 2> "$rigTmp/err" || :

## A request the server never answered was never exercised, so the run stops there.
for rigId in 2 3 4 5 6 7 8 ; do
	LC_ALL=C grep -q "^{\"jsonrpc\":\"2.0\",\"id\":$rigId," "$rigTmp/wire" || {
		echo "-- the server left request $rigId unanswered, so its stderr follows --" >&2
		sed 's/^/    /' "$rigTmp/err" >&2
		rigRefuse "no tools/call answer for request $rigId"
	}
done
## A refused write would leave every byte assertion below measuring a missing file.
[ -f "$rigDir/w-inner" ] || rigRefuse "the control Write did not land, so the rig cannot write here: $( LC_ALL=C grep -m1 '"id":2,' "$rigTmp/wire" )"

## Every byte, one character per field, so a newline shows as \n and nothing is trimmed.
rigBytes(){ ## file name
	od -An -c "$rigDir/$1" | tr -d ' \n'
}

rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFails=$(( rigFails + 1 ))
	fi
}

echo "-- Write --"
rigAssert "control: an inner newline is kept"           "$( rigBytes w-inner )" 'a\nb'
rigAssert "content ending in one newline keeps it"      "$( rigBytes w-probe )" '#probe\nlinetwo\n'
rigAssert "and is 17 bytes, as given"                   "$( wc -c < "$rigDir/w-probe" | tr -d ' ' )" 17
rigAssert "content with no final newline gains none"    "$( rigBytes w-none )" 'a'
rigAssert "content ending in two newlines keeps both"   "$( rigBytes w-two )" 'a\n\n'

echo "-- Edit on the last line --"
rigAssert "control: an edit before the final newline keeps it" "$( rigBytes e-keep )" 'a\nLAST\n'
rigAssert "new_text ending in a newline adds it"        "$( rigBytes e-add )" 'a\nLAST\n'
rigAssert "old_text ending in a newline removes it"     "$( rigBytes e-drop )" 'a\nLAST'

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ WRITE EXACT CHECK FAILED: $rigFails assertion(s)" >&2
	echo "  fix:  AgentsHarnessArgExact and its two callers in sh-lib/AgentsUniversalHarness.sh --" >&2
	echo "        never the assertion" >&2
	exit 1
fi
echo "HARNESS_WRITE_EXACT: OK (served Write and Edit: final newline kept, none added, two kept, last-line Edits exact)"
