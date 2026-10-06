#!/usr/bin/env bash
## Differential check on AgentsHarnessJsonField.awk: the linear engine answers every
## fixture exactly as the previous, quadratic one did -- stdout, stderr and exit status,
## byte for byte -- and its library entry (jfParseText, which the stream consumers of
## both wire adapters use) yields the same value for every leaf. The previous engine is
## kept ONLY here, as check-fixtures/AgentsHarnessJsonField.legacy.awk; nothing in
## sh-lib loads it. Fixtures are hand-written edge cases (escapes, \u and surrogates,
## grammar quirks, malformed input, duplicates, values crossing the 256-byte chunk
## boundary) plus a seeded, deterministic generator of nested and mutated documents.
## Offline by construction: temp files only, no network, no credential.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigNew="$rigHere/AgentsHarnessJsonField.awk"
rigOld="$rigTest/check-fixtures/AgentsHarnessJsonField.legacy.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigNew" ] || rigRefuse "the field reader is not at the origin this workspace resolves: $rigNew"
[ -f "$rigOld" ] || rigRefuse "the legacy engine fixture is missing: $rigOld"

rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsHarnessJsonFieldDiffCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigFailShown=0
rigFail(){ ## what differed
	rigFailCount=$(( rigFailCount + 1 ))
	[ "$rigFailShown" -lt 20 ] || return 0
	rigFailShown=$(( rigFailShown + 1 ))
	printf '  FAIL  %s\n' "$1"
}

## One engine on one document and path, every observable kept: stdout, stderr, rc.
rigRunOne(){ ## engine file, document file, path, extra -v, output stem
	local runRc=0
	if [ -n "$4" ] ; then
		LC_ALL=C awk -v path="$3" -v "$4" -f "$1" < "$2" > "$5.out" 2> "$5.err" || runRc=$?
	else
		LC_ALL=C awk -v path="$3" -f "$1" < "$2" > "$5.out" 2> "$5.err" || runRc=$?
	fi
	printf '%s' "$runRc" > "$5.rc"
}

rigCompare(){ ## document file, path, extra -v
	rigRunOne "$rigOld" "$1" "$2" "$3" "$rigTmp/old"
	rigRunOne "$rigNew" "$1" "$2" "$3" "$rigTmp/new"
	if cmp -s "$rigTmp/old.out" "$rigTmp/new.out" && cmp -s "$rigTmp/old.err" "$rigTmp/new.err" && cmp -s "$rigTmp/old.rc" "$rigTmp/new.rc" ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFail "$( basename "$1" ) path=[$2] ${3:-plain}: rc $( cat "$rigTmp/old.rc" ) -> $( cat "$rigTmp/new.rc" ), stdout $( cksum < "$rigTmp/old.out" | cut -d' ' -f1 ) -> $( cksum < "$rigTmp/new.out" | cut -d' ' -f1 )"
	fi
}

## The library entry: one walk, every leaf. Each leaf's value is written to its own
## file so a value carrying newlines compares exactly; the manifest lists the paths.
cat > "$rigTmp/leaves.awk" <<'EOF'
BEGIN { jfLibrary = 1 ; }
{ leavesDoc = (NR > 1) ? leavesDoc "\n" $0 : $0 ; }
END {
	leavesRc = jfParseText(leavesDoc)
	print leavesRc > (outDir "/rc")
	leavesN = 0
	for (leavesPath in jfLeafSeen) {
		if (leavesPath ~ /[\n\t]/) continue
		leavesN++
		print leavesPath > (outDir "/paths")
		printf("%sX", jfLeaf[leavesPath]) > (outDir "/v." leavesN)
	}
	close(outDir "/paths")
}
EOF

rigCompareLeaves(){ ## document file
	local leafLine leafN=0 leafRc
	rm -rf "$rigTmp/lv" ; mkdir "$rigTmp/lv"
	: > "$rigTmp/lv/paths"
	LC_ALL=C awk -v outDir="$rigTmp/lv" -f "$rigNew" -f "$rigTmp/leaves.awk" < "$1" 2>/dev/null
	leafRc="$( cat "$rigTmp/lv/rc" 2>/dev/null )"
	if [ "$leafRc" != 0 ] ; then
		## Not parsed: the legacy engine must refuse it too, for any path.
		rigRunOne "$rigOld" "$1" a "" "$rigTmp/old"
		if [ "$( cat "$rigTmp/old.rc" )" = 1 ] ; then rigPassCount=$(( rigPassCount + 1 )) ; else rigFail "$( basename "$1" ) library rc $leafRc, legacy rc $( cat "$rigTmp/old.rc" )" ; fi
		return 0
	fi
	while IFS= read -r leafLine ; do
		leafN=$(( leafN + 1 ))
		[ -n "$leafLine" ] || continue
		rigRunOne "$rigOld" "$1" "$leafLine" "sentinel=1" "$rigTmp/old"
		if [ "$( cat "$rigTmp/old.rc" )" = 0 ] && cmp -s "$rigTmp/old.out" "$rigTmp/lv/v.$leafN" ; then
			rigPassCount=$(( rigPassCount + 1 ))
		else
			rigFail "$( basename "$1" ) library leaf [$leafLine] differs from the legacy engine (legacy rc $( cat "$rigTmp/old.rc" ))"
		fi
	done < "$rigTmp/lv/paths"
}

