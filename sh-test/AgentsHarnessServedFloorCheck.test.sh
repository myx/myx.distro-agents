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
## name, so a server-own tool sharing a harness name -- the Monitor twin -- falls outside it too.
##
## THE MONITOR TWIN is also exercised through a real server: served, a start creating its job
## files, a poll returning new lines, a kill stopping it, and a finished job's exit code.
##
## NOT REACHED, and this is a limit rather than an omission: the other half of the
## documented test -- a tool handing back a handle only its own process can resolve. That
## is a fact about process lifetime, visible in neither a declaration nor a source scan.
## `Monitor` is caught here only because it also takes a command. A future tool minting a
## process-local handle and taking none would pass this check and still be unservable.
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
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigCore="$rigHere/AgentsUniversalHarness.sh"
rigSlice="$rigHere/AgentsHarnessJsonField.awk"
rigMirror="$rigHere/AgentsHarnessMcpMirror.sh"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigField="$rigHere/AgentsHarnessJsonField.awk"

## Refusing to report is this block's whole job: a run that exercised nothing must never
## print a pass, and an empty extraction is a fault here rather than a clean floor.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

for rigFile in "$rigCore" "$rigSlice" "$rigMirror" "$rigTool" "$rigField" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

rigTmp="$( mktemp -d -t "AgentsHarnessServedFloorCheck-XXXXXXXX" )" || exit 1
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
' "$rigCore" > "$rigTmp/executors"

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
rigAskSchema="$( LC_ALL=C awk '
	{
		askAt = index( $0, "{\"name\":\"AskUserQuestion\"" ) ;
		if ( askAt == 0 ) { next ; }
		askRest = substr( $0, askAt ) ;
		schemaAt = index( askRest, "\"inputSchema\":" ) ;
		nextAt = index( substr( askRest, 2 ), "{\"name\":\"" ) ;
		if ( schemaAt > 0 && ( nextAt == 0 || schemaAt < nextAt ) ) { print substr( askRest, schemaAt, ( nextAt == 0 ? length( askRest ) : nextAt ) - schemaAt ) ; }
	}
' "$rigTmp/list" )"
## The read cap the descriptions state is the one the served path applies, filled from the
## one constant (AgentsHarnessReadCap.include), never restated by hand.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsHarnessReadCap.include"
rigAssert "the served Read and Skill state the MCP cap" \
	"$( LC_ALL=C grep -o -F "Content over the ${agentsReadCapMcp}-byte cap is cut" "$rigTmp/list" | wc -l | tr -d ' ' )" "2"
rigAssert "no unfilled cap placeholder is served" \
	"$( LC_ALL=C grep -c -F '{{READ_CAP_BYTES}}' "$rigTmp/list" )" "0"
rigAssert "a hosted wire's rendering states the wire cap" \
	"$( MDAT_READ_CAP_BYTES="$agentsReadCapWire" bash "$rigMirror" 2>/dev/null | LC_ALL=C grep -o -F "Content over the ${agentsReadCapWire}-byte cap is cut" | wc -l | tr -d ' ' )" "2"
for rigAskField in kind refusal_id reason task_ref understood source will_do pending_id ; do
	rigAssert "the served AskUserQuestion carries '$rigAskField'" \
		"$( printf '%s' "$rigAskSchema" | LC_ALL=C grep -q -F "\"$rigAskField\":{" && printf 'yes' || printf 'no' )" "yes"
done

## A host whose list this server never recorded is told to list again on its first call,
## and a host that listed the same floor is not. The call is a refused Bash: it renders
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
echo "-- a floor the host never listed from this server is announced --"
rigAssert "a call with no recorded listing sends list_changed" \
	"$( rigListChanged unlisted '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"Bash","arguments":{}}}' )" "1 answered, 1 notice(s)"
rigAssert "a call after listing the same floor sends none" \
	"$( rigListChanged listed '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"Bash","arguments":{}}}' )" "1 answered, 0 notice(s)"

## The Monitor twin, through a second run of the real server. Each call waits for the answer
## before it, because the server handles requests in parallel.
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
	rigCall 11 Monitor '{"command":"printf \"one\\ntwo\\n\" ; sleep 30","description":"rig watch"}'
	rigAwait 11
	rigJob="$( rigJobId 11 )"
	if [ -n "$rigJob" ] ; then
		for rigFile in out pid cursor ; do
			for rigPath in "$rigTmp"/.local/temp/agent-mcp.*/jobs/"$rigJob"/"$rigFile" ; do
				[ ! -f "$rigPath" ] || printf '%s\n' "$rigFile" >> "$rigTmp/jobfiles"
			done
		done
		sleep 1
		rigCall 12 Monitor "{\"job\":$rigJob}"
		rigAwait 12
		rigCall 13 Monitor "{\"job\":$rigJob,\"action\":\"kill\"}"
		rigAwait 13
		sleep 1
		rigCall 14 Monitor "{\"job\":$rigJob}"
		rigAwait 14
	fi
	rigCall 15 Monitor '{"command":"exit 3","description":"rig exit"}'
	rigAwait 15
	rigJob="$( rigJobId 15 )"
	if [ -n "$rigJob" ] ; then
		sleep 2
		rigCall 16 Monitor "{\"job\":$rigJob}"
		rigAwait 16
	fi
} | MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --intern-mcp-server --run > "$rigTmp/jobwire" 2> "$rigTmp/joberr" || :

echo "-- the Monitor twin, exercised through the real server --"
rigAssert "Monitor is served" "$( LC_ALL=C grep -qx 'Monitor' "$rigTmp/served" && printf 'served' || printf 'unserved' )" "served"
rigAssert "a Monitor start created out, pid and cursor in execute's job store" "$( LC_ALL=C sort "$rigTmp/jobfiles" | tr '\n' ' ' )" "cursor out pid "
rigAssert "a poll returned the new lines" "$( rigAnswer 12 | LC_ALL=C grep -q 'one\\ntwo\\n\[job' && printf 'yes' || printf 'no' )" "yes"
rigAssert "action kill stopped the job" "$( rigAnswer 14 | LC_ALL=C grep -q 'stopped before it could finish' && printf 'stopped' || printf 'not stopped' )" "stopped"
rigAssert "a finished job reports its exit code" "$( rigAnswer 16 | LC_ALL=C grep -q 'finished, exit code 3' && printf 'yes' || printf 'no' )" "yes"


## execute's own poll, one answer at a time, while its job is still writing: every token the
## job wrote must come back exactly once across the polls. A cursor saved from the file's
## size after the read skips whatever landed between the two. A poll hands out bytes, not
## lines, so the answers are joined before anything is counted.
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
	echo "        sh-lib/AgentsTools.InternMcpRequest.include, and say there why --" >&2
	echo "        never the assertion" >&2
	exit 1
fi
printf 'HARNESS_SERVED_FLOOR: OK (%s tools served off the wire of %s on the harness floor, %s command-running tool(s) in the core, none of them served)\n' \
	"$rigServedCount" "$rigMirrorCount" "$rigExecutorCount"
