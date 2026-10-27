#!/usr/bin/env bash
## Behavioural check on the D2 secondary-tool dispatch. The myx.distro MCP serves the seven
## secondary tools one-per-subsystem-file -- AgentsMcpSecondaryMirror.sh rendering the
## `agentsFrontSecondary` list of AgentsContext.FrontTable.include, each taking the operation
## as an argument so the served catalogue stays short. The mirror and the dispatch arm that
## runs them (AgentsTools.InternMcpRequest.include) landed already, but were manually verified
## only: no dedicated test held that (1) all seven are served with the {operation, args[],
## description} shape, (2) a cross-file operation is refused (DistroAgentsSlack cannot name
## --get-board-item), and (3) a valid operation routes into its own file's arm
## (DistroAgentsSlack + --slack-read reaches the Slack arm).
##
## Read OFF THE WIRE, from the real server's own tools/list and tools/call answers, the way
## AgentsHarnessServedFloorCheck.test.sh reads them -- never by re-applying the mirror here,
## which would only report that the two agree. The refusal and the routing are observed
## through a real server too: the refusal is the dispatcher's own error, and the routing is
## proven by the Slack arm's own diagnostic, reached before any network (the acting member's
## skill directory does not exist under the rig's skillset root, so nothing is fetched).
##
## Offline, and self-contained in its scratch. The root under test is MMDAPP, and the server's
## scratch is relocated onto this check's own fixture, so nothing is written outside it. The
## tree under test is whatever MDLT_ORIGIN names, so a red run needs the planted tree named
## there, not merely executed.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigField="$rigHere/harness/AgentsHarnessJsonField.awk"

## Refusing to report is this block's whole job: a run that exercised nothing must never
## print a pass, and an empty extraction is a fault here rather than a clean floor.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

for rigFile in "$rigTool" "$rigField" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMcpSecondaryToolCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The scenario IS the workspace for these runs. `.local` is what the server requires of it.
mkdir -p "$rigTmp/.local"

## The one JSON reader of this package, on the one line carrying a captured answer.
rigSlice(){ ## wire line file, json path, mode
	LC_ALL=C awk -v path="$2" -v mode="$3" -f "$rigField" < "$1" 2>/dev/null || :
}
rigValue(){ ## wire line file, json path -- decoded scalar, empty when absent
	LC_ALL=C awk -v path="$2" -v optional=1 -f "$rigField" < "$1" 2>/dev/null || :
}

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
		printf '  PASS  %s\n' "$1"
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

rigSecondaryNames="DistroAgentsSlack DistroAgentsAtlassian DistroAgentsGoogle DistroAgentsMail DistroAgentsTrello DistroAgentsContacts AgentDispatcherTools"

## The catalogue, off the server's own tools/list answer.
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
} | MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --intern-mcp-server --run > "$rigTmp/wire" 2> "$rigTmp/err" || :

LC_ALL=C grep '"id":2,' "$rigTmp/wire" > "$rigTmp/list" 2>/dev/null || :
[ -s "$rigTmp/list" ] || {
	echo "-- the server answered no tools/list, so its stderr follows --" >&2
	sed 's/^/    /' "$rigTmp/err" >&2
	rigRefuse "no catalogue was returned, so the served secondary tools were never observed"
}

## Every served name, in order, read the one way this package reads JSON.
: > "$rigTmp/names"
rigIdx=0
while : ; do
	rigName="$( rigSlice "$rigTmp/list" "result.tools.$rigIdx.name" raw )"
	[ -n "$rigName" ] || break
	rigName="${rigName#\"}" ; rigName="${rigName%\"}"
	printf '%s\n' "$rigName" >> "$rigTmp/names"
	rigIdx=$(( rigIdx + 1 ))
done

