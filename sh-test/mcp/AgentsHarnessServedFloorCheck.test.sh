#!/usr/bin/env bash
## Behavioural check on WHAT THE MCP SERVER ACTUALLY SERVES. A harness tool joins the
## served floor by default -- the mirror renders the whole wire and the served set is a
## subtraction, `mcpUnservedToolNames`, which is a list somebody has to remember. Nothing
## asked whether a new tool belonged on it: the site check counts a tool's four structural
## sites, the tools-JSON check parses its declaration, and the mirror renders it by design.
## `Monitor` reached the floor that way, where it could not work at all -- the command ran,
## no scratch survived the call, and the job was left running with its log already deleted.
##
## THE RULE, in two forms, because the first is evadable and the second is not:
##   1. No HARNESS TOOL on the served floor declares a `command` argument. That is the rule
##      as written in AgentsTools.InternMcpRequest.include and in MAGIC.md, and it is
##      NAME-BASED: a tool running arbitrary code under `script`, `cmd` or `shell` passes it
##      untouched.
##   2. No harness tool on the served floor is one whose own function in the core executes a
##      caller-supplied string as a shell command. That is read off the core, not off a
##      parameter name, so renaming the parameter does not evade it.
## Both are asserted. The first is what a reader of the rule expects to be held; the second
## is what the rule is for.
##
## THE SCOPE IS THE HARNESS TOOLS, not everything served, and that is load-bearing rather
## than a hedge. `execute` is served and declares a `command` of its own, deliberately: it
## IS the sanctioned execution method here, which is the whole reason `Bash` is subtracted
## and callers are sent to it instead. Written over the served set as a whole, rule 1 is
## false against a design that is correct. The candidate population is therefore the floor
## the mirror renders, and `execute` falls outside it by construction rather than by being
## remembered as an exception.
## A served entry is a harness tool only when it matches the mirror's own rendering of that
## name, so a server-own tool sharing a harness name falls outside it too.
##
## NOT REACHED, and this is a limit rather than an omission: the other half of the
## documented test -- a tool handing back a handle only its own process can resolve. That
## is a fact about process lifetime, visible in neither a declaration nor a source scan.
## A future tool minting a process-local handle and taking no command would pass this
## check and still be unservable.
##
## The served set is read OFF THE WIRE, from the real server's own `tools/list` answer,
## rather than by re-applying the subtraction here: a check that recomputes what it is
## checking reports the two agree and nothing more.
##
## Offline, and self-contained in its scratch. The root under test is MMDAPP, and it is
## relocated onto this check's own fixture, so the server's scratch stays inside there and
## nothing is written outside it, with no gate stubbed. The tree under test is whatever
## MDLT_ORIGIN names, so a red run needs the planted tree named there, not merely executed.
set -u
## This check holds the numbered-job path of a server that has no session to own a task (epic S20: with a session, execute is a task underneath, held by
## AgentsMcpToolTaskCheck). The session of the machine running the check must not reach the server.
export MDAT_TOOL_TASK_OFF=yes
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-reply.include.sh" || { echo "⛔ ERROR: the rig's reply fixture is missing from the package: sh-test/check-fixtures/rig-reply.include.sh -- refusing to report a result" >&2 ; exit 1 ; }
rigCore="$rigHere/harness/AgentsUniversalHarness.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-harness-text.include.sh" || exit 1
rigSlice="$rigHere/harness/AgentsHarnessJsonField.awk"
rigMirror="$rigHere/harness/AgentsHarnessMcpMirror.sh"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigField="$rigHere/harness/AgentsHarnessJsonField.awk"

## Refusing to report is this block's whole job: a run that exercised nothing must never
## print a pass, and an empty extraction is a fault here rather than a clean floor.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

for rigFile in "$rigCore" "$rigSlice" "$rigMirror" "$rigTool" "$rigField" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessServedFloorCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The scenario IS the workspace for this run. `.local` is what the server requires of it.
mkdir -p "$rigTmp/.local"

{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
} | MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --intern-mcp-server --run > "$rigTmp/wire" 2> "$rigTmp/err" || :

