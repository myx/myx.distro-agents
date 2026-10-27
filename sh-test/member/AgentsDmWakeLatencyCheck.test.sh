#!/usr/bin/env bash
## Behavioural check on the time a work-duty takes to read a Slack DM to its member (S6.3, sketch 7.4): MEASURED, never assumed.
## The work-duty's input scan (--intern-op-work-duty-input-scan) collects over a window of 60 s; a DM, bare or tagged, ends the collect at
## once, whenever it arrives. Here the DM is posted by a person 6 seconds INTO the collect (not before it, as the scan check has it), and the
## time from the post to the scan's return with the DM in it is the number measured. It must stay within a poll round or two of the
## Slack reads (the live Wait floor is 15 s for the tags and DMs), and a DM that is only bare, with no mention, wakes it as a tagged one does.
## The reaction that says the DM was seen is the member's own, on its next Wait (--wait-react-seen): the tooling's part is the read.
## Offline: a Slack-shaped fake curl first on PATH; every tree is this rig's own.
## Offline: a Slack-shaped fake curl first on PATH; every tree is this rig's own.
## Offline: a Slack-shaped fake curl first on PATH; every tree is this rig's own.
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
rigTmp="$( rigTempDir AgentsWorkDutyInputScanCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/keeper-rig"
printf 'rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md" ; printf 'rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.armed.md"
cp "$rigTest/check-fixtures/work-duty.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigNow="$( date +%s )"
rigWs="" rigData="" rigDir="" rigSession="rig-wd-session"
rigScene(){ ## name, the collect window in seconds
	rigNow="$( date +%s )"
	rigDir="$rigTmp/$1"
	rigWs="$rigDir/ws" rigData="$rigDir/data"
	rm -rf "$rigDir"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/sessions/$rigSession" "$rigData/inboxes/keeper-rig/incoming" "$rigData/inboxes/keeper-rig/processed" "$rigData/board"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=%s\n' "$2" > "$rigWs/.local/.agents/magic-team.agent.env"
	printf -- '---\ntype: note\nfrom: magic-coordinator\n---\n\nRIG-INCOMING-NOTE\n' > "$rigData/inboxes/keeper-rig/incoming/note-20261019T0100Z-rig-open.md"
	printf -- '---\ntype: note\nfrom: magic-coordinator\nprocessed-at: 2026-10-19 01:05 +0000\n---\n\nRIG-PROCESSED-NOTE\n' > "$rigData/inboxes/keeper-rig/processed/note-20261019T0000Z-rig-done.md"
	: > "$rigDir/api.log"
	## The pointers of the session, a little behind now: what the last collect of this session had got to.
	printf 'collect:keeper-rig:slack:magic-team\t%s.000000\ncollect:keeper-rig:tagged:keeper-rig\t%s.000000\n' "$(( rigNow - 100 ))" "$(( rigNow - 100 ))" > "$rigWs/.local/agents/sessions/$rigSession/session.chat.pointers"
}
rigMsg(){ ## ts user text [thread ts]
	printf '{"ts":"%s","user":"%s","text":"%s"%s}' "$1" "$2" "$3" "${4:+,\"thread_ts\":\"$4\"}"
}
rigHistory(){ ## channel, messages...
	local historyChannel="$1" historyOut="" historyOne
	shift
	for historyOne in "$@" ; do historyOut="$historyOut${historyOut:+,}$historyOne" ; done
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$historyOut" > "$rigDir/history.$historyChannel.json"
}
rigCall(){ ## result name, op words... -- one call from the rig workspace; rc, out, err and how long it took
	local callName="$1" callStart callRc=0
	shift
	callStart="$( date +%s )"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_SCENARIO="$rigDir" MDAT_WAIT_REMIND=off MDAT_WAIT_POLL_SECONDS=1 python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 120 -- bash "$rigTool" "$@" ) > "$rigDir/$callName.out" 2> "$rigDir/$callName.err" < /dev/null || callRc=$?
	printf '%s' "$callRc" > "$rigDir/$callName.rc"
	printf '%s' "$(( $( date +%s ) - callStart ))" > "$rigDir/$callName.took"
}
rigHolds(){ ## result name, text -- how many lines of the result hold it
	LC_ALL=C grep -c -F -- "$2" "$rigDir/$1.out" || :
}
rigScan(){ ## result name
	rigCall "$1" --intern-op-work-duty-input-scan keeper-rig --session-id "$rigSession"
}
rigTook(){ cat "$rigDir/$1.took" ; }

