#!/usr/bin/env bash
## Behavioural check on the off-duty floor of the work-duty scan (S18.4): `--intern-op-work-duty-input-scan <member>
## [--session-id <id>] [--floor work-duty|off-duty]`. One scan operation and one option, never a second scan, so a source
## added to the work-duty floor cannot be forgotten on the off-duty one. Held, run and not read:
##   1. THE OFF-DUTY FLOOR NARROWS THE SOURCES. `--floor off-duty` is accepted, and the coordinator's scan under it
##      carries no external owners' section. Email and Trello are read by neither floor.
##   2. THE CONTROL: the same scan with `--floor work-duty` and with no `--floor` at all carries that section. Without
##      this row the absence above proves nothing.
##   3. SLACK STAYS ON under both floors, so the option narrows one source and not the others.
##   4. A FLOOR THAT IS NO FLOOR is refused, naming both floors, and `--floor` with no value is refused too.
## Offline: a Slack-shaped fake curl first on PATH, and every tree the rig's own.
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
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigTest/check-fixtures/rig-owner-writes.include.sh" || rigRefuse "the rig's owner-writes fixture is missing from the package"
rigTmp="$( rigTempDir AgentsWorkDutyOffDutyFloorCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigWs/.local/agents/sessions/rig-session" \
	"$rigWs/.local/agents/schedule/duty" "$rigTmp/skills/magic-coordinator" "$rigData/inboxes/magic-coordinator/incoming" "$rigData/board"
printf 'rig\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.basic.md"
printf 'rig\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.armed.md"
cp "$rigTest/check-fixtures/work-duty.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## One item of an owner who is no member, so the external owners' section has a row to carry when it is read at all: put by the store's owner.
printf -- '---\ntype: note\nowner: human-owner\n---\n\n# Note: rig\n' | rigOwnerInboxPut magic-coordinator note-20261019T0101Z-rig-ext.md || rigRefuse "the rig inbox item could not be put by the store's owner"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
rigScan(){ ## label, the scan's own options... -- rc in <label>.rc, report in <label>.out, stderr in <label>.err
	local scanName="$1" scanRc=0
	shift
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" MDAT_DATA_ROOT="$rigData" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_WAIT_REMIND=off MDAT_WAIT_POLL_SECONDS=1 \
		python3 -I -B "$rigTest/check-fixtures/rig-exec.py" --alarm 300 -- bash "$rigTool" --intern-op-work-duty-input-scan magic-coordinator --session-id rig-session "$@" ) \
		> "$rigTmp/$scanName.out" 2> "$rigTmp/$scanName.err" < /dev/null || scanRc=$?
	printf '%s' "$scanRc" > "$rigTmp/$scanName.rc"
}
rigHas(){ ## label, a fixed line prefix -- how many lines of that report carry it
	LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.out" || :
}

echo "-- 1. the off-duty floor is accepted, and narrows the external owners' section away --"
rigScan offduty --floor off-duty
rigAssert "exit 0 under --floor off-duty"                    "$( cat "$rigTmp/offduty.rc" )" "0"
rigAssert "and no external owners' section under it"         "$( rigHas offduty '## External owners' )" "0"

echo "-- 2. the control: the work-duty floor, and no floor at all, carry that section --"
rigScan workduty --floor work-duty
rigScan nofloor
rigAssert "exit 0 under --floor work-duty"                   "$( cat "$rigTmp/workduty.rc" )" "0"
rigAssert "the external owners' section is there under it"   "$( rigHas workduty '## External owners' )" "1"
rigAssert "exit 0 with no --floor at all"                    "$( cat "$rigTmp/nofloor.rc" )" "0"
rigAssert "the external owners' section is there with none"  "$( rigHas nofloor '## External owners' )" "1"

echo "-- 3. Slack is a source of both floors --"
rigAssert "the off-duty scan still reads Slack"              "$( rigHas offduty '## Slack:' )" "1"
rigAssert "and so does the work-duty scan"                   "$( rigHas workduty '## Slack:' )" "1"

echo "-- 4. a floor that is no floor is refused, naming both --"
rigScan badfloor --floor sometimes
rigScan novalue --floor
rigAssert "an unknown floor exits 1, naming both floors"     "$( cat "$rigTmp/badfloor.rc" ):$( LC_ALL=C grep -c -F 'takes work-duty or off-duty' "$rigTmp/badfloor.err" )" "1:1"
rigAssert "--floor with no value exits 1, naming both"       "$( cat "$rigTmp/novalue.rc" ):$( LC_ALL=C grep -c -F 'work-duty or off-duty' "$rigTmp/novalue.err" )" "1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WORK DUTY OFF DUTY FLOOR CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
printf 'WORK_DUTY_OFF_DUTY_FLOOR: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
