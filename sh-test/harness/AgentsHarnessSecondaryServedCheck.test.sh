#!/usr/bin/env bash
## AgentsHarnessSecondaryServedCheck.test.sh -- the twelve tool files `agentsFrontSecondary` names are
## served on the harness wire itself, each taking the operation as its argument, in the shape the
## myx.distro MCP already serves them (sketch 3.1, line 130: every served MCP call and every leg run
## publishes the full session tool set up front). Before this, the harness named them only in the
## unserved list, so a leg run with no MCP server had no Slack, no Atlassian, no items, no asks.
##
## Read off the tree under test in four ways, because each catches a different half-built state.
##
## 1. THE DECLARATION, through the JSON reader the harness reads its own answers with, one element at
##    a time. A name grepped out of the file proves the text is there, not that the endpoint can parse
##    it -- and an unparseable literal reaches the model as a 400 the harness prints as a refused call.
## 2. THE ARMS, one dispatch and one announce for each name, so a name on the wire is never one the
##    harness has no way to run or to show.
## 3. THE RUN, through AgentsHarnessToolSecondary against the real tool file: the operation taken from
##    `operation`, its words from `args`, and the tool file's own output back.
## 4. THE PARITY, the same twelve served over MCP by AgentsMcpSecondaryMirror.sh: one list, both sides.
##
## And the unserved list, which must no longer carry them: a tool served and listed as unserved at once
## is the contradiction the two halves of the old design met in.
##
## Offline, and self-contained in its scratch. The tree under test is whatever MDLT_ORIGIN names.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"

rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigWire="$rigHere/harness/AgentsOpenAiChatWire.sh"
rigRun="$rigHere/harness/AgentsHarnessRun.include"
rigSlice="$rigHere/harness/AgentsHarnessJsonField.awk"
rigMirror="$rigHere/mcp/AgentsMcpSecondaryMirror.sh"
rigFront="$rigHere/harness/AgentsContext.FrontTable.Help.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

for rigFile in "$rigWire" "$rigRun" "$rigSlice" "$rigMirror" "$rigFront" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessSecondaryServedCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The one list both sides read, from the table that routes the operations: not a second copy here.
rigNames="$( ( . "$rigFront" ; printf '%s\n' "$agentsFrontSecondary" ) )"
[ -n "$rigNames" ] || rigRefuse "agentsFrontSecondary declares no tool file, so this check would exercise nothing"

## The literal, lifted out between its own opening and closing quote, exactly as the mirror lifts it.
rigToolsJson="$( LC_ALL=C awk -v q="'" '
	index($0, "harnessToolsJson=" q) == 1 {
		inLiteral = 1
		print substr($0, length("harnessToolsJson=" q) + 1)
		next ;
	}
	inLiteral && $0 == "]" q { print "]" ; exit ; }
	inLiteral { print ; }
' "$rigWire" )"
[ -n "$rigToolsJson" ] || rigRefuse "no harnessToolsJson literal was extracted from ${rigWire##*/} -- an extraction that matched nothing must never read as a clean run"
printf '{"tools":%s}' "$rigToolsJson" > "$rigTmp/doc"

## Every name the parser reaches, one a line. A literal the parser refuses stops the run as a fault of
## its own, never as an empty population.
rigDeclared=""
rigAt=0
while : ; do
	rigReadRc=0
	rigName="$( LC_ALL=C awk -v path="tools.$rigAt.function.name" -v mode=raw -f "$rigSlice" < "$rigTmp/doc" 2> /dev/null )" || rigReadRc=$?
	case "$rigReadRc" in
		0) ;;
		3) break ;;
		*) rigRefuse "the harnessToolsJson literal in ${rigWire##*/} is not valid JSON: the parser refused it at element $rigAt (rc=$rigReadRc)" ;;
	esac
	rigName="${rigName//\"/}"
	[ -z "$rigName" ] || rigDeclared="$rigDeclared $rigName"
	rigAt=$(( rigAt + 1 ))
done
[ "$rigAt" -gt 0 ] || rigRefuse "the literal parsed and declared no tool at all, so there is nothing to check against"