## ---- hand-written fixtures -----------------------------------------------------
rigCase=0
rigFixture(){ ## document text (written verbatim, no newline added)
	rigCase=$(( rigCase + 1 ))
	printf '%s' "$1" > "$rigTmp/hand.$rigCase.json"
}
rigFixture '{}'
rigFixture ''
rigFixture '   '
rigFixture '[1,2]'
rigFixture '{"a":1} x'
rigFixture '{"a":1}'$'\n\n'
rigFixture '{"a":"é😀\ud800A\ud800x\udc00😀"}'
rigFixture '{"a":"\uZZZZ"}'
rigFixture '{"a":"\u12"}'
rigFixture '{"a":"\ud800\u12G4"}'
rigFixture '{"a":"\ud800\uzzzz"}'
rigFixture '{"a":"abc'
rigFixture '{"a":"abc\'
rigFixture '{"a":"abc\"}'
rigFixture '{"a" 1}'
rigFixture '{"a":}'
rigFixture '{"a":txyz}'
rigFixture '{"a":t}'
rigFixture '{"a":nul}'
rigFixture '{"a":f,"b":2}'
rigFixture '{a":1}'
rigFixture '{"":{"b":2},"b":3}'
rigFixture '{"a":[]}'
rigFixture '{"a":[1,[2,3],{"b":[]}],"b":{"__count":"x"}}'
rigFixture '{"a":1,"a":2}'
rigFixture '{"a.b":1,"a":{"b":2}}'
rigFixture $'{\n  "a": {\n    "b": "multi\\nline\\n\\n"\n  },\r\n  "s": "tab\\there"\n}\n'
rigFixture '{"a":"x\/y\b\f\n\r\t\q\\\""}'
rigFixture '{"a":"\u0000b","b":"c\u0000"}'
rigFixture '{"a":-1.5e+3,"b":+2,"c":1-2,"d":.}'
rigFixture '{"a":1,}'
rigFixture '{"a":[1,]}'
rigFixture '{"a":{"b":{"c":{"d":[{"e":"deep"}]}}}}'
rigFixture '{"a":"trailing newline\n"}'
rigFixture '{"a":"é raw utf8 ✓"}'
rigFixture '{"a":1}}'
rigFixture '{"a":[1 2]}'
rigFixture '{"a"::1}'
rigFixture 'garbage {"a":1}'
## Values and runs that cross the 256-byte chunk boundary in every way the walk handles.
rigLong="" ; rigI=0
while [ "$rigI" -lt 300 ] ; do rigLong="${rigLong}ab\\u00e9\\ud83d\\ude00\\n\\\"" ; rigI=$(( rigI + 1 )) ; done
rigFixture '{"a":"'"$rigLong"'","b":1}'
rigFixture '{"a":"'"$rigLong"'\ud800'"$rigLong"'"}'
rigNums="" ; rigI=0
while [ "$rigI" -lt 400 ] ; do rigNums="${rigNums}${rigNums:+,}$rigI" ; rigI=$(( rigI + 1 )) ; done
rigFixture '{"a":['"$rigNums"'],"b":1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890}'
rigSpaces="$( printf '%600s' '' )"
rigFixture '{'"$rigSpaces"'"a"'"$rigSpaces"':'"$rigSpaces"'"v"'"$rigSpaces"'}'"$rigSpaces"
rigFixture '{"a":"'"$( printf '%300s' '' | tr ' ' 'x' )"'\'
rigFixture '{"a":"'"$( printf '%255s' '' | tr ' ' 'x' )"'é"}'
rigFixture '{"a":"'"$( printf '%253s' '' | tr ' ' 'x' )"'😀"}'

rigHandPaths='a
b
c
d
s
a.b
a.0
a.1
a.1.0
a.1.__count
a.__count
a.2.b.__count
b.__count
a.b.c.d.0.e
a.b.c.d.__count
.0
nope'
echo "-- hand-written fixtures, every path, plain / optional / sentinel --"
rigI=1
while [ "$rigI" -le "$rigCase" ] ; do
	rigMode=0
	while IFS= read -r rigPath ; do
		case "$rigMode" in
			0) rigCompare "$rigTmp/hand.$rigI.json" "$rigPath" "" ;;
			1) rigCompare "$rigTmp/hand.$rigI.json" "$rigPath" "optional=1" ;;
			2) rigCompare "$rigTmp/hand.$rigI.json" "$rigPath" "sentinel=1" ;;
		esac
		rigMode=$(( ( rigMode + 1 ) % 3 ))
	done <<< "$rigHandPaths"
	rigCompareLeaves "$rigTmp/hand.$rigI.json"
	rigI=$(( rigI + 1 ))
