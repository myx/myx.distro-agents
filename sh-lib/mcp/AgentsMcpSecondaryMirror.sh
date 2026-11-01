#!/usr/bin/env bash
set -e

## AgentsMcpSecondaryMirror.sh -- renders the secondary tools of the myx.distro MCP as one
## tools/list array: one tool per tool file the front table declares as secondary
## (agentsFrontSecondary, sh-lib/harness/AgentsContext.FrontTable.Help.include), the operation passed
## as the argument, so the served catalogue stays short. Derived from the same table that routes
## the operations, so the mirror cannot drift from the files it serves.
##
## The shape is MCP: {"name","description","inputSchema"}. The description is the tool file's own
## summary plus the call's stated intent, and every inputSchema carries `operation`, the positional
## `args` and the optional `description`, the same three fields a call is dispatched from.
##
## Issues no request and touches no host. The array goes to stdout and every diagnostic to stderr;
## the whole array is buffered and printed at the end, so a run that fails partway leaves nothing on
## stdout that reads as a finished floor. Every failure is loud: an empty list must never read as a
## floor that declares no tools.

mirrorFront="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
mirrorHelp="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.Help.include"
mirrorEscape="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/mcp/AgentsMcpJsonEscape.awk"

if [ ! -f "$mirrorFront" ] ; then
	printf '%s\n' "AgentsMcpSecondaryMirror: ⛔ ERROR: the front table is missing from this package: $mirrorFront" >&2
	exit 1
fi
## The list and the one-line summaries are the Help include's, which the front table does not itself source: without it
## this mirror renders nothing, and a list that is empty for want of a source reads exactly like a list somebody emptied.
if [ ! -f "$mirrorHelp" ] ; then
	printf '%s\n' "AgentsMcpSecondaryMirror: ⛔ ERROR: the front table's help include is missing from this package: $mirrorHelp" >&2
	exit 1
fi
if [ ! -f "$mirrorEscape" ] ; then
	printf '%s\n' "AgentsMcpSecondaryMirror: ⛔ ERROR: the JSON escaper is missing from this package: $mirrorEscape" >&2
	exit 1
fi
. "$mirrorFront"
. "$mirrorHelp"

mirrorOut=""
for mirrorFile in $agentsFrontSecondary ; do
	mirrorDesc="$( AgentsToolsFrontSummary "$mirrorFile" ) Run its operations here, not through execute. Pass description to give a short description of why."
	mirrorDesc="$( printf '%s' "$mirrorDesc" | LC_ALL=C awk -f "$mirrorEscape" )"
	[ -z "$mirrorOut" ] || mirrorOut="$mirrorOut,"
	mirrorOut="$mirrorOut{\"name\":\"$mirrorFile\",\"description\":\"$mirrorDesc\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"operation\":{\"type\":\"string\",\"description\":\"The operation to run, with its leading --, such as --slack-read. List the operations of this file with $mirrorFile --help-syntax.\"},\"args\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Optional. The positional arguments and flags of the operation, in order.\"},\"description\":{\"type\":\"string\",\"description\":\"Optional. One short sentence: why this call is made, what you expect from it. Recorded as your stated intent in the transcript and the tracking feed; it does not change what the tool does.\"},\"sync\":{\"type\":\"boolean\",\"description\":\"true overrides the window and waits with no window at all: the operation runs to its own end before this returns.\"},\"async\":{\"type\":\"boolean\",\"description\":\"true overrides the window and returns at once with TASK-ID=process-N, without waiting for the window of this tool.\"}},\"required\":[\"operation\"]}}"
done

if [ -z "$mirrorOut" ] ; then
	printf '%s\n' "AgentsMcpSecondaryMirror: ⛔ ERROR: agentsFrontSecondary declares no tool files, so the mirror would advertise an empty floor" >&2
	exit 1
fi
printf '[%s]\n' "$mirrorOut"
