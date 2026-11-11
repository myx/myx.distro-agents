#!/usr/bin/env bash
## Behavioural check on an answered ask reaching its asker on the session floor (sh-lib/questions/AgentsTools.InternOpPendingReply.include,
## AgentsToolsPendingReplyFloorNotice). A run that rewound to its checkpoint since it asked holds neither the question nor the wait on it,
## so the close of an answered ask writes one message on the asking session's printback channel, in its chat file, addressed to the member that asked.
## Held:
##   1. an answered close writes the message: the ask's id and kind, its question, its verdict and who answered
##   2. the member's own floor delivers it, so a floor Wait or an idle wait hears it with no `ask:` source
##   3. a withdrawn close writes nothing: its asker took it back itself
##   4. a session with no folder here gets nothing, and no folder is made for it
## Red recipe: take the call to AgentsToolsPendingReplyFloorNotice out of the close, and rows 1 and 2 fail.
## Offline: a rig workspace under this check's temp tree; every close is --quiet, so no reaction reaches Slack.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTool" ] || rigRefuse "the team tooling is not in the package: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPendingReplyFloorNoticeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSession="rig-ask-session" rigMember="keeper-rig"
mkdir -p "$rigWs/.local/agents/pending/closed" "$rigWs/.local/agents/sessions/$rigSession" "$rigTmp/home"
rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## An open ask of the member, in the session named.
rigAsk(){ ## id, session, kind
	printf -- '---\nstatus: reply-pending\nowner: %s\nsession-id: %s\nkind: %s\naddress-to: human-owner\nasked-at: 2026-11-11 02:00 +0200\n---\n\n# Question asked\n\n# 🔐 Rig heading\n\nMay the rig member restart its duty tonight?\n\n**More** below\n' \
		"$rigMember" "$2" "$3" > "$rigWs/.local/agents/pending/$1.md"
}
rigClose(){ ## id, then the close's own options
	local closeId="$1" ; shift
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --intern-op-pending-reply-close "$closeId" --quiet "$@" --context rig > /dev/null 2> "$rigTmp/close.err" < /dev/null
}
rigChat(){ cat "$rigWs/.local/agents/sessions/$rigSession/session.chat" 2> /dev/null ; }
rigChatRun(){ ## code -- in a clean shell with the chat include, as the member's run
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SESSION_ID="$rigSession" \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include" ; '"$1" 2> /dev/null
}
rigHas(){ rigChat | LC_ALL=C grep -c -F -- "$1" ; }

echo "-- 1. an answered close writes the message --"
## The member has read its floor before it asked, as a live run has: its pointer stands at the file's end.
rigChatRun "AgentsToolsSessionChatReaderInit $rigSession $rigMember" > /dev/null
rigAsk rig-ask-yes "$rigSession" decision
rigClose rig-ask-yes --status reply-received --verdict restart --answered-by U0RIGOWNER
rigAssert "the close itself succeeds"                          "$?:$( [ -f "$rigWs/.local/agents/pending/rig-ask-yes.md" ] || [ -f "$rigWs/.local/agents/pending/closed/rig-ask-yes.md" ] && echo kept )" "0:kept"
rigAssert "the ask's id and kind, its question, its verdict and who answered" \
	"$( rigHas 'ASK-ANSWERED rig-ask-yes (decision)' ):$( rigHas 'QUESTION: May the rig member restart its duty tonight?' ):$( rigHas 'VERDICT: restart' ):$( rigHas 'ANSWERED-BY: U0RIGOWNER' )" "1:1:1:1"

echo "-- 2. the member's own floor delivers it --"
rigFloor="$( rigChatRun "AgentsToolsSessionChatFloor $rigSession $rigMember ''" )"
rigAssert "a floor read of the member returns the answer and its question" \
	"$( printf '%s\n' "$rigFloor" | LC_ALL=C grep -c -e 'ASK-ANSWERED rig-ask-yes' -e 'VERDICT: restart' )" "2"

echo "-- 3. a withdrawn close writes nothing --"
rigBefore="$( rigHas 'ASK-ANSWERED' )"
rigAsk rig-ask-back "$rigSession" question
rigClose rig-ask-back --status withdrawn --withdrawn-by "$rigMember" --withdraw-reason "the rig takes it back"
rigAssert "no message for a question its asker took back"      "$( rigHas 'ASK-ANSWERED' ):$( rigHas 'rig-ask-back' )" "$rigBefore:0"

echo "-- 4. a session with no folder here --"
rigAsk rig-ask-far rig-session-elsewhere question
rigClose rig-ask-far --status reply-received --verdict yes
rigAssert "nothing is written, and no folder is made for it"   "$( [ -e "$rigWs/.local/agents/sessions/rig-session-elsewhere" ] && echo made || echo none )" "none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PENDING REPLY FLOOR NOTICE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PENDING_REPLY_FLOOR_NOTICE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
