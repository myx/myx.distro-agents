#!/usr/bin/env bash
## Behavioural check on MDAT_SCAN_TRACE, the seconds each section of the work-duty scan took (sh-lib/member/AgentsTools.InternOpWorkDuty.include,
## AgentsWaitProbeScan). A slow scan names its slow part: the scan says one line per section on its stderr, and a Wait that runs it says them on its own.
## Held: with MDAT_SCAN_TRACE=1 the scan's stderr holds a `scan-trace: <section> <n>s` line for each section, in the order the report has them, the
## report is the same as without; with it unset nothing is said.
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
rigTmp="$( rigTempDir AgentsWorkDutyScanTraceCheck )" || exit 1
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
rigSession="rig-scan-trace-session" rigRun="rig-scan-trace-run"
rigScan(){ ## name, then env words
	local scanName="$1"
	shift
	( cd "$rigW" && env -u MDAT_SKILLSET_ROOT -u CLAUDE_CODE_SESSION_ID HOME="$rigH" MMDAPP="$rigW" MDLT_ORIGIN="$rigW/source" MDAT_DATA_ROOT="$rigD" RIG_SCENARIO="$rigTmp" \
		MDAT_SESSION_ID="$rigSession" MDAT_SPAWN_SESSION_ID="$rigRun" MDAT_SPAWN_AGENT=magic-coordinator MDAT_WAIT_REMIND=off "$@" \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 120 -- bash "$rigW/source/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-work-duty-input-scan magic-coordinator ) > "$rigTmp/$scanName.out" 2> "$rigTmp/$scanName.err" < /dev/null || :
}
echo "-- traced --"
rigScan traced MDAT_SCAN_TRACE=1
rigAssert "one line per section, in the order of the report" "$( LC_ALL=C sed -n 's/^scan-trace: \([a-z-]*\) [0-9]*s$/\1/p' "$rigTmp/traced.err" | LC_ALL=C tr '\n' ' ' )" "inbox external-owner-items permission-asks board-digest-review-and-registries recheck-dates dependencies slack-collect "
echo "-- not traced --"
rigScan plain
rigAssert "nothing is said when it is unset" "$( LC_ALL=C grep -c '^scan-trace: ' "$rigTmp/plain.err" )" 0
rigAssert "the report is the same with and without" "$( LC_ALL=C grep -v -e '^tokens' "$rigTmp/traced.out" | cksum ):$( LC_ALL=C grep -c . "$rigTmp/traced.out" | LC_ALL=C awk '{ print ( $1 > 10 ) ? "full" : "short" }' )" "$( LC_ALL=C grep -v -e '^tokens' "$rigTmp/plain.out" | cksum ):full"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WORK DUTY SCAN TRACE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WORK_DUTY_SCAN_TRACE: OK (%d assertions, offline)\n' "$rigPassCount"
