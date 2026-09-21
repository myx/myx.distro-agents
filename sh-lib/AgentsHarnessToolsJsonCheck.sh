#!/usr/bin/env bash
set -e

## AgentsHarnessToolsJsonCheck.sh -- the tools declaration literal is valid JSON,
## and every declaration in it is reachable BY THE PARSER rather than only by a
## text match. Issues no request and touches no host.
##
## WHY THIS EXISTS, measured rather than supposed: a missing comma between two
## declarations in `harnessToolsJson` passes the ENTIRE existing check pass.
## `bash -n` is clean, because the literal is bash single-quoted and the shell
## never parses its contents. `AgentsHarnessSelfCheck.awk` reports
## `OK (N tools, four sites each)` and exits 0, because it matches the envelope as
## TEXT and does not parse. The defect then surfaces only as a 400 from the live
## endpoint, which the harness prints as a refused request -- so it reads as an API
## or credential fault rather than as a local edit, which is the worst shape a
## defect takes. A structural count cannot see a syntactic break inside the thing
## it is counting; this is that blind spot closed one layer down.
##
## TWO SEPARATE ASSERTIONS LIVE HERE, AND THEY CATCH DIFFERENT DEFECTS. Do not
## read either as the backstop of the other.
##
## 1. THE PER-ELEMENT PARSE is what catches a missing comma. The walk asks the
##    parser for each element in turn, so a merge is refused at element 0 and the
##    counts below are never reached. Measured: that is the branch a
##    missing-comma fixture actually fires, every time.
##
## 2. THE COUNT COMPARISON catches something else entirely, and the direction
##    that fires is PARSED > TEXT, never the reverse. `AgentsHarnessSelfCheck.awk`
##    finds a declaration by the literal text `{"type":"function","function":{"name":"`
##    and by nothing else, so a declaration written with its keys in another order
##    is VALID JSON that the endpoint accepts and the model sees, while that check
##    cannot see it at all. For a NEW tool added that way the site check never
##    learns the tool exists, so it never reports the missing announce arm,
##    dispatch arm or function -- the exact "declared but not implemented" class
##    it exists to catch, walking straight past it. Measured on a fixture that
##    reorders one declaration: 11 parsed against 10 text envelopes, this FAILs,
##    and the site check reports only that one already-implemented tool lost its
##    declared site.
##
##    The opposite direction, TEXT > PARSED, has no constructed case. Prose in a
##    description cannot inflate the text count, because valid JSON escapes an
##    inner quote as \" and the envelope pattern matches only the raw form. It is
##    kept as a genuine backstop rather than deleted: no case is not the same as
##    no case existing, and the counts are already in hand either way.
##
## Parsed through AgentsHarnessJsonSlice.awk, which is not the reader the harness
## runs its own responses through -- a literal validated by the same code that
## consumes it proves only that the two agree.

checkHere="$( cd "$( dirname -- "$0" )" && pwd )"
checkWire="${1:-$checkHere/AgentsOpenAiChatWire.sh}"
checkSliceAwk="$checkHere/AgentsHarnessJsonSlice.awk"

if [ ! -f "$checkWire" ] ; then
	echo "HARNESS_TOOLS_JSON: FAIL"
	echo "  warn: no wire adapter to read at $checkWire"
	echo "  fix:  pass the wire adapter path, or run this from the package sh-lib"
	exit 1
fi
if [ ! -f "$checkSliceAwk" ] ; then
	echo "HARNESS_TOOLS_JSON: FAIL"
	echo "  warn: the JSON slice reader is missing from this package: $checkSliceAwk"
	echo "  fix:  re-run this workspace's own release step to restore sh-lib"
	exit 1
fi

## The literal, lifted out between its own opening and closing quote. The quote
## travels as an awk variable rather than through three layers of shell quoting.
checkToolsJson="$( LC_ALL=C awk -v q="'" '
	index($0, "harnessToolsJson=" q) == 1 {
		inLiteral = 1
		print substr($0, length("harnessToolsJson=" q) + 1)
		next ;
	}
	inLiteral && $0 == "]" q { print "]" ; exit ; }
	inLiteral { print ; }
' "$checkWire" )"

if [ -z "$checkToolsJson" ] ; then
	echo "HARNESS_TOOLS_JSON: FAIL"
	echo "  warn: no harnessToolsJson literal was extracted from ${checkWire##*/} --"
	echo "        an extraction that matched nothing must never read as a clean run"
	echo "  fix:  check that the literal still opens with harnessToolsJson='["
	exit 1
