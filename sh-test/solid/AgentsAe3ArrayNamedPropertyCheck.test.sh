#!/usr/bin/env bash
## Behavioural check on the XML writer's array branch (the AE3 tree's own
## `ae3.sdk/java/ru/myx/ae3/xml/Xml.java`), run rather than read: every named own property of an array
## survives a write and a read back.
##   1. THE NAMED PROPERTY SURVIVES, in three shapes: no properties and no elements, one property and no
##      elements, and one property beside one element.
##   2. THE ELEMENT IS THE CONTROL: the array that carries one element reads that element back in every
##      arm, so a changed reading is the named property and not the writer's element loop.
##   3. THE INSTRUMENT CAN FAIL: the same probe compiled against a copy of the source with the loop this
##      check guards lifted out reads `alpha=undefined` there, and still reads its element back. A green
##      arm beside a green planted arm would have established nothing.
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
	printf 'AGENTS_AE3_ARRAY_NAMED_PROPERTY: SKIPPED, nothing was measured: %s\n' "$1"
	exit 0
}
[ -f "$rigFixtures/ae3-tree.include.sh" ] || rigRefuse "the AE3 tree fixture is not in the package"
[ -f "$rigFixtures/ae3-array-named-property.probe.java" ] || rigRefuse "the probe fixture is not in the package"
command -v javac > /dev/null 2>&1 || rigNothingMeasured "javac is not on PATH, so no arm can be compiled"
command -v java > /dev/null 2>&1 || rigNothingMeasured "java is not on PATH, so no arm can be run"
. "$rigFixtures/ae3-tree.include.sh" || rigRefuse "the AE3 tree fixture would not load"
. "$rigFixtures/rig-temp.include.sh" || rigRefuse "the rig fixture would not load"

rigTree="$( ae3TreeRoot ae3.sdk ae3.api ae3.sys ae3.sys.pkg.base acm-base-api 2> /dev/null )" || rigNothingMeasured "no place holds a tree with the AE3 projects this writer needs"
rigSource="$rigTree/ae3.sdk/java/ru/myx/ae3/xml/Xml.java"
[ -f "$rigSource" ] || rigNothingMeasured "the AE3 tree holds no $rigSource"
rigTmp="$( rigTempDir AgentsAe3ArrayNamedPropertyCheck )" || rigRefuse "the rig's folder could not be made"
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
rigValue(){ ## log file, what the probe called the shape, the field wanted -- its value, or `none`
	LC_ALL=C sed -n "s/^.*PROBE-BACK $2: //p" "$1" 2> /dev/null | LC_ALL=C sed -n 1p \
		| LC_ALL=C awk -v want="$3=" '{ for ( eachField = 1 ; eachField <= NF ; eachField++ ) if ( index( $eachField, want ) == 1 ) { print substr( $eachField, length( want ) + 1 ) ; exit } }'
}

rigCpCompile="$( ae3CompilePath "$rigTree" )"
rigCpRun="$( ae3RunPath "$rigTree" )"
mkdir -p "$rigTmp/tree/ru/myx/ae3/xml" "$rigTmp/planted/ru/myx/ae3/xml" "$rigTmp/probe/ru/myx/ae3/probe" \
	"$rigTmp/tree-bin" "$rigTmp/planted-bin" "$rigTmp/probe-bin" || rigRefuse "the rig's folders could not be made"

echo "-- the two arms, both compiled from the tree's own source --"
cp "$rigSource" "$rigTmp/tree/ru/myx/ae3/xml/Xml.java" || rigRefuse "the tree's own source could not be read"
LC_ALL=C awk '
	$0 == "\t\t\t\tfor (final Iterator<String> iterator = array.baseKeysOwn(); iterator.hasNext();) {" { skip = 1 ; seen++ ; next }
	skip == 1 { if ( $0 == "\t\t\t\t}" ) { skip = 0 } ; next }
	{ print }
	END { if ( seen == 0 ) { print "AGENTS-AE3-ARRAY-NAMED-PROPERTY: the source holds no guarded loop to lift out, so the planted arm is the source as it stands" > "/dev/stderr" } }
' "$rigSource" > "$rigTmp/planted/ru/myx/ae3/xml/Xml.java" || rigRefuse "the planted copy could not be written"
ae3Compile "$rigCpCompile" "$rigTmp/tree/ru/myx/ae3/xml/Xml.java" "$rigTmp/tree-bin" || rigRefuse "the tree's source did not compile"
ae3Compile "$rigCpCompile" "$rigTmp/planted/ru/myx/ae3/xml/Xml.java" "$rigTmp/planted-bin" || rigRefuse "the planted source did not compile"
cp "$rigFixtures/ae3-array-named-property.probe.java" "$rigTmp/probe/ru/myx/ae3/probe/Ae3ArrayNamedPropertyProbe.java" || rigRefuse "the probe fixture could not be read"
ae3Compile "$rigCpCompile" "$rigTmp/probe/ru/myx/ae3/probe/Ae3ArrayNamedPropertyProbe.java" "$rigTmp/probe-bin" || rigRefuse "the probe did not compile"

echo "-- 1. the named property survives, in every shape --"
ae3Run 120 "$rigTmp/tree-bin:$rigTmp/probe-bin:$rigCpRun" ru.myx.ae3.probe.Ae3ArrayNamedPropertyProbe > "$rigTmp/tree.log" 2>&1
rigAssert "the probe reached its own end on the tree's arm" "$( LC_ALL=C grep -c -F 'PROBE-END' "$rigTmp/tree.log" )" 1
rigAssert "a property with no elements survives the write and the read" "$( rigValue "$rigTmp/tree.log" one-prop-no-elements alpha )" "A"
rigAssert "a property beside an element survives too" "$( rigValue "$rigTmp/tree.log" one-prop-one-element alpha )" "A"
rigAssert "an array of no properties and no elements reads back as no properties" \
	"$( rigValue "$rigTmp/tree.log" empty alpha )" "undefined"

echo "-- 2. the element is the control --"
rigAssert "control: the element of that array is read back" "$( rigValue "$rigTmp/tree.log" one-prop-one-element length )" "1"

echo "-- 3. the instrument can fail: the same probe on the planted defect --"
ae3Run 120 "$rigTmp/planted-bin:$rigTmp/probe-bin:$rigCpRun" ru.myx.ae3.probe.Ae3ArrayNamedPropertyProbe > "$rigTmp/planted.log" 2>&1
rigAssert "the probe reached its own end on the planted arm" "$( LC_ALL=C grep -c -F 'PROBE-END' "$rigTmp/planted.log" )" 1
rigAssert "with the guarded loop lifted out, the same property reads back as undefined" \
	"$( rigValue "$rigTmp/planted.log" one-prop-no-elements alpha )" "undefined"
rigAssert "with it lifted out, the property beside an element reads back as undefined too" \
	"$( rigValue "$rigTmp/planted.log" one-prop-one-element alpha )" "undefined"
rigAssert "control: that arm still writes and reads the element" "$( rigValue "$rigTmp/planted.log" one-prop-one-element length )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ AE3 ARRAY NAMED PROPERTY CHECK FAILED: %d of %d assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'AGENTS_AE3_ARRAY_NAMED_PROPERTY: OK (%d assertions, two arms compiled from the tree source)\n' "$rigPassCount"
