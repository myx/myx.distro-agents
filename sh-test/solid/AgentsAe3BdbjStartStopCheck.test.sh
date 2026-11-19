#!/usr/bin/env bash
## Behavioural check on the bdbje local S4 driver's stop (the AE3 tree's own
## `ae3.sys.pkg.s4.lcl.bdbje/java/ru/myx/ae3/vfs/s4/lcl/bdbj/WorkerBdbj.java`), run rather than read:
## a start followed by a stop leaves no transaction open on the environment.
##   1. START AND STOP BOTH SUCCEED: the probe starts the driver over a storage folder of its own and
##      stops it, and reports each call's own outcome.
##   2. THE ENVIRONMENT IS CLOSED CLEANLY: a stop that left a transaction open raises
##      `IllegalStateException: There are N existing transactions opened against the Environment`, and
##      that is what this row reads.
##   3. THE INSTRUMENT CAN FAIL: the same probe compiled against a copy of the source whose stop closes
##      the global transaction instead of destroying it raises that exception, and still reports both
##      calls reached. A green arm beside a green planted arm would have established nothing.
## Both arms are compiled from that one source file into this rig, and the arm's own output dir comes
## first on the run classpath: the tree's bin is a live Eclipse build, so it is the tree's own state and
## no control. Where no AE3 tree or no JDK is reachable the check measures nothing and says so.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigNothingMeasured(){
	printf 'AGENTS_AE3_BDBJ_START_STOP: SKIPPED, nothing was measured: %s\n' "$1"
	exit 0
}
[ -f "$rigFixtures/ae3-tree.include.sh" ] || rigRefuse "the AE3 tree fixture is not in the package"
[ -f "$rigFixtures/ae3-bdbj-start-stop.probe.java" ] || rigRefuse "the probe fixture is not in the package"
command -v javac > /dev/null 2>&1 || rigNothingMeasured "javac is not on PATH, so no arm can be compiled"
command -v java > /dev/null 2>&1 || rigNothingMeasured "java is not on PATH, so no arm can be run"
. "$rigFixtures/ae3-tree.include.sh" || rigRefuse "the AE3 tree fixture would not load"
. "$rigFixtures/rig-temp.include.sh" || rigRefuse "the rig fixture would not load"

rigTree="$( ae3TreeRoot ae3.sys.pkg.s4.lcl.bdbje ae3.sys.pkg.s4 ae3.pkg.lib.bdbje ae3.sys ae3.api ae3.sdk ae3.system acm-base-api 2> /dev/null )" \
	|| rigNothingMeasured "no place holds a tree with the AE3 projects this driver needs"
rigSource="$rigTree/ae3.sys.pkg.s4.lcl.bdbje/java/ru/myx/ae3/vfs/s4/lcl/bdbj/WorkerBdbj.java"
[ -f "$rigSource" ] || rigNothingMeasured "the AE3 tree holds no $rigSource"
[ -d "$rigTree/acm-cvs/sys-current/axiom" ] || rigNothingMeasured "the AE3 tree holds no acm-cvs/sys-current/axiom, which the AE3 boot needs"
rigTmp="$( rigTempDir AgentsAe3BdbjStartStopCheck )" || rigRefuse "the rig's folder could not be made"
rigTmp="$( cd "$rigTmp" && pwd -P )" || rigRefuse "the rig's folder could not be resolved"
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
rigSaid(){ ## log file, fixed text -- how many lines hold it
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}

rigCpCompile="$( ae3CompilePath "$rigTree" )"
rigCpRun="$( ae3RunPath "$rigTree" )"
mkdir -p "$rigTmp/tree/ru/myx/ae3/vfs/s4/lcl/bdbj" "$rigTmp/planted/ru/myx/ae3/vfs/s4/lcl/bdbj" "$rigTmp/probe/ru/myx/ae3/probe" \
	"$rigTmp/tree-bin" "$rigTmp/planted-bin" "$rigTmp/probe-bin" "$rigTmp/tree-storage" "$rigTmp/planted-storage" \
	|| rigRefuse "the rig's folders could not be made"

