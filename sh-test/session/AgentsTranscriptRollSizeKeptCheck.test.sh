#!/usr/bin/env bash
## Behavioural check of the transcript's roll test on the call path (code-craft: a measure is kept, never redone per call). The part a
## line goes to is the last part under the roll size (AgentsTranscriptPathInto); its size is kept a minute in the process, and beside the
## session (`transcript.size`), which a part here that must be measured has removed or aged. In a rig session:
##   1. a hundred tool calls in one process measure the part's size once
##   2. and their hundred lines are in the transcript
##   3. a part past the roll size still rolls on the call that measures it: the next lines go to the next part
##   4. control: a minute after the size was read, it is read again
## Red before the change: each call measured the part with wc and tr, a hundred of each for a hundred calls.
## Offline: a rig session whose transcript is a plain file outside any audit folder, so nothing is committed; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTranscriptRollSizeKeptCheck )" || exit 1
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
rigShell(){ ## roll size, script: run as the rig session with the include loaded, wc counted
	: > "$rigForks"
	env -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID MMDAPP="$rigTmp/ws" harnessSessionId="$rigSession" MDAT_TRANSCRIPT_COMMIT_SECONDS=999999 \
		MDAT_TRANSCRIPT_ROLL_BYTES="$1" rigPkg="$rigPkg" rigForks="$rigForks" bash -c '
		. "$rigPkg/sh-lib/session/AgentsTools.SessionTranscript.include" || exit 1
		wc(){ printf "wc\n" >> "$rigForks" ; command wc "$@" ; }
		'"$2" > /dev/null 2>&1
}
rigCalls='i=0 ; while [ $i -lt 100 ] ; do AgentsTranscriptToolStart Read ; AgentsTranscriptToolDone Read "{}" "ok $i" mcp ; i=$(( i + 1 )) ; done'

echo "-- 1. a hundred calls measure the part once --"
: > "$rigLog"
rigShell 8388608 "$rigCalls"
rigAssert "the part measured by a hundred calls" "$( LC_ALL=C grep -cx wc "$rigForks" )" 1

echo "-- 2. the lines land --"
rigAssert "tool lines in the transcript" "$( LC_ALL=C grep -c ' TOOL Read' "$rigLog" )" 100

echo "-- 3. a part past the roll size still rolls --"
rm -f "$rigDir/transcript.size"
rigShell 1000 'AgentsTranscriptToolStart Read ; AgentsTranscriptToolDone Read "{}" "ok" mcp'
rigNext="${rigLog%.log}-part2.log"
rigAssert "the next part is made" "$( [ -f "$rigNext" ] && echo made || echo none )" made
rigAssert "and the line went to it" "$( LC_ALL=C grep -c ' TOOL Read' "$rigNext" 2> /dev/null )" 1

echo "-- 4. control: a minute later the size is read again --"
rm -f "$rigDir/transcript.size"
rigShell 8388608 'AgentsTranscriptToolDone Read "{}" "ok" mcp ; agentsTranscriptSizedAt=$(( SECONDS - 61 ))
	read -r rigAt rigRest < "$MMDAPP/.local/agents/sessions/$harnessSessionId/transcript.size" ; printf "%s %s\n" $(( rigAt - 61 )) "$rigRest" > "$MMDAPP/.local/agents/sessions/$harnessSessionId/transcript.size"
	AgentsTranscriptToolDone Read "{}" "ok" mcp'
rigAssert "two measures a minute apart" "$( LC_ALL=C grep -cx wc "$rigForks" )" 2

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ TRANSCRIPT ROLL SIZE KEPT CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'TRANSCRIPT_ROLL_SIZE_KEPT: OK (%d assertions, offline, rig session only)\n' "$rigPass"