## Every name served over MCP, from the mirror the server renders its own catalogue with.
rigMcpNames="$( bash "$rigMirror" 2>/dev/null | LC_ALL=C awk '
	{ line = $0 ; while (match(line, /\{"name":"[A-Za-z]+"/)) { part = substr(line, RSTART, RLENGTH) ; sub(/.*"name":"/, "", part) ; sub(/"$/, "", part) ; print part ; line = substr(line, RSTART + RLENGTH) } }
' )"
## One name a word, so the membership test below reads both lists the same way. An empty mirror is not
## a rig that could not reach its subject: the mirror is half of what the parity assertion is about, so
## it fails there rather than stopping the run.
rigMcpNames="$( printf '%s' "$rigMcpNames" | LC_ALL=C tr '\n' ' ' )"

rigMissingOnWire=""
rigMissingOnMcp=""
for rigWant in $rigNames ; do
	case " $rigDeclared " in *" $rigWant "*) ;; *) rigMissingOnWire="$rigMissingOnWire $rigWant" ;; esac
	case " $rigMcpNames " in *" $rigWant "*) ;; *) rigMissingOnMcp="$rigMissingOnMcp $rigWant" ;; esac
done

echo "-- 1. the twelve are declared on the harness wire, parsed rather than matched as text --"
rigAssert "every tool file agentsFrontSecondary names is declared on the harness wire" "[${rigMissingOnWire# }]" "[]"

echo "-- 2. and each has the arm that runs it and the arm that shows it --"
rigDispatchMissing=""
rigAnnounceMissing=""
for rigWant in $rigNames ; do
	LC_ALL=C grep -q -F -e "${rigWant}) harnessResult=\"\$( AgentsHarnessToolSecondary ${rigWant} " "$rigRun" || rigDispatchMissing="$rigDispatchMissing $rigWant"
	LC_ALL=C grep -q -E -e "^[[:space:]]+${rigWant}\)[[:space:]]*$" "$rigRun" || rigAnnounceMissing="$rigAnnounceMissing $rigWant"
done
rigAssert "every one of them has a dispatch arm calling the shared handler" "[${rigDispatchMissing# }]" "[]"
rigAssert "every one of them has an announce arm" "[${rigAnnounceMissing# }]" "[]"

echo "-- 3. a secondary call runs the operation in the tool file that is the tool --"
rigCall(){ ## tool file, arguments JSON -- the handler's own output
	(
		harnessHere="$rigHere" ; harnessAgent="magic-developer" ; harnessScratch="$rigTmp"
		MDLT_ORIGIN="$MDLT_ORIGIN" ; MMDAPP="$rigTmp"
		harnessArgParsed=0 ; harnessArgRaw="" ; harnessArgPaths=() ; harnessArgEncs=()
		. "$rigRun"
		AgentsHarnessToolSecondary "$1" "$2"
	) 2>&1
}
rigSaid(){ ## text, fixed string -- yes or no, so a count the rig cannot pin still asserts something
	case "$1" in *"$2"*) printf 'yes' ;; *) printf 'no' ;; esac
}
rigAssert "the operation named in operation runs, and the tool file's own output comes back" \
	"$( rigSaid "$( rigCall DistroAgentsTesting '{"operation":"--help-syntax"}' )" 'DistroAgentsTesting.fn.sh --' )" "yes"
rigAssert "the words in args reach the operation, in order" \
	"$( rigSaid "$( rigCall DistroAgentsKnowledge '{"operation":"--help-syntax","args":["--list-places"]}' )" 'DistroAgentsKnowledge.fn.sh --list-places' )" "yes"
rigAssert "a call with no operation is refused, naming what it takes" \
	"$( rigSaid "$( rigCall DistroAgentsKnowledge '{}' )" 'requires a non-empty operation' )" "yes"
rigAssert "a tool file the package does not hold is refused rather than run" \
	"$( rigSaid "$( rigCall DistroAgentsNonesuch '{"operation":"--anything"}' )" 'no tool file DistroAgentsNonesuch.fn.sh' )" "yes"

echo "-- 4. one list, both sides: the same twelve are served over MCP --"
rigAssert "every tool of the twelve the harness serves is served over MCP too" "[${rigMissingOnMcp# }]" "[]"

echo "-- 5. and none of them is still listed as unserved in the harness --"
rigUnserved="$( ( . "$rigHere/harness/AgentsHarnessUnserved.include" ; AgentsToolsUnservedInHarness ) 2>/dev/null )"
rigStillUnserved=""
for rigWant in $rigNames ; do
	case " $( printf '%s' "$rigUnserved" | LC_ALL=C tr '\n' ' ' ) " in *" $rigWant "*) rigStillUnserved="$rigStillUnserved $rigWant" ;; esac
done
rigAssert "no tool of agentsFrontSecondary is in the harness's unserved list" "[${rigStillUnserved# }]" "[]"
rigAssert "and the list still carries RootSession, which the harness really does not serve" \
	"$( printf '%s' "$rigUnserved" | LC_ALL=C grep -c -x 'RootSession' )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS SECONDARY SERVED CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_SECONDARY_SERVED: OK (%d assertions, offline)\n' "$rigPassCount"
exit 0