## The one line carrying the catalogue, selected by its own id rather than by position.
LC_ALL=C grep '"id":2' "$rigTmp/wire" > "$rigTmp/list" 2>/dev/null || :
[ -s "$rigTmp/list" ] || {
	echo "-- the server answered no tools/list, so its stderr follows --" >&2
	sed 's/^/    /' "$rigTmp/err" >&2
	rigRefuse "no catalogue was returned, so the served set was never observed"
}

rigSliceRead(){ ## json path, mode -- reads the recorded catalogue
	LC_ALL=C awk -v path="$1" -v mode="$2" -f "$rigSlice" < "$rigTmp/list" 2>/dev/null || :
}

## The candidate population: the harness tool floor as the mirror renders it, which is what
## a tool joins by default. Read here rather than taken from the catalogue, so `execute` --
## the server's own tool, which no mirror declares -- is outside the scope by construction.
bash "$rigMirror" > "$rigTmp/mirror.json" 2>/dev/null || :
{ printf '{"t":' ; cat "$rigTmp/mirror.json" ; printf '}' ; } > "$rigTmp/mirror.obj"
LC_ALL=C awk '
	{
		while ( match( $0, /\{"name":"[A-Za-z]+"/ ) ) {
			toolName = substr( $0, RSTART + 9, RLENGTH - 10 )
			print toolName
			$0 = substr( $0, RSTART + RLENGTH ) ;
		}
	}
' "$rigTmp/mirror.json" > "$rigTmp/mirror"

## Every served name, and beside each one -- where it is a harness tool -- whether its own
## schema declares `command`.
## A harness tool by its declaration, not its name: the served entry must equal the mirror's
## own rendering, or a server-own tool sharing that name would be counted as one.
: > "$rigTmp/served" ; : > "$rigTmp/commanded" ; : > "$rigTmp/harness"
rigIndex=0
while : ; do
	rigName="$( rigSliceRead "result.tools.$rigIndex.name" raw )"
	[ -n "$rigName" ] || break
	rigName="${rigName#\"}" ; rigName="${rigName%\"}"
	printf '%s\n' "$rigName" >> "$rigTmp/served"
	rigIndex=$(( rigIndex + 1 ))
	LC_ALL=C grep -qx -- "$rigName" "$rigTmp/mirror" || continue
	rigAt="$( LC_ALL=C grep -nx -- "$rigName" "$rigTmp/mirror" | head -n 1 | cut -d: -f1 )"
	rigAt=$(( rigAt - 1 ))
	[ "\"$rigName\"" = "$( LC_ALL=C awk -v path="t.$rigAt.name" -v mode=raw -f "$rigSlice" < "$rigTmp/mirror.obj" 2>/dev/null )" ] \
		|| rigRefuse "the mirror's name list is out of step with its own entries at $rigName"
	[ "$( LC_ALL=C awk -v path="t.$rigAt" -v mode=raw -f "$rigSlice" < "$rigTmp/mirror.obj" 2>/dev/null )" = "$( rigSliceRead "result.tools.$(( rigIndex - 1 ))" raw )" ] || continue
	printf '%s\n' "$rigName" >> "$rigTmp/harness"
	rigSliceRead "result.tools.$(( rigIndex - 1 )).inputSchema.properties" keys > "$rigTmp/props"
	! LC_ALL=C grep -qx 'command' "$rigTmp/props" || printf '%s\n' "$rigName" >> "$rigTmp/commanded"
done

## The tools whose own function executes a caller-supplied string as a shell command, read
## off the core. Attribution is by the enclosing function header and a closing brace in
## column one -- never by brace depth, which mis-attributes a top-level line to whichever
## function it merely sits after. The AgentsHarnessTool<Name> naming this relies on is held
## independently by AgentsHarnessSelfCheck.test.awk.
LC_ALL=C awk '
	/^AgentsHarnessTool[A-Za-z]+\(\)/ {
		toolName = $0
		sub( /^AgentsHarnessTool/, "", toolName )
		sub( /\(\).*$/, "", toolName )
		next ;
	}
	/^\}/ {
		toolName = ""
		next ;
	}
	/^[[:space:]]*#/ { next ; }
	toolName != "" && ( /eval "/ || /bash -c / ) {
		if ( !seenTool[toolName]++ ) print toolName ;
	}
