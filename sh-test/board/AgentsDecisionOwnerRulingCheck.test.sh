#!/usr/bin/env bash
## Behavioural check on the decision writer's owner-ruling guard (board task 2026-11-17T2332Z): a
## line that tells a decision by the human-owner lands only with the message or the ask's verdict
## it came from, or from a readback he confirmed. Each refusal is paired with the case that must
## land, so a guard that refuses everything, and one that refuses nothing, both fail this check.
## Offline: the board is this rig's own temp store, written through the owner fixtures.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsQuestions.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the questions tool is not at the origin this workspace resolves: $rigTool"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
. "${MDLT_ORIGIN}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDecisionOwnerRulingCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigTask="task-20261008T1200Z-rig-ruling"
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/ws/.local/questions" "$rigTmp/skills"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"

. "${MDLT_ORIGIN}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigTmp/ws" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigTmp/skills"
rigOwnerBoardReady
printf -- '---\ntype: task\nowner: magic-developer\n---\n\nrig item for the ruling guard\n' | rigOwnerBoardPut running "$rigTask.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigOp(){ ## output name, arguments... -- one call of the questions tool in this rig
	local opOut="$1" ; shift
	rigRc=0
	( cd "$rigTmp/ws" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigData" \
		bash "$rigTool" "$@" ) > "$rigTmp/$opOut" 2> "$rigTmp/$opOut.err" || rigRc=$?
}
rigSection(){ ## item file -> its Decisions lines, in file order
	LC_ALL=C awk '/^## Decisions[ \t]*$/ { on = 1 ; next ; } on && /^##? / { on = 0 ; } on && /^- / { print ; }' "$1"
}
## A closed readback, as the questions store keeps one: the one a decision was made with answered it.
rigConfirmed(){ ## pending id, item, understood text, who answered
	mkdir -p "$rigTmp/ws/.local/questions"
	printf -- '---\nstatus: reply-received\nowner: magic-developer\nkind: readback\naddress-to: human-owner\nitem: %s\nverdict: yes\nanswered-by: %s\nresolved-at: 2026-10-08 12:30 +0300\n---\n\n# Question asked\n\n# 🔁 Readback\n\nConfirm my reading.\n\n**📥 What I understood**\n%s\n\n**📎 Where it came from**\nthe rig\n' \
		"$2" "${4:-URIGOWNER}" "$3" > "$rigTmp/ws/.local/questions/$1.md"
}

echo "-- a ruling the human-owner never gave is refused --"
rigConfirmed rb-member "$rigTask" "His ruling is that the rig stands." magic-coordinator
rigOp r1 --record-decision --team-member magic-developer "$rigTask.md" --kind clarification --text "His ruling is that the rig stands." --readback rb-member
rigAssert "the line is refused"                       "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken )" refused
rigAssert "and the refusal says what backs a ruling"  "$( LC_ALL=C grep -c 'human-owner' "$rigTmp/r1.err" )" 1
rigAssert "nothing was written"                       "$( rigSection "$rigData/board/running/$rigTask.md" | wc -l | tr -d ' ' )" 0

echo "-- the same text lands with the message it came from named --"
rigConfirmed rb-sourced "$rigTask" "His ruling is that the rig stands." magic-coordinator
rigOp r2 --record-decision --team-member magic-developer "$rigTask" --kind clarification --text "His ruling is that the rig stands." \
	--source "slack:URIGOWNER:1794000000.000100" --readback rb-sourced
rigAssert "the line lands"                            "$( [ "$rigRc" -eq 0 ] && echo landed || echo refused )" landed
rigAssert "with his message in its source"            "$( rigSection "$rigData/board/running/$rigTask.md" | LC_ALL=C grep -c 'slack:URIGOWNER:1794000000.000100' )" 1

echo "-- a readback he confirmed lands his ruling with no further source --"
rigConfirmed rb-his-own "$rigTask" "His verdict was to keep the rig clause."
rigOp r3 --record-decision --team-member magic-developer "$rigTask" --kind resolved --text "His verdict was to keep the rig clause." --readback rb-his-own
rigAssert "the line lands"                            "$( [ "$rigRc" -eq 0 ] && echo landed || echo refused )" landed
rigAssert "with the readback in its source"           "$( rigSection "$rigData/board/running/$rigTask.md" | LC_ALL=C grep -c 'readback rb-his-own' )" 1

## The ask he ANSWERED is his decision too: the help promises "the message or the ask's verdict it
## came from", and the verdict half was the loop he named as a bug -- a settlement he had already
## given was read back to him again (task 2026-11-25T2218Z).
rigVerdict(){ ## pending id, item, question, who answered, the verdict
	printf -- '---\nstatus: reply-received\nowner: magic-developer\nkind: question\naddress-to: human-owner\nitem: %s\nverdict: %s\nanswered-by: %s\nresolved-at: 2026-10-08 12:40 +0300\n---\n\n# Question asked\n\n%s\n' \
		"$2" "${5:-yes}" "${4:-URIGOWNER}" "$3" > "$rigTmp/ws/.local/questions/$1.md"
}
echo "-- the ask's verdict he answered lands the line, and asks him nothing --"
rigVerdict q-his-verdict "$rigTask" "Is the rig clause kept?" URIGOWNER yes
rigPendingBefore="$( ls "$rigTmp/ws/.local/questions" | wc -l | tr -d ' ' )"
rigOp r5 --record-decision --team-member magic-developer "$rigTask" --kind resolved --text "The rig clause is kept, as he answered." --source q-his-verdict
rigAssert "the line lands from his verdict"           "$( [ "$rigRc" -eq 0 ] && echo landed || echo refused )" landed
rigAssert "with his verdict in its source"            "$( rigSection "$rigData/board/running/$rigTask.md" | LC_ALL=C grep -c 'his verdict q-his-verdict' )" 1
rigAssert "and nothing new was posted at him"         "$( ls "$rigTmp/ws/.local/questions" | wc -l | tr -d ' ' )" "$rigPendingBefore"
echo "-- control: an ask another member answered is no verdict of his --"
rigVerdict q-not-his "$rigTask" "Is the rig clause kept?" magic-coordinator yes
rigOp r6 --record-decision --team-member magic-developer "$rigTask" --kind resolved --text "The rig clause is dropped, he says." --source q-not-his
rigAssert "it is refused, with no readback named"     "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken )" refused
rigAssert "and nothing was recorded"                  "$( rigSection "$rigData/board/running/$rigTask.md" | LC_ALL=C grep -c 'The rig clause is dropped' )" 0

echo "-- text that tells no person's decision is untouched --"
rigConfirmed rb-plain "$rigTask" "The rig scope is the decisions helper only."
rigOp r4 --record-decision --team-member magic-developer "$rigTask" --kind clarification --text "The rig scope is the decisions helper only." --readback rb-plain
rigAssert "a plain clarification lands"               "$( [ "$rigRc" -eq 0 ] && echo landed || echo refused )" landed

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DECISION OWNER RULING CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "✅ DECISION OWNER RULING CHECK PASSED: $rigPassCount assertion(s)"
