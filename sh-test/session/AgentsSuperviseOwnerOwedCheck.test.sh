#!/usr/bin/env bash
## Behavioural check on S13 `owner-owed`: each message of the human-owner in a workspace's conversations that no message
## of another account follows in its own thread, read from the comms cache alone. Held:
##   0. the control: the rig's cache is the store the check wrote, and a conversation outside the team channel and the
##      direct ones yields no line
##   1. his message in his own direct conversation, unanswered, yields `owner-owed <ws> <conversation>:<ts> age=<n>m <words>`
##      with his own words, the store's own tags stripped
##   2. a reply of another account after it removes the line
##   3. a reply before it does not: the line stands, and its thread is its own
##   4. a message of another account alone yields no line
##   5. the team channel's own messages are read, and its threads with them
##   6. the scan's header carries the kind, and the scan reaches it with no service call
##   8. his message answered only by the local copy of our reply, in a thread folder no pull made, yields no line: that folder's
##      own `slack-local-thread` line names it; the same copy in a folder with no line leaves the message owed
## Red before the kind: no `owner-owed` line at all. Offline: the store is the check's own, and nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/AgentDispatcherTools.fn.sh"
rigInclude="$rigPkg/sh-lib/supervise/AgentsTools.SuperviseOwnerOwed.include"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigFn" ] || rigRefuse "the dispatcher is not at the origin: $rigFn"
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsSuperviseOwnerOwedCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigStore="$rigWs/.local/cache/comms/slack"
rigData="$rigTmp/data"
mkdir -p "$rigStore" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sessions" "$rigWs/.local/agents/pending" "$rigData/audit/2026-11" || rigRefuse "the rig could not be made: $rigTmp"
rigOwner="U0RIGOWNR" rigTeam="CRIGTEAM01" rigOther="U0RIGOTHR"
printf 'SLACK_CHANNEL_MAGIC_TEAM=%s\nSLACK_CHANNEL_HUMAN_OWNER=%s\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK1\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
	"$rigTeam" "$rigOwner" > "$rigWs/.local/.agents/magic-team.agent.env"

rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigNow="$( date +%s )"

## ONE CONVERSATION of the cache: its folder, its pulling line, and its month folder for the messages.
rigConv(){ ## the folder name, the target, the member
	mkdir -p "$rigStore/$1/202611"
	printf '1793600000 %s 0\n\nslack-conversation %s %s false\n' "$2" "$2" "$3" > "$rigStore/$1/.state.txt"
}
## ONE THREAD of the cache: its pulling line names the conversation and the thread it is, as the store's own does.
rigThread(){ ## the folder name, the conversation, the thread ts, the member
	mkdir -p "$rigStore/$1/202611"
	printf '1793600000 %s.%s 0\n\nslack-thread %s:%s %s false\n' "$3" 000001 "$2" "$3" "$4" > "$rigStore/$1/.state.txt"
}
## ONE MESSAGE: `<ts> | <author> | <text>`, the store's own line.
rigMsg(){ ## the folder, its month, the ts, the author, the text
	printf '%s | %s | %s\n' "$3" "$4" "$5" >> "$rigStore/$1/$2/messages.txt"
}

## His direct conversation with the team, and one of its threads.
rigConv "slack-bot-D0RIGONLY1" "D0RIGONLY1" magic-coordinator
rigConv "slack-bot-D0RIGANSW1" "D0RIGANSW1" magic-coordinator
rigConv "slack-bot-D0RIGANSW1-1793600003.000001" "D0RIGANSW1:1793600003.000001" magic-coordinator
rigConv "slack-bot-D0RIGBEFR1" "D0RIGBEFR1" magic-coordinator
rigThread "slack-bot-D0RIGBEFR1-1793600004.000001" "D0RIGBEFR1" 1793600004.000001 magic-coordinator
rigConv "slack-bot-D0RIGALON1" "D0RIGALON1" magic-coordinator
rigConv "slack-bot-D0RIGEMPT1" "D0RIGEMPT1" magic-coordinator
## The team channel, one thread of it, and one channel that is neither it nor a direct one.
rigConv "slack-$rigTeam" "$rigTeam" magic-coordinator
rigThread "slack-$rigTeam-1793600005.000001" "$rigTeam" 1793600005.000001 magic-coordinator
rigConv "slack-CRIGTRACK1" "CRIGTRACK1" magic-coordinator