' <( rigHarnessCat ) > "$rigTmp/executors"

rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFails=$(( rigFails + 1 ))
	fi
}

rigCount(){ ## record name -- how many names it holds
	LC_ALL=C awk 'END { print NR + 0 ; }' "$rigTmp/$1"
}

rigNonEmpty(){ ## record name -- yes when it holds more than nothing
	if [ "$( rigCount "$1" )" -gt 0 ] ; then printf 'yes' ; else printf 'no' ; fi
}

rigServedCount="$( rigCount served )"
rigMirrorCount="$( rigCount mirror )"
rigExecutorCount="$( rigCount executors )"

echo "-- the served floor, read off the server's own tools/list answer --"
## The controls sit in the same block as the results they qualify: without them an empty
## catalogue, an empty candidate population and an extraction that matched nothing each
## pass every assertion below while having measured nothing at all.
rigAssert "the server answered with a tool catalogue" "$( rigNonEmpty served )" "yes"
rigAssert "the mirror rendered a harness tool floor to scope the rule to" "$( rigNonEmpty mirror )" "yes"
rigAssert "the core declares at least one tool that runs a caller-supplied command" "$( rigNonEmpty executors )" "yes"
rigAssert "a served entry matched the mirror's own rendering, so the harness population was observed" "$( rigNonEmpty harness )" "yes"

## The rule as written. Name-based, and stated as such so a clean result is not read as
## proof that nothing arbitrary is served.
rigAssert "no served harness tool declares a 'command' argument" "$( rigCount commanded )" "0"

## The same rule by what a tool DOES rather than by what it calls its argument.
while IFS= read -r rigExecutor ; do
	[ -n "$rigExecutor" ] || continue
	rigAssert "$rigExecutor runs a caller-supplied command, so it is not served as a harness tool" \
		"$( LC_ALL=C grep -qx -- "$rigExecutor" "$rigTmp/harness" && printf 'served' || printf 'unserved' )" "unserved"
done < "$rigTmp/executors"

## A typed ask served without its fields degrades to a plain question: a permission request
## would then read as one, and its answer would never be applied as a verdict.
rigAskSchemaOf(){ ## served tool name -- its inputSchema as the catalogue carries it
	LC_ALL=C awk -v askName="{\"name\":\"$1\"" '
		{
			askAt = index( $0, askName ) ;
			if ( askAt == 0 ) { next ; }
			askRest = substr( $0, askAt ) ;
			schemaAt = index( askRest, "\"inputSchema\":" ) ;
			nextAt = index( substr( askRest, 2 ), "{\"name\":\"" ) ;
			if ( schemaAt > 0 && ( nextAt == 0 || schemaAt < nextAt ) ) { print substr( askRest, schemaAt, ( nextAt == 0 ? length( askRest ) : nextAt ) - schemaAt ) ; }
		}
	' "$rigTmp/list"
}
rigAskHolds(){ ## served tool name, field -- yes when its served schema declares the field
	rigAskSchemaOf "$1" | LC_ALL=C grep -q -F "\"$2\":{" && printf 'yes' || printf 'no'
}
## The read cap the descriptions state is the one the served path applies, filled from the
## one constant (AgentsHarnessReadCap.include), never restated by hand.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessReadCap.include"
rigAssert "the served Read and Skill state the MCP cap" \
	"$( LC_ALL=C grep -o -F "Content over the ${agentsReadCapMcp}-byte cap is cut" "$rigTmp/list" | wc -l | tr -d ' ' )" "2"
rigAssert "no unfilled cap placeholder is served" \
	"$( LC_ALL=C grep -c -F '{{READ_CAP_BYTES}}' "$rigTmp/list" )" "0"
rigAssert "a hosted wire's rendering states the wire cap" \
	"$( MDAT_READ_CAP_BYTES="$agentsReadCapWire" bash "$rigMirror" 2>/dev/null | LC_ALL=C grep -o -F "Content over the ${agentsReadCapWire}-byte cap is cut" | wc -l | tr -d ' ' )" "2"
