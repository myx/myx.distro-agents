#!/usr/bin/env bash
## Behavioural check on S18 item 3: the harness serves no `Agent` tool, and the one spawn that remains is
## `AgentDispatcherTools --spawn-run`, which delegates to `DistroAgentsDispatcher --spawn-session`.
## Read from the two files themselves, offline: the harness wire's own tool list, and the dispatcher's arms.
## Fails today: the wire still declares `Agent`.
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

echo "-- the harness serves one spawn, and it is not Agent --"
rigAssert "the wire no longer declares an Agent tool" \
	"$( LC_ALL=C grep -c '"name":"Agent"' "$rigWire" )" 0
rigAssert "the dispatcher serves --spawn-run" \
	"$( LC_ALL=C grep -c -- '--spawn-run)' "$rigDispatcher" )" 1
rigAssert "and the spawn delegates to DistroAgentsDispatcher --spawn-session" \
	"$( LC_ALL=C grep -c -- 'DistroAgentsDispatcher --spawn-session' "$rigDispatcher" )" 1

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ HARNESS SPAWN TOOL CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_SPAWN_TOOL: OK (%d assertions, offline)\n' "$rigPasses"