## 1. His own message, nobody answering.
rigMsg "slack-bot-D0RIGONLY1" 202611 "$(( rigNow - 7200 )).000100" "$rigOwner" 'RIG-OWED-ONE unanswered in his own conversation'
## 2. Answered after it, in the same conversation.
rigMsg "slack-bot-D0RIGANSW1" 202611 "$(( rigNow - 7100 )).000100" "$rigOwner" 'RIG-OWED-TWO answered later'
rigMsg "slack-bot-D0RIGANSW1" 202611 "$(( rigNow - 7000 )).000100" "$rigOther" 'RIG-ANSWER-TWO'
## 3. A reply before it only: in the conversation, and a thread of it carrying his message.
rigMsg "slack-bot-D0RIGBEFR1" 202611 "$(( rigNow - 8100 )).000100" "$rigOther" 'RIG-EARLIER-THREE'
rigMsg "slack-bot-D0RIGBEFR1-1793600004.000001" 202611 "$(( rigNow - 8000 )).000100" "$rigOwner" '[reactions: eyes x1 ('"$rigOther"')] RIG-OWED-THREE answered only before it'
## 4. Another account alone, in a conversation of its own.
rigMsg "slack-bot-D0RIGALON1" 202611 "$(( rigNow - 6900 )).000100" "$rigOther" 'RIG-OTHER-ALONE'
## 5. The team channel's own message, answered, and a thread of it carrying his unanswered one.
rigMsg "slack-$rigTeam" 202611 "$(( rigNow - 6800 )).000100" "$rigOwner" 'RIG-OWED-FIVE answered in the channel'
rigMsg "slack-$rigTeam" 202611 "$(( rigNow - 6700 )).000100" "$rigOther" 'RIG-ANSWER-FIVE'
rigMsg "slack-$rigTeam-1793600005.000001" 202611 "$(( rigNow - 6600 )).000100" "$rigOwner" 'RIG-OWED-THREADED unanswered in its thread'
## 5b. His channel message whose own thread folder answers it, and the same shape with no answer: the store keeps a reply in
## the thread's own folder, never in the channel's file, so this is the shape every answered message of his takes.
rigMsg "slack-$rigTeam" 202611 "$(( rigNow - 6500 )).000100" "$rigOwner" 'RIG-OWED-FIVE-THREADED answered in its own thread'
rigThread "slack-$rigTeam-$(( rigNow - 6500 )).000100" "$rigTeam" "$(( rigNow - 6500 )).000100" magic-coordinator
rigMsg "slack-$rigTeam-$(( rigNow - 6500 )).000100" 202611 "$(( rigNow - 6400 )).000100" "$rigOther" 'RIG-ANSWER-FIVE-THREADED'
rigMsg "slack-$rigTeam" 202611 "$(( rigNow - 6300 )).000100" "$rigOwner" 'RIG-OWED-FIVE-LONELY its thread answers nothing'
rigThread "slack-$rigTeam-$(( rigNow - 6300 )).000100" "$rigTeam" "$(( rigNow - 6300 )).000100" magic-coordinator
## 7. A folder whose own name and whose pulling line name different conversations: the pulling line is the fact, and a
## conversation is read from its own `.state.txt`, as the cache-to-inbox transfer reads it.
rigConv "slack-bot-D0RIGNAME9" "D0RIGREAL9" magic-coordinator
rigMsg "slack-bot-D0RIGNAME9" 202611 "$(( rigNow - 6200 )).000100" "$rigOwner" 'RIG-OWED-NAMEMISMATCH names its pulling line'
## 8. Answered only by the local copy of our reply, in a thread folder no pull made, written by the store's own post writer; the
## control, the same copy in a folder the writer was given no thread for.
rigConv "slack-bot-D0RIGLOCL1" "D0RIGLOCL1" magic-coordinator
rigLocalAt="$(( rigNow - 6100 )).000100" rigBareAt="$(( rigNow - 6050 )).000100"
rigMsg "slack-bot-D0RIGLOCL1" 202611 "$rigLocalAt" "$rigOwner" 'RIG-OWED-LOCAL answered by a local copy alone'
rigMsg "slack-bot-D0RIGLOCL1" 202611 "$rigBareAt" "$rigOwner" 'RIG-OWED-BARE answered in a folder with no line'
( MMDAPP="$rigWs" ; . "$rigPkg/sh-lib/comms/AgentsTools.CommsCache.include" \
	&& AgentsToolsCommsCachePostStore "$rigStore/slack-bot-D0RIGLOCL1-$rigLocalAt" magic-coordinator 'RIG-LOCAL-REPLY' "D0RIGLOCL1:$rigLocalAt" true \
	&& AgentsToolsCommsCachePostStore "$rigStore/slack-bot-D0RIGLOCL1-$rigBareAt" magic-coordinator 'RIG-LOCAL-BARE' ) > /dev/null 2>&1 || rigRefuse "the store's post writer could not write the local copies"
## 0. A channel that is neither the team channel nor a direct one.
rigMsg "slack-CRIGTRACK1" 202611 "$(( rigNow - 6500 )).000100" "$rigOwner" 'RIG-OWED-OUTSIDE another channel'

