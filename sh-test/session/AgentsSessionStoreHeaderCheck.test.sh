#!/usr/bin/env bash
## Check on the header of sh-lib/session/AgentsTools.SessionStore.include: every function it names is one the file defines,
## so a reader who calls what the header lists reaches code that exists.
## Held:
##   1. control: the predicate reads the header and finds the names it documents, so an empty answer is not an empty run
##   2. no name the header documents is missing from the file
##   3. red: a constructed header naming a function the file does not define is caught
##   4. green: the same header, naming only the two functions the file defines, is clear
##   5. a name in a sentence of the header is no claim, so prose alone is not caught
## Usage: AgentsSessionStoreHeaderCheck.test.sh [<package root>]   (default: the package at $MDLT_ORIGIN). Offline: it writes only its own rig.
set -u
argRoot=""
case "${1:-}" in --*) ;; "") ;; *) argRoot="$1" ;; esac
if [ -n "$argRoot" ] && [ -d "$argRoot/sh-lib" ] ; then
	scanPackage="$argRoot"
else
	: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set, and no package root was given}"
	scanPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
fi
storeFile="sh-lib/session/AgentsTools.SessionStore.include"
scanRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$scanPackage/$storeFile" ] || scanRefuse "no $storeFile under $scanPackage"
. "$scanPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
scanRig="$( rigTempDir AgentsSessionStoreHeaderCheck )" || exit 1
scanRig="$( cd "$scanRig" && pwd -P )" || exit 1
[ -n "${RIG_KEEP:-}" ] || trap 'chmod -R u+w "$scanRig" 2>/dev/null ; rm -rf -- "$scanRig"' EXIT

## A documented name is a `##` header line whose first word starts `Agents` and whose remainder is empty or a usage tail
## (`<...>` or `--...`), so a sentence naming a function is no claim. A defined name is a definition line at any indent,
## bare or after `function`. `scanNames <file> missing|documented` prints the names of that half, one a line.
scanNames(){
	LC_ALL=C awk -v want="$2" '
		function docName(line,   rest, name, tail) {
			if (line !~ /^## Agents[A-Za-z0-9]+/) return ""
			rest = line ; sub(/^## /, "", rest) ; sub(/^[A-Za-z0-9]+/, "", rest)
			if (rest != "" && rest !~ /^ /) return ""
			name = line ; sub(/^## /, "", name) ; sub(/[ ].*/, "", name)
			tail = rest ; sub(/^ +/, "", tail)
			if (tail == "" || tail ~ /^(--|<)/) return name
			return ""
		}
		function defName(line,   w) {
			w = line
			if (w ~ /^[ \t]*#/) return ""
			sub(/^[ \t]*/, "", w) ; sub(/^function[ \t]+/, "", w)
			if (w !~ /^[A-Za-z_][A-Za-z0-9_]*[ \t]*\(\)/) return ""
			sub(/[ \t]*\(\).*/, "", w)
			return w
		}
		{ d = defName($0) ; if (d != "") { def[d] = 1 ; next ; } ; n = docName($0) ; if (n != "") doc[n] = 1 ; }
		END {
			for (n in doc) {
				if (want == "documented") { print n ; continue ; }
				if (n in def) continue
				print n
			}
		}' "$1" | LC_ALL=C sort
}

scanPassCount=0
scanFailCount=0
scanAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; scanPassCount=$(( scanPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; scanFailCount=$(( scanFailCount + 1 ))
	fi
}
scanList(){ ## file, half -- the names of that half as one line
	scanNames "$1" "$2" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed -e 's/ $//'
}

echo "-- 1. control: the predicate reads a header and lists what it documents --"
scanAssert "control: the file's header documents more than twenty names" \
	"$( [ "$( scanNames "$scanPackage/$storeFile" documented | LC_ALL=C grep -c . )" -gt 20 ] && printf many || printf few )" many

echo "-- 2. every function the header names is one the file defines --"
scanAssert "no documented name is missing from the file" "[$( scanList "$scanPackage/$storeFile" missing )]" "[]"

echo "-- 3. red then green on a constructed header --"
scanRigHeader(){ ## folder, header body -- a package file holding that header and two definitions
	mkdir -p "$1/sh-lib/session" || return 1
	printf '%s\nAgentsScanOneDefined(){ ## text\n\tprintf %%s one\n}\nAgentsScanTwoDefined(){ ## text\n\tprintf %%s two\n}\n' "$2" \
		> "$1/$storeFile"
}
scanRigHeader "$scanRig/planted" '##
## A constructed header naming one function the file defines and one it does not.
##
## AgentsScanOneDefined <argument>   one the file defines
## AgentsScanThreeMissing <argument>   one the file does not define
##' || scanRefuse "the constructed package could not be written"
scanAssert "red: a documented name the file does not define is caught" \
	"$( scanList "$scanRig/planted/$storeFile" missing )" "AgentsScanThreeMissing"
scanRigHeader "$scanRig/clear" '##
## A constructed header naming only functions the file defines.
##
## AgentsScanOneDefined <argument>   one the file defines
## AgentsScanTwoDefined <argument>   the other the file defines
##' || scanRefuse "the constructed package could not be written"
scanAssert "green: a header naming only defined functions is clear" \
	"$( scanList "$scanRig/clear/$storeFile" missing )" ""
printf '## AgentsScanFourAbsent appears in this sentence only, and claims nothing.\nAgentsScanOneDefined(){ ## text\n\tprintf %%s one\n}\n' \
	> "$scanRig/clear/$storeFile" || scanRefuse "the constructed package could not be written"
scanAssert "a name in a sentence is no claim, so prose alone is not caught" \
	"$( scanList "$scanRig/clear/$storeFile" missing )" ""

if [ "$scanFailCount" -ne 0 ] ; then
	echo "⛔ SESSION STORE HEADER CHECK FAILED: $scanFailCount of $(( scanPassCount + scanFailCount )) assertion(s)" >&2
	echo "  fix:  $storeFile, its header -- never the assertion" >&2
	exit 1
fi
printf 'SESSION_STORE_HEADER: OK (%d assertions, offline)\n' "$scanPassCount"
