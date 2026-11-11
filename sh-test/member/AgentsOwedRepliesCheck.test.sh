#!/usr/bin/env bash
## Behavioural check on the replies a member owes (sh-lib/member/AgentsTools.OwedReplies.include). Held:
##   1. A PERSON'S MESSAGE with a reply address, handed over by a Wait, is noted once, by that address; a second note of the same text adds nothing.
##   2. THE TOOLING'S OWN LINES are never owed: a line with [tracking:], [author-run:] or [sender:] is skipped.
##   3. THE BLOCK LISTS WHAT IS OLDER THAN THE BOUND, oldest first, and nothing younger; bound 0 lists all.
##   4. A SEND INTO THE THREAD CLEARS IT; a send into another thread of the channel does not.
##   5. A DM ANSWERED AT ITS TOP clears every entry of that conversation.
## Offline: a temp workspace, no Slack.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/member/AgentsTools.OwedReplies.include" ] || rigRefuse "the owed-replies include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsOwedRepliesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
mkdir -p "$rigTmp/.local/agents" || exit 1
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
export MMDAPP="$rigTmp"
. "$rigPackage/sh-lib/member/AgentsTools.OwedReplies.include" || exit 1
rigFile="$rigTmp/.local/agents/schedule/owed/keeper-rig"
rigArrivals='# in C0RIG0001
1794216240.000100 | UPERSON1 | [reply-to: slack:C0RIG0001:1794216240.000100] Where does the variable go?
1794216300.000100 | U0BOT0001 | [reply-to: slack:C0RIG0001:1794216300.000100] [tracking: start] Session started by the schedule
1794216360.000100 | UPERSON2 | [reply-to: slack:D0RIG0002:1794216360.000100] [author-run: abc] a tooling post with an author run
1794216420.000100 | UPERSON3 | [reply-to: slack:D0RIG0002:1794216420.000100] can you look at the deploy?'
printf '%s\n' "$rigArrivals" | AgentsToolsOwedRepliesNote keeper-rig 1794216500
rigAssert "two persons' messages noted, the tooling's two lines skipped" "$( wc -l < "$rigFile" | tr -d ' ' )" "2"
rigAssert "the note carries the address, the user and the text" "$( LC_ALL=C grep -c $'^1794216500\tslack:C0RIG0001:1794216240.000100\tUPERSON1\tWhere does the variable go?$' "$rigFile" )" "1"
printf '%s\n' "$rigArrivals" | AgentsToolsOwedRepliesNote keeper-rig 1794216600
rigAssert "the same arrivals noted again add nothing" "$( wc -l < "$rigFile" | tr -d ' ' )" "2"
rigAssert "nothing is due 10 minutes on" "$( AgentsToolsOwedRepliesPrint keeper-rig 1794217100 | wc -l | tr -d ' ' )" "0"
rigOut="$( AgentsToolsOwedRepliesPrint keeper-rig 1794218400 )"
rigAssert "31 minutes on both are due, the block heads them" "$( printf '%s\n' "$rigOut" | head -1 | cut -c1-16 )" "OWED REPLIES: 2,"
rigAssert "oldest first, with its age and address" "$( printf '%s\n' "$rigOut" | sed -n 2p | cut -c1-49 )" "- 31m slack:C0RIG0001:1794216240.000100 UPERSON1:"
rigAssert "bound 0 lists at once" "$( MDAT_OWED_REPLY_SECONDS=0 AgentsToolsOwedRepliesPrint keeper-rig 1794216501 | head -1 | cut -c1-14 )" "OWED REPLIES: "
AgentsToolsOwedRepliesClear keeper-rig slack C0RIG0001 1794216999.000000
rigAssert "a send into another thread of the channel clears nothing" "$( wc -l < "$rigFile" | tr -d ' ' )" "2"
AgentsToolsOwedRepliesClear keeper-rig slack C0RIG0001 1794216240.000100
rigAssert "a send into the message's thread clears it" "$( LC_ALL=C grep -c 'C0RIG0001' "$rigFile" )" "0"
AgentsToolsOwedRepliesClear keeper-rig slack D0RIG0002 ""
rigAssert "a DM answered at its top clears the conversation" "$( wc -l < "$rigFile" | tr -d ' ' )" "0"
printf '%s: %s passed, %s failed\n' "${0##*/}" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
