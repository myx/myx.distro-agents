#!/usr/bin/env bash
## Behavioural check of a call's machinery time in its record (AgentsHarnessContextToolMeta, AgentsHarnessToolRunMsKeep): mach_ms is
## the call's whole time less what the call itself ran (a Wait's waiting, a Bash child's run), the measure the pace gate reads. Every
## tool runs in the subshell of harnessResult="$( ... )" (AgentsHarnessRun.include), so the span a tool keeps must reach the record
## from that subshell: kept there, the record subtracts it, and reads it once only. A variable alone set in the subshell is lost, and
## the call is all machinery (shown here as the control). A tool that keeps nothing is all machinery. Offline: a temp scratch only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessContext.include"
rigTranscript="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionTranscript.include"
[ -f "$rigLib" ] && [ -f "$rigTranscript" ] || { echo "⛔ ERROR: a library is not at the origin -- refusing to report a result" >&2 ; exit 1 ; }
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessToolMachCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One call's record, its whole time set to 20 s before now; the shell text runs first, as the tool would, then the record is written.
## Prints `<dur_ms> <mach_ms>`.
rigMeta(){ ## shell text, run as the tool
	( harnessHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib" ; harnessScratch="$rigTmp/scratch" ; mkdir -p "$harnessScratch"
	  . "$rigTranscript" 2> /dev/null ; . "$rigLib" 2> /dev/null
	  agentsTranscriptT0=$(( $( date +%s )000 - 20000 )) ; harnessToolRunMs=""
	  eval "$1"
	  AgentsHarnessContextToolMeta Wait call-1 "WAIT-RESULT: TIMEOUT" "" | LC_ALL=C sed -n 's/.*"dur_ms":\([0-9]*\),"mach_ms":\([0-9]*\).*/\1 \2/p' )
}
rigBand(){ ## `<dur> <mach>`, the run kept (ms) -- "subtracted" where mach is dur less the run, within 2 s; "all" where mach is dur
	set -- $1 "$2"
	if [ "$2" = "$1" ] ; then printf all ; return 0 ; fi
	[ $(( $1 - $3 - $2 )) -le 2000 ] && [ $(( $1 - $3 - $2 )) -ge -2000 ] && printf subtracted || printf "off:$1:$2"
}

echo "-- the span a tool keeps from inside its subshell reaches its record --"
rigAssert "kept by AgentsHarnessToolRunMsKeep in the subshell: the 15 s it ran are not machinery" \
	"$( rigBand "$( rigMeta 'rigOut="$( AgentsHarnessToolRunMsKeep 15000 ; printf ok )"' )" 15000 )" subtracted
rigAssert "and it is read once: the next call, keeping nothing, is all machinery" \
	"$( rigMeta 'rigOut="$( AgentsHarnessToolRunMsKeep 15000 ; printf ok )" ; AgentsHarnessContextToolMeta Wait call-0 x "" > /dev/null' | LC_ALL=C awk '{ print ( $1 == $2 ) ? "all" : "subtracted" ; }' )" all
echo "-- the controls --"
rigAssert "control: a variable alone set in the subshell is lost, and the call is all machinery" \
	"$( rigBand "$( rigMeta 'rigOut="$( harnessToolRunMs=15000 ; printf ok )"' )" 15000 )" all
rigAssert "control: a tool that keeps nothing is all machinery" \
	"$( rigBand "$( rigMeta ':' )" 15000 )" all
rigAssert "the Wait and both Bash paths keep their span by it" \
	"$( LC_ALL=C grep -c 'AgentsHarnessToolRunMsKeep "\$(( waitWaitedSec \* 1000 ))"' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessWait.include" ):$( LC_ALL=C grep -c 'AgentsHarnessToolRunMsKeep "\$harnessToolRunMs"' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessToolsBash.include" )" "1:2"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS TOOL MACH CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_TOOL_MACH: OK (%d assertions, offline, temp scratch only)\n' "$rigPassCount"
