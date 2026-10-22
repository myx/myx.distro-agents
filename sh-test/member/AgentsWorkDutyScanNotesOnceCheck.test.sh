#!/usr/bin/env bash
## Behavioural check on the work-duty scan printing each inbox note once (sh-lib/board/AgentsTools.BoardRoundScan.include). The scan ran the
## context scan twice, once for the inbox sections and once for the board digest, and both printed the member's notes: in the live scan 29 notes
## were printed twice, 56 KB of 190. Held: a note in the inbox has its `## inbox/<file>` block once in the report, and the board digest still lists the board.
## Red before the change: the note's block is there twice.
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
rigTmp="$( rigTempDir AgentsWorkDutyScanNotesOnceCheck )" || exit 1
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
		perl -e 'alarm 120 ; exec @ARGV' bash "$rigW/source/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --wait-for-input magic-coordinator --wait-source scan:work-duty --wait-timeout 0 ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" < /dev/null 4> /dev/null || waitRc=$?
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

rigItemWrite "tokens: in=1 cache-read=2 cache-write=3 out=4"
printf -- '---\ntype: note\nfrom: magic-coordinator\n---\n\n# Note: printed once\n' > "$rigD/inboxes/magic-coordinator/incoming/note-20261022T1900Z-printed-once.md"
echo "-- the scan prints a note once --"
( cd "$rigW" && env -u MDAT_SKILLSET_ROOT -u CLAUDE_CODE_SESSION_ID HOME="$rigH" MMDAPP="$rigW" MDLT_ORIGIN="$rigW/source" MDAT_DATA_ROOT="$rigD" RIG_SCENARIO="$rigTmp" \
	MDAT_SESSION_ID="$rigSession" MDAT_SPAWN_SESSION_ID="$rigRun" MDAT_SPAWN_AGENT=magic-coordinator MDAT_WAIT_REMIND=off \
	perl -e 'alarm 120 ; exec @ARGV' bash "$rigW/source/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-work-duty-input-scan magic-coordinator ) > "$rigTmp/scan.out" 2> "$rigTmp/scan.err" < /dev/null || :
rigAssert "the note's block is in the report once" "$( LC_ALL=C grep -c -x -F '## inbox/note-20261022T1900Z-printed-once.md' "$rigTmp/scan.out" )" 1
rigAssert "the board digest is still there, with the running item" "$( LC_ALL=C grep -c -x -F '## board digest' "$rigTmp/scan.out" ):$( LC_ALL=C grep -c -F 'dispatch-rig-running.md' "$rigTmp/scan.out" )" "1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WORK DUTY SCAN NOTES ONCE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WORK_DUTY_SCAN_NOTES_ONCE: OK (%d assertions, offline)\n' "$rigPassCount"
