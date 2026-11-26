#!/usr/bin/env bash
## Behavioural check on the readback of a decision asked of the human-owner (--record-decision --with):
## his own message, named in the source as `<channel>:<ts>` as every post and log writes it, is his decision
## and is recorded at once, asking him nothing; a text over the 300 bytes of a decision line is refused, never cut
## inside the quote he is asked to confirm; his own Slack account, named as the party, is the human-owner, so
## the readback is the team bot's and its record says so; and a readback is one per correction: another source on
## the same item is another readback, the same source asked again is the one still open, and an answered readback
## of one correction is no answer to another.
## Offline: a temp workspace and data root under .local/temp, a Slack-shaped fake curl first on PATH, no Slack.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsDecisionReadbackOwnerCheck.XXXXXX" )" || exit 1
## Calls here start the rig's schedule thread, a detached process: it is ended before the tree goes.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends its threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigStore="$rigTmp/ws/.local/agents/pending"
rigBoard="$rigTmp/data/board"
mkdir -p "$rigStore" "$rigTmp/home" "$rigTmp/bin" "$rigTmp/scenario" "$rigTmp/ws/.local/.agents" "$rigTmp/ws/.local/agents"
for rigState in backlog pending running review blocked parked processed archived retained ; do mkdir -p "$rigBoard/$rigState" ; done
cp "${MDLT_ORIGIN}/myx/myx.distro-agents/sh-test/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
RIG_SCENARIO="$rigTmp/scenario"
RIG_CURL_LOG="$rigTmp/scenario/curl.log"
export PATH RIG_SCENARIO RIG_CURL_LOG
: > "$RIG_CURL_LOG"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigTmp/ws/.local/.agents/$rigMember.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRc=0
## One team operation as the member, in the rig's workspace: out and err kept under the output name.
rigOp(){ ## output name, op, arguments...
	local opOut="$1" ; shift
	rigRc=0
	( cd "$rigTmp/ws" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" \
		MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$MDAT_SKILLSET_ROOT" MDAT_DATA_ROOT="$rigTmp/data" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigTool" "$@" ) > "$rigTmp/$opOut" 2> "$rigTmp/$opOut.err" || rigRc=$?
	return 0
}
rigField(){ ## record file, field -- an open record, else its closed one
	[ -f "$1" ] || set -- "${1%/*}/closed/${1##*/}" "$2"
	LC_ALL=C awk -v key="$2" 'NR > 1 && $0 == "---" { exit ; } index($0, key ": ") == 1 { print substr($0, length(key) + 3) ; exit ; }' "$1" 2> /dev/null
}
rigSlot(){ ## record id, slot -- one slot of the post as kept beside the record
	local slotFile="$rigStore/$1.fields"
	[ -f "$slotFile" ] || slotFile="$rigStore/closed/$1.fields"
	LC_ALL=C awk -F'\t' -v key="$2" '$1 == key { print substr( $0, length( key ) + 2 ) ; exit ; }' "$slotFile" 2> /dev/null
}
rigSection(){ ## item file -> its Decisions lines, in file order
	LC_ALL=C awk '/^## Decisions[ \t]*$/ { on = 1 ; next ; } on && /^##? / { on = 0 ; } on && /^- / { print ; }' "$1"
}
rigId(){ ## output name -> the first pending id the call printed
	LC_ALL=C grep -o -E '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$rigTmp/$1" | head -1
}
rigRecords(){ ## how many readback records the store holds, open and closed
	LC_ALL=C ls "$rigStore"/*.md "$rigStore"/closed/*.md 2> /dev/null | wc -l | tr -d ' '
}
rigPosts(){ ## how many posts went out
	LC_ALL=C awk '$0 == "chat.postMessage" { n++ ; } END { print n + 0 ; }' "$RIG_CURL_LOG"
}
rigNewItem(){ ## item name, its plain heading -> its board file
	printf -- '---\ntype: task\nowner: %s\n---\n\n# %s\n' "$rigMember" "$2" > "$rigBoard/running/$1.md"
}
## His own message, as the comms cache holds a conversation: `<ts> | <author> | <text>`.
rigCache="$rigTmp/ws/.local/cache/comms/slack/slack-rig-DRIGDM01/202611"
mkdir -p "$rigCache"
printf '1700000100.000100 | URIGOWNER | The rig keeps the red wire on the left.\n1700000200.000100 | URIGOTHER | The rig keeps the blue wire.\n' > "$rigCache/messages.txt"

echo "-- his own message is his decision: named bare, as every post writes it, it is recorded and he is asked nothing --"
rigItem1="task-20261125T1200Z-rig-own-message"
rigNewItem "$rigItem1" "The rig keeps its own wire"
rigOp own1 --record-decision --team-member "$rigMember" "$rigItem1" --kind clarification --text "The rig keeps the red wire on the left." --source "DRIGDM01:1700000100.000100" --with human-owner
rigAssert "the bare reference records it at once, with his message as its source, and posts nothing" \
	"$rigRc:$( rigSection "$rigBoard/running/$rigItem1.md" | LC_ALL=C grep -c -F 'clarification: The rig keeps the red wire on the left. (his message slack:DRIGDM01:1700000100.000100, by URIGOWNER' ):$( rigRecords ):$( rigPosts )" "0:1:0:0"
rigItem2="task-20261125T1201Z-rig-own-message-prefixed"
rigNewItem "$rigItem2" "The rig keeps its prefixed wire"
rigOp own2 --record-decision --team-member "$rigMember" "$rigItem2" --kind clarification --text "The rig keeps the red wire on the left." --source "slack:DRIGDM01:1700000100.000100" --with human-owner
rigAssert "the control, the prefixed reference, records it the same way" \
	"$rigRc:$( rigSection "$rigBoard/running/$rigItem2.md" | LC_ALL=C grep -c -F '(his message slack:DRIGDM01:1700000100.000100, by URIGOWNER' ):$( rigRecords ):$( rigPosts )" "0:1:0:0"
rigItem3="task-20261125T1202Z-rig-other-message"
rigNewItem "$rigItem3" "The rig keeps another wire"
rigOp own3 --record-decision --team-member "$rigMember" "$rigItem3" --kind clarification --text "The rig keeps the blue wire." --source "DRIGDM01:1700000200.000100" --with human-owner
rigAssert "a message of another person is not his decision: it is read back to him, and nothing is recorded" \
	"$rigRc:$( rigSection "$rigBoard/running/$rigItem3.md" | wc -l | tr -d ' ' ):$( rigRecords )" "0:0:1"

echo "-- a text over the line's 300 bytes is refused, and one within it is quoted whole --"
rigItem4="task-20261125T1203Z-rig-long-text"
rigNewItem "$rigItem4" "The rig keeps a long text"
rigLong="$( LC_ALL=C awk 'BEGIN { for ( i = 1 ; i <= 40 ; i++ ) printf "word%02d goes here. ", i ; }' )"
rigBefore="$( rigRecords )"
rigOp long1 --record-decision --team-member "$rigMember" "$rigItem4" --kind clarification --text "$rigLong" --with human-owner
rigAssert "the long text: refused, naming the cap, with nothing asked and nothing recorded" \
	"$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( LC_ALL=C grep -c 'a decision line holds 300' "$rigTmp/long1.err" ):$( rigRecords ):$( rigPosts )" "refused:1:$rigBefore:1"
rigShort="$( LC_ALL=C awk 'BEGIN { for ( i = 1 ; i <= 14 ; i++ ) printf "word%02d goes here. ", i ; }' )"
rigShort="${rigShort% }"
rigOp long2 --record-decision --team-member "$rigMember" "$rigItem4" --kind clarification --text "$rigShort" --with human-owner
rigIdLong="$( rigId long2 )"
rigAssert "the text within the cap is quoted whole, with no cut mark" \
	"$rigRc:$( rigSlot "$rigIdLong" understood | LC_ALL=C grep -c -F -- "$rigShort" ):$( rigSlot "$rigIdLong" understood | LC_ALL=C grep -c -F -- '...' )" "0:1:0"

echo "-- his own account is the human-owner: the readback is the bot's and the record says so --"
rigItem5="task-20261125T1204Z-rig-account"
rigNewItem "$rigItem5" "The rig asks by account"
rigOp acc1 --record-decision --team-member "$rigMember" "$rigItem5" --kind clarification --text "The rig asks him by his account." --source "ref-account-1" --with URIGOWNER
rigIdAcc="$( rigId acc1 )"
rigAssert "asked by his account: addressed to the human-owner, as the bot, in his conversation" \
	"$( rigField "$rigStore/$rigIdAcc.md" address-to ):$( rigField "$rigStore/$rigIdAcc.md" ask-identity ):$( rigField "$rigStore/$rigIdAcc.md" communication-channel-id )" "human-owner:bot:slack:human-owner"
rigOp acc2 --record-decision --team-member "$rigMember" "$rigItem5" --kind clarification --text "The rig asks him by his account." --source "ref-account-1" --with human-owner
rigAssert "asked again by the word human-owner: it is the one open readback, not a second" \
	"$( rigId acc2 ):$( LC_ALL=C grep -c 'ALREADY-OPEN' "$rigTmp/acc2" )" "$rigIdAcc:1"

echo "-- one readback per correction --"
rigItem6="task-20261125T1205Z-rig-corrections"
rigNewItem "$rigItem6" "The rig keeps the corrections apart"
rigOp cor1 --record-decision --team-member "$rigMember" "$rigItem6" --kind clarification --text "The rig keeps the green wire." --source "ref-correction-a" --with human-owner
rigIdA="$( rigId cor1 )"
rigOp cor2 --record-decision --team-member "$rigMember" "$rigItem6" --kind clarification --text "The rig keeps the green wire at the top." --source "ref-correction-b" --with human-owner
rigIdB="$( rigId cor2 )"
rigAssert "another source on the same item is another readback, and the first stays open" \
	"$( [ -n "$rigIdA" ] && [ -n "$rigIdB" ] && [ "$rigIdA" != "$rigIdB" ] && echo two || echo one ):$( rigField "$rigStore/$rigIdA.md" status ):$( rigField "$rigStore/$rigIdB.md" status )" "two:reply-pending:reply-pending"
rigBeforeCor3="$( rigRecords )"
rigOp cor3 --record-decision --team-member "$rigMember" "$rigItem6" --kind clarification --text "The rig keeps the green wire." --source "ref-correction-a" --with human-owner
rigAssert "the same source asked again is the readback still open" \
	"$( rigId cor3 ):$( LC_ALL=C grep -c 'ALREADY-OPEN' "$rigTmp/cor3" ):$( [ "$( rigRecords )" = "$rigBeforeCor3" ] && echo same || echo grew )" "$rigIdA:1:same"
rigOp cor4 --intern-op-pending-reply-close "$rigIdA" --if-open --status reply-received --verdict yes --answered-by URIGOWNER
rigOp cor5 --record-decision --team-member "$rigMember" "$rigItem6" --kind clarification --text "The rig keeps the green wire at the bottom." --source "ref-correction-c" --with human-owner
rigIdC="$( rigId cor5 )"
rigAssert "the answer to one correction is no answer to another: a new readback is open for it" \
	"$( [ -n "$rigIdC" ] && [ "$rigIdC" != "$rigIdA" ] && [ "$rigIdC" != "$rigIdB" ] && echo new || echo not-new ):$( rigField "$rigStore/$rigIdC.md" status ):$( LC_ALL=C grep -c 'NOT ASKED AGAIN' "$rigTmp/cor5" )" "new:reply-pending:0"

echo
printf 'DECISION_READBACK_OWNER: %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || { echo "⛔ DECISION READBACK OWNER CHECK FAILED" >&2 ; exit 1 ; }
