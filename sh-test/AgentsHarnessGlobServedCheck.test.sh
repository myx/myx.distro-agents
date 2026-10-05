#!/usr/bin/env bash
## Behavioural check on Glob AS THE MCP SERVER SERVES IT: every call goes through the real
## server's tools/call, and every answer is read off the wire it writes. It covers `**/`
## recursion, a `/` pattern matching direct children only, a `/` pattern through a symlinked
## directory, oldest-first modification-time order, a missing directory, and the head part.
## Each gap assertion sits beside a control that passes on the tree before the fix, so a
## FAIL there is the gap and not a broken rig. Offline: MMDAPP and HOME are this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigField="$rigHere/AgentsHarnessJsonField.awk"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

for rigFile in "$rigHere/AgentsUniversalHarness.sh" "$rigField" "$rigTool" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

rigTmp="$( mktemp -d -t "AgentsHarnessGlobServedCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## `source/` is inside the access roots the server computes for a workspace; the rig root itself is not.
rigFix="$rigTmp/source/fix"
mkdir -p "$rigTmp/.local" "$rigFix/sub/deep" "$rigFix/ordered" "$rigTmp/source/elsewhere"
printf 'x\n' > "$rigFix/sub/deep/nest.txt"
printf 'x\n' > "$rigFix/sub/direct.txt"
printf 'x\n' > "$rigTmp/source/elsewhere/far.txt"
ln -s "$rigTmp/source/elsewhere" "$rigFix/link"
printf 'x\n' > "$rigFix/ordered/a.dat"
printf 'x\n' > "$rigFix/ordered/b.dat"
printf 'x\n' > "$rigFix/ordered/c.dat"
## Aged against the directory's own listing order, newest first, so oldest-first is its reverse:
## a walk that returns listing order fails whatever order this filesystem lists in.
rigAgeYear=2022
rigOldestFirst=''
while IFS= read -r rigAged ; do
	touch -t "${rigAgeYear}01010000" "$rigAged"
	rigOldestFirst="${rigAged##*/} $rigOldestFirst"
	rigAgeYear=$(( rigAgeYear - 1 ))
done <<< "$( find -L "$rigFix/ordered/" -name '*.dat' )"
rigOldestFirst="${rigOldestFirst% }"

rigGlob(){ ## request id, pattern, path -- one tools/call line
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"Glob","arguments":{"pattern":"%s","path":"%s"}}}\n' "$1" "$2" "$3"
}
{
	rigGlob 2 'nest.txt' "$rigFix"
	rigGlob 3 '**/nest.txt' "$rigFix"
	rigGlob 4 '*.txt' "$rigFix"
	rigGlob 5 'sub/*.txt' "$rigFix"
	rigGlob 6 'far.txt' "$rigFix"
	rigGlob 7 'link/*.txt' "$rigFix"
	rigGlob 8 '*.dat' "$rigFix/ordered"
	rigGlob 9 '*.txt' "$rigFix/missing"
	rigGlob 10 'su*' "$rigFix"
	rigGlob 11 '*' "$rigFix"
	rigGlob 12 'sub/*' "$rigFix"
	rigGlob 13 '' "$rigFix"
	printf '%s\n' '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"Glob","arguments":{"pattern":"nest.txt"}}}'
} | ( cd "$rigFix" && MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" HOME="$rigTmp/home" \
	bash "$rigTool" --intern-mcp-server --run ) > "$rigTmp/wire" 2> "$rigTmp/err" || :

## A request the server never answered was never exercised, so the run stops there.
for rigId in 2 3 4 5 6 7 8 9 10 11 12 13 14 ; do
	LC_ALL=C grep -q "^{\"jsonrpc\":\"2.0\",\"id\":$rigId," "$rigTmp/wire" || {
		echo "-- the server left request $rigId unanswered, so its stderr follows --" >&2
		sed 's/^/    /' "$rigTmp/err" >&2
		rigRefuse "no tools/call answer for request $rigId"
	}
done

rigWire(){ ## request id -- its raw response line
	LC_ALL=C grep -m1 "^{\"jsonrpc\":\"2.0\",\"id\":$1," "$rigTmp/wire"
}

rigPart(){ ## request id, json path under result.content -- the decoded value, empty when absent
	rigWire "$1" | LC_ALL=C awk -v path="result.content.$2" -v optional=1 -f "$rigField" 2>/dev/null || :
}

## The tool's own result: the last text part, since the head part goes first.
rigResult(){ ## request id
	local partIndex
	partIndex="$( rigPart "$1" __count )"
	partIndex=$(( ${partIndex:-0} - 1 ))
	while [ "$partIndex" -ge 0 ] ; do
		[ "$( rigPart "$1" "$partIndex.type" )" != text ] || { rigPart "$1" "$partIndex.text" ; return 0 ; }
		partIndex=$(( partIndex - 1 ))
	done
}

rigNames(){ ## request id, suffix -- basenames of result lines ending in it, in result order, space-joined
	local resultLine nameList=''
	while IFS= read -r resultLine ; do
		case "$resultLine" in *"$2") nameList="$nameList ${resultLine##*/}" ;; esac
	done <<< "$( rigResult "$1" )"
	printf '%s' "${nameList# }"
}

