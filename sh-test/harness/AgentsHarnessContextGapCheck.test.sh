#!/usr/bin/env bash
## Behavioural check on the kept-context validator (sh-lib/harness/AgentsHarnessContextTranscript.awk, mode=validate), on the
## numbering a resumed context carries. Held, run rather than read:
##   1. A GAP IS A VALID CONTEXT: a file holding messages 1 and 5 (a run that resumed a kept context numbered up to 4) validates,
##      and its message count is read.
##   2. DISORDER IS REFUSED, naming the line and both numbers.
##   3. A REPEATED NUMBER IS REFUSED TOO.
##   4. THE CONTROL: consecutive numbers validate, so row 1 is about the gap alone.
## The camunda-7 run's kept context jumped 26 -> 403, and the old validator refused it, so a restart dropped the whole history.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigAwkFile="$rigPackage/sh-lib/harness/AgentsHarnessContextTranscript.awk"
rigJson="$rigPackage/sh-lib/harness/AgentsHarnessJsonField.awk"
[ -f "$rigAwkFile" ] || { echo "⛔ ERROR: no $rigAwkFile" >&2 ; exit 1 ; }
[ -f "$rigJson" ] || { echo "⛔ ERROR: no $rigJson" >&2 ; exit 1 ; }
rigTmp="$( mktemp -d "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp/AgentsHarnessContextGapCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
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
rigCtx(){ ## file, message numbers... -- a kept context whose messages carry those numbers
	local ctxFile="$1" ctxNo=1
	shift
	{
		printf '{"type":"context","session":"rig"}\n'
		printf '{"type":"system","text":"rig"}\n'
		printf '{"type":"tools","tools":[]}\n'
		for ctxNo in "$@" ; do
			printf '{"type":"message","n":%s,"kind":"assistant","record":{"role":"assistant","content":"rig"}}\n' "$ctxNo"
		done
	} > "$ctxFile"
}
rigValidate(){ ## file
	LC_ALL=C awk -v mode=validate -f "$rigJson" -f "$rigAwkFile" "$1" 2> /dev/null
}
echo "-- 1. a gap is a valid context --"
rigCtx "$rigTmp/gap.ctx" 1 5
rigAssert "messages 1 and 5 validate, and the count is read" "$( rigValidate "$rigTmp/gap.ctx" )" "2"
echo "-- 2. disorder is refused --"
rigCtx "$rigTmp/order.ctx" 5 3
rigAssert "a message numbered below the one before is refused, naming both" "$( rigValidate "$rigTmp/order.ctx" | cut -c1-60 )" "line 5 is message 3, after message 5"
echo "-- 3. a repeat is refused --"
rigCtx "$rigTmp/repeat.ctx" 2 2
rigAssert "a repeated number is refused" "$( rigValidate "$rigTmp/repeat.ctx" | cut -c1-40 )" "line 5 is message 2, after message 2"
echo "-- 4. the control: consecutive numbers validate --"
rigCtx "$rigTmp/plain.ctx" 1 2 3
rigAssert "consecutive messages validate with their count" "$( rigValidate "$rigTmp/plain.ctx" )" "3"
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS CONTEXT GAP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'HARNESS_CONTEXT_GAP: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