done
rigCompare "$rigTmp/hand.1.json" "" ""
printf '  %d compared so far, %d failing\n' "$(( rigPassCount + rigFailCount ))" "$rigFailCount"

## ---- generated fixtures ----------------------------------------------------------
## Park-Miller, exact in a double on every awk, so the same seed is the same set
## everywhere. Every 3rd document is mutated: cut short, a byte dropped, or one added.
cat > "$rigTmp/gen.awk" <<'EOF'
function rnd(n) { seed = (seed * 16807) % 2147483647 ; return seed % n ; }
function genKey(   k) {
	k = rnd(8)
	if (k == 0) return "a"
	if (k == 1) return "b"
	if (k == 2) return "c"
	if (k == 3) return ""
	if (k == 4) return "__count"
	if (k == 5) return "a.b"
	if (k == 6) return "k\\u0041"
	return "s"
}
function genStr(   n, i, out, k) {
	n = rnd(4) == 0 ? rnd(400) : rnd(12)
	out = ""
	for (i = 0 ; i < n ; i++) {
		k = rnd(26)
		if (k == 0) out = out "\\n"
		else if (k == 1) out = out "\\\""
		else if (k == 2) out = out "\\\\"
		else if (k == 3) out = out "\\u00e9"
		else if (k == 4) out = out "\\ud83d\\ude00"
		else if (k == 5) out = out "\\ud800"
		else if (k == 6) out = out "\\t\\r\\b\\f\\/"
		else if (k == 7) out = out "\\q"
		else if (k == 8) out = out "\\u20AC"
		else if (k == 9) out = out " "
		else out = out substr("abcdefghijklmnop", k - 9, 1)
	}
	return "\"" out "\""
}
function ws() { k = rnd(6) ; return k == 0 ? " " : (k == 1 ? "\n  " : "") ; }
function genVal(depth,   k, n, i, out) {
	k = rnd(depth > 3 ? 5 : 8)
	if (k == 0) return genStr()
	if (k == 1) return rnd(2) ? "true" : "false"
	if (k == 2) return "null"
	if (k == 3) return (rnd(2) ? "-" : "") rnd(100000) (rnd(3) == 0 ? ".5e" rnd(9) : "")
	if (k == 4) return genStr()
	if (k == 5 || k == 6) {
		n = rnd(5) ; out = "{" ws()
		for (i = 0 ; i < n ; i++) out = out (i ? "," ws() : "") "\"" genKey() "\"" ws() ":" ws() genVal(depth + 1)
		return out ws() "}"
	}
	n = rnd(5) ; out = "[" ws()
	for (i = 0 ; i < n ; i++) out = out (i ? "," ws() : "") genVal(depth + 1)
	return out ws() "]"
}
function genPath(depth,   k, p) {
	p = genKey()
	while (rnd(2) && depth < 5) { depth++ ; k = rnd(3) ; p = p "." (k == 0 ? rnd(4) : (k == 1 ? "__count" : genKey())) ; }
	return p
}
BEGIN {
	seed = 20261006
	for (doc = 1 ; doc <= count ; doc++) {
		text = "{" ws()
		n = 1 + rnd(4)
		for (i = 0 ; i < n ; i++) text = text (i ? "," : "") "\"" genKey() "\":" ws() genVal(1)
		text = text "}"
		if (doc % 3 == 0) {
			k = rnd(3) ; at = 1 + rnd(length(text))
			if (k == 0) text = substr(text, 1, at)
			else if (k == 1) text = substr(text, 1, at - 1) substr(text, at + 1)
			else text = substr(text, 1, at) substr("\"\\{}[],: tx0u", 1 + rnd(13), 1) substr(text, at + 1)
		}
		printf("%s\n", text) > (dir "/gen." doc ".json")
		close(dir "/gen." doc ".json")
		for (i = 0 ; i < 4 ; i++) print genPath(1) > (dir "/gen." doc ".paths")
		close(dir "/gen." doc ".paths")
	}
}
EOF
rigGenCount=90
LC_ALL=C awk -v dir="$rigTmp" -v count="$rigGenCount" -f "$rigTmp/gen.awk" || rigRefuse "the fixture generator did not run"
echo "-- $rigGenCount generated documents (every 3rd mutated), 4 paths each, plus every leaf --"
rigI=1
while [ "$rigI" -le "$rigGenCount" ] ; do
	rigMode=0
	while IFS= read -r rigPath ; do
		case "$rigMode" in
			0) rigCompare "$rigTmp/gen.$rigI.json" "$rigPath" "" ;;
			1) rigCompare "$rigTmp/gen.$rigI.json" "$rigPath" "sentinel=1" ;;
		esac
		rigMode=$(( ( rigMode + 1 ) % 2 ))
	done < "$rigTmp/gen.$rigI.paths"
	rigCompareLeaves "$rigTmp/gen.$rigI.json"
	rigI=$(( rigI + 1 ))
done

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ JSON FIELD DIFF CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) comparison(s)" >&2 ; exit 1
fi
printf 'JSON_FIELD_DIFF: OK (%d comparisons against the previous engine, offline)\n' "$rigPassCount"
