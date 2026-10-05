#!/usr/bin/env bash
## Two grant-gate edges beside AgentsHarnessPermissionCheck: an Allow once is used up by
## passing the gate even when the call it admitted then fails, and a granted target
## swapped for a dangling link out never creates anything at the link's far end.
## Offline: the Slack-shaped fake curl is first on PATH; no event-track is configured.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to record under"

rigTmp="$( mktemp -d -t AgentsHarnessPermissionEdgeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/IN" "$rigWs/OUT" "$rigWs/ELSEWHERE"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
RIG_CURL_LOG="$rigTmp/curl.log"
export RIG_CURL_LOG
: > "$RIG_CURL_LOG"

## One Write under session rig-session; prints the result's first line.
rigWrite(){ ## path
	( cd "$rigWs" && printf '{"path":"%s","content":"x"}' "$1" | env -u MDAT_DATA_ROOT -u MDAT_SESSION_UNATTENDED -u CLAUDE_CODE_SESSION_ID \
		MDAT_SPAWN_SESSION_ID=rig-session RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDAT_SPAWN_AGENT="$rigMember" \
		bash "$rigHarness" --intern-tool Write --access-read-root "$rigWs" --access-write-root "$rigWs/IN" ) > "$rigTmp/out" 2> "$rigTmp/err"
	LC_ALL=C awk 'NR == 1 { print ; }' "$rigTmp/out"
}
rigRefusalId(){
	LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/out" | head -1
}
rigGrant(){ ## refusal id, kind
	( cd "$rigWs" && env -u MDAT_DATA_ROOT MMDAPP="$rigWs" \
		bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-permission-grant-open magic-coordinator \
		--session-id rig-session --refusal-id "$1" --kind "$2" ) 2>/dev/null | LC_ALL=C sed -n 's/^\(GRANT: [a-z]*\) .*$/\1/p' | head -1
}

echo "-- an Allow once is used up by the gate, even when the admitted call then fails --"
## OUT/blocker is a file, so creating OUT/blocker/x's parent fails after the gate passes.
printf 'file\n' > "$rigWs/OUT/blocker"
rigTarget="$rigWs/OUT/blocker/x"
rigWrite "$rigTarget" > /dev/null
rigIdOnce="$( rigRefusalId )"
[ -n "$rigIdOnce" ] || rigRefuse "the first Write was not refused with an id, so there is nothing to grant"
rigAssert "the grant is opened"                        "$( rigGrant "$rigIdOnce" once )" "GRANT: once"
rigAssert "the admitted call fails on its own"         "$( rigWrite "$rigTarget" | LC_ALL=C sed -n 's/^\(ERROR: could not create the parent directory\).*/\1/p' )" "ERROR: could not create the parent directory"
rigAssert "the retry is refused at the gate"           "$( rigWrite "$rigTarget" | LC_ALL=C sed -n 's/^\(ERROR: path not in the allowed write-root set\).*/\1/p' )" "ERROR: path not in the allowed write-root set"
rigIdNext="$( rigRefusalId )"
rigAssert "under a new refusal id"                     "$( [ -n "$rigIdNext" ] && [ "$rigIdNext" != "$rigIdOnce" ] && printf yes || printf no )" yes

echo "-- a granted target swapped for a dangling link out creates nothing at its far end --"
rigTarget="$rigWs/OUT/g"
rigWrite "$rigTarget" > /dev/null
rigAssert "the grant is opened"                        "$( rigGrant "$( rigRefusalId )" session )" "GRANT: session"
rigAssert "control: the granted retry writes"          "$( rigWrite "$rigTarget" | LC_ALL=C sed -n 's/^\(OK: wrote\).*/\1/p' )" "OK: wrote"
rm -f "$rigTarget"
ln -s "$rigWs/ELSEWHERE/new" "$rigTarget"
rigWrite "$rigTarget" > /dev/null
rigAssert "nothing is created where the dangling link points" "$( [ -e "$rigWs/ELSEWHERE/new" ] && printf created || printf absent )" absent

rigAssert "no request left this box"                   "$( LC_ALL=C awk '/^url:/ { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION EDGE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_PERMISSION_EDGE: OK (%d assertions, offline)\n' "$rigPassCount"