rigIndexOf(){ ## served tool name -- its index in the array, rc 1 when it is not served
	rigAt=0
	while : ; do
		rigAtName="$( rigSlice "$rigTmp/list" "result.tools.$rigAt.name" raw )"
		[ -n "$rigAtName" ] || return 1
		rigAtName="${rigAtName#\"}" ; rigAtName="${rigAtName%\"}"
		[ "$rigAtName" != "$1" ] || { printf '%s' "$rigAt" ; return 0 ; }
		rigAt=$(( rigAt + 1 ))
	done
}
rigPropsHolds(){ ## properties-keys block, key -- yes when it is one of them
	printf '%s\n' "$1" | LC_ALL=C grep -qx -- "$2" && printf yes || printf no
}
rigHolds(){ ## text, needle -- yes when the text holds the needle
	case "$1" in
		*"$2"*) printf yes ;;
		*)      printf no ;;
	esac
}

echo "-- the secondary tools, read off the server's own tools/list answer --"
rigAssert "the server answered with a tool catalogue" "$( [ -s "$rigTmp/names" ] && printf yes || printf no )" "yes"
for rigSec in $rigSecondaryNames ; do
	rigSecIdx="$( rigIndexOf "$rigSec" )" || { rigAssert "$rigSec is served" unserved served ; continue ; }
	rigAssert "$rigSec is served" served served
	rigProps="$( rigSlice "$rigTmp/list" "result.tools.$rigSecIdx.inputSchema.properties" keys )"
	rigAssert "$rigSec declares 'operation'"   "$( rigPropsHolds "$rigProps" operation )"   yes
	rigAssert "$rigSec declares 'args'"        "$( rigPropsHolds "$rigProps" args )"        yes
	rigAssert "$rigSec declares 'description'" "$( rigPropsHolds "$rigProps" description )" yes
	rigAssert "$rigSec's args is an array of strings" \
		"$( rigValue "$rigTmp/list" "result.tools.$rigSecIdx.inputSchema.properties.args.type" ):$( rigValue "$rigTmp/list" "result.tools.$rigSecIdx.inputSchema.properties.args.items.type" )" \
		"array:string"
	rigAssert "$rigSec requires 'operation'" \
		"$( rigValue "$rigTmp/list" "result.tools.$rigSecIdx.inputSchema.required.0" )" operation
done

## The dispatch, through a second run of the real server: one cross-file operation, refused
## by the dispatcher before anything runs, and one valid operation, routed into the Slack arm.
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	printf '%s\n' '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"DistroAgentsSlack","arguments":{"operation":"--get-board-item"}}}'
	printf '%s\n' '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"DistroAgentsSlack","arguments":{"operation":"--slack-read"}}}'
} | MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --intern-mcp-server --run > "$rigTmp/callwire" 2> "$rigTmp/callerr" || :

LC_ALL=C grep '"id":3,' "$rigTmp/callwire" > "$rigTmp/cross" 2>/dev/null || :
LC_ALL=C grep '"id":4,' "$rigTmp/callwire" > "$rigTmp/valid" 2>/dev/null || :
[ -s "$rigTmp/cross" ] || rigRefuse "the cross-file call was never answered, so the refusal was never observed"
[ -s "$rigTmp/valid" ] || rigRefuse "the valid call was never answered, so the routing was never observed"

rigCrossMsg="$( rigValue "$rigTmp/cross" error.message )"
rigValidText="$( rigValue "$rigTmp/valid" result.content.0.text )"

echo "-- the cross-file refusal and the routing, through the real server --"
rigAssert "a cross-file operation is refused" \
	"$( rigHolds "$rigCrossMsg" 'not an operation of that tool file' )" yes
rigAssert "the refusal names the foreign operation" \
	"$( rigHolds "$rigCrossMsg" '--get-board-item' )" yes
rigAssert "the valid call is not refused as cross-file" \
	"$( rigHolds "$rigValidText" 'not an operation of that tool file' )" no
rigAssert "the valid call reached the Slack arm" \
	"$( rigHolds "$rigValidText" '--slack-read:' )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SECONDARY TOOL DISPATCH CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
printf 'MCP_SECONDARY_TOOL_DISPATCH: OK (%d assertions, offline)\n' "$rigPassCount"
