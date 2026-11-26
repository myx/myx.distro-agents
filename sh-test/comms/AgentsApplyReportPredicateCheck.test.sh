#!/usr/bin/env bash
## Behavioural check on the one predicate both apply-report refusals stand on (AgentsApplyReportCheck.awk, and
## AgentsTools.ApplyReport.include over it): a line that says a file was applied and gives no place path, or no
## read-back, is a fault; a line that claims no apply is not measured at all. Offline, no rig tree, no network. Held:
##   1. control: a line with the place path and cmp is clean
##   2. a bare file name and a line number is two faults, one for the path and one for the read-back
##   3. an place path with no read-back is exactly one fault, the read-back's
##   4. a read-back with a relative path is exactly one fault, the path's
##   5. a line claiming no apply is not measured, whatever it holds
##   6. the include prints the faults, and returns 1
##   7. the two fault kinds are the two the scope names, and nothing else
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigComms="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms"
rigAwk="$rigComms/AgentsApplyReportCheck.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigAwk" ] || rigRefuse "the predicate is not in the tree under test: $rigAwk"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRun(){ ## the text -- prints the faults, sets rigRc
	rigFaults="$( printf '%s\n' "$1" | LC_ALL=C awk -f "$rigAwk" )" ; rigRc=$?
}

echo "-- 1. control: the place path and its read-back --"
rigRun 'put in place (base): myx/style.css.tpl -> ws-myx.ae3-devel:source/myx/style.css.tpl; read-back: ws-myx.ae3-devel:source/myx/style.css.tpl, cmp clean against the staged file'
rigAssert "clean, and no fault printed" "$rigRc:[$rigFaults]" "0:[]"

echo "-- 2. a bare name and a line number: both faults --"
rigRun 'applied: style.css.tpl:1314'
rigAssert "rc 1, and one fault of each kind" \
	"$rigRc:$( printf '%s\n' "$rigFaults" | LC_ALL=C grep -c '^applied-without-place-path: ' ):$( printf '%s\n' "$rigFaults" | LC_ALL=C grep -c '^applied-without-read-back: ' )" "1:1:1"

echo "-- 3. the place path, no read-back: the read-back's fault only --"
rigRun 'applied: ws-myx-devops:source/myx/style.css.tpl'
rigAssert "rc 1, one read-back fault, no path fault" \
	"$rigRc:$( printf '%s\n' "$rigFaults" | LC_ALL=C grep -c '^applied-without-place-path: ' ):$( printf '%s\n' "$rigFaults" | LC_ALL=C grep -c '^applied-without-read-back: ' )" "1:0:1"

echo "-- 4. a read-back with a relative path: the path's fault only --"
rigRun 'applied: source/myx/style.css.tpl, cksum 1234-99'
rigAssert "rc 1, one path fault, no read-back fault" \
	"$rigRc:$( printf '%s\n' "$rigFaults" | LC_ALL=C grep -c '^applied-without-place-path: ' ):$( printf '%s\n' "$rigFaults" | LC_ALL=C grep -c '^applied-without-read-back: ' )" "1:1:0"

echo "-- 5. no apply claimed: not measured --"
rigRun 'style.css.tpl:1314 is where the rule stands, and the checks pass.'
rigAssert "clean, though the line holds a file and a line number" "$rigRc:[$rigFaults]" "0:[]"
rigRun 'applying the fix now, ws-myx-devops:source/myx/style.css.tpl open'
rigAssert "a gerund is no apply claimed either" "$rigRc:[$rigFaults]" "0:[]"

echo "-- 6. the include prints what the awk found, and returns 1 --"
type AgentsToolsApplyReportFaults > /dev/null 2>&1 || . "$rigComms/AgentsTools.ApplyReport.include" || rigRefuse "the include did not load"
rigIncludeFaults="$( printf 'applied: style.css.tpl:1314\n' | AgentsToolsApplyReportFaults )" ; rigIncludeRc=$?
rigAssert "the include answers 1 with the same two faults" \
	"$rigIncludeRc:$( printf '%s\n' "$rigIncludeFaults" | LC_ALL=C grep -c '^applied-without-' )" "1:2"
rigIncludeFaults="$( printf 'nothing was applied, the checks pass\n' | AgentsToolsApplyReportFaults )" ; rigIncludeRc=$?
rigAssert "and 0 for a report that claims no apply" "$rigIncludeRc:[$rigIncludeFaults]" "0:[]"

echo "-- 7. only the two fault kinds are named --"
rigRun 'applied: style.css.tpl:1314'
rigAssert "the kinds are the scope's two" \
	"$( printf '%s\n' "$rigFaults" | LC_ALL=C awk -F: '{ print $1 ; }' | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" "applied-without-place-path applied-without-read-back "

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ APPLY REPORT PREDICATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'APPLY_REPORT_PREDICATE: OK (%d assertions, offline)\n' "$rigPassCount"
