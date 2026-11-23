#!/usr/bin/env bash
## Behavioural check on the harness's own spawn surface: the wire declares its native `Agent` tool, and the
## dispatcher's `AgentDispatcherTools --spawn-run` delegates to `DistroAgentsDispatcher --spawn-session`.
## The MCP server is a proxy mirror of these tools, used when the native harness is not available, and it carries more methods.
## Read from the two files themselves, offline: the harness wire's own tool list, and the dispatcher's arms.
set -u
: "${MMDAPP:?MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigWire="$rigOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsOpenAiChatWire.sh"
rigDispatcher="$rigOrigin/myx/myx.distro-agents/sh-scripts/AgentDispatcherTools.fn.sh"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
[ -f "$rigWire" ] || { echo "⛔ no wire at $rigWire" >&2 ; exit 1 ; }

echo "-- the harness serves its own spawn, and the dispatcher delegates it --"
rigAssert "the wire declares its native Agent tool" \
	"$( LC_ALL=C grep -c '"name":"Agent"' "$rigWire" )" 1
rigAssert "the dispatcher serves --spawn-run" \
	"$( LC_ALL=C grep -c -- '--spawn-run)' "$rigDispatcher" )" 1
rigAssert "and the spawn delegates to DistroAgentsDispatcher --spawn-session" \
	"$( LC_ALL=C grep -c -- 'DistroAgentsDispatcher --spawn-session' "$rigDispatcher" )" 1

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ HARNESS SPAWN TOOL CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_SPAWN_TOOL: OK (%d assertions, offline)\n' "$rigPasses"