## The DM conversation, empty at the start; the person's message lands $2 seconds into a collect of a minute. Sets rigLateTook, the seconds from the post to the return.
rigLate(){ ## result name, seconds before the DM lands, message text
	local lateName="$1" lateAfter="$2" lateText="$3" latePid lateLanded lateEnded
	rigScene "$lateName" 60
	printf '[{"id":"DRIGDM001","is_im":true,"is_mpim":false,"user":"URIGFRIEND","is_user_deleted":false,"is_member":true}]\n' > "$rigDir/dms.json"
	rigHistory DRIGDM001
	rigScan "$lateName" &
	latePid=$!
	sleep "$lateAfter"
	rigHistory DRIGDM001 "$( rigMsg "$(( $( date +%s ) )).000001" URIGFRIEND "$lateText" )"
	lateLanded="$( date +%s )"
	wait "$latePid" 2> /dev/null || :
	lateEnded="$( date +%s )"
	rigLateTook=$(( lateEnded - lateLanded ))
}
echo "-- a DM that lands during the collect ends it within a poll round or two --"
rigLate bare 6 RIG-DM-LATE-BARE ; rigBare="$rigLateTook"
rigAssert "a bare DM (no mention in it): the scan returns with it, and not at the end of the minute" "$( [ "$rigBare" -le 25 ] && echo within || echo "took:$rigBare" ):$( rigHolds bare RIG-DM-LATE-BARE ):$( rigHolds bare '# returned: immediate' )" "within:1:1"
rigLate tagged 6 'RIG-DM-LATE-TAGGED @keeper-rig look' ; rigTagged="$rigLateTook"
rigAssert "a DM that tags the member: the same" "$( [ "$rigTagged" -le 25 ] && echo within || echo "took:$rigTagged" ):$( rigHolds tagged RIG-DM-LATE-TAGGED ):$( rigHolds tagged '# returned: immediate' )" "within:1:1"
printf '  measured: a DM landing 6 s into the collect, read and returned in %ss (bare) and %ss (tagged)\n' "$rigBare" "$rigTagged"

echo "-- a mention in another channel the member is in, not the team channel: read by the wider sweep --"
rigScene wide 60
printf '[{"id":"CRIGGEN01","is_im":false,"is_mpim":false,"user":"","is_user_deleted":false,"is_member":true},{"id":"CRIGNOTIN","is_im":false,"is_mpim":false,"user":"","is_user_deleted":false,"is_member":false}]\n' > "$rigDir/dms.json"
rigHistory CRIGGEN01 "$( rigMsg "$(( rigNow - 30 )).000001" URIGFRIEND 'RIG-WIDE-MENTION @keeper-rig in general' )" "$( rigMsg "$(( rigNow - 20 )).000001" URIGFRIEND 'RIG-WIDE-PLAIN no mention here' )"
rigHistory CRIGNOTIN "$( rigMsg "$(( rigNow - 25 )).000001" URIGFRIEND 'RIG-NOT-IN @keeper-rig where the member is not' )"
rigScan wide
rigAssert "the mention in a channel the member is in is returned at once, and only it" \
	"$( [ "$( rigTook wide )" -le 25 ] && echo within || echo "took:$( rigTook wide )" ):$( rigHolds wide RIG-WIDE-MENTION ):$( rigHolds wide RIG-WIDE-PLAIN ):$( rigHolds wide RIG-NOT-IN )" "within:1:0:0"
rigAssert "a channel the member is not in is not read" "$( LC_ALL=C grep -c '^conversations.history CRIGNOTIN ' "$rigDir/api.log" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DM WAKE LATENCY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DM_WAKE_LATENCY: OK (%d assertions, offline)\n' "$rigPassCount"
