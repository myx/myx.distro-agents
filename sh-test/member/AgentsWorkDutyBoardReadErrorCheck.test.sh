#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the work-duty scan's board read (S26 item 3): a board read that FAILS is an
## error in the scan's result, never a board with nothing due. (--intern-op-work-duty-input-scan,
## AgentsTools.InternOpWorkDuty.include; the digest it reads is AgentsTools.InternOpSessionContextScan.include)
##   1. THE CONTROL, both directions on one subject: a readable board holding one item lists that item and
##      the scan exits 0 -- so an empty board section means the read happened and found nothing.
##   2. A board state folder that exists and cannot be listed makes the scan exit non-zero, and says so on
##      stderr. It does not print an empty digest and exit 0.
##   3. A board that is readable and genuinely empty is NOT an error: exit 0, and no error line.
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
rigTmp="$( rigTempDir AgentsWorkDutyBoardReadErrorCheck )" || exit 1
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
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
mkdir -p "$rigData/inboxes/magic-coordinator/incoming" "$rigData/board/pending"

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
## How many lines of the two streams of one run say the board could not be read.
rigBoardFailures(){ ## out-file, err-file
	cat "$1" "$2" | LC_ALL=C grep -c 'could not be read' || :
}
rigItem(){ ## name, owner
	printf -- '---\ntype: task\nowner: %s\n---\n\n# rig\n' "$2" > "$rigData/board/pending/$1"
}

echo "-- 1. the control: a readable board with one item --"
rigItem task-20261019T0100Z-rig-one.md magic-coordinator
rigAssert "the scan exits 0" "$( rigScan "$rigTmp/read.out" "$rigTmp/read.err" )" "0"
rigAssert "the board digest lists the one item" "$( LC_ALL=C grep -c -x -F '## pending/task-20261019T0100Z-rig-one.md' "$rigTmp/read.out" || : )" "1"
rigAssert "and it reports no board read failure" "$( [ "$( rigBoardFailures "$rigTmp/read.out" "$rigTmp/read.err" )" -eq 0 ] && printf silent || printf said )" "silent"

echo "-- 2. a board state folder that cannot be listed: an empty board, not a read --"
rm -f "$rigData/board/pending/task-20261019T0100Z-rig-one.md"
rigItem task-20261019T0101Z-rig-two.md magic-coordinator
mkdir -p "$rigData/board/blocked"
chmod 000 "$rigData/board/blocked"
rigBusyRc="$( rigScan "$rigTmp/busy.out" "$rigTmp/busy.err" )"
chmod 755 "$rigData/board/blocked"
rigBusyWord="nonzero"
[ "$rigBusyRc" != "0" ] || rigBusyWord="zero"
rigAssert "the scan exits non-zero, so its caller cannot take an empty board as a result" "$rigBusyWord" "nonzero"
rigAssert "and it says the board could not be read" "$( [ "$( rigBoardFailures "$rigTmp/busy.out" "$rigTmp/busy.err" )" -ge 1 ] && printf said || printf silent )" "said"
rm -rf "$rigData/board/blocked"
rm -f "$rigData/board/pending/task-20261019T0101Z-rig-two.md"

echo "-- 3. a readable board that is genuinely empty is no error --"
rigAssert "the scan exits 0" "$( rigScan "$rigTmp/empty.out" "$rigTmp/empty.err" )" "0"
rigAssert "and it reports no board read failure" "$( [ "$( rigBoardFailures "$rigTmp/empty.out" "$rigTmp/empty.err" )" -eq 0 ] && printf silent || printf said )" "silent"

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'WORK_DUTY_BOARD_READ_ERROR: OK\n'
