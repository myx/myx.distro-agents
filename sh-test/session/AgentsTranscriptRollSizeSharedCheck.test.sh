#!/usr/bin/env bash
## Behavioural check of the transcript's roll test across processes (code-craft: a measure is kept, never redone per call). A served
## call is a process of its own, so the part's size is kept beside the session too (`transcript.size`). In a rig session:
##   1. twenty tool calls, each in a process of its own, measure the part's size once
##   2. and their twenty lines are in the transcript
##   3. a kept size a minute old is measured again, and a part past the roll size then rolls: the next line goes to the next part
##   4. control: a kept size of another part is not taken for this one
## Red before the change: each process measured the part with wc, twenty for twenty calls.
## Offline: a rig session whose transcript is a plain file outside any audit folder, so nothing is committed; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTranscriptRollSizeSharedCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigSession="rig-0000-0000-0000-000000000000"
rigDir="$rigTmp/ws/.local/agents/sessions/$rigSession"
rigLog="$rigTmp/store/log/session-rig.log"
mkdir -p "$rigDir" "${rigLog%/*}" || exit 1
printf '%s\n' "$rigLog" > "$rigDir/transcript"
rigForks="$rigTmp/forks"
rigCall(){ ## roll size: one tool call in a process of its own, as a served call is, wc counted
	env -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID MMDAPP="$rigTmp/ws" harnessSessionId="$rigSession" MDAT_TRANSCRIPT_COMMIT_SECONDS=999999 \
		MDAT_TRANSCRIPT_ROLL_BYTES="$1" rigPkg="$rigPkg" rigForks="$rigForks" bash -c '
		. "$rigPkg/sh-lib/session/AgentsTools.SessionTranscript.include" || exit 1
		wc(){ printf "wc\n" >> "$rigForks" ; command wc "$@" ; }
		AgentsTranscriptToolStart Read ; AgentsTranscriptToolDone Read "{}" "ok" mcp' > /dev/null 2>&1
}
rigWcs(){ LC_ALL=C grep -cx wc "$rigForks" 2> /dev/null || echo 0 ; }

echo "-- 1. twenty calls in processes of their own measure once --"
: > "$rigLog" ; : > "$rigForks" ; rm -f "$rigDir/transcript.size"
rigI=0 ; while [ "$rigI" -lt 20 ] ; do rigCall 8388608 ; rigI=$(( rigI + 1 )) ; done
rigAssert "the part measured by twenty processes" "$( rigWcs )" 1

echo "-- 2. the lines land --"
rigAssert "tool lines in the transcript" "$( LC_ALL=C grep -c ' TOOL Read' "$rigLog" )" 20

echo "-- 3. a kept size a minute old is measured again, and the part rolls --"
LC_ALL=C awk 'BEGIN { for ( i = 0 ; i < 40 ; i++ ) printf "%063d\n", i }' >> "$rigLog"
printf '%s %s %s\n' "$(( $( date +%s ) - 61 ))" 10 "$rigLog" > "$rigDir/transcript.size"
: > "$rigForks"
rigCall 1000
rigAssert "measured again" "$( rigWcs )" 1
rigAssert "the line went to the next part" "$( LC_ALL=C grep -c ' TOOL Read' "${rigLog%.log}-part2.log" 2> /dev/null )" 1

echo "-- 4. control: another part's kept size is not taken --"
printf '%s %s %s\n' "$( date +%s )" 10 "$rigTmp/store/log/other.log" > "$rigDir/transcript.size"
: > "$rigForks"
rigCall 8388608
rigAssert "measured, the kept size naming another part" "$( rigWcs )" 1

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ TRANSCRIPT ROLL SIZE SHARED CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'TRANSCRIPT_ROLL_SIZE_SHARED: OK (%d assertions, offline, rig session only)\n' "$rigPass"