## Each field on the tool that owns it, and pending_id on each of them. The tool name sets
## the kind, so none of them declares `kind`.
for rigAskPair in RequestPermission:refusal_id RequestPermission:reason RequestPermission:task_ref \
	ConfirmReadback:understood ConfirmReadback:source ConfirmReadback:will_do \
	ProposeApprove:proposal ProposeApprove:document ProposeApprove:task_ref ProposeApprove:pending_id \
	AskQuestion:pending_id ConfirmReadback:pending_id EscalateDecision:pending_id RequestPermission:pending_id ; do
	rigAssert "the served ${rigAskPair%%:*} carries '${rigAskPair#*:}'" \
		"$( rigAskHolds "${rigAskPair%%:*}" "${rigAskPair#*:}" )" "yes"
done
rigAssert "no served asking tool carries 'kind'" \
	"$( for rigAskTool in AskQuestion ConfirmReadback EscalateDecision RequestPermission ProposeApprove ; do rigAskHolds "$rigAskTool" kind ; done )" "nonononono"

## Every served tool takes the optional `description`, the call's stated intent, in the same
## text, never required, and named in the tool's own description.
rigIntentParam='{"type":"string","description":"Optional. One short sentence: why this call is made, what you expect from it. Recorded as your stated intent in the transcript and the tracking feed; it does not change what the tool does."}'
: > "$rigTmp/intent"
rigIndex=0
while : ; do
	rigName="$( rigSliceRead "result.tools.$rigIndex.name" raw )"
	[ -n "$rigName" ] || break
	rigName="${rigName#\"}" ; rigName="${rigName%\"}"
	rigIntentGot="$( rigSliceRead "result.tools.$rigIndex.inputSchema.properties.description" raw )"
	rigIntentRequired="$( rigSliceRead "result.tools.$rigIndex.inputSchema.required" raw )"
	rigIntentToolText="$( rigSliceRead "result.tools.$rigIndex.description" raw )"
	case "$rigIntentRequired" in *'"description"'*) rigIntentRequired=required ;; *) rigIntentRequired=optional ;; esac
	[ "$rigIntentGot" != "$rigIntentParam" ] || rigIntentGot=intent
	case "$rigIntentToolText" in *'Pass description to give a short description of why.'*) rigIntentToolText=told ;; *) rigIntentToolText=untold ;; esac
	printf '%s %s %s %s\n' "$rigName" "${rigIntentGot:-absent}" "$rigIntentRequired" "$rigIntentToolText" >> "$rigTmp/intent"
	rigIndex=$(( rigIndex + 1 ))
done
rigAssert "every served tool was read for its description" "$( rigCount intent )" "$rigServedCount"
## EVERY TOOL TAKES THE OPTIONAL INTENT DESCRIPTION, AND SAYS SO -- with one exception, and it is
## the owner's own: ThisSession's description is dictated word for word in the epic's F7.2 spec
## ("Post to your own session thread. ... A session with no thread is refused with ERROR."), so it
## is not extended here to repeat the house sentence. The PARAMETER is still declared and still
## optional; what is not asserted is the sentence, because the owner's text governs over the house
## convention. Its row is dropped from this count and asserted separately below.
rigAssert "every served tool takes the optional intent description, and says so" \
	"$( LC_ALL=C grep -v '^ThisSession ' "$rigTmp/intent" | LC_ALL=C grep -c -v ' intent optional told$' )" "0"
rigAssert "ThisSession takes it too, and its description is the owner's own words without the house sentence" \
	"$( LC_ALL=C grep -c -x 'ThisSession intent optional untold' "$rigTmp/intent" )" "1"
rigAssert "execute is one of them" "$( LC_ALL=C grep -c -x 'execute intent optional told' "$rigTmp/intent" )" "1"

