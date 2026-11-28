#!/usr/bin/env bash
## Behavioural check of the session token totals as a file of their own (code-craft: a file is split per feature; a call parses what its
## own path needs; a caller loads the file that defines what it calls). The transcript include is parsed on every tool call; the token
## totals are read at a milestone, a close or a board view. Held:
##   1. the transcript include defines no token function, and AgentsTools.SessionTokens.include defines all nine
##   2. the token include alone answers: its functions load the transcript's session folder where they call it
##   3. every file that calls a token function loads the token include
## Red before the change: the nine token functions were the transcript include's, parsed by every tool call.
## Offline: a rig session folder of this check's own; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionTokensSplitCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigTr="$rigPkg/sh-lib/session/AgentsTools.SessionTranscript.include"
rigTk="$rigPkg/sh-lib/session/AgentsTools.SessionTokens.include"

echo "-- 1. the token functions are a file of their own --"
rigAssert "token functions the transcript include defines" "$( LC_ALL=C grep -c '^AgentsSessionTokens[A-Za-z]*()' "$rigTr" )" 0
rigAssert "token functions the token include defines" "$( LC_ALL=C grep -c '^AgentsSessionTokens[A-Za-z]*()' "$rigTk" 2> /dev/null || echo 0 )" 9

echo "-- 2. the token include alone answers --"
mkdir -p "$rigTmp/ws/.local/agents/sessions/rig-sess" && printf '10 20 30 40\n' > "$rigTmp/ws/.local/agents/sessions/rig-sess/tokens"
rigAssert "a session's tokens header value, from the token include alone" \
	"$( MMDAPP="$rigTmp/ws" bash -c '. "$1" || exit 1 ; AgentsSessionTokensHeaderValue rig-sess' rig "$rigTk" 2> /dev/null | LC_ALL=C grep -c 'in=10' )" 1

echo "-- 3. every caller loads the token include --"
rigBad=""
for rigFile in $( LC_ALL=C grep -rlE '(^|[^A-Za-z0-9_])AgentsSessionTokens(Add|HeaderUpdate|HeaderValue|Line|NewRunsInto|RollupRowOf|RollupRows|RollupText|RowsInto)([^A-Za-z0-9_(]|$)' "$rigPkg/sh-lib" "$rigPkg/sh-scripts" ) ; do
	[ "$rigFile" != "$rigTk" ] || continue
	LC_ALL=C grep -vE '^[[:space:]]*#' "$rigFile" | LC_ALL=C grep -qE '(^|[^A-Za-z0-9_])AgentsSessionTokens[A-Za-z]+([^A-Za-z0-9_(]|$)' || continue
	LC_ALL=C grep -q 'AgentsTools.SessionTokens.include' "$rigFile" || rigBad="$rigBad ${rigFile#$rigPkg/}"
done
rigAssert "callers that never load the token include" "${rigBad:-none}" none

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SESSION TOKENS SPLIT CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_TOKENS_SPLIT: OK (%d assertions, offline)\n' "$rigPass"
