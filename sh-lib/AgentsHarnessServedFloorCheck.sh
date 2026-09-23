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
##      as written in AgentsTools.InternMcpServer.include and in MAGIC.md, and it is
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
## Offline and self-contained. The root under test is MMDAPP, and it is relocated onto this
## check's own fixture -- the server's scratch and every file it reads are inside there, so
## no file of the real workspace is touched and no gate is stubbed. MDLT_ORIGIN is the tree
## this check sits in, so a planted copy tests itself, which is what makes a red run possible.
set -u

rigHere="$( cd "$( dirname -- "$0" )" && pwd )"
rigCore="$rigHere/AgentsUniversalHarness.sh"
rigSlice="$rigHere/AgentsHarnessJsonSlice.awk"
rigMirror="$rigHere/AgentsHarnessMcpMirror.sh"
rigOrigin="$( cd "$rigHere/../../.." && pwd )"
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

## Refusing to report is this block's whole job: a run that exercised nothing must never
## print a pass, and an empty extraction is a fault here rather than a clean floor.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

for rigFile in "$rigCore" "$rigSlice" "$rigMirror" "$rigTool" ; do
	[ -f "$rigFile" ] || rigRefuse "not found in the tree this check sits in: $rigFile"
done

rigTmp="$( mktemp -d -t "AgentsHarnessServedFloorCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The scenario IS the workspace for this run. `.local` is what the server requires of it.
mkdir -p "$rigTmp/.local"

{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
} | MMDAPP="$rigTmp" MDLT_ORIGIN="$rigOrigin" \
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
bash "$rigMirror" 2>/dev/null | LC_ALL=C awk '
	{
		while ( match( $0, /\{"name":"[A-Za-z]+"/ ) ) {
			toolName = substr( $0, RSTART + 9, RLENGTH - 10 )
			print toolName
			$0 = substr( $0, RSTART + RLENGTH ) ;
		}
	}
' > "$rigTmp/mirror"

## Every served name, and beside each one -- where it is a harness tool -- whether its own
## schema declares `command`.
: > "$rigTmp/served" ; : > "$rigTmp/commanded"
rigIndex=0
while : ; do
	rigName="$( rigSliceRead "result.tools.$rigIndex.name" raw )"
	[ -n "$rigName" ] || break
	rigName="${rigName#\"}" ; rigName="${rigName%\"}"
	printf '%s\n' "$rigName" >> "$rigTmp/served"
	rigIndex=$(( rigIndex + 1 ))
	LC_ALL=C grep -qx -- "$rigName" "$rigTmp/mirror" || continue
	rigSliceRead "result.tools.$(( rigIndex - 1 )).inputSchema.properties" keys > "$rigTmp/props"
	! LC_ALL=C grep -qx 'command' "$rigTmp/props" || printf '%s\n' "$rigName" >> "$rigTmp/commanded"
done

## The tools whose own function executes a caller-supplied string as a shell command, read
## off the core. Attribution is by the enclosing function header and a closing brace in
## column one -- never by brace depth, which mis-attributes a top-level line to whichever
## function it merely sits after. The AgentsHarnessTool<Name> naming this relies on is held
## independently by AgentsHarnessSelfCheck.awk.
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

## The rule as written. Name-based, and stated as such so a clean result is not read as
## proof that nothing arbitrary is served.
rigAssert "no served harness tool declares a 'command' argument" "$( rigCount commanded )" "0"

## The same rule by what a tool DOES rather than by what it calls its argument.
while IFS= read -r rigExecutor ; do
	[ -n "$rigExecutor" ] || continue
	rigAssert "$rigExecutor runs a caller-supplied command, so it is not served" \
		"$( LC_ALL=C grep -qx -- "$rigExecutor" "$rigTmp/served" && printf 'served' || printf 'unserved' )" "unserved"
done < "$rigTmp/executors"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SERVED FLOOR CHECK FAILED: $rigFails assertion(s)" >&2
	echo "  warn: a tool that runs arbitrary code reaches an MCP client through this" >&2
	echo "        server, around the deny hook that covers Bash on the *-native leg --" >&2
	echo "        or a tool the served set needs was not served at all" >&2
	echo "  fix:  add it to mcpUnservedToolNames in" >&2
	echo "        sh-lib/AgentsTools.InternMcpServer.include, and say there why --" >&2
	echo "        never the assertion" >&2
	exit 1
fi
printf 'HARNESS_SERVED_FLOOR: OK (%s tools served off the wire of %s on the harness floor, %s command-running tool(s) in the core, none of them served)\n' \
	"$rigServedCount" "$rigMirrorCount" "$rigExecutorCount"
