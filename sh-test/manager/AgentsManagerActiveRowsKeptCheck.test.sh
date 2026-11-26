#!/usr/bin/env bash
## Text check on the session rows cache (sh-lib/manager/AgentsTools.ManagerSessionRows.include): the whole history, the
## manager's list, and the active and waiting lists each keep their own copy for thirty seconds. The active and waiting
## lists were the two that did not, so the supervisor's and the root's every tick re-derived the whole store: measured on
## MDV, `--spawns --active` cost 13.7 s a call, and 15 s a call twice in a row.
## The file is read as the text it is: the function needs the whole session store to run, and the floor here is which lists
## are kept, not how a row is rendered. No store is read and no call is opened.
## RED RECIPE, measured on live 2026-11-25 16:4x +0200: before the active and waiting names, assertions 1 and 2 fail, and
## assertion 3 (the control: the two lists kept all along) passes.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rows="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ManagerSessionRows.include"
[ -f "$rows" ] || { echo "⛔ ERROR: no $rows" >&2 ; exit 1 ; }
keptCase="$( LC_ALL=C sed -n '/case "$rowsOp" in/,/esac/p' "$rows" )"
[ -n "$keptCase" ] || { echo "⛔ ERROR: the kept-list case is not found in $rows" >&2 ; exit 1 ; }
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
rigHas(){ case "$keptCase" in *"$1"*) printf 'yes' ;; *) printf 'no' ;; esac ; }

rigAssert "the kept case carries --active-sessions" "$( rigHas '--active-sessions' )" yes
rigAssert "the kept case carries --waiting-sessions" "$( rigHas '--waiting-sessions' )" yes
rigAssert "the two lists kept all along stay, as the control" "$( rigHas '--all-sessions' )" yes
rigAssert "the kept copy still names its own rows file" "$( LC_ALL=C grep -c 'manager-sessions.ready' "$rows" 2> /dev/null || : )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER ACTIVE ROWS KEPT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'MANAGER_ACTIVE_ROWS_KEPT: OK (%d assertions, text of the kept case only)\n' "$rigPassCount"
