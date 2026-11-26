#!/usr/bin/env bash
## Behavioural check on THE LANE COUNT the suite's runner takes (`AgentsRunLaneCount`, sh-test/runner/AgentsRunExecute.sh):
## how many runs may stand beside each other, and which pace it reads for that.
##
## The owner's finding (W2, item task-20261125T1848Z): the count was widest when the machine said nothing -- `laneMax` on no
## measure, on a stale one, and on one over too few calls -- and it read whichever rig was freshest, not the rig that wanted
## the lane. A file-only retest request then put 911 tests in the line for five hours. Held:
##   1. no pace measure of the rig: one lane, and the reason says so
##   2. a measure older than its TTL: one lane
##   3. a fresh measure over too few calls to judge: one lane
##   4. control: a fresh measure under the gate over enough calls: the machine's own max
##   5. control: a fresh measure at or over the gate: one lane
## Offline: a rig workspace under this check's own temp tree, its own HOME, and one tiny test. No socket is opened.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigRunner="$rigPkg/sh-test/AgentsRunTests.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the test runner is not at the origin this workspace resolves: $rigRunner"
[ -f "$rigPkg/sh-test/runner/AgentsRunExecute.sh" ] || rigRefuse "the runner's part is missing from the package: sh-test/runner/AgentsRunExecute.sh"

rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRunLaneCountCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home"
rigWs="$rigTmp/ws"
rigCopy="$rigWs/myx/myx.distro-agents"
rigMeasure="$rigWs/.local/agents/schedule/pace.measure"
mkdir -p "$rigHome" "$rigCopy/sh-test/runner" "$rigCopy/sh-test/check-fixtures" "$rigWs/.local/agents/schedule" "$rigTmp/run" || exit 1
cp "$rigRunner" "$rigCopy/sh-test/AgentsRunTests.sh" || exit 1
cp "$rigPkg/sh-test/runner"/*.sh "$rigCopy/sh-test/runner/" || exit 1
cp "$rigPkg/sh-test/check-fixtures"/runner-*.py "$rigCopy/sh-test/check-fixtures/" || exit 1
cat > "$rigCopy/sh-test/RigLanes.test.sh" <<'RIGLANES'
#!/usr/bin/env bash
echo "RIG_LANES: OK"
RIGLANES
chmod +x "$rigCopy/sh-test/RigLanes.test.sh" || exit 1

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
rigText(){ ## a run's name, text -- whether its stdout or stderr holds it
	case "$( cat "$rigTmp/run/$1.out" "$rigTmp/run/$1.err" 2> /dev/null )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}
rigLanesTaken(){ ## a run's name -- the lanes open at its turn, from its own report line, stdout and stderr both, or no-lane-line
	local lanesText=""
	lanesText="$( cat "$rigTmp/run/$1.out" "$rigTmp/run/$1.err" 2> /dev/null | LC_ALL=C sed -n 's/.*running in [0-9][0-9]* lane(s) of the \([0-9][0-9]*\) open at its turn.*/\1/p' | LC_ALL=C sed -n 1p )"
	case "$lanesText" in ''|*[!0123456789]*) printf 'no-lane-line' ;; *) printf '%s' "$lanesText" ;; esac
}
rigRun(){ ## name -- one run of the tiny test, its output in <name>.out
	(
		cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigCopy" \
			MDAT_TOOL_PACE_CACHE_SECONDS="${rigTtl:-60}" \
			bash "$rigCopy/sh-test/AgentsRunTests.sh" RigLanes
	) > "$rigTmp/run/$1.out" 2> "$rigTmp/run/$1.err"
}
rigEpoch(){ date +%s ; }

## 1. no measure at all
rm -f "$rigMeasure"
rigRun without
rigAssert "no pace measure of the rig takes one lane"        "$( rigLanesTaken without )" "1"
rigAssert "and the reason says the rig records none"         "$( rigText without 'records no pace measure' )" "yes"

## 2. a measure past its TTL
printf '%s 300 2000 15\n' "$(( $( rigEpoch ) - 600 ))" > "$rigMeasure"
rigRun stale
rigAssert "a measure older than its TTL takes one lane"      "$( rigLanesTaken stale )" "1"
rigAssert "and the reason says how old it is"                "$( rigText stale 'too little to judge' )" "yes"

## 3. a fresh measure over too few calls
printf '%s 300 2000 1\n' "$( rigEpoch )" > "$rigMeasure"
rigRun few
rigAssert "a fresh measure over too few calls takes one lane" "$( rigLanesTaken few )" "1"

## 4. control: a fresh measure under the gate over enough calls
printf '%s 300 2000 15\n' "$( rigEpoch )" > "$rigMeasure"
rigRun under
rigAssert "control: a fresh measure under the gate takes the machine's max" "$( rigLanesTaken under )" "3"
rigAssert "and its reason names the median it read"          "$( rigText under 'median 2000 ms' )" "yes"

## 5. control: a fresh measure at or over the gate
printf '%s 300 4000 15\n' "$( rigEpoch )" > "$rigMeasure"
rigRun over
rigAssert "a fresh measure at the gate takes one lane"       "$( rigLanesTaken over )" "1"

echo
if [ "$rigFailCount" = "0" ] ; then
	printf 'LANE_COUNT: OK (%s assertions, offline, a rig workspace only)\n' "$rigPassCount"
	exit 0
fi
printf '⛔ LANE COUNT CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))"
exit 1
