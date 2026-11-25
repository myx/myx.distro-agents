#!/usr/bin/env bash
## Behavioural check on where a Wait notes the replies a member owes (sh-lib/wait/AgentsTools.MemberWaitResult.include). It runs the real Wait over a fake Slack and a real inbox. Held:
##   1. A PERSON'S SLACK MESSAGE a stateful Wait hands over is noted in schedule/owed/<member> by its reply address, with the account and the text.
##   2. A LINE OF THE TOOLING (`[tracking:`) in the same return is not noted. The same message returned to another run adds no second line.
##      A run's own next Wait is not used for this. It does not hand an unchanged conversation over again, so it would add no line whatever the noting did.
##   3. AN INBOX ITEM that carries a thread address in its header is noted by that address, with its author from the item body.
##   4. THE WAIT SHOWS THAT ADDRESS under the item's name, as a `# reply-to:` line.
##   5. ONLY WHAT IS NEW is noted. An item already in the baseline of the same hit is not noted again by a later return.
##   6. WITH NO BASELINE only an item younger than three owed periods is noted. An old item of a first Wait is not, and a young one beside it is.
##   7. ONCE PER WAIT: a Wait with a Slack hit and an inbox hit notes each address once, with the Wait's own epoch. A collect notes the same way.
## The kinds run here are slack, inbox and a collect. Replies, chat, dms, mentions, channel and thread take the same arm of the same case and are not run.
## Red before the change: the owed store stays empty, because the noting read renderings that carried no reply address.
## Offline: a Slack-shaped fake curl is first on PATH, every workspace is a folder of the rig's own, and no model CLI is started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigFixtures="$rigTest/check-fixtures"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="rig-member"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
[ -f "$rigHere/member/AgentsTools.OwedReplies.include" ] || rigRefuse "the owed-replies include is missing"
. "$rigFixtures/rig-temp.include.sh" || exit 1
. "$rigFixtures/rig-owner-writes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsOwedRepliesWaitNoteCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/skills/$rigMember"
printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
cp "$rigFixtures/wait-own-post-replies.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
rigWaitPath="$rigTmp/bin:$PATH"

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
rigDir="" rigSession="" rigOut="" rigWs="" rigData="" rigHome="" rigSkills="$rigTmp/skills" rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )"
rigScene(){ ## scenario name
	rigNow="$( date +%s )"
	rigDir="$rigTmp/$1" rigSession="rig-sess-$1" rigWs="$rigDir/ws" rigData="$rigDir/data" rigHome="$rigDir/home"
	rm -rf "$rigDir"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/sessions/$rigSession" "$rigHome"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/$rigMember.agent.env"
	: > "$rigDir/api.log"
	rigInboxReady "$rigData" "$rigMember" || rigRefuse "could not make the inbox ready to be written"
}
rigHistory(){ ## the conversation: one person's message and one line of the tooling
	printf '{"ok":true,"messages":[{"ts":"%s.000001","user":"URIGOTHER","text":"RIG-N-ONE where does the variable go?"},{"ts":"%s.000001","user":"URIGOTHER","text":"[tracking: start] RIG-N-TOOL a line of the tooling"}],"has_more":false}\n' \
		"$(( rigNow - 90 ))" "$(( rigNow - 80 ))" > "$rigDir/history.CRIGXXX01.json"
}
rigWait(){ ## output basename, then the operation's arguments after the member
	local waitName="$1" waitPid waitWatch
	shift
	rigOut="$rigDir/$waitName.out"
	env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_WAIT_POLL_SECONDS -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS \
		"PATH=$rigWaitPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigWs" "MDAT_DATA_ROOT=$rigData" "MDAT_SKILLSET_ROOT=$rigSkills" "MDAT_SESSION_ID=$rigSession" \
		MDAT_WAIT_POLL_SECONDS=1 MDAT_WAIT_SETTLE_SECONDS=1 MDAT_WAIT_REMIND=off \
		"$rigTool" --wait-for-input --team-member "$rigMember" "$@" > "$rigOut" 2> "$rigDir/$waitName.err" &
	waitPid=$!
	( waitLeft=60 ; while [ "$waitLeft" -gt 0 ] ; do kill -0 "$waitPid" 2>/dev/null || exit 0 ; sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
	  printf 'rig: the wait did not return within 60s, and was killed\n' >> "$rigDir/$waitName.err" ; kill -TERM "$waitPid" 2>/dev/null ; sleep 2 ; kill -KILL "$waitPid" 2>/dev/null ) &
	waitWatch=$!
	wait "$waitPid" 2>/dev/null
	kill -TERM "$waitWatch" 2>/dev/null
	wait "$waitWatch" 2>/dev/null || :
}
rigFirst(){ LC_ALL=C awk 'NR == 1 { print ; exit ; }' "$rigOut" ; }
rigOwedFile(){ printf '%s' "$rigWs/.local/agents/schedule/owed/$rigMember" ; }
rigOwedCount(){ if [ -f "$( rigOwedFile )" ] ; then LC_ALL=C wc -l < "$( rigOwedFile )" | LC_ALL=C tr -d ' ' ; else printf 0 ; fi ; }
rigEpochOk(){ ## -- whether the first line of the store carries an epoch between the scene's start and now
	local epochSeen epochNow
	epochSeen="$( head -1 "$( rigOwedFile )" 2> /dev/null | LC_ALL=C cut -f1 )" ; epochNow="$( date +%s )"
	case "$epochSeen" in ''|*[!0123456789]*) printf no ; return 0 ;; esac
	[ "$epochSeen" -ge "$rigNow" ] && [ "$epochSeen" -le "$epochNow" ] && printf yes || printf no
}
rigOwedHas(){ ## fixed text -- how many lines of the owed store hold it
	if [ -f "$( rigOwedFile )" ] ; then LC_ALL=C grep -c -F -- "$1" "$( rigOwedFile )" || : ; else printf 0 ; fi
}
rigItem(){ ## item name, the thread root ts, the message's own ts, the author, the text
	printf -- '---\ntype: note\nfrom: %s\nowner: %s\ncommunication-channel-id: slack:CRIGXXX01:%s\n---\n\n## slack-message CRIGXXX01:%s\nsource: slack\nchannel: CRIGXXX01\nts: %s\nauthor: %s\n\n%s\n' \
		"$rigMember" "$rigMember" "$2" "$3" "$3" "$4" "$5" | rigOwnerInboxPut "$rigMember" "$1"
}