## The scan, by the dispatcher of the origin under test, exactly as the supervisor runs it.
rigScan(){
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="${rigScanPath:-/usr/bin:/bin:/usr/sbin:/sbin}" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigFn" --supervise-scan --workspace "$rigWs" 2>&1
}
rigOwed(){ ## the text -- every owner-owed line, one a line
	printf '%s\n' "$rigOut" | LC_ALL=C awk '$1 == "owner-owed"' | LC_ALL=C grep -F -- "$1" || :
}
rigOut="$( rigScan )"

echo "-- 0. the control: the store is the check's own, and another channel is not read --"
rigAssert "control: the rig's cache holds message files the reading can open" \
	"$( LC_ALL=C cat "$rigStore"/*/[0-9][0-9][0-9][0-9][0-9][0-9]/messages.txt 2> /dev/null | LC_ALL=C grep -c -- '^[0-9]' | LC_ALL=C awk '$1 > 0 { print "held" }' )" held
rigAssert "control the other way: the same reading prints nothing where no message of his stands" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C awk '$1 == "owner-owed" && $3 ~ /D0RIGEMPT1/ { print "line" }' )" ""
rigAssert "a channel that is neither the team channel nor a direct one yields no line" "$( rigOwed RIG-OWED-OUTSIDE )" ""

echo "-- 1. his unanswered message in his own conversation --"
rigAssert "the scan read the rig rather than a missing store" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -E '^error ' )" 0
rigAssert "its line names the conversation, its own ts and its age, then his own words with the store's tags stripped" \
	"$( rigOwed RIG-OWED-ONE )" \
	"$( printf 'owner-owed %s D0RIGONLY1:%s.000100 age=120m RIG-OWED-ONE unanswered in his own conversation\n' "${rigWs##*/}" "$(( rigNow - 7200 ))" )"

echo "-- 2. a reply after it removes the line --"
rigAssert "no line for the message another account answered" "$( rigOwed RIG-OWED-TWO )" ""

echo "-- 3. a reply before it does not --"
rigAssert "the line stands, and names his own message by its conversation and ts" "$( rigOwed RIG-OWED-THREE | LC_ALL=C awk '{ print $3 }' )" \
	"D0RIGBEFR1:$(( rigNow - 8000 )).000100"

echo "-- 4. a message of another account alone --"
rigAssert "no line for it" "$( rigOwed RIG-OTHER-ALONE )" ""

echo "-- 5. the team channel and its threads --"
rigAssert "the channel's answered message yields no line" "$( rigOwed 'RIG-OWED-FIVE answered' )" ""
rigAssert "his channel message its own thread folder answers yields no line" "$( rigOwed RIG-OWED-FIVE-THREADED )" ""
rigAssert "his channel message whose thread answers nothing still yields its line" \
	"$( rigOwed RIG-OWED-FIVE-LONELY | LC_ALL=C awk '{ print $3 }' )" "$rigTeam:$(( rigNow - 6300 )).000100"
rigAssert "the folder whose name and pulling line differ is read from the pulling line" \
	"$( rigOwed RIG-OWED-NAMEMISMATCH | LC_ALL=C awk '{ print $3 }' )" "D0RIGREAL9:$(( rigNow - 6200 )).000100"
rigAssert "its thread's unanswered message yields its own line" "$( rigOwed RIG-OWED-THREADED | LC_ALL=C awk '{ print $3 }' )" \
	"$rigTeam:$(( rigNow - 6600 )).000100"

echo "-- 8. a local copy of our reply, in a thread folder no pull made --"
rigAssert "his message answered only by our local copy in its thread yields no line" "$( rigOwed RIG-OWED-LOCAL )" ""
rigAssert "control: the same copy in a folder that names no thread leaves him owed" "$( rigOwed RIG-OWED-BARE | LC_ALL=C awk '{ print $3 }' )" "D0RIGLOCL1:$rigBareAt"

echo "-- 6. the kind is the scanner's own, and no service is reached --"
rigAssert "the scan's header lists the kind" \
	"$( LC_ALL=C grep -c -- 'owner-owed' "$rigPkg/sh-lib/supervise/AgentsTools.SuperviseScan.include" )" 1
rigAssert "the scan made no service call: no Slack request in its output" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -E 'slack-workspace|X-Request-Detail|auth.test' )" 0
[ -f "$rigInclude" ] && rigAssert "the reading is a file of its own beside the scan" yes yes || rigRefuse "the reading's include is not at the origin: $rigInclude"

printf 'SUPERVISE_OWNER_OWED: %s (%d assertions)\n' "$( [ "$rigFail" = 0 ] && echo OK || echo FAIL )" "$(( rigPass + rigFail ))"
[ "$rigFail" = 0 ] || exit 1
