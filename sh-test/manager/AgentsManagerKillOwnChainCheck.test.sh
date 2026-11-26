#!/usr/bin/env bash
## Behavioural check on the kill's own-chain guard (sh-lib/run/AgentsTools.ManagerSessionKill.include,
## AgentsToolsManagerKillOwnChain): a pid that is this process or one it descends from is the console that asked, and is
## never signalled. Held, run rather than read:
##   1. THE CALLER ITSELF IS ITS OWN CHAIN.
##   2. AN ANCESTOR IS TOO: the parent of this shell is a pid the guard refuses.
##   3. THE CONTROL: a process that is no ancestor (a child of this shell) is a run's to signal.
## Measured 2026-11-25: the kill's own command line names the session id it ends, the run recognition took the calling
## shell for the run, and TERM ended the caller twice.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/run/AgentsTools.ManagerSessionKill.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: no $rigInclude" >&2 ; exit 1 ; }
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerKillOwnChainCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
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
rigGuard(){ ## pid
	MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" || exit 9 ; AgentsToolsManagerKillOwnChain "$2" && printf own || printf signal' rig-guard "$rigInclude" "$1" 2> /dev/null
}
echo "-- 1. the caller is its own chain --"
rigAssert "this process is refused" "$( rigGuard $$ )" "own"
echo "-- 2. an ancestor is the caller's chain too --"
rigParentPid="$( ps -o ppid= -p $$ 2> /dev/null | LC_ALL=C tr -d ' ' )"
rigAssert "an ancestor of this shell is refused" "$( rigGuard "$rigParentPid" )" "own"
echo "-- 3. the control: a process that is no ancestor may be signalled --"
sleep 30 & rigChild=$!
rigAssert "a child of this shell is not the caller's chain" "$( rigGuard "$rigChild" )" "signal"
kill -TERM "$rigChild" 2> /dev/null || :
wait "$rigChild" 2> /dev/null || :
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER KILL OWN CHAIN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'MANAGER_KILL_OWN_CHAIN: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
