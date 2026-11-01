#!/usr/bin/env bash
## Behavioural check on the clock of a start (S4.5 of the refactorings epic), run rather than read: the whole seconds
## each step of a start took, kept as `<step>=<n>s` words by AgentsToolsStartStepsSay (its one line is the session's
## start milestone), and appended to the session's `launch.steps`, one a line, by AgentsToolsStartStepMark.
##   1. EVERY STEP THAT RAN IS NAMED, once, in the order it ran, and the line ends with the whole start's total.
##   2. THE SESSION KEEPS THE SAME STEPS: `launch.steps` beside its launcher holds one `<step>=<n>s` a line, in that order.
##   3. A MARK OUTSIDE A START writes nothing and says nothing: no step invented, no file touched.
##   4. A START WHOSE CLOCK NEVER BEGAN says plain `start`, so the milestone still reads as a start.
##   5. THE SCAN'S OWN SECTIONS ride on the input-scan step, so a slow scan names its slow section in the same line.
## Offline: a workspace of the rig's own, and the clock read from the real `date`.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/session/AgentsTools.SpawnSandbox.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "not found at the origin this workspace resolves: $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsStartStepsCheck )" || exit 1
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
}

rigWs="" rigSession=""
rigScene(){ ## scenario name
	rigWs="$rigTmp/$1/ws"
	rigSession="rig-sess-$1"
	rm -rf "$rigTmp/$1"
	mkdir -p "$rigWs/.local/agents/sessions/$rigSession"
}
rigSteps(){ ## the session's own record of its steps, one a line
	cat "$rigWs/.local/agents/sessions/$rigSession/launch.steps" 2> /dev/null
}
## The clock's three calls, made in one shell, as the start makes them: nothing of the test's own is named.
rigClock(){ ## what to do: begin-and-mark, mark-only, say-only
	MMDAPP="$rigWs" MDAT_SPAWN_SESSION_ID="$rigSession" MDLT_ORIGIN="$rigOrigin" "${BASH:-bash}" -c '
		. "$1" || exit 1
		case "$2" in
			begin-and-mark) AgentsToolsStartStepBegin ; AgentsToolsStartStepMark prepare ; AgentsToolsStartStepMark input-scan ; AgentsToolsStartStepsSay "$3" ;;
			mark-only) AgentsToolsStartStepMark prepare ;;
			say-only) AgentsToolsStartStepsSay "" ;;
		esac
	' rig "$rigInclude" "$1" "${2:-}"
}

echo "-- 1. every step that ran is named, once, in order, and the line ends with the total --"
rigScene steps
rigLine="$( rigClock begin-and-mark )"
rigAssert "the milestone is one start-steps line"                    "$( printf '%s\n' "$rigLine" | LC_ALL=C grep -c -E '^start steps: prepare=[0-9]+s input-scan=[0-9]+s total=[0-9]+s$' )" 1
rigAssert "a step that did not run is not in the line"               "$( printf '%s\n' "$rigLine" | LC_ALL=C grep -c -E 'sandbox=|records=' )" 0

echo "-- 2. the session keeps the same steps, one a line --"
rigAssert "one line each, in the order it ran"                       "$( rigSteps | LC_ALL=C sed 's/=[0-9]*s$//' | tr '\n' ' ' )" "prepare input-scan "
rigAssert "each line is <step>=<n>s"                                 "$( rigSteps | LC_ALL=C grep -c -E '^[a-z-]+=[0-9]+s$' )" 2

echo "-- 3. a mark outside a start invents nothing --"
rigScene mark-only
rigClock mark-only
rigAssert "nothing written where no start began"                     "$( rigSteps )" ""
rigAssert "and the milestone of no start says plain start"           "$( rigClock say-only )" "start"

echo "-- 4. a start whose clock never began says plain start --"
rigScene say-only
rigAssert "plain start, and no steps"                                "$( rigClock say-only )" "start"

echo "-- 5. the scan's own sections ride on the input-scan step --"
rigScene scan
printf '%s\n' 'sandbox=1s' 'board=2s' > "$rigTmp/scan-sections"
rigLine="$( rigClock begin-and-mark "$rigTmp/scan-sections" )"
rigAssert "the slow section is named in the same line"               "$( printf '%s\n' "$rigLine" | LC_ALL=C grep -c -F 'input-scan[sandbox=1s board=2s]=' )" 1
rigAssert "and the start's total still closes the line"              "$( printf '%s\n' "$rigLine" | LC_ALL=C grep -c -E 'total=[0-9]+s$' )" 1

if [ "$rigFailCount" != 0 ] ; then
	printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount"
	exit 1
fi
printf 'RESULT: PASS (%s assertions)\n' "$rigPassCount"
exit 0
