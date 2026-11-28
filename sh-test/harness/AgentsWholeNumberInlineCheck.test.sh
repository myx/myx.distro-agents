#!/usr/bin/env bash
## Static check that the whole-number test is written inline at each use. A digits test is one `case`, so a helper for it costs a
## function call and a load guard at every site and saves nothing. Held:
##   1. no sh-lib or sh-scripts file defines, calls or guards AgentsHarnessWholeNumber
##   2. every harness file that tested numbers this way still parses
## Red before the change: eleven harness files defined, guarded or called the helper.
## Offline: reads the package tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}

echo "-- 1. no file names the helper --"
rigAssert "files naming AgentsHarnessWholeNumber" \
	"$( LC_ALL=C grep -rlF 'AgentsHarnessWholeNumber' "$rigPkg/sh-lib" "$rigPkg/sh-scripts" | sed "s|^$rigPkg/||" | tr '\n' ' ' )" ""

echo "-- 2. the harness files still parse --"
rigBad=""
for rigFile in "$rigPkg"/sh-lib/harness/AgentsHarness*.include "$rigPkg"/sh-lib/harness/AgentsUniversalHarness.sh "$rigPkg"/sh-lib/harness/AgentsOpenAiChatWire.sh ; do
	bash -n "$rigFile" 2> /dev/null || rigBad="$rigBad ${rigFile##*/}"
done
rigAssert "harness files that fail bash -n" "$rigBad" ""

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ WHOLE NUMBER INLINE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'WHOLE_NUMBER_INLINE: OK (%d assertions, offline)\n' "$rigPass"
