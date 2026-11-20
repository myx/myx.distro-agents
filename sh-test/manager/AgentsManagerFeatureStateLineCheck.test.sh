#!/usr/bin/env bash
## Behavioural check on the state line of a feature's check, as both readers of sh-lib/manager/AgentsTools.ManagerFeature.include take it
## (`AgentsToolsManagerFeatureRows` and `AgentsToolsManagerFeaturePartState`): a check text whose state line comes first, one whose state
## line comes after its platform, home and size, which is how setup.feature-lancedb prints, and one that names no state at all. Held, with
## each reader taken from the include as it is and nothing else of the include:
##   1. the state line first: the state is that line, and the lines after it are the detail.
##   2. the state line after other lines: the same state, and those lines the detail. A first line that is no state word is no state, so
##      an installed feature is not reported broken for printing its platform first.
##   3. no state line: broken, and the detail says the check named no state; a check that prints nothing says that instead.
##   4. both readers read one text: the feature row and the state of its one part are the same word for the same text.
##   5. a part of a multi-part check is read by its own part.<id>.state, whatever line the feature's own state is on.
## Red before the change: against the reader as 8b98c3f5^ had it, four of these eight fail, since the first line was taken as the
## state whatever it held. Green against the reader as it stands.
## Offline: no feature and no fragment is run; the two readers alone are, over texts of this check's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ManagerFeature.include"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigInclude" ] || rigRefuse "the readers' include is not at the origin: $rigInclude"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## Each reader as the include holds it, and nothing else of the include: its case dispatch below the functions is never entered.
for rigReader in AgentsToolsManagerFeatureRows AgentsToolsManagerFeaturePartState ; do
	rigText="$( LC_ALL=C sed -n "/^$rigReader(){/,/^}/p" "$rigInclude" )"
	[ -n "$rigText" ] || rigRefuse "$rigReader is not in the include"
	eval "$rigText"
done
rigRowsField(){ ## check text, field number -- that field of the feature row, or `none` where the reader printed no row
	printf '%s\n' "$1" | AgentsToolsManagerFeatureRows setup.feature-lancedb | LC_ALL=C awk -F'\t' -v want="$2" '$1 == "feature" { print $want ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } ; }'
}
rigPartState(){ ## check text, feature, part -- the part's state, or `refused` where the reader turns the part away
	printf '%s\n' "$1" | AgentsToolsManagerFeaturePartState "$2" "$3" 2> /dev/null || printf 'refused'
}
rigFirst="$( printf '%s\n' 'lancedb: installed' 'platform: macOS arm64' 'size: 12 MB' 'query: ok' )"
rigLast="$( printf '%s\n' 'platform: macOS arm64' 'home: /rig/lancedb' 'size: 12 MB' 'lancedb: installed' 'query: ok' )"
rigNone="$( printf '%s\n' 'platform: macOS arm64' 'home: /rig/lancedb' 'size: 12 MB' 'query: ok' )"
rigParts="$( printf '%s\n' 'local-ai: broken' 'part.chat-a.part: chat' 'part.chat-a.state: installed' 'part.stt-a.part: stt' 'part.stt-a.state: not installed' )"

echo "-- 1. the state line first --"
rigAssert "an installed feature whose state line comes first, and the lines after it as the detail with whitespace read _" \
	"$( rigRowsField "$rigFirst" 4 ) | $( rigRowsField "$rigFirst" 11 )" "installed | platform=macOS_arm64;_query=ok"
echo "-- 2. the state line after other lines --"
rigAssert "the same state where the platform, the home and the size come first, as setup.feature-lancedb prints them" \
	"$( rigRowsField "$rigLast" 4 )" "installed"
rigAssert "and those lines are the detail, none of them read as the state" \
	"$( rigRowsField "$rigLast" 5 ) | $( rigRowsField "$rigLast" 11 )" "12582912 | platform=macOS_arm64;_home=/rig/lancedb;_query=ok"
echo "-- 3. no state line --"
rigAssert "a check that names no state is broken, and says so in its own detail" \
	"$( rigRowsField "$rigNone" 4 ) | $( rigRowsField "$rigNone" 11 )" "broken | platform=macOS_arm64;_home=/rig/lancedb;_query=ok;_the_check_named_no_state"
rigAssert "a check that prints nothing is broken, and says that instead" \
	"$( rigRowsField "$( printf '' )" 4 ) | $( rigRowsField "$( printf '' )" 11 )" "broken | the_check_printed_nothing"
echo "-- 4. both readers read one text --"
rigAssert "the feature row and the state of its one part are the same word, whatever line the state is on: first, after others, none" \
	"$( rigRowsField "$rigFirst" 4 ):$( rigPartState "$rigFirst" setup.feature-lancedb lancedb ) $( rigRowsField "$rigLast" 4 ):$( rigPartState "$rigLast" setup.feature-lancedb lancedb ) $( rigRowsField "$rigNone" 4 ):$( rigPartState "$rigNone" setup.feature-lancedb lancedb )" \
	"installed:installed installed:installed broken:broken"
echo "-- 5. the parts of a multi-part check --"
rigAssert "each part's own state, by its own line, whatever the feature's line says" \
	"$( rigPartState "$rigParts" setup.feature-local-ai chat-a ) $( rigPartState "$rigParts" setup.feature-local-ai stt-a )" "installed not-installed"
rigAssert "a part the check does not name is turned away, and the feature's own state is not offered in its place" \
	"$( rigPartState "$rigParts" setup.feature-local-ai nothing ) $( rigPartState "$rigFirst" setup.feature-lancedb lancedb )" "refused installed"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER FEATURE STATE LINE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
echo "MANAGER_FEATURE_STATE_LINE: OK ($rigPassCount assertions, offline)"
