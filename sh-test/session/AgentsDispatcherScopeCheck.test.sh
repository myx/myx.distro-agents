#!/usr/bin/env bash
## Check on the dispatcher's per-executor --scope (T5): the scope word is validated and the coordinator/console-only
## scopes are refused to a member's session. The function is sourced and called directly, offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPackage/sh-lib/member/AgentsTools.CallerCheck.include"
. "$rigPackage/sh-lib/session/AgentsTools.Dispatcher.include"
rigFails=0 rigPasses=0
rigAssert(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi ; }
rigHas(){ LC_ALL=C grep -c -F -- "$1" <<< "$2" || : ; }
## A member's session (MDAT_SPAWN_AGENT set) is not the coordinator. The exact wording of the reason is the code's to refine:
## held here are the refusal, the word refused, and what the reason says about it -- so a rewording is not a break, while an
## accepted scope, a lost reason, or a missing accepted word still is.
rigOut="$( MDSC_CMD=DistroAgentsDispatcher MDAT_SPAWN_AGENT=magic-rig AgentsToolsDispatcherSessions --all-sessions --scope all 2>&1 )" ; rigRc=$?
rigAssert "--scope all is refused to a non-coordinator member" "$rigRc $( rigHas '--scope all' "$rigOut" ) $( rigHas 'coordinator' "$rigOut" ) $( rigHas 'console' "$rigOut" )" "1 1 1 1"
rigOut="$( MDSC_CMD=DistroAgentsDispatcher MDAT_SPAWN_AGENT=magic-rig AgentsToolsDispatcherSessions --active-sessions --scope member keeper-x 2>&1 )" ; rigRc=$?
rigAssert "--scope member is refused to a non-coordinator member" "$rigRc $( rigHas '--scope member' "$rigOut" ) $( rigHas 'coordinator' "$rigOut" ) $( rigHas 'console' "$rigOut" )" "1 1 1 1"
rigOut="$( MDSC_CMD=DistroAgentsDispatcher MDAT_SPAWN_AGENT=magic-rig AgentsToolsDispatcherSessions --waiting-sessions --scope bogus 2>&1 )" ; rigRc=$?
rigAssert "an unknown scope word is refused" "$rigRc $( rigHas 'bogus' "$rigOut" ) $( rigHas 'this-session' "$rigOut" ) $( rigHas 'own' "$rigOut" ) $( rigHas 'member' "$rigOut" ) $( rigHas 'all' "$rigOut" )" "1 1 1 1 1 1"
rigOut="$( MDSC_CMD=DistroAgentsDispatcher MDAT_SPAWN_AGENT=magic-rig AgentsToolsDispatcherSessions --all-sessions --scope member 2>&1 )" ; rigRc=$?
rigAssert "--scope member without a member is refused" "$rigRc $( rigHas '--scope member' "$rigOut" ) $( rigHas 'team member' "$rigOut" )" "1 1 1"
if [ "$rigFails" -ne 0 ] ; then echo "⛔ DISPATCHER_SCOPE FAILED: $rigFails of $(( rigPasses + rigFails ))" >&2 ; exit 1 ; fi
printf 'DISPATCHER_SCOPE: OK (%d assertions)\n' "$rigPasses"
