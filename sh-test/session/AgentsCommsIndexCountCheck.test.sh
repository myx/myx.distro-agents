#!/usr/bin/env bash
## Behavioural check of the comms reader's count of a chat index (AgentsToolsSessionCommsIndexCount): the count equals the
## file's newline count (wc -l), a last line with no newline is not counted, a missing or empty file counts 0, and a large
## index is counted in about a second. The reader calls the count every second for each live session, so a count that grows
## faster than the file holds the reader on one core. Offline: the function is read from its include and run on temp files.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigComms="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionComms.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigComms" ] || rigRefuse "a library is not at the origin: $rigComms"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommsIndexCountCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The function alone, as the include defines it: the include's other code needs a workspace this check does not make.
LC_ALL=C sed -n '/^AgentsToolsSessionCommsIndexCount(){/,/^}/p' "$rigComms" > "$rigTmp/count.sh"
[ -s "$rigTmp/count.sh" ] || rigRefuse "AgentsToolsSessionCommsIndexCount is not in $rigComms"
. "$rigTmp/count.sh"
type AgentsToolsSessionCommsIndexCount > /dev/null 2>&1 || rigRefuse "AgentsToolsSessionCommsIndexCount could not be loaded"

rigCount(){ ## file -- the count the function sets
	AgentsToolsSessionCommsIndexCount "$1" ; printf '%s' "$agentsCommsIndexCount"
}
printf 'a\tb\n' > "$rigTmp/one"
printf 'a\nb\nc' > "$rigTmp/open"
: > "$rigTmp/empty"
rigAssert "control: one line counts 1" "$( rigCount "$rigTmp/one" )" 1
rigAssert "a last line with no newline is not counted" "$( rigCount "$rigTmp/open" )" 2
rigAssert "an empty index counts 0" "$( rigCount "$rigTmp/empty" )" 0
rigAssert "a missing index counts 0" "$( rigCount "$rigTmp/missing" )" 0

## A large index, about 64 KB in 800 lines of the index's own shape: tab-separated, with a Slack ts and a thread.
rigLine=0
while [ "$rigLine" -lt 800 ] ; do
	printf '%s\t1700000000.%06d\tCRIG00001:1700000000.000100\tslack\tmagic-coordinator\t%s\n' "$rigLine" "$rigLine" "a block of the session chat, kept as one line of its index"
	rigLine=$(( rigLine + 1 ))
done > "$rigTmp/large"
rigWant="$( LC_ALL=C wc -l < "$rigTmp/large" | LC_ALL=C tr -d ' ' )"
rigStart="$SECONDS"
rigGot="$( rigCount "$rigTmp/large" )"
rigTook=$(( SECONDS - rigStart ))
rigAssert "a large index counts as wc -l does" "$rigGot" "$rigWant"
rigAssert "a large index ($( LC_ALL=C wc -c < "$rigTmp/large" | LC_ALL=C tr -d ' ' ) bytes) is counted within 2 s" "$( [ "$rigTook" -le 2 ] && printf within || printf "over: ${rigTook}s" )" within

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ COMMS_INDEX_COUNT CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'COMMS_INDEX_COUNT: OK (%d assertions, offline)\n' "$rigPassCount"
