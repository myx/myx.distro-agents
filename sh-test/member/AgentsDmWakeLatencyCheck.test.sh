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

## THE MENTIONS SOURCE (mentions:<member>): one search.messages call, its TTL kept by the session across Waits.
## A search answer: one match, a reply in a thread of another conversation, the text given.
rigSearch(){ ## file, ts, text
	printf '{"ok":true,"messages":{"total":1,"paging":{"count":100,"total":1,"page":1,"pages":1},"matches":[{"ts":"%s","user":"URIGFRIEND","text":"%s","permalink":"https://rig.slack.com/archives/CRIGOTHER/p1?thread_ts=%s.000001&cid=CRIGOTHER","channel":{"id":"CRIGOTHER"}}]}}\n' "$2" "$3" "$(( rigNow - 5000 ))" > "$1"
}
rigNoMatch(){ ## file
	printf '{"ok":true,"messages":{"total":0,"paging":{"count":100,"total":0,"page":1,"pages":1},"matches":[]}}\n' > "$1"
}
## The session's pointer of the source, where the last Wait left it: a little behind now.
rigMentionsPointer(){ printf 'mentions:keeper-rig\t%s.000000\n' "$(( rigNow - 100 ))" >> "$rigWs/.local/agents/sessions/$rigSession/session.chat.pointers" ; }
rigSearches(){ ## scene -- how many searches were made
	LC_ALL=C grep -c '^search.messages ' "$rigTmp/$1/search.log" 2> /dev/null || printf 0
}
mkdir -p "$rigTmp/skills/magic-coordinator" && printf 'rig\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.basic.md"

echo "-- a mention in a thread reply of any conversation: found by the member's own search --"
rigScene mention 60
rigMentionsPointer
printf 'SLACK_USER_TOKEN=rig-user-KEEPER\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
printf 'keeper-rig=URIGKEEP1=k=K=K=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
rigSearch "$rigDir/search.rig-user-KEEPER.json" "$(( rigNow - 10 )).000003" 'RIG-THREAD-MENTION <@URIGKEEP1> in a thread'
rigScan mention
rigAssert "the reply that mentions it is returned at once, its conversation and thread named, by one search for its id" \
	"$( [ "$( rigTook mention )" -le 25 ] && echo within || echo "took:$( rigTook mention )" ):$( rigHolds mention RIG-THREAD-MENTION ):$( rigHolds mention '# in CRIGOTHER' )$( rigHolds mention '[thread-reply of' ):$( rigSearches mention ):$( LC_ALL=C grep -c -F 'search.messages rig-user-KEEPER <@URIGKEEP1>' "$rigDir/search.log" )" "within:1:11:1:1"

echo "-- the member's own Wait gives the mention it returns the seen reaction, in the mention's conversation --"
rigScene seen 60
printf 'SLACK_USER_TOKEN=rig-user-KEEPER\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
printf 'keeper-rig=URIGKEEP1=k=K=K=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
rigSearch "$rigDir/search.rig-user-KEEPER.json" "$(( rigNow - 10 )).000005" 'RIG-SEEN-MENTION <@URIGKEEP1>'
rigCall seen --intern-op-wait-for-input keeper-rig --wait-default --wait-session-id "$rigSession" --wait-source mentions:keeper-rig --wait-since-utime "$(( rigNow - 100 ))" --wait-timeout 10
rigAssert "the mention is returned, and an eyes reaction is asked for in its conversation" \
	"$( rigHolds seen RIG-SEEN-MENTION ):$( [ "$( LC_ALL=C grep -c '^reactions.add CRIGOTHER' "$rigDir/api.log" )" -ge 1 ] && echo reacted || echo none )" "1:reacted"

echo "-- the TTL holds across Waits: one search per expired check, none at a Wait start inside it --"
rigScene ttl 20
rigMentionsPointer
printf 'SLACK_USER_TOKEN=rig-user-KEEPER\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
printf 'keeper-rig=URIGKEEP1=k=K=K=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
rigNoMatch "$rigDir/search.rig-user-KEEPER.json"
rigTtlStart="$( date +%s )"
rigScan ttl-1
rigTtlOne="$( rigSearches ttl )"
rigScan ttl-2
rigTtlTwo="$( rigSearches ttl )"
rigTtlLeft=$(( rigTtlStart + 62 - $( date +%s ) )) ; [ "$rigTtlLeft" -le 0 ] || sleep "$rigTtlLeft"
rigScan ttl-3
rigAssert "a 20 s collect searches once; a second Wait inside the 60 s does not; one after it does, once" "$rigTtlOne:$rigTtlTwo:$( rigSearches ttl )" "1:1:2"

echo "-- a member with no Slack account: a text search for @<member>, by the team identity that may search --"
rigScene text 60
rigMentionsPointer
printf 'SLACK_USER_TOKEN=rig-user-COORD\n' > "$rigWs/.local/.agents/magic-coordinator.agent.env"
rigSearch "$rigDir/search.rig-user-COORD.json" "$(( rigNow - 10 )).000004" 'RIG-TEXT-MENTION @keeper-rig look at this'
rigScan text
rigAssert "the text mention is returned, found by the coordinator's search for the text @keeper-rig" \
	"$( rigHolds text RIG-TEXT-MENTION ):$( LC_ALL=C grep -c -F 'search.messages rig-user-COORD "@keeper-rig"' "$rigDir/search.log" )" "1:1"

echo "-- the team identity that searches is the magic-team setting WAIT_MENTIONS_SEARCHER --"
rigScene searcher 60
rigMentionsPointer
mkdir -p "$rigTmp/skills/magic-rig-searcher" && printf 'rig\n' > "$rigTmp/skills/magic-rig-searcher/magic-rig-searcher.basic.md"
printf 'WAIT_MENTIONS_SEARCHER=magic-rig-searcher\n' >> "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-SEARCHER\n' > "$rigWs/.local/.agents/magic-rig-searcher.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-COORD\n' > "$rigWs/.local/.agents/magic-coordinator.agent.env"
rigSearch "$rigDir/search.rig-user-SEARCHER.json" "$(( rigNow - 10 )).000006" 'RIG-SET-MENTION @keeper-rig'
rigScan searcher
rigAssert "the setting's member searches, not the coordinator" \
	"$( rigHolds searcher RIG-SET-MENTION ):$( LC_ALL=C grep -c '^search.messages rig-user-SEARCHER ' "$rigDir/search.log" ):$( LC_ALL=C grep -c '^search.messages rig-user-COORD ' "$rigDir/search.log" )" "1:1:0"

echo "-- no identity may search: an error in the Wait's header, never an empty result --"
rigScene noscope 60
rigCall noscope --intern-op-wait-for-input keeper-rig --wait-source mentions:keeper-rig --wait-timeout 2
rigAssert "the source is named never read, and why is said" \
	"$( LC_ALL=C grep -c '^WAIT-NEVER-READ: .*\[mentions:keeper-rig\]' "$rigDir/noscope.out" ):$( LC_ALL=C grep -c -F 'no identity may search its mentions' "$rigDir/noscope.err" )" "1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DM WAKE LATENCY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DM_WAKE_LATENCY: OK (%d assertions, offline)\n' "$rigPassCount"
