#!/usr/bin/env bash
## The Config Checker run on the testing system (C1 of the refactorings epic): a group of tests
## that run the checker against the ACTUAL installation, not a stand-in, and hold that it checks
## every setting in place, working and connecting. `--manager-check-run --local` runs each domain's
## own read-only diagnosis (`--owner-setup-<domain> --check`), which changes nothing; --local leaves
## out the two domains whose check asks outside the machine (claude, the CLI's sign-in, and slack,
## the team's token), so no CLI and no network is reached here.
## Held:
##   1. the call ends 0, and every domain answers, domain by domain in the one order; a domain may
##      print a row for each of its settings, each row eight TAB fields, its state one of
##      ok, warn, fail, skipped
##   2. the two domains whose check asks outside the machine are each one `skipped` row, left out
##      and not started
##   3. one `summary` row, the last, sums every row: checks, ok, warn, fail, skipped, seconds, and
##      its counts add up
##   4. nothing is written: the run folder the checker keeps in the workspace's scratch is gone
##      after the call
## Live: the real owner-setup checks run, so how many settings each domain reports, and what it
## says of them, depends on this machine; the shape, the order and the summing do not.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
mkdir -p "$MMDAPP/.local/agents/scratch" || rigRefuse "no workspace scratch could be made for what the checks print"
rigOut="$( ( cd "$MMDAPP" && env MMDAPP="$MMDAPP" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash "$rigTool" --manager-check-run --local --seconds 90 ) 2> /dev/null < /dev/null )" || rigRc=$?
rigRc="${rigRc:-0}"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}

echo "-- 1. every domain answers, in the one order, each row a known state --"
rigAssert "the call ends 0 though a check may fail: a diagnosis that finds a setting wrong is a row, not an error" "$rigRc" "0"
rigAssert "every domain answers, domain by domain in the order of the operation" "$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '$1 == "check" && !seen[$2]++ { printf "%s ", $2 }' )" "claude copilot grok scaleway slack storage "
rigAssert "each row has eight fields, and each state is one of ok, warn, fail, skipped" "$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '$1 == "check" { if ( NF != 8 ) bad++ ; if ( $6 != "ok" && $6 != "warn" && $6 != "fail" && $6 != "skipped" ) bad++ } END { print bad + 0 }' )" "0"
rigAssert "the two domains whose check asks outside the machine are each one skipped row, left out and not started" "$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '$1 == "check" && ($2 == "claude" || $2 == "slack") { printf "%s:%s ", $2, $6 }' )" "claude:skipped slack:skipped "

echo "-- 2. the one summing row, the last --"
rigAssert "the summary sums every row: ok, warn, fail and skipped add up to the checks" "$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '$1 == "summary" { print ( ($2 + 0) == ($3 + $4 + $5 + $6) ) }' )" "1"
rigAssert "it counts every domain's rows, so at least six, one a domain" "$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '$1 == "summary" { print ( ($2 + 0) >= 6 ) }' )" "1"
rigAssert "and it is the last row, after every check row, naming the seconds it took" "$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '$1 == "summary" { print $1, NF, ( ($7 + 0) >= 0 ) }' | LC_ALL=C tail -1 ) $( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '{ last = $1 } END { print last }' )" "summary 7 1 summary"

echo "-- 3. read-only, and the run folder gone after --"
rigAssert "the checker names the owner's read-only check alone, no apply and no set of its own" "$( LC_ALL=C grep -c -F -- '"--owner-setup-$runName" --check' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ManagerCheck.include" ) $( LC_ALL=C grep -c -F -e '"--owner-setup-$runName" --apply' -e '"--owner-setup-$runName" --set' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ManagerCheck.include" )" "1 0"
rigAssert "the run folder it kept in the workspace's scratch is gone after the call" "$( ls -1 "$MMDAPP/.local/agents/scratch" | LC_ALL=C grep -c '^AgentsManagerCheck\.' )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CONFIG CHECKER LIVE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CONFIG_CHECKER_LIVE: OK (%d assertions, live, the real owner-setup checks)\n' "$rigPasses"