fi

## What the self-check sees: envelopes matched as text, never parsed.
checkTextCount="$( printf '%s\n' "$checkToolsJson" | LC_ALL=C awk '
	{ envelopeCount += gsub(/\{"type":"function","function":\{"name":"/, "&") }
	END { print envelopeCount + 0 ; }
' )"

## The slice reader takes an object at top level, so the array is given one.
checkDoc="{\"tools\":$checkToolsJson}"

checkIndex=0
checkNames=""
while : ; do
	checkRc=0
	printf '%s' "$checkDoc" | LC_ALL=C awk -v path="tools.$checkIndex.function" -v mode=keys -f "$checkSliceAwk" >/dev/null 2>&1 || checkRc=$?
	case "$checkRc" in
		0) ;;
		3) break ;;
		*)
			echo "HARNESS_TOOLS_JSON: FAIL"
			echo "  warn: the harnessToolsJson literal in ${checkWire##*/} is NOT VALID JSON"
			echo "        -- the parser refused it (rc=$checkRc) while reading element $checkIndex."
			echo "        Nothing else in the check pass can see this: bash -n is clean because"
			echo "        the literal is single-quoted, and the site check matches text without"
			echo "        parsing. It reaches the model as a 400 the harness prints as a refused"
			echo "        request, which reads as an API or credential fault."
			echo "  fix:  repair the JSON -- most often a missing comma between two declarations"
			exit 1
		;;
	esac
	checkName="$( printf '%s' "$checkDoc" | LC_ALL=C awk -v path="tools.$checkIndex.function.name" -v mode=raw -f "$checkSliceAwk" 2>/dev/null )" || checkName=""
	checkName="${checkName//\"/}"
	if [ -z "$checkName" ] ; then
		echo "HARNESS_TOOLS_JSON: FAIL"
		echo "  warn: declaration $checkIndex parses but carries no function.name, so the model"
		echo "        is offered a tool it cannot call and no site check would notice"
		echo "  fix:  give that declaration its own \"name\""
		exit 1
	fi
	checkNames="$checkNames $checkName"
	checkIndex=$(( checkIndex + 1 ))
done

if [ "$checkIndex" = "0" ] ; then
	## An empty population cannot fail, so it is a FAIL rather than a pass --
	## the same rule AgentsHarnessSelfCheck.awk holds itself to.
	echo "HARNESS_TOOLS_JSON: FAIL"
	echo "  warn: the literal parsed but declares no tools at all"
	echo "  fix:  check that the array still holds one object per tool"
	exit 1
fi

## The assertion the whole file exists for. The two directions are DIFFERENT
## DEFECTS and are never reported alike -- a message naming a missing comma over
## a literal that has one too many declarations sends the reader to the wrong
## place, which is worse than reporting the counts and stopping.
if [ "$checkTextCount" -gt "$checkIndex" ] ; then
	echo "HARNESS_TOOLS_JSON: FAIL"
	echo "  warn: $checkTextCount declaration envelope(s) are present as TEXT, but the parser"
	echo "        reaches only $checkIndex. Declarations have merged -- a missing comma between"
	echo "        two of them is what does this. The site check counts the text and reports"
	echo "        OK; the endpoint reads the parse and returns 400."
	echo "  fix:  add the missing comma between the declarations"
	exit 1
fi
if [ "$checkIndex" -gt "$checkTextCount" ] ; then
	echo "HARNESS_TOOLS_JSON: FAIL"
	echo "  warn: $checkIndex declaration(s) parse, but only $checkTextCount carry the exact envelope"
	echo "        AgentsHarnessSelfCheck.awk matches. That check finds a declaration by the"
	echo "        literal text {\"type\":\"function\",\"function\":{\"name\":\" and nothing else, so a"
	echo "        declaration written with its keys in another order is VALID JSON that goes"
	echo "        on the wire while being INVISIBLE to the site check -- and a NEW tool added"
	echo "        that way is never reported as missing its announce arm, its dispatch arm or"
	echo "        its function, because the site check never learns the tool exists at all."
	echo "  fix:  write every declaration with \"type\" first and \"function\" second, so the"
	echo "        site check can see it -- or change what that check matches, in both places"
	exit 1
fi

printf 'HARNESS_TOOLS_JSON: OK (%d declarations parse, text and parser agree)\n' "$checkIndex"
printf '  tools:%s\n' "$checkNames"
exit 0
