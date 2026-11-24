#!/usr/bin/env bash
## Behavioural check on the hold line of the work-duty scan (epic S22, the hold floor): while the schedule holds new work, the scan of
## magic-coordinator's duty opens with a line that says so, and the duty works its board group alone, starting nothing.
## (--intern-op-work-duty-input-scan, AgentsTools.InternOpWorkDuty.include)
##   1. WITH HOLDING SET the scan exits 0 and carries the line `**HOLDING:**` once, ahead of the inbox section.
##   2. THE CONTROL: with no holding set the same scan exits 0 and does not carry it.
## Offline: a Slack-shaped fake curl first on PATH.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTest="$rigOrigin/myx/myx.distro-agents/sh-test"
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWorkDutyHoldingScanCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwx -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigWs/.local/agents/sessions/rig-session" \
	"$rigTmp/skills/magic-coordinator" "$rigTmp/skills/human-owner"
printf 'rig\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.basic.md"
printf 'rig\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.armed.md"
printf -- '---\nstatus: reference-only\n---\n# human-owner\n' > "$rigTmp/skills/human-owner/SKILL.md"
printf 'rig\n' > "$rigTmp/skills/human-owner/human-owner.basic.md"
cp "$rigTest/check-fixtures/work-duty.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
rigEnv(){ ## the holding line of the rig's settings, or nothing
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=1\n%s' "${1:+$1$'\n'}" > "$rigWs/.local/.agents/magic-team.agent.env"
}

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The scan of magic-coordinator: stdout to the first file, stderr to the second, its status printed.
rigScan(){ ## out-file, err-file
	local scanRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_WAIT_REMIND=off MDAT_WAIT_POLL_SECONDS=1 \
		python3 -I -B "$rigTest/check-fixtures/rig-exec.py" --alarm 180 -- \
		bash "$rigTool" --intern-op-work-duty-input-scan magic-coordinator --session-id rig-session < /dev/null ) > "$1" 2> "$2" || scanRc=$?
	printf '%s' "$scanRc"
}
. "$rigTest/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigTmp/skills"
rigOwnerBoardReady || rigRefuse "the board could not be made ready"

echo "-- 1. with holding set the scan says so, ahead of its inbox section --"
rigEnv "MDAT_SCHEDULE_HOLDING=on"
rigAssert "the scan exits 0" "$( rigScan "$rigTmp/hold.out" "$rigTmp/hold.err" )" "0"
rigAssert "it carries the holding line once" "$( LC_ALL=C grep -c -F '**HOLDING:**' "$rigTmp/hold.out" || : )" "1"
rigAssert "and the line comes before the inbox section" \
	"$( LC_ALL=C awk '/^\*\*HOLDING:\*\*/ { held = NR ; } /^## Inbox: items not yet processed/ { inbox = NR ; } END { print ( held > 0 && inbox > held ) ? "before" : "not-before" ; }' "$rigTmp/hold.out" )" "before"

echo "-- 2. the control: with no holding set the scan does not carry it --"
rigEnv ""
rigAssert "the scan exits 0" "$( rigScan "$rigTmp/free.out" "$rigTmp/free.err" )" "0"
rigAssert "it carries no holding line" "$( LC_ALL=C grep -c -F '**HOLDING:**' "$rigTmp/free.out" || : )" "0"
rigAssert "and it still carries the inbox section, so the scan read what it reads" "$( LC_ALL=C grep -c -x -F '## Inbox: items not yet processed' "$rigTmp/free.out" || : )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WORK DUTY HOLDING SCAN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'WORK_DUTY_HOLDING_SCAN: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
