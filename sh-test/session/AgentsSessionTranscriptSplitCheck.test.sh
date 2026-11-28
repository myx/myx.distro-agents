#!/usr/bin/env bash
## Behavioural check of the session transcript split per feature (code-craft: a file is split per feature; a call parses what its own
## path needs; a caller loads the file that defines what it calls). AgentsTools.SessionTranscript.include is parsed on every tool call;
## a transcript opened, noted and closed, the harness loop's own events, and a supervisor's reads of it are not on that path. Held:
##   1. each part defines its own functions, and the transcript include none of them
##   2. each part loads alone: the transcript's own functions are there after it
##   3. every file that calls a function of a part loads that part
## Red before the change: every one of these functions was the transcript include's, parsed by every tool call.
## Offline: the includes alone; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigSession="$rigPkg/sh-lib/session"
rigParts='Life:AgentsTranscriptNewRel AgentsTranscriptStart AgentsTranscriptSetItem AgentsTranscriptNote AgentsTranscriptSpawnEnd AgentsTranscriptEventAfterEnd
Loop:AgentsTranscriptHarnessStart AgentsTranscriptHarnessRound AgentsTranscriptHarnessRestart AgentsTranscriptHarnessRewind AgentsTranscriptHarnessFinal
Read:AgentsTranscriptLastTool AgentsTranscriptRunTail'

echo "-- 1. each part defines its own functions --"
while IFS=: read -r rigPart rigFns ; do
	rigFile="$rigSession/AgentsTools.SessionTranscript$rigPart.include" ; rigIn="" ; rigOut=""
	for rigFn in $rigFns ; do
		LC_ALL=C grep -q "^$rigFn()" "$rigFile" 2> /dev/null || rigIn="$rigIn $rigFn"
		! LC_ALL=C grep -q "^$rigFn()" "$rigSession/AgentsTools.SessionTranscript.include" || rigOut="$rigOut $rigFn"
	done
	rigAssert "the $rigPart part defines its functions" "${rigIn:-all}" all
	rigAssert "and the transcript include none of them" "${rigOut:-none}" none
done <<< "$rigParts"

echo "-- 2. each part loads alone --"
for rigPart in Life Loop Read ; do
	rigAssert "the $rigPart part alone brings the transcript's own functions" \
		"$( bash -c '. "$1" || exit 1 ; type AgentsTranscriptPathInto > /dev/null 2>&1 && echo there' rig "$rigSession/AgentsTools.SessionTranscript$rigPart.include" 2> /dev/null )" there
done

echo "-- 3. every caller loads the part it calls --"
rigBad=""
while IFS=: read -r rigPart rigFns ; do
	rigPattern="$( printf '%s' "$rigFns" | LC_ALL=C tr ' ' '|' )"
	for rigFile in $( LC_ALL=C grep -rlE "(^|[^A-Za-z0-9_])($rigPattern)([^A-Za-z0-9_(]|\$)" "$rigPkg/sh-lib" "$rigPkg/sh-scripts" ) ; do
		case "$rigFile" in "$rigSession/AgentsTools.SessionTranscript$rigPart.include") continue ;; esac
		LC_ALL=C grep -vE '^[[:space:]]*#' "$rigFile" | LC_ALL=C grep -qE "(^|[^A-Za-z0-9_])($rigPattern)([^A-Za-z0-9_(]|\$)" || continue
		LC_ALL=C grep -q "AgentsTools.SessionTranscript$rigPart.include" "$rigFile" || rigBad="$rigBad ${rigFile#$rigPkg/}($rigPart)"
	done
done <<< "$rigParts"
rigAssert "callers that never load the part they call" "${rigBad:-none}" none

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SESSION TRANSCRIPT SPLIT CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_TRANSCRIPT_SPLIT: OK (%d assertions, offline)\n' "$rigPass"