echo "-- the two arms, both compiled from the tree's own source --"
cp "$rigSource" "$rigTmp/tree/ru/myx/ae3/vfs/s4/lcl/bdbj/WorkerBdbj.java" || rigRefuse "the tree's own source could not be read"
sed 's|this\.xctGlobal\.destroy();|this.xctGlobal.close();|' "$rigSource" > "$rigTmp/planted/ru/myx/ae3/vfs/s4/lcl/bdbj/WorkerBdbj.java" \
	|| rigRefuse "the planted copy could not be written"
[ "$( LC_ALL=C grep -c -F 'this.xctGlobal.close();' "$rigTmp/planted/ru/myx/ae3/vfs/s4/lcl/bdbj/WorkerBdbj.java" )" = 1 ] || {
	echo "AGENTS-AE3-BDBJ-START-STOP: the source holds no destroy call to plant its defect at, so the planted arm is the source as it stands" >&2
}
ae3Compile "$rigCpCompile" "$rigTmp/tree/ru/myx/ae3/vfs/s4/lcl/bdbj/WorkerBdbj.java" "$rigTmp/tree-bin" || rigRefuse "the tree's source did not compile"
ae3Compile "$rigCpCompile" "$rigTmp/planted/ru/myx/ae3/vfs/s4/lcl/bdbj/WorkerBdbj.java" "$rigTmp/planted-bin" || rigRefuse "the planted source did not compile"
cp "$rigFixtures/ae3-bdbj-start-stop.probe.java" "$rigTmp/probe/ru/myx/ae3/probe/Ae3BdbjStartStopProbe.java" || rigRefuse "the probe fixture could not be read"
ae3Compile "$rigCpCompile" "$rigTmp/probe/ru/myx/ae3/probe/Ae3BdbjStartStopProbe.java" "$rigTmp/probe-bin" || rigRefuse "the probe did not compile"

echo "-- 1. start and stop both succeed --"
ae3Run 180 "$rigTmp/tree-bin:$rigTmp/probe-bin:$rigCpRun" ru.myx.ae3.probe.Ae3BdbjStartStopProbe \
	"$rigTree" "$rigTmp/tree-storage" > "$rigTmp/tree.log" 2>&1
rigAssert "the probe reached its own end on the tree's arm" "$( rigSaid "$rigTmp/tree.log" 'PROBE-END' )" 1
rigAssert "the driver starts" "$( rigSaid "$rigTmp/tree.log" 'PROBE-OK-START start-only' )" 1
rigAssert "and stops" "$( rigSaid "$rigTmp/tree.log" 'PROBE-OK-STOP start-only' )" 1

echo "-- 2. the environment is closed cleanly --"
rigAssert "no stop left a transaction open on the environment" "$( rigSaid "$rigTmp/tree.log" 'existing transactions opened against the Environment' )" 0

echo "-- 3. the instrument can fail: the same probe on the planted defect --"
ae3Run 180 "$rigTmp/planted-bin:$rigTmp/probe-bin:$rigCpRun" ru.myx.ae3.probe.Ae3BdbjStartStopProbe \
	"$rigTree" "$rigTmp/planted-storage" > "$rigTmp/planted.log" 2>&1
rigAssert "the probe reached its own end on the planted arm" "$( rigSaid "$rigTmp/planted.log" 'PROBE-END' )" 1
rigAssert "the driver still starts there" "$( rigSaid "$rigTmp/planted.log" 'PROBE-OK-START start-only' )" 1
rigAssert "with the destroy call replaced by a close, the stop fails" "$( rigSaid "$rigTmp/planted.log" 'PROBE-STOP-FAILED start-only' )" 1
rigAssert "and what it reports is the open transactions it left" \
	"$( rigSaid "$rigTmp/planted.log" 'existing transactions opened against the Environment' )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ AE3 BDBJ START STOP CHECK FAILED: %d of %d assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'AGENTS_AE3_BDBJ_START_STOP: OK (%d assertions, two arms compiled from the tree source)\n' "$rigPassCount"