echo "-- 1. a person's Slack message is noted by its reply address --"
rigScene slack
rigHistory
rigWait slack-1 --wait-default --wait-session-id "$rigSession" --wait-source slack:CRIGXXX01 --wait-since-utime "$(( rigNow - 120 ))" --wait-timeout 4
rigAssert "the wait returned the arrivals" "$( rigFirst )" "WAIT-RESULT: RECEIVED"
rigAssert "the line carries the Wait's own epoch" "$( rigEpochOk )" "yes"
rigAssert "the owed store holds the person's message once, by address, account and text" \
	"$( LC_ALL=C grep -c -E "^[0-9]+$( printf '\t' )slack:CRIGXXX01:$(( rigNow - 90 )).000001$( printf '\t' )URIGOTHER$( printf '\t' )RIG-N-ONE where does the variable go\?$" "$( rigOwedFile )" 2> /dev/null || : )" 1

echo "-- 2. a line of the tooling is not noted, and a return to another run adds nothing --"
rigAssert "the line of the tooling is not in the store" "$( rigOwedHas 'RIG-N-TOOL' )" 0
rigAssert "and the store holds one line" "$( rigOwedCount )" 1
mkdir -p "$rigWs/.local/agents/sessions/$rigSession-other" || rigRefuse "could not make the folder of the other run"
rigWait slack-2 --wait-default --wait-session-id "$rigSession-other" --wait-source slack:CRIGXXX01 --wait-since-utime "$(( rigNow - 120 ))" --wait-timeout 4
rigAssert "the same message returned to another run" "$( rigFirst )" "WAIT-RESULT: RECEIVED"
rigAssert "adds no second line" "$( rigOwedCount )" 1

echo "-- 3. an inbox item with a thread address in its header is noted by it --"
rigScene inbox
rigEA="$(( rigNow - 100 ))" rigEB="$(( rigNow - 90 ))" rigEC="$(( rigNow - 60 ))"
rigItem "note-20261101T0101Z-slack-$rigEA.000300.md" "$rigEA.000200" "$rigEA.000300" URIGPERSON1 "RIG-W-A please look at the deploy"
rigItem "note-20261101T0102Z-slack-$rigEB.000400.md" "$rigEB.000400" "$rigEB.000400" URIGPERSON2 "RIG-W-B a top-level question"
rigWait inbox-1 --wait-default --wait-session-id "$rigSession" --wait-source "inbox:$rigMember" --wait-timeout 5 --wait-since-utime 1
rigAssert "the wait returned the items" "$( rigFirst )" "WAIT-RESULT: RECEIVED"
rigAssert "the reply is noted by the thread root, with its author and text" \
	"$( rigOwedHas "$( printf 'slack:CRIGXXX01:%s.000200\tURIGPERSON1\tRIG-W-A please look at the deploy' "$rigEA" )" )" 1
rigAssert "the top-level item is noted by its own ts" \
	"$( rigOwedHas "$( printf 'slack:CRIGXXX01:%s.000400\tURIGPERSON2\tRIG-W-B a top-level question' "$rigEB" )" )" 1

echo "-- 4. the wait shows the address under the item's name --"
rigAssert "the reply's address stands under its name" \
	"$( LC_ALL=C awk -v name="note-20261101T0101Z-slack-$rigEA.000300.md" '$0 == name { getline following ; print following ; exit ; }' "$rigOut" )" "# reply-to: slack:CRIGXXX01:$rigEA.000200"
