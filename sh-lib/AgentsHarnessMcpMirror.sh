#!/usr/bin/env bash
set -e

## AgentsHarnessMcpMirror.sh -- renders the harness tool floor as an MCP tools/list
## array, DERIVED from the same `harnessToolsJson` literal the harness puts on the
## wire. Nothing here is a second list: a tool appears in this output because it is
## declared to the model, so the mirror cannot drift from the floor it mirrors.
##
## The two shapes differ only in their envelope. The wire carries
## {"type":"function","function":{"name","description","parameters"}} and MCP carries
## {"name","description","inputSchema"}, so this rewrites the envelope and copies each
## declaration's own raw JSON through untouched -- a description already escaped for
## the wire is already escaped for MCP, and re-escaping it would corrupt it.
##
## Parsed through AgentsHarnessJsonSlice.awk, which is not the reader the harness runs
## its own responses through: a literal rendered by the same code that consumes it
## proves only that the two agree.
##
## Issues no request and touches no host. The array goes to stdout and every diagnostic
## to stderr; the whole array is buffered and printed at the end, so a run that fails
## partway leaves nothing on stdout that reads as a finished floor. Every failure is
## loud, because an extraction that matched nothing must never read as a floor that
## declares no tools.

mirrorHere="$( cd "$( dirname -- "$0" )" && pwd )"
mirrorWire="${1:-$mirrorHere/AgentsOpenAiChatWire.sh}"
mirrorSliceAwk="$mirrorHere/AgentsHarnessJsonSlice.awk"

if [ ! -f "$mirrorWire" ] ; then
	printf '%s\n' "AgentsHarnessMcpMirror: ⛔ ERROR: no wire adapter to read at $mirrorWire" >&2
	printf '%s\n' "  fix:  pass the wire adapter path, or run this from the package sh-lib" >&2
	exit 1
fi
if [ ! -f "$mirrorSliceAwk" ] ; then
	printf '%s\n' "AgentsHarnessMcpMirror: ⛔ ERROR: the JSON slice reader is missing from this package: $mirrorSliceAwk" >&2
	printf '%s\n' "  fix:  re-run this workspace's own release step to restore sh-lib" >&2
	exit 1
fi

## The literal, lifted out between its own opening and closing quote. The quote travels
## as an awk variable rather than through three layers of shell quoting.
mirrorToolsJson="$( LC_ALL=C awk -v q="'" '
	index($0, "harnessToolsJson=" q) == 1 {
		inLiteral = 1
		print substr($0, length("harnessToolsJson=" q) + 1)
		next ;
	}
	inLiteral && $0 == "]" q { print "]" ; exit ; }
	inLiteral { print ; }
' "$mirrorWire" )"

if [ -z "$mirrorToolsJson" ] ; then
	printf '%s\n' "AgentsHarnessMcpMirror: ⛔ ERROR: no harnessToolsJson literal was extracted from ${mirrorWire##*/} -- an extraction that matched nothing must never read as a clean run" >&2
	printf '%s\n' "  fix:  check that the literal still opens with harnessToolsJson='[" >&2
	exit 1
fi

## The slice reader takes an object at top level, so the array is given one.
mirrorDoc="{\"tools\":$mirrorToolsJson}"

mirrorIndex=0
mirrorOut=""
while : ; do
	mirrorRc=0
	printf '%s' "$mirrorDoc" | LC_ALL=C awk -v path="tools.$mirrorIndex.function" -v mode=keys -f "$mirrorSliceAwk" >/dev/null 2>&1 || mirrorRc=$?
	case "$mirrorRc" in
		0) ;;
		3) break ;;
		*)
			printf '%s\n' "AgentsHarnessMcpMirror: ⛔ ERROR: the harnessToolsJson literal in ${mirrorWire##*/} is NOT VALID JSON -- the parser refused it (rc=$mirrorRc) while reading element $mirrorIndex" >&2
			printf '%s\n' "  fix:  repair the JSON -- most often a missing comma between two declarations" >&2
			exit 1
		;;
	esac

	mirrorName="$( printf '%s' "$mirrorDoc" | LC_ALL=C awk -v path="tools.$mirrorIndex.function.name" -v mode=raw -f "$mirrorSliceAwk" 2>/dev/null )" || mirrorName=""
	mirrorDescription="$( printf '%s' "$mirrorDoc" | LC_ALL=C awk -v path="tools.$mirrorIndex.function.description" -v mode=raw -f "$mirrorSliceAwk" 2>/dev/null )" || mirrorDescription=""
	mirrorSchema="$( printf '%s' "$mirrorDoc" | LC_ALL=C awk -v path="tools.$mirrorIndex.function.parameters" -v mode=raw -f "$mirrorSliceAwk" 2>/dev/null )" || mirrorSchema=""

	## A mirrored tool the caller cannot name, cannot read, or cannot call is worse
	## than an absent one: it reaches a native console as a tool that exists and
	## refuses, which reads as a broken server rather than as a local edit.
	if [ -z "$mirrorName" ] ; then
		printf '%s\n' "AgentsHarnessMcpMirror: ⛔ ERROR: declaration $mirrorIndex parses but carries no function.name, so no refusal could name the method a caller should use instead" >&2
		printf '%s\n' "  fix:  give that declaration its own \"name\"" >&2
		exit 1
	fi
	if [ -z "$mirrorDescription" ] ; then
		printf '%s\n' "AgentsHarnessMcpMirror: ⛔ ERROR: declaration $mirrorIndex ($mirrorName) carries no function.description, so a caller is offered a tool with nothing saying what it does" >&2
		printf '%s\n' "  fix:  give that declaration its own \"description\"" >&2
		exit 1
	fi
	if [ -z "$mirrorSchema" ] ; then
		printf '%s\n' "AgentsHarnessMcpMirror: ⛔ ERROR: declaration $mirrorIndex ($mirrorName) carries no function.parameters, and MCP has no default for a missing inputSchema" >&2
		printf '%s\n' "  fix:  give that declaration its own \"parameters\" object" >&2
		exit 1
	fi

	[ 0 -eq "$mirrorIndex" ] || mirrorOut="$mirrorOut,"
	mirrorOut="$mirrorOut{\"name\":$mirrorName,\"description\":$mirrorDescription,\"inputSchema\":$mirrorSchema}"
	mirrorIndex=$(( mirrorIndex + 1 ))
done

if [ 0 -eq "$mirrorIndex" ] ; then
	## An empty population cannot fail, so it is a FAIL rather than a pass -- the same
	## rule AgentsHarnessSelfCheck.awk holds itself to.
	printf '%s\n' "AgentsHarnessMcpMirror: ⛔ ERROR: the literal parsed but declares no tools at all, so the mirror would advertise an empty floor" >&2
	printf '%s\n' "  fix:  check that the array still holds one object per tool" >&2
	exit 1
fi

printf '[%s]\n' "$mirrorOut"
exit 0