rigHas(){ ## text, needle -- yes when the text holds it
	case "$1" in *"$2"*) printf 'yes' ;; *) printf 'no' ;; esac
}

rigIsError(){ ## text -- yes when it is a refusal
	case "$1" in ERROR*) printf 'yes' ;; *) printf 'no' ;; esac
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

echo "-- **/ reaches a nested file --"
rigAssert "control: a bare name finds the nested file" "$( rigHas $'\n'"$( rigResult 2 )"$'\n' $'/sub/deep/nest.txt\n' )" "yes"
rigAssert "**/nest.txt finds the nested file" "$( rigHas $'\n'"$( rigResult 3 )"$'\n' $'/sub/deep/nest.txt\n' )" "yes"

echo "-- dir/*.ext matches direct children of dir only --"
rigAssert "control: *.txt finds the direct child" "$( rigHas $'\n'"$( rigResult 4 )"$'\n' $'/sub/direct.txt\n' )" "yes"
rigAssert "sub/*.txt matches sub/direct.txt and nothing deeper" "$( rigNames 5 .txt )" "direct.txt"

echo "-- a / pattern reaches into a symlinked directory --"
rigAssert "control: a bare name finds the file behind the link" "$( rigNames 6 .txt )" "far.txt"
rigAssert "link/*.txt finds the file behind the link" "$( rigNames 7 .txt )" "far.txt"

echo "-- results are ordered by modification time, oldest first --"
rigAssert "control: all three aged files are found" "$( rigNames 8 .dat | tr ' ' '\n' | LC_ALL=C sort | paste -sd ' ' - )" "a.dat b.dat c.dat"
rigAssert "the aged files come back oldest first" "$( rigNames 8 .dat )" "$rigOldestFirst"

echo "-- a missing directory is refused --"
rigAssert "a missing directory returns ERROR" "$( rigHas "ERROR-START$( rigResult 9 )" 'ERROR-STARTERROR' )" "yes"

echo "-- the separate request/result part is still produced --"
rigAssert "the head part leads the answer, names Glob and carries a result line" \
	"$( rigHas "$( rigWire 2 )" '"result":{"content":[{"type":"text","text":"   📁 Glob ' )$( rigHas "$( rigPart 2 0.text )" '      result ' )" "yesyes"

## "<result lines> <of them directories>" -- a result line is an absolute path.
rigDirCount(){ ## request id
	local resultLine lineTotal=0 dirTotal=0
	while IFS= read -r resultLine ; do
		case "$resultLine" in (/*) ;; (*) continue ;; esac
		lineTotal=$(( lineTotal + 1 ))
		[ ! -d "$resultLine" ] || dirTotal=$(( dirTotal + 1 ))
	done <<< "$( rigResult "$1" )"
	printf '%s %s' "$lineTotal" "$dirTotal"
}

echo "-- a pattern returns files, never directories --"
rigAssert "a pattern matching only a directory name returns nothing" "$( rigDirCount 10 )" "0 0"
rigAssert "and that is not an error" "$( rigIsError "$( rigResult 10 )" )" "no"
rigAssert "control: * still reaches the nested files" "$( rigHas $'\n'"$( rigResult 11 )"$'\n' $'/sub/deep/nest.txt\n' )" "yes"
rigAssert "* returns no directory, the searched one included" "$( rigDirCount 11 | cut -d' ' -f2 )" "0"
rigAssert "sub/* returns sub's file and not its folder" "$( rigNames 12 '' )" "direct.txt"
rigAssert "and that is not an error" "$( rigIsError "$( rigResult 12 )" )" "no"
rigAssert "control: an empty pattern still lists the directory, folders included" \
	"$( [ "$( rigDirCount 13 | cut -d' ' -f2 )" -gt 0 ] && printf listed || printf unlisted )" "listed"

echo "-- path defaults to the working directory --"
rigAssert "with no path, the working directory is searched" "$( rigHas $'\n'"$( rigResult 14 )"$'\n' $'/sub/deep/nest.txt\n' )" "yes"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ GLOB SERVED CHECK FAILED: $rigFails assertion(s)" >&2
	echo "  warn: Glob as the MCP server serves it does not yet match paths, follow" >&2
	echo "        links or order its results the way it was decided" >&2
	echo "  fix:  AgentsHarnessToolGlob in sh-lib/AgentsUniversalHarness.sh --" >&2
	echo "        never the assertion" >&2
	exit 1
fi
echo "HARNESS_GLOB_SERVED: OK (served Glob: **/ recursion, direct-child patterns, symlinked dirs, oldest-first order, missing dir, head part)"
