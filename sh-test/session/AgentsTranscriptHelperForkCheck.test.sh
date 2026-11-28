#!/usr/bin/env bash
## Behavioural check of the transcript's helpers on the call path (code-craft: no subshell per call; the `...Into` form with printf -v).
## AgentsTools.SessionTranscript.include run in a rig session under xtrace, where a helper run inside a command substitution shows as a
## trace line one level deeper than its caller, naming the helper:
##   1. a hundred tool calls (AgentsTranscriptToolStart, AgentsTranscriptToolDone) run no helper -- the session key, the base tool, the
##      outcome, the session folder, the transcript and its part -- inside a subshell
##   2. and their hundred tool lines are still in the session's transcript, each with its outcome
##   3. control: the printing forms still print what the other callers read
## Red before the change: each call ran the helpers through $( ), seven subshells a call.
## Offline: a rig session whose transcript is a plain file outside any audit folder, so nothing is committed; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTranscriptHelperForkCheck )" || exit 1
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
: > "$rigLog" ; printf '%s\n' "$rigLog" > "$rigDir/transcript"
rigShell(){ ## script: run with the include loaded, as the rig session, its trace on the trace file
	env -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID MMDAPP="$rigTmp/ws" harnessSessionId="$rigSession" MDAT_TRANSCRIPT_COMMIT_SECONDS=999999 \
		rigPkg="$rigPkg" PS4='+:${FUNCNAME[0]:-main}: ' bash -c '
		. "$rigPkg/sh-lib/session/AgentsTools.SessionTranscript.include" || exit 1
		'"$1"
}

echo "-- 1. a hundred tool calls run no helper in a subshell --"
rigShell 'set -x ; i=0 ; while [ $i -lt 100 ] ; do AgentsTranscriptToolStart Read ; AgentsTranscriptToolDone Read "{}" "ok $i" mcp ; i=$(( i + 1 )) ; done' 2> "$rigTmp/trace" > /dev/null
rigAssert "helper calls inside a subshell, in a hundred calls" \
	"$( LC_ALL=C grep -cE '^\+\+[+]*:[^:]*: AgentsTranscript(SessionKey|BaseTool|OutcomeOf|SessionDir|Base|Path)( |$)' "$rigTmp/trace" )" 0

echo "-- 2. the tool lines still land --"
rigAssert "tool lines in the transcript" "$( LC_ALL=C grep -c ' TOOL Read ' "$rigLog" )" 100
rigAssert "each with its outcome" "$( LC_ALL=C grep -c ' TOOL Read.* -> ok' "$rigLog" )" 100

echo "-- 3. control: the printing forms --"
rigAssert "the session key prints" "$( rigShell 'AgentsTranscriptSessionKey' 2> /dev/null )" "$rigSession"
rigAssert "the base tool prints" "$( rigShell 'AgentsTranscriptBaseTool mcp__myx_distro__Read' 2> /dev/null )" Read
rigAssert "the outcome prints" "$( rigShell 'AgentsTranscriptOutcomeOf "ERROR: REFUSAL-ID: x"' 2> /dev/null )" refused
rigAssert "the session folder prints" "$( rigShell 'AgentsTranscriptSessionDir "$harnessSessionId"' 2> /dev/null )" "$rigDir"
rigAssert "the transcript prints" "$( rigShell 'AgentsTranscriptPath "$harnessSessionId"' 2> /dev/null )" "$rigLog"
rigAssert "a session id with a slash is refused" "$( rigShell 'AgentsTranscriptSessionDir "a/b" ; echo "rc=$?"' 2> /dev/null )" "rc=1"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ TRANSCRIPT HELPER FORK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'TRANSCRIPT_HELPER_FORK: OK (%d assertions, offline, rig session only)\n' "$rigPass"
