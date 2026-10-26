#!/usr/bin/env bash
## Check on --session-floor-remove (T9b): the explicit timed removal of a run's delivery floor. The function is
## sourced and called directly; the syntax and the seconds validation are what this holds, offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
set -- '' ; . "$rigPackage/sh-lib/session/AgentsTools.ThisSession.include"
rigFails=0 rigPasses=0
rigAssert(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi ; }
rigHas(){ LC_ALL=C grep -c -F -- "$1" <<< "$2" || : ; }
rigOut="$( MDSC_CMD=DistroAgentsSession AgentsToolsThisSessionFloorRemove --session-floor-remove 2>&1 )" ; rigRc=$?
rigAssert "no seconds is refused with the syntax" "$rigRc $( rigHas 'syntax is --session-floor-remove <seconds>' "$rigOut" )" "1 1"
rigOut="$( MDSC_CMD=DistroAgentsSession AgentsToolsThisSessionFloorRemove --session-floor-remove abc 2>&1 )" ; rigRc=$?
rigAssert "a non-numeric seconds is refused" "$rigRc $( rigHas '<seconds> is whole seconds' "$rigOut" )" "1 1"
rigOut="$( MDSC_CMD=DistroAgentsSession AgentsToolsThisSessionFloorRemove --session-floor-remove 0 2>&1 )" ; rigRc=$?
rigAssert "no member's session is refused by the ThisSession bind" "$rigRc $( rigHas 'no member' "$rigOut" )" "1 1"
if [ "$rigFails" -ne 0 ] ; then echo "⛔ SESSION_CHAT_FLOOR_REMOVE FAILED: $rigFails of $(( rigPasses + rigFails ))" >&2 ; exit 1 ; fi
printf 'SESSION_CHAT_FLOOR_REMOVE: OK (%d assertions)\n' "$rigPasses"
