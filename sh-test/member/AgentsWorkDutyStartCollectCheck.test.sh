#!/usr/bin/env bash
## Behavioural check on S4.5: a work-duty is running within seconds. The scan the spawner runs for a start (MDAT_SCAN_AT_START=1,
## AgentsToolsInputScanDefRun) reads Slack once and waits no collect window; the scan a Wait runs keeps the window of WAIT_COLLECT_SECONDS.
## Held: with the window set to twelve seconds, the scan's report heading names the window it used, twelve seconds without the mark and one
## second with it, and the scan's own trace (MDAT_SCAN_TRACE_FILE) shows the collect of the start shorter than the other (the rig's own cost
## of one Slack read stays in both); the report has the same sections either way. And the spawner's real run of a scan carries the mark, where its seed run does not (AgentsToolsInputScanDefRun).
## Offline: a Slack-shaped fake curl logs and answers any call; every tree is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWorkDutyStartCollectCheck )" || exit 1
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
rigCopyTree "${rigHere%/myx/myx.distro-agents/sh-lib}" "$rigW/source" || rigRefuse "the rig's source copy could not be made"
printf '# magic-coordinator\n' > "$rigW/.local/agents/members/magic-coordinator/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=12\n' > "$rigW/.local/.agents/magic-team.agent.env"
for rigState in pending running blocked parked review ; do
	mkdir -p "$rigD/board/$rigState"
done
rigSession="rig-start-collect-session" rigRun="rig-start-collect-run"
rigScan(){ ## name, then env words
	local scanName="$1"
	shift
	( cd "$rigW" && env -u MDAT_SKILLSET_ROOT -u CLAUDE_CODE_SESSION_ID HOME="$rigH" MMDAPP="$rigW" MDLT_ORIGIN="$rigW/source" MDAT_DATA_ROOT="$rigD" RIG_SCENARIO="$rigTmp" \
		MDAT_SESSION_ID="$rigSession" MDAT_SPAWN_SESSION_ID="$rigRun" MDAT_SPAWN_AGENT=magic-coordinator MDAT_WAIT_REMIND=off MDAT_SCAN_TRACE_FILE="$rigTmp/$scanName.trace" "$@" \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 120 -- bash "$rigW/source/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-work-duty-input-scan magic-coordinator ) > "$rigTmp/$scanName.out" 2> "$rigTmp/$scanName.err" < /dev/null || :
}
rigCollect(){ ## name -- the seconds the slack-collect section took, from the trace
	LC_ALL=C sed -n 's/^slack-collect=\([0-9]*\)s$/\1/p' "$rigTmp/$1.trace" | head -1
}
echo "-- a Wait's scan keeps the window (the control: it must be able to wait) --"
rigScan waited
rigAssert "without the mark the collect waits out the twelve seconds" "$( LC_ALL=C grep -c -e 'the team channel over 12s' "$rigTmp/waited.out" ) $( [ "$( rigCollect waited )" -ge 12 ] 2> /dev/null && printf waited || printf "short:%s" "$( rigCollect waited )" )" "1 waited"
echo "-- a start's scan reads once --"
rigScan started MDAT_SCAN_AT_START=1
rigAssert "with the mark the window is one second, and the collect is shorter" "$( LC_ALL=C grep -c -e 'the team channel over 1s' "$rigTmp/started.out" ) $( [ "$( rigCollect started )" -lt "$( rigCollect waited )" ] 2> /dev/null && printf shorter || printf "waited:%s started:%s" "$( rigCollect waited )" "$( rigCollect started )" )" "1 shorter"
rigAssert "the report has the same sections either way" "$( LC_ALL=C grep '^## ' "$rigTmp/started.out" | LC_ALL=C sed 's/ over [0-9]*s$//' | cksum )" "$( LC_ALL=C grep '^## ' "$rigTmp/waited.out" | LC_ALL=C sed 's/ over [0-9]*s$//' | cksum )"
echo "-- the spawner's real run of a scan carries the mark, and its seed run does not --"
( export MMDAPP="$rigW" MDLT_ORIGIN="$rigW/source" ; DistroAgentsTools(){ printf '%s start=%s seed=%s\n' "$*" "${MDAT_SCAN_AT_START:-none}" "${MDAT_SCAN_SEED_QUIET:-none}" >> "$rigTmp/wire.calls" ; return 0 ; }
	. "$rigW/source/myx/myx.distro-agents/sh-lib/session/AgentsTools.InputScanDef.include" > /dev/null 2>&1
	AgentsToolsInputScanDefRun "work-duty --session-id {{session-id}}" magic-coordinator rig-wire-session rig-wire-run "$rigTmp/wire.out" ) > "$rigTmp/wire.log" 2>&1
rigAssert "the real run carries the start mark" "$( LC_ALL=C grep -c -e '--intern-op-work-duty-input-scan magic-coordinator --session-id rig-wire-session start=1 seed=none' "$rigTmp/wire.calls" 2> /dev/null || : )" 1
rigAssert "the seed run is bare-named and carries the seed mark, not the start mark" "$( LC_ALL=C grep -c -e '--intern-op-work-duty-input-scan magic-coordinator start=none seed=1' "$rigTmp/wire.calls" 2> /dev/null || : )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WORK DUTY START COLLECT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WORK_DUTY_START_COLLECT: OK (%d assertions, offline)\n' "$rigPassCount"
