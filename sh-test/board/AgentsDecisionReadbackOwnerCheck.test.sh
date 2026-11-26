#!/usr/bin/env bash
## Behavioural check on the record route of a decision (--record-decision): his own message, named in the source
## as `<channel>:<ts>` as every post and log writes it, is his decision and is recorded at once, asking him
## nothing; a `--with` line is recorded at once too, and its provenance is that party and the time; a text over
## the 300 bytes of a decision line is refused, never cut; and a text that tells a decision by the human-owner is
## refused where no source stands behind it.
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
rigAssert "a message of another person: a --with line, recorded at once with its provenance" \
	"$rigRc:$( rigSection "$rigBoard/running/$rigItem3.md" | LC_ALL=C grep -c -E 'clarification: The rig keeps the blue wire\. \(DRIGDM01:1700000200\.000100, with human-owner at [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}Z\)$' ):$( rigRecords ):$( rigPosts )" "0:1:0:0"

echo "-- a text over the line's 300 bytes is refused, and one within it is quoted whole --"
rigItem4="task-20261125T1203Z-rig-long-text"
rigNewItem "$rigItem4" "The rig keeps a long text"
rigLong="$( LC_ALL=C awk 'BEGIN { for ( i = 1 ; i <= 40 ; i++ ) printf "word%02d goes here. ", i ; }' )"
rigBefore="$( rigRecords )"
rigOp long1 --record-decision --team-member "$rigMember" "$rigItem4" --kind clarification --text "$rigLong" --with human-owner
rigAssert "the long text: refused, naming the cap, with nothing recorded" \
	"$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( LC_ALL=C grep -c 'a decision line holds 300' "$rigTmp/long1.err" ):$( rigRecords ):$( rigPosts )" "refused:1:$rigBefore:0"
rigShort="$( LC_ALL=C awk 'BEGIN { for ( i = 1 ; i <= 14 ; i++ ) printf "word%02d goes here. ", i ; }' )"
rigShort="${rigShort% }"
rigOp long2 --record-decision --team-member "$rigMember" "$rigItem4" --kind clarification --text "$rigShort" --with human-owner
rigAssert "the text within the cap lands whole, with no cut mark" \
	"$rigRc:$( rigSection "$rigBoard/running/$rigItem4.md" | LC_ALL=C grep -c -F -- "clarification: $rigShort (with human-owner at" ):$( rigSection "$rigBoard/running/$rigItem4.md" | LC_ALL=C grep -c -F -- '...' )" "0:1:0"

echo "-- a --with line with no source: recorded, its provenance the party and the time --"
rigItem5="task-20261125T1204Z-rig-account"
rigNewItem "$rigItem5" "The rig records by party"
rigOp acc1 --record-decision --team-member "$rigMember" "$rigItem5" --kind clarification --text "The rig names the party." --with URIGOWNER
rigAssert "recorded at once, and nothing asked of anyone" \
	"$rigRc:$( rigSection "$rigBoard/running/$rigItem5.md" | LC_ALL=C grep -c -E 'clarification: The rig names the party\. \(with URIGOWNER at [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}Z\)$' ):$( rigRecords ):$( rigPosts )" "0:1:0:0"

echo "-- two --with lines on one item are two lines, and neither asks anything --"
rigItem6="task-20261125T1205Z-rig-corrections"
rigNewItem "$rigItem6" "The rig keeps the corrections apart"
rigOp cor1 --record-decision --team-member "$rigMember" "$rigItem6" --kind clarification --text "The rig keeps the green wire." --with human-owner
rigOp cor2 --record-decision --team-member "$rigMember" "$rigItem6" --kind clarification --text "The rig keeps the green wire at the top." --with human-owner
rigAssert "two lines land, and no readback is opened for either" \
	"$rigRc:$( rigSection "$rigBoard/running/$rigItem6.md" | wc -l | tr -d ' ' ):$( rigRecords ):$( rigPosts )" "0:2:0:0"

echo "-- a text that tells his decision still needs the source it came from --"
rigItem7="task-20261125T1206Z-rig-owner-ruling"
rigNewItem "$rigItem7" "The rig keeps his ruling"
rigOp own7 --record-decision --team-member "$rigMember" "$rigItem7" --kind resolved --text "His ruling stands: the rig keeps the red wire." --with human-owner
rigAssert "a ruling with no source behind it: refused, with nothing recorded" \
	"$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigSection "$rigBoard/running/$rigItem7.md" | wc -l | tr -d ' ' ):$( rigRecords ):$( rigPosts )" "refused:0:0:0"

echo
printf 'DECISION_READBACK_OWNER: %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || { echo "⛔ DECISION READBACK OWNER CHECK FAILED" >&2 ; exit 1 ; }