## The list is fixed for the run: no host is ever told to list again (no listChanged), whether
## it listed before its first call or not. The call is a refused Bash: it renders
## the floor and answers without running anything.
## Each line is sent only once the answer to the one before is on the wire, as a host
## waits for it; a fixed delay loses that order on a loaded machine. Bounded at 60 s.
rigListChanged(){ ## scenario name, then the request lines, each carrying its own id
	local listScenario="$1" listLine listId listWait
	shift
	mkdir -p "$rigTmp/$listScenario/.local"
	: > "$rigTmp/$listScenario.wire"
	for listLine in "$@" ; do
		printf '%s\n' "$listLine"
		listId="${listLine#*\"id\":}"
		listId="${listId%%,*}"
		listWait=0
		while ! LC_ALL=C grep -q "\"id\":$listId," "$rigTmp/$listScenario.wire" && [ "$listWait" -lt 60 ] ; do
			sleep 1
			listWait=$(( listWait + 1 ))
		done
	done | MMDAPP="$rigTmp/$listScenario" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --intern-mcp-server --run 2>/dev/null >> "$rigTmp/$listScenario.wire" || :
	LC_ALL=C grep -c '"id":9,' "$rigTmp/$listScenario.wire" | tr -d '\n'
	printf ' answered, '
	LC_ALL=C grep -c 'notifications/tools/list_changed' "$rigTmp/$listScenario.wire" | tr -d '\n'
	printf ' notice(s)'
}
echo "-- the tool list is fixed for the run: nothing is announced --"
rigAssert "a call with no recorded listing sends no list_changed" \
	"$( rigListChanged unlisted '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"Bash","arguments":{}}}' )" "1 answered, 0 notice(s)"
rigAssert "initialize declares no listChanged" \
	"$( LC_ALL=C grep -c -F '"listChanged":false' "$rigTmp/wire" ) $( LC_ALL=C grep -c -F '"listChanged":true' "$rigTmp/wire" || : )" "1 0"
rigAssert "a call after listing the same floor sends none" \
	"$( rigListChanged listed '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"Bash","arguments":{}}}' )" "1 answered, 0 notice(s)"

## The job store, through a second run of the real server: `execute`'s own background jobs.
## `Monitor` is removed (epic D3: `Wait` replaces the native Monitor), so what was its twin
## now exercises the same out/pid/cursor store through the tool the server still serves.
## Each call waits for the answer before it, because the server handles requests in parallel.
rigCall(){ ## id, tool, arguments -- one tools/call request line
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"%s","arguments":%s}}\n' "$1" "$2" "$3"
}
rigAnswer(){ ## id -- the answer carrying that id
	LC_ALL=C grep "\"id\":$1," "$rigTmp/jobwire" 2>/dev/null || :
}
rigAwait(){ ## id -- until that answer is on the wire, 20s at most
	rigWaited=0
	until [ -n "$( rigAnswer "$1" )" ] ; do
		rigWaited=$(( rigWaited + 1 ))
		[ "$rigWaited" -le 100 ] || return 0
		sleep 0.2
	done
}
rigJobId(){ ## id -- the job id a start answered with
	rigAnswer "$1" | LC_ALL=C sed -n 's/.*\[job \([0-9][0-9]*\) started.*/\1/p'
}
: > "$rigTmp/jobfiles"
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	rigCall 11 execute '{"command":"printf \"one\\ntwo\\n\" ; sleep 30","background":true,"description":"rig watch"}'
	rigAwait 11
	rigJob="$( rigJobId 11 )"
	if [ -n "$rigJob" ] ; then
		for rigFile in out pid cursor ; do
			for rigPath in "$rigTmp"/.local/temp/agent-mcp.*/jobs/"$rigJob"/"$rigFile" ; do
				[ ! -f "$rigPath" ] || printf '%s\n' "$rigFile" >> "$rigTmp/jobfiles"
			done
		done
		sleep 1
		rigCall 12 execute "{\"job\":$rigJob}"
		rigAwait 12
		rigCall 13 execute "{\"job\":$rigJob,\"action\":\"kill\"}"
		rigAwait 13
		sleep 1
		rigCall 14 execute "{\"job\":$rigJob}"
		rigAwait 14
	fi
	rigCall 15 execute '{"command":"exit 3","background":true,"description":"rig exit"}'
	rigAwait 15
	rigJob="$( rigJobId 15 )"
	if [ -n "$rigJob" ] ; then
		sleep 2
		rigCall 16 execute "{\"job\":$rigJob}"
		rigAwait 16
	fi
} | MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --intern-mcp-server --run > "$rigTmp/jobwire" 2> "$rigTmp/joberr" || :