rigAssert "the top-level item's address stands under its name" \
	"$( LC_ALL=C awk -v name="note-20261101T0102Z-slack-$rigEB.000400.md" '$0 == name { getline following ; print following ; exit ; }' "$rigOut" )" "# reply-to: slack:CRIGXXX01:$rigEB.000400"
rigAssert "and each name stays on a line of its own" "$( LC_ALL=C grep -c -x -e "note-20261101T0101Z-slack-$rigEA.000300.md" -e "note-20261101T0102Z-slack-$rigEB.000400.md" "$rigOut" )" 2

echo "-- 5. only what is new is noted by a later return --"
: > "$( rigOwedFile )"
rigItem "note-20261101T0103Z-slack-$rigEC.000500.md" "$rigEC.000500" "$rigEC.000500" URIGPERSON3 "RIG-W-C the item that arrived last"
rigWait inbox-2 --wait-continue --wait-session-id "$rigSession" --wait-timeout 5
rigAssert "the later return came with the new item" "$( rigFirst )" "WAIT-RESULT: RECEIVED"
rigAssert "the store holds the new item" "$( rigOwedHas "slack:CRIGXXX01:$rigEC.000500" )" 1
rigAssert "and holds neither item of the first return" "$( rigOwedHas "slack:CRIGXXX01:$rigEA.000200" ):$( rigOwedHas "slack:CRIGXXX01:$rigEB.000400" )" "0:0"

echo "-- 6. with no baseline, an old item is not noted and a young one is --"
rigScene oldinbox
rigEOld="$(( rigNow - 90000 ))" rigEYoung="$(( rigNow - 70 ))"
rigItem "note-20261101T0104Z-slack-$rigEOld.000600.md" "$rigEOld.000600" "$rigEOld.000600" URIGPERSON4 "RIG-W-OLD a question from a day ago"
rigItem "note-20261101T0105Z-slack-$rigEYoung.000700.md" "$rigEYoung.000700" "$rigEYoung.000700" URIGPERSON5 "RIG-W-YOUNG a question just now"
rigWait inbox-3 --wait-default --wait-session-id "$rigSession" --wait-source "inbox:$rigMember" --wait-timeout 5 --wait-since-utime 1
rigAssert "the first wait returned the items" "$( rigFirst )" "WAIT-RESULT: RECEIVED"
rigAssert "the young item is noted, and the old one is not" "$( rigOwedHas "slack:CRIGXXX01:$rigEYoung.000700" ):$( rigOwedHas "slack:CRIGXXX01:$rigEOld.000600" )" "1:0"
rigAssert "the old item is still listed, with no address line under it" \
	"$( LC_ALL=C awk -v name="note-20261101T0104Z-slack-$rigEOld.000600.md" '$0 == name { getline following ; print following ; exit ; }' "$rigOut" | LC_ALL=C grep -c '^# reply-to:' || : )" "0"

echo "-- 7. one note for a Wait, from a Slack hit and an inbox hit together --"
rigScene both
rigHistory
rigEBoth="$(( rigNow - 50 ))"
rigItem "note-20261101T0106Z-slack-$rigEBoth.000800.md" "$rigEBoth.000800" "$rigEBoth.000800" URIGPERSON6 "RIG-W-BOTH an inbox question"
rigWait both-1 --wait-default --wait-session-id "$rigSession" --wait-source slack:CRIGXXX01 --wait-source "inbox:$rigMember" --wait-timeout 5 --wait-since-utime "$(( rigNow - 120 ))"
rigAssert "the wait returned both hits" "$( rigFirst )" "WAIT-RESULT: RECEIVED"
rigAssert "each address is in the store once" "$( rigOwedHas "slack:CRIGXXX01:$(( rigNow - 90 )).000001" ):$( rigOwedHas "slack:CRIGXXX01:$rigEBoth.000800" ):$( rigOwedCount )" "1:1:2"
rigAssert "the lines carry the Wait's own epoch" "$( rigEpochOk )" "yes"

echo "-- 8. a collect notes a message the same way --"
rigScene collect
rigHistory
rigWait collect-1 --wait-collect 8 --wait-session-id "$rigSession" --wait-source slack:CRIGXXX01 --wait-since-utime "$(( rigNow - 120 ))"
rigAssert "the collect returned the arrivals" "$( rigFirst )" "WAIT-RESULT: RECEIVED"
rigAssert "the collect noted the person's message once and not the line of the tooling" "$( rigOwedHas "slack:CRIGXXX01:$(( rigNow - 90 )).000001" ):$( rigOwedHas 'RIG-N-TOOL' ):$( rigOwedCount )" "1:0:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ OWED REPLIES WAIT NOTE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'OWED_REPLIES_WAIT_NOTE: OK (%d assertions, offline)\n' "$rigPassCount"
