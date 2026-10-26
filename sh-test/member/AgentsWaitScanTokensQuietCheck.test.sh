#!/usr/bin/env bash
## Behavioural check on `scan:work-duty` as a Wait source over a report that carries live token counters (AgentsWaitProbeScan,
## sh-lib/member/AgentsTools.MemberWait.include). The board sections of the scan print the `tokens:` and `tokens-total:` lines of
## every running item, and the harness rewrites those at every model round, so a report summed whole differed at every wait: the
## idle wait of a work-duty run returned after one round, whatever had arrived, with a 190 KB report that held nothing new. The
## wake is on a change of the report other than those counters. Held:
##   1. the first wait reads the report: RECEIVED, with the counters in it (the report is returned whole)
##   2. read again with nothing changed: TIMEOUT
##   3. only the token counters of the running item changed: TIMEOUT, not RECEIVED
##   4. a line that only begins like a counter (`tokens: unknown`) is not left out: its change wakes the wait
##   5. a note added to the inbox: RECEIVED, with the note
## Red before the fix: step 3 is RECEIVED.
## Offline: a Slack-shaped fake curl logs and answers any call; every tree is this rig's own; the collect window of the scan is one second.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A scan may start the control thread of a session of its rig that is not finished: the rig ends it.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitScanTokensQuietCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigW="$rigTmp/ws" rigD="$rigTmp/data" rigH="$rigTmp/home"
mkdir -p "$rigW/.local/.agents" "$rigW/.local/agents/spawned" "$rigW/.local/agents/members/magic-coordinator" "$rigD/inboxes/magic-coordinator/incoming" "$rigH"
## The rig's own workspace has a source folder: the context of the tool is detected from it.
ln -s "${rigHere%/myx/myx.distro-agents/sh-lib}" "$rigW/source" || rigRefuse "the rig's source link could not be made"
printf '# magic-coordinator\n' > "$rigW/.local/agents/members/magic-coordinator/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=1\n' > "$rigW/.local/.agents/magic-team.agent.env"
for rigState in pending running blocked parked review ; do
	mkdir -p "$rigD/board/$rigState"
done
rigItem="$rigD/board/running/dispatch-rig-running.md"
rigItemWrite(){ ## the tokens line the running item holds
	printf -- '---\ntype: dispatch\nowner: magic-coordinator\nstatus: dispatch-started\n%s\n---\n\n# Rig running item\n' "$1" > "$rigItem"
}
rigItemWrite "tokens: in=1 cache-read=2 cache-write=3 out=4"
rigSession="rig-scan-tokens-session" rigRun="rig-scan-tokens-run"
## One Wait on the scan source, timeout 0, as a run of the team session.
rigWait(){ ## result name
	local waitRc=0
	( cd "$rigW" && env -u MDAT_SKILLSET_ROOT -u CLAUDE_CODE_SESSION_ID HOME="$rigH" MMDAPP="$rigW" MDLT_ORIGIN="$rigW/source" MDAT_DATA_ROOT="$rigD" RIG_SCENARIO="$rigTmp" \
		MDAT_SESSION_ID="$rigSession" MDAT_SPAWN_SESSION_ID="$rigRun" MDAT_SPAWN_AGENT=magic-coordinator MDAT_WAIT_REMIND=off \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 120 -- bash "$rigW/source/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --wait-for-input magic-coordinator --wait-source scan:work-duty --wait-timeout 0 ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" < /dev/null 4> /dev/null || waitRc=$?
	printf '%s' "$waitRc" > "$rigTmp/$1.rc"
}
rigResult(){ ## result name -- the outcome word of its WAIT-RESULT line, or none
	local resultWord
	resultWord="$( LC_ALL=C sed -n 's/^WAIT-RESULT: \([A-Z]*\).*/\1/p' "$rigTmp/$1.out" | head -1 )"
	printf '%s' "${resultWord:-none}"
}
rigHolds(){ ## result name, text -- yes or no
	LC_ALL=C grep -q -F -e "$2" "$rigTmp/$1.out" && printf yes || printf no
}

echo "-- 1. the first wait reads the report, counters and all --"
rigWait w1
rigAssert "RECEIVED, ending 0"                                    "$( rigResult w1 ):$( cat "$rigTmp/w1.rc" )" "RECEIVED:0"
rigAssert "the report is returned whole: the counters are in it"  "$( rigHolds w1 'tokens: in=1 cache-read=2 cache-write=3 out=4' )" yes
echo "-- 2. nothing changed: TIMEOUT --"
rigWait w2
rigAssert "the second read finds the report as it was"            "$( rigResult w2 )" "TIMEOUT"
echo "-- 3. only the token counters changed: TIMEOUT --"
rigItemWrite "tokens: in=5 cache-read=60 cache-write=700 out=8000"
rigWait w3
rigAssert "counters alone do not wake the wait"                   "$( rigResult w3 )" "TIMEOUT"
echo "-- 4. a line that only begins like a counter is a change --"
rigItemWrite "tokens: unknown"
rigWait w4
rigAssert "RECEIVED, with the line"                               "$( rigResult w4 ):$( rigHolds w4 'tokens: unknown' )" "RECEIVED:yes"
echo "-- 5. a note added to the inbox wakes the wait --"
printf -- '---\ntype: note\nfrom: magic-coordinator\n---\n\n# Note: scan tokens quiet\n' > "$rigD/inboxes/magic-coordinator/incoming/note-20261022T1700Z-scan-tokens-quiet.md"
rigWait w5
rigAssert "RECEIVED, with the note added"                         "$( rigResult w5 ):$( rigHolds w5 'note-20261022T1700Z-scan-tokens-quiet' )" "RECEIVED:yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT SCAN TOKENS QUIET CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_SCAN_TOKENS_QUIET: OK (%d assertions, offline)\n' "$rigPassCount"