echo "-- the harness and the MCP server list the same tools; a tool unserved on a side says where it runs --"
rigParityMissing="$( while IFS= read -r rigFloorName ; do [ -n "$rigFloorName" ] || continue ; LC_ALL=C grep -qx -- "$rigFloorName" "$rigTmp/served" || printf '%s ' "$rigFloorName" ; done < "$rigTmp/mirror" )"
rigAssert "every tool of the harness floor is listed over MCP" "[${rigParityMissing% }]" "[]"
for rigUnserved in Bash WorkspaceContextExecute ; do
	rigUnservedAt="$( LC_ALL=C grep -nx -- "$rigUnserved" "$rigTmp/served" | head -n 1 | cut -d: -f1 )"
	rigUnservedAt=$(( ${rigUnservedAt:-0} - 1 ))
	rigUnservedSays=silent
	case "$( rigSliceRead "result.tools.$rigUnservedAt.description" raw )" in
		*'runs in the harness only'*) rigUnservedSays=said ;;
	esac
	rigAssert "$rigUnserved is listed over MCP with a description saying it runs in the harness, and takes no command" \
		"$rigUnservedSays $( rigSliceRead "result.tools.$rigUnservedAt.inputSchema.properties" keys | LC_ALL=C grep -c -x 'command' || : )" "said 0"
done
. "$rigHere/harness/AgentsHarnessUnserved.include"
rigHarnessUnserved="$( AgentsToolsUnservedInHarness )"
rigAssert "every tool only the MCP server serves is listed over MCP: execute, RootSession and the secondary tools" \
	"$( for rigName in execute $rigHarnessUnserved ; do LC_ALL=C grep -qx -- "$rigName" "$rigTmp/served" || printf '%s ' "$rigName" ; done )" ""
rigAssert "the harness lists each of them, saying it runs over MCP" \
	"$( LC_ALL=C grep -c -F -e 'AgentsToolsUnservedInHarness' -e 'AgentsToolsUnservedSays harness' "$rigHere/harness/AgentsHarnessMcpClient.sh" ) $( AgentsToolsUnservedSays harness RootSession | LC_ALL=C grep -c 'runs over MCP only' )" "2 1"

echo "-- the job store of execute, exercised through the real server --"
rigAssert "Monitor is not served: Wait replaces the native Monitor" "$( LC_ALL=C grep -qx 'Monitor' "$rigTmp/served" && printf 'served' || printf 'unserved' )" "unserved"
rigAssert "execute is served, so a background job has a home" "$( LC_ALL=C grep -qx 'execute' "$rigTmp/served" && printf 'served' || printf 'unserved' )" "served"
rigAssert "an execute start created out, pid and cursor in its job store" "$( LC_ALL=C sort "$rigTmp/jobfiles" | tr '\n' ' ' )" "cursor out pid "
rigAssert "a poll returned the new lines" "$( rigAnswer 12 | LC_ALL=C grep -q 'one\\ntwo\\n\[job' && printf 'yes' || printf 'no' )" "yes"
rigAssert "action kill stopped the job" "$( rigAnswer 14 | LC_ALL=C grep -q 'stopped before it could finish' && printf 'stopped' || printf 'not stopped' )" "stopped"
rigAssert "a finished job reports its exit code" "$( rigAnswer 16 | LC_ALL=C grep -q 'finished, exit code 3' && printf 'yes' || printf 'no' )" "yes"


