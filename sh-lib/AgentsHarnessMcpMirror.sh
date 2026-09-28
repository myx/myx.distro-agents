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
## Parsed in one pass by AgentsHarnessMcpMirror.awk, which is not the reader the harness
## runs its own responses through: a literal rendered by the same code that consumes it
## proves only that the two agree.
##
## Usage: AgentsHarnessMcpMirror.sh [wire-adapter-path] [excluded-names]. An empty first
## argument takes the default wire; the second is a space-separated list of tool names
## left out of the array.
##
## Issues no request and touches no host. The array goes to stdout and every diagnostic
## to stderr; the whole array is buffered and printed at the end, so a run that fails
## partway leaves nothing on stdout that reads as a finished floor. Every failure is
## loud, because an extraction that matched nothing must never read as a floor that
## declares no tools.

mirrorHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
mirrorWire="${1:-$mirrorHere/AgentsOpenAiChatWire.sh}"
mirrorAwk="$mirrorHere/AgentsHarnessMcpMirror.awk"

if [ ! -f "$mirrorWire" ] ; then
	printf '%s\n' "AgentsHarnessMcpMirror: ⛔ ERROR: no wire adapter to read at $mirrorWire" >&2
	printf '%s\n' "  fix:  pass the wire adapter path, or run this from the package sh-lib" >&2
	exit 1
fi
if [ ! -f "$mirrorAwk" ] ; then
	printf '%s\n' "AgentsHarnessMcpMirror: ⛔ ERROR: the mirror renderer is missing from this package: $mirrorAwk" >&2
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

## One pass renders the whole array, and every refusal is the awk's own: nothing on
## stdout and a nonzero status, which set -e hands on as this script's.
printf '%s\n' "$mirrorToolsJson" | LC_ALL=C awk -v exclude="${2:-}" -f "$mirrorAwk"
