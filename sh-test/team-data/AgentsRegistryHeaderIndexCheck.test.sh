#!/usr/bin/env bash
## Behavioural check of the registry rows read from each record's frontmatter once. The pending-replies and spawned-sessions
## rebuilds ask several headers of every record, over stores of thousands of records, on every console refresh. Held:
##   1. a header is the first value of its key that is not empty, trimmed, its inner spaces written `_`; a key absent, or
##      only empty, is `-`
##   2. a header lookup walks no frontmatter line: the record is indexed once, as it is read
## Red before the change: every lookup walked and trimmed every line of the record again.
## Offline: records of this check alone, under its own temp folder.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRegistryHeaderIndexCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigAwk="$rigPkg/sh-lib/team-data/AgentsRegistryHeaderRows.awk"
printf -- '---\nsession-id:\nsession-id:  s-one  \nowner: magic tester\nstatus: reply-pending\nblocked-on: \n---\nstatus: not-a-header\n' > "$rigTmp/ask-one.md"
printf -- '---\nowner:\n---\n' > "$rigTmp/ask-two.md"

echo "-- 1. the header rules --"
rigAssert "rows of two records" "$( printf 'A%s\nA%s\n' "$rigTmp/ask-one.md" "$rigTmp/ask-two.md" | LC_ALL=C awk -v registryRows=pending -f "$rigAwk" | tr '\n' '|' )" \
	"ask-one.md ask s-one magic_tester reply-pending - -|ask-two.md ask - - - - -|"

echo "-- 2. a lookup walks no line --"
rigAssert "loops in the header lookup" "$( LC_ALL=C awk '/^function registryHeader\(/ { inFn = 1 } inFn && /for \(/ { n++ } inFn && /^\}/ { inFn = 0 } END { print n + 0 }' "$rigAwk" )" 0

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ REGISTRY HEADER INDEX CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'REGISTRY_HEADER_INDEX: OK (%d assertions, offline)\n' "$rigPass"