## execute's own poll, one answer at a time, while its job is still writing: every token the
## job wrote must come back exactly once across the polls. A cursor saved from the file's
## size after the read skips whatever landed between the two. A poll hands out bytes, not
## lines, so the answers are joined before anything is counted.
rigCall(){ ## id, tool, arguments -- one tools/call request line
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"%s","arguments":%s}}\n' "$1" "$2" "$3"
}
rigPollAnswer(){ ## id
	LC_ALL=C grep "\"id\":$1," "$rigTmp/pollwire" 2>/dev/null || :
}
rigPollAwait(){ ## id -- until that answer is on the wire, 20s at most
	rigWaited=0
	until [ -n "$( rigPollAnswer "$1" )" ] ; do
		rigWaited=$(( rigWaited + 1 ))
		[ "$rigWaited" -le 400 ] || return 0
		sleep 0.05
	done
}
rigPollLines=20000
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	rigCall 21 execute "{\"command\":\"i=0 ; while [ \$i -lt $rigPollLines ] ; do printf 'L%05dE\\\\n' \$i ; i=\$(( i + 1 )) ; [ \$(( i % 50 )) -ne 0 ] || sleep 0.005 ; done\",\"background\":true}"
	rigPollAwait 21
	rigJob="$( rigPollAnswer 21 | LC_ALL=C sed -n 's/.*\[job \([0-9][0-9]*\) started.*/\1/p' )"
	if [ -n "$rigJob" ] ; then
		rigPollId=22
		while [ "$rigPollId" -lt 1000 ] ; do
			rigCall "$rigPollId" execute "{\"job\":$rigJob}"
			rigPollAwait "$rigPollId"
			rigPollAnswer "$rigPollId" | LC_ALL=C grep -q 'finished, exit code' && break
			rigPollId=$(( rigPollId + 1 ))
		done
	fi
} | MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --intern-mcp-server --run > "$rigTmp/pollwire" 2> "$rigTmp/pollerr" || :
LC_ALL=C grep -q 'finished, exit code 0' "$rigTmp/pollwire" || rigRefuse "the polled execute job was never seen to finish, so no count below would be complete"
## Every poll answer's own output, in id order, joined with no separator: the status line
## from its last "\n[job " on is dropped, and so is an empty poll's placeholder.
rigPollText="" ; rigPollAt=22
while [ -n "$( rigPollAnswer "$rigPollAt" )" ] ; do
	rigPollPart="$( rigPollAnswer "$rigPollAt" | LC_ALL=C awk -v path=result.content.0.text -v optional=1 -v sentinel=1 -f "$rigField" 2>/dev/null )"
	rigPollPart="${rigPollPart%X}"
	rigPollPart="$( printf '%s' "$rigPollPart" | rigReplyBare )"
	rigPollPart="${rigPollPart%$'\n'\[job *}"
	[ "$rigPollPart" != "(no new output)" ] || rigPollPart=""
	rigPollText="$rigPollText$rigPollPart"
	rigPollAt=$(( rigPollAt + 1 ))
done
## "<distinct> <duplicates>" of the LnnnnnE tokens across the joined output.
rigPollCount="$( printf '%s' "$rigPollText" | LC_ALL=C awk '
	{
		scanText = $0
		while ( match( scanText, /L[0-9][0-9][0-9][0-9][0-9]E/ ) ) {
			tokenText = substr( scanText, RSTART, RLENGTH )
			if ( seenToken[tokenText]++ ) dupCount++ ; else distinctCount++ ;
			scanText = substr( scanText, RSTART + RLENGTH )
		}
	}
	END { print distinctCount + 0, dupCount + 0 ; }
' )"

echo "-- execute's poll, answered one at a time --"
rigAssert "every line the job wrote came back, none twice" "$rigPollCount" "$rigPollLines 0"
if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SERVED FLOOR CHECK FAILED: $rigFails assertion(s)" >&2
	echo "  warn: a tool that runs arbitrary code reaches an MCP client through this" >&2
	echo "        server, around the deny hook that covers Bash on the *-native leg --" >&2
	echo "        or a tool the served set needs was not served at all" >&2
	echo "  fix:  add it to mcpUnservedToolNames in" >&2
	echo "        sh-lib/mcp/AgentsTools.InternMcpRequest.include, and say there why --" >&2
	echo "        never the assertion" >&2
	exit 1
fi
printf 'HARNESS_SERVED_FLOOR: OK (%s tools served off the wire of %s on the harness floor, %s command-running tool(s) in the core, none of them served)\n' \
	"$rigServedCount" "$rigMirrorCount" "$rigExecutorCount"
