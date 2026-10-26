#!/usr/bin/env bash
## Check on --queue-ask (K2): the librarian's escalation of a concrete edit to a pending question. The function is
## sourced and called directly; the syntax and the librarian-only gate are what this holds, offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPackage/sh-lib/member/AgentsTools.LibrarianWork.include"
rigFails=0 rigPasses=0
rigAssert(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi ; }
rigHas(){ LC_ALL=C grep -c -F -- "$1" <<< "$2" || : ; }
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsConcreteEditPendingCheck.XXXXXX" )" || exit 1 ; trap 'rm -rf -- "$rigTmp"' EXIT ; mkdir -p "$rigTmp/data"
rigOut="$( MDSC_CMD=AgentLibrarianTools AgentsToolsLibrarianQueueAsk --queue-ask 2>&1 )" ; rigRc=$?
## the operation names itself in the message and then the syntax, so the line reads "… --queue-ask: syntax is <name>"
rigAssert "no name is refused with the syntax" "$rigRc $( rigHas '--queue-ask: syntax is <name>' "$rigOut" )" "1 1"
rigOut="$( MDSC_CMD=AgentLibrarianTools MDAT_DATA_ROOT="$rigTmp/data" AgentsToolsLibrarianQueueAsk --queue-ask req-1.md 2>&1 )" ; rigRc=$?
rigAssert "a call from no librarian is refused" "$rigRc $( rigHas 'runs only as magic-librarian' "$rigOut" )" "1 1"
if [ "$rigFails" -ne 0 ] ; then echo "⛔ CONCRETE_EDIT_PENDING FAILED: $rigFails of $(( rigPasses + rigFails ))" >&2 ; exit 1 ; fi
printf 'CONCRETE_EDIT_PENDING: OK (%d assertions)\n' "$rigPasses"
