#!/usr/bin/env bash
## Behavioural check on the newest-part-first transcript read (sh-lib/session/AgentsTools.SessionTranscript.include, AgentsTranscriptLastTool):
## the scan asks every live run for its last tool line, and reading every part of every transcript is the scan's whole cost.
## Held, with the parts list stubbed so the files are the subject:
##   1. THE NEWEST PART ANSWERS, AND NO EARLIER PART IS OPENED: an unreadable older part still answers cleanly, with no
##      diagnostic, which is what proves the walk stopped at the newest part.
##   2. A NEWEST PART WITH NO TOOL LINE SENDS THE WALK ONE PART BACK: the older part's line comes back.
##   3. THE CONTROL: no parts at all answers nothing, so row 1 is about the file that answered and not about an empty answer.
## RED RECIPE, measured 2026-11-26 00:10 +0200: before the change the function awk'd every part (one awk over the whole
## list). With an unreadable older part that run reports its diagnostic on stderr, so row 1's empty-stderr assertion fails.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/session/AgentsTools.SessionTranscript.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: no $rigInclude" >&2 ; exit 1 ; }
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTranscriptLastToolCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigOld="$rigTmp/old.log"
rigNew="$rigTmp/new.log"
printf '1 TOOL Bash\n2 TOOL Read\n' > "$rigOld"
printf '3 TOOL Bash\n4 TOOL Wait\n' > "$rigNew"
rigPassCount=0
rigFailCount=0
rigAssert(){
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
echo "-- 1. the newest part answers, and the older one is not opened --"
chmod 000 "$rigOld"
rigOut="$( MDLT_ORIGIN="$MDLT_ORIGIN" RIG_PARTS="$rigOld
$rigNew" bash -c '
	. "$1" || exit 9
	AgentsTranscriptParts(){ printf "%s\n" "$RIG_PARTS" ; }
	AgentsTranscriptLastTool rig-session
' rig-last-tool "$rigInclude" 2> "$rigTmp/stderr" )" || rigOut=""
rigErr="$( cat "$rigTmp/stderr" 2> /dev/null )"
chmod 644 "$rigOld"
rigAssert "the newest part line is the answer" "$rigOut" "4 Wait"
rigAssert "and the unreadable older part was never opened" "$rigErr" ""
echo "-- 2. a newest part with no tool line walks one part back --"
printf '5 NOTE something\n' > "$rigNew"
rigOut="$( MDLT_ORIGIN="$MDLT_ORIGIN" RIG_PARTS="$rigOld
$rigNew" bash -c '
	. "$1" || exit 9
	AgentsTranscriptParts(){ printf "%s\n" "$RIG_PARTS" ; }
	AgentsTranscriptLastTool rig-session
' rig-last-tool "$rigInclude" 2> /dev/null )" || rigOut=""
rigAssert "the older part answers" "$rigOut" "2 Read"
echo "-- 3. no parts answers nothing --"
rigOut="$( MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
	. "$1" || exit 9
	AgentsTranscriptParts(){ : ; }
	AgentsTranscriptLastTool rig-session
' rig-last-tool "$rigInclude" 2> /dev/null )" || rigOut=""
rigAssert "none is an empty answer" "$rigOut" ""
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TRANSCRIPT LAST TOOL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'TRANSCRIPT_LAST_TOOL: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
