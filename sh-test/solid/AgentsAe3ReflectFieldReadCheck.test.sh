#!/usr/bin/env bash
## Behavioural check on the reflection's field pass (the AE3 tree's own
## `ae3.sys/java/ru/myx/ae3/reflect/ValueReflectionImpl.java`), run rather than read: a public field
## that carries a same-name setter must still read its own value.
##   1. THE FIELD READS, AND THE SETTER STILL RUNS: the probe reads `BB3` from a public field with two
##      same-name setters and no getter, and `BB3,str=123` after a write through that setter.
##   2. THE CONTROLS ARE UNTOUCHED: a plain public field and a public field with a getter read `BB3` in
##      the same arm, so a changed reading is the subject's own shape and not the probe.
##   3. THE INSTRUMENT CAN FAIL: the same probe compiled against a copy of the source with the guard
##      clause taken out reads `undefined` there, and still reads `BB3` for both controls. A green arm
##      beside a green planted arm would have established nothing.
## Both arms are compiled from that one source file into this rig, and the arm's own output dir comes
## first on the run classpath: the tree's bin is a live Eclipse build, so it is the tree's own state
## and no control. Where no AE3 tree or no JDK is reachable the check measures nothing and says so.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigNothingMeasured(){
	printf 'AGENTS_AE3_REFLECT_FIELD_READ: SKIPPED, nothing was measured: %s\n' "$1"
	exit 0
}
[ -f "$rigFixtures/ae3-tree.include.sh" ] || rigRefuse "the AE3 tree fixture is not in the package"
[ -f "$rigFixtures/ae3-reflect-field-read.probe.java" ] || rigRefuse "the probe fixture is not in the package"
command -v javac > /dev/null 2>&1 || rigNothingMeasured "javac is not on PATH, so no arm can be compiled"
command -v java > /dev/null 2>&1 || rigNothingMeasured "java is not on PATH, so no arm can be run"
. "$rigFixtures/ae3-tree.include.sh" || rigRefuse "the AE3 tree fixture would not load"
. "$rigFixtures/rig-temp.include.sh" || rigRefuse "the rig fixture would not load"

rigTree="$( ae3TreeRoot ae3.sys ae3.api ae3.sdk ae3.system acm-base-api 2> /dev/null )" || rigNothingMeasured "no place holds a tree with the AE3 projects this read needs"
rigSource="$rigTree/ae3.sys/java/ru/myx/ae3/reflect/ValueReflectionImpl.java"
[ -f "$rigSource" ] || rigNothingMeasured "the AE3 tree holds no $rigSource"
rigTmp="$( rigTempDir AgentsAe3ReflectFieldReadCheck )" || rigRefuse "the rig's folder could not be made"
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
rigReading(){ ## log file, what the probe called the shape -- the value it printed, or `none`
	LC_ALL=C sed -n "s/^.*PROBE-READ $2: //p" "$1" 2> /dev/null | LC_ALL=C sed -n 1p
}

rigCpCompile="$( ae3CompilePath "$rigTree" )"
rigCpRun="$( ae3RunPath "$rigTree" )"
mkdir -p "$rigTmp/tree/ru/myx/ae3/reflect" "$rigTmp/planted/ru/myx/ae3/reflect" "$rigTmp/probe/ru/myx/ae3/probe" \
	"$rigTmp/tree-bin" "$rigTmp/planted-bin" "$rigTmp/probe-bin" || rigRefuse "the rig's folders could not be made"

echo "-- the two arms, both compiled from the tree's own source --"
cp "$rigSource" "$rigTmp/tree/ru/myx/ae3/reflect/ValueReflectionImpl.java" || rigRefuse "the tree's own source could not be read"
LC_ALL=C awk '
	$0 == "\t\t\t\tif (existing != null && !(existing instanceof HandlerForGetterAndSetter)) {" { print "\t\t\t\tif (existing != null) {" ; seen++ ; next }
	{ print }
	END { if ( seen == 0 ) { print "AGENTS-AE3-REFLECT-FIELD-READ: the source holds no guard clause to take out, so the planted arm is the source as it stands" > "/dev/stderr" } }
' "$rigSource" > "$rigTmp/planted/ru/myx/ae3/reflect/ValueReflectionImpl.java" || rigRefuse "the planted copy could not be written"
ae3Compile "$rigCpCompile" "$rigTmp/tree/ru/myx/ae3/reflect/ValueReflectionImpl.java" "$rigTmp/tree-bin" || rigRefuse "the tree's source did not compile"
ae3Compile "$rigCpCompile" "$rigTmp/planted/ru/myx/ae3/reflect/ValueReflectionImpl.java" "$rigTmp/planted-bin" || rigRefuse "the planted source did not compile"
cp "$rigFixtures/ae3-reflect-field-read.probe.java" "$rigTmp/probe/ru/myx/ae3/probe/Ae3ReflectFieldReadProbe.java" || rigRefuse "the probe fixture could not be read"
ae3Compile "$rigCpCompile" "$rigTmp/probe/ru/myx/ae3/probe/Ae3ReflectFieldReadProbe.java" "$rigTmp/probe-bin" || rigRefuse "the probe did not compile"

echo "-- 1. the field reads, and its setter still runs --"
ae3Run 120 "$rigTmp/tree-bin:$rigTmp/probe-bin:$rigCpRun" ru.myx.ae3.probe.Ae3ReflectFieldReadProbe > "$rigTmp/tree.log" 2>&1
rigAssert "the probe reached its own end on the tree's arm" "$( LC_ALL=C grep -c -F 'PROBE-END' "$rigTmp/tree.log" )" 1
rigAssert "a public field with two same-name setters and no getter reads its value" "$( rigReading "$rigTmp/tree.log" setter-only )" "BB3"
rigAssert "a write through that setter reaches the field, and the read still answers the field" \
	"$( rigReading "$rigTmp/tree.log" setter-only-after-put )" "BB3,str=123"

echo "-- 2. the controls are untouched --"
rigAssert "control: a plain public field reads its value" "$( rigReading "$rigTmp/tree.log" plain )" "BB3"
rigAssert "control: a public field with a getter beside its setters reads its value" "$( rigReading "$rigTmp/tree.log" getter )" "BB3"

echo "-- 3. the instrument can fail: the same probe on the planted defect --"
ae3Run 120 "$rigTmp/planted-bin:$rigTmp/probe-bin:$rigCpRun" ru.myx.ae3.probe.Ae3ReflectFieldReadProbe > "$rigTmp/planted.log" 2>&1
rigAssert "the probe reached its own end on the planted arm" "$( LC_ALL=C grep -c -F 'PROBE-END' "$rigTmp/planted.log" )" 1
rigAssert "with the guard clause taken out, that same read answers undefined" "$( rigReading "$rigTmp/planted.log" setter-only )" "undefined"
rigAssert "control: that arm still reads a plain public field" "$( rigReading "$rigTmp/planted.log" plain )" "BB3"
rigAssert "control: that arm still reads a field with a getter" "$( rigReading "$rigTmp/planted.log" getter )" "BB3"

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ AE3 REFLECT FIELD READ CHECK FAILED: %d of %d assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'AGENTS_AE3_REFLECT_FIELD_READ: OK (%d assertions, two arms compiled from the tree source)\n' "$rigPassCount"
