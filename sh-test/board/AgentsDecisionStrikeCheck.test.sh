#!/usr/bin/env bash
## Behavioural check on striking a recorded decision (board task 2026-11-17T2332Z): a line is
## struck through, never deleted. Who may strike it -- its writer, the item's owner, or
## magic-coordinator above them -- each through the confirmed readback of the reason; a line
## already struck, or one that stands not on the item, is refused; a dismissed line records the
## strike; the mark survives a later body write; and a struck answer no longer stops a re-ask.
## Offline: the board is this rig's own temp store, written through the owner fixtures.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsQuestions.fn.sh"
rigToolsFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the questions tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigToolsFn" ] || rigRefuse "the tools dispatcher is not at the origin this workspace resolves: $rigToolsFn"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
. "${MDLT_ORIGIN}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDecisionStrikeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigTask="task-20261008T1200Z-rig-strike"
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/ws/.local/questions" "$rigTmp/skills" "$rigTmp/home"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"

. "${MDLT_ORIGIN}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigTmp/ws" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigTmp/skills"
rigOwnerBoardReady
printf -- '---\ntype: task\nowner: magic-developer\nreview-by: keeper-myx\n---\n\nrig item for the strike\n' | rigOwnerBoardPut running "$rigTask.md"

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
rigToolsOp(){ ## output name, arguments... -- one call of the tools dispatcher in this rig
	local opOut="$1" ; shift
	rigRc=0
	( cd "$rigTmp/ws" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigData" \
		bash "$rigToolsFn" "$@" ) > "$rigTmp/$opOut" 2> "$rigTmp/$opOut.err" || rigRc=$?
}
rigSection(){ ## item file -> its Decisions lines, in file order
	LC_ALL=C awk '/^## Decisions[ \t]*$/ { on = 1 ; next } on && /^##? / { on = 0 } on && /^- / { print }' "$1"
}
rigLine(){ ## the recorded line holding this text, whole
	rigSection "$rigData/board/running/$rigTask.md" | LC_ALL=C grep -F -- "$1" | head -1
}
## A closed readback, as the questions store keeps one: the one a decision was made with answered it.
rigConfirmed(){ ## pending id, understood text, who answered
	mkdir -p "$rigTmp/ws/.local/questions"
	printf -- '---\nstatus: reply-received\nowner: magic-developer\nkind: readback\naddress-to: human-owner\nitem: %s\nverdict: yes\nanswered-by: %s\nresolved-at: 2026-10-08 12:30 +0300\n---\n\n# Question asked\n\n# 🔁 Readback\n\nConfirm my reading.\n\n**📥 What I understood**\n%s\n\n**📎 Where it came from**\nthe rig\n' \
		"$rigTask" "${3:-URIGOWNER}" "$2" > "$rigTmp/ws/.local/questions/$1.md"
}

echo "-- two lines are recorded, by the reviewer, on an item the rig's own member owns --"
rigConfirmed rb-a "The rig contract clause stays."
rigOp w1 --record-decision --team-member keeper-myx "$rigTask.md" --kind resolved --text "The rig contract clause stays." --readback rb-a
[ "$rigRc" = "0" ] || rigRefuse "the first line was not recorded: $( cat "$rigTmp/w1.err" )"
rigConfirmed rb-b "The rig vendor list is frozen."
rigOp w2 --record-decision --team-member keeper-myx "$rigTask" --kind resolved --text "The rig vendor list is frozen." --readback rb-b
[ "$rigRc" = "0" ] || rigRefuse "the second line was not recorded: $( cat "$rigTmp/w2.err" )"
rigAssert "the item holds two recorded lines"        "$( rigSection "$rigData/board/running/$rigTask.md" | wc -l | tr -d ' ' )" 2

echo "-- a strike takes its reason and its readback, and no --kind --"
rigConfirmed rb-strike "the clause was withdrawn the next day"
rigOp s1 --record-decision --team-member keeper-myx "$rigTask" --strike "$( rigLine 'The rig contract clause stays.' )" --reason "the clause was withdrawn the next day" --readback rb-strike
rigAssert "the writer's strike lands"                 "$( [ "$rigRc" -eq 0 ] && echo struck || echo refused )" struck
rigAssert "the line stays, marked struck"             "$( rigLine 'The rig contract clause stays.' | LC_ALL=C grep -c '\[struck by keeper-myx: the clause was withdrawn the next day\]$' )" 1
rigAssert "nothing was deleted"                       "$( rigSection "$rigData/board/running/$rigTask.md" | wc -l | tr -d ' ' )" 3
rigAssert "a strike records no new line kind"         "$( rigLine 'The rig contract clause stays.' | LC_ALL=C grep -c 'struck: the line struck' )" 0
rigAssert "a dismissed line records the strike"       "$( rigSection "$rigData/board/running/$rigTask.md" | LC_ALL=C grep -c 'dismissed: the line struck: - .*The rig contract clause stays\..* -- the clause was withdrawn the next day' )" 1

echo "-- the same line is struck once --"
rigOp s2 --record-decision --team-member keeper-myx "$rigTask" --strike "$( rigLine 'The rig vendor list is frozen.' )" --reason "second strike" --readback rb-strike
rigAssert "a spent readback strikes nothing"          "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken )" refused
rigConfirmed rb-s2 "the vendor list is not frozen"
rigOp s3 --record-decision --team-member keeper-myx "$rigTask" --strike "$( rigLine 'The rig vendor list is frozen.' )" --reason "the vendor list is not frozen" --readback rb-s2
rigAssert "another line strikes on its own readback"  "$( [ "$rigRc" -eq 0 ] && echo struck || echo refused )" struck
rigConfirmed rb-s3 "struck once already"
rigOp s4 --record-decision --team-member keeper-myx "$rigTask" --strike "$( rigLine 'The rig vendor list is frozen.' | LC_ALL=C sed 's/ \[struck by [^]]*\]$//' )" --reason "struck once already" --readback rb-s3
rigAssert "a line already struck is refused"         "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken )" refused

echo "-- a text that stands on no line is refused --"
rigConfirmed rb-s5 "no such line"
rigOp s5 --record-decision --team-member keeper-myx "$rigTask" --strike "- 2020-01-01T00:00Z keeper-myx resolved: a line that was never recorded" --reason "no such line" --readback rb-s5
rigAssert "an absent line is refused"                 "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken )" refused

echo "-- a staged line's readback is the guard, so it must be confirmed --"
printf -- '---\nstatus: reply-pending\nowner: magic-developer\nkind: readback\nitem: %s\n---\n\nunanswered\n' "$rigTask" > "$rigTmp/ws/.local/questions/rb-open.md"
rigOp s6 --record-decision --team-member magic-developer "$rigTask" --strike "$( rigLine 'The rig vendor list is frozen.' | LC_ALL=C sed 's/ \[struck by [^]]*\]$//' )" --reason "open readback" --readback rb-open
rigAssert "an unanswered readback strikes nothing"    "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken )" refused

echo "-- a strike is confirmed by who confirmed the line, or by the human-owner --"
rigConfirmed rb-c "The rig courier is the night one." URIGOTHER
rigOp w3 --record-decision --team-member keeper-myx "$rigTask" --kind resolved --text "The rig courier is the night one." --readback rb-c
[ "$rigRc" = "0" ] || rigRefuse "the third line was not recorded: $( cat "$rigTmp/w3.err" )"
rigConfirmed rb-s7 "the courier changed" URIGTHIRD
rigOp s7 --record-decision --team-member keeper-myx "$rigTask" --strike "$( rigLine 'The rig courier is the night one.' )" --reason "the courier changed" --readback rb-s7
rigAssert "a third party's confirmation strikes nothing" "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( LC_ALL=C grep -c 'URIGOTHER did' "$rigTmp/s7.err" ):$( rigLine 'The rig courier is the night one.' | LC_ALL=C grep -c 'struck by' )" refused:1:0
rigConfirmed rb-s8 "the courier changed" URIGOTHER
rigOp s8 --record-decision --team-member keeper-myx "$rigTask" --strike "$( rigLine 'The rig courier is the night one.' )" --reason "the courier changed" --readback rb-s8
rigAssert "the line's own confirmer strikes it"         "$( [ "$rigRc" -eq 0 ] && echo struck || echo refused ):$( rigLine 'The rig courier is the night one.' | LC_ALL=C grep -c 'struck by keeper-myx: the courier changed' )" struck:1
echo "-- the strike names its readback, and that readback strikes once --"
rigAssert "the dismissed line names its readback and confirmer" "$( rigSection "$rigData/board/running/$rigTask.md" | LC_ALL=C grep -c 'dismissed: the line struck: .*The rig courier is the night one.* -- the courier changed (readback rb-s8, confirmed by URIGOTHER at 2026-10-08 12:30 +0300)$' )" 1
rigConfirmed rb-d "The rig depot opens at six." URIGOTHER
rigOp w4 --record-decision --team-member keeper-myx "$rigTask" --kind resolved --text "The rig depot opens at six." --readback rb-d
[ "$rigRc" = "0" ] || rigRefuse "the fourth line was not recorded: $( cat "$rigTmp/w4.err" )"
rigOp s9 --record-decision --team-member keeper-myx "$rigTask" --strike "$( rigLine 'The rig depot opens at six.' )" --reason "the courier changed" --readback rb-s8
rigAssert "a strike's readback, spent, strikes no other line" "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigLine 'The rig depot opens at six.' | LC_ALL=C grep -c 'struck by' )" refused:0
echo "-- a contact at tier-admin may confirm a strike --"
mkdir -p "$rigData/contacts/persons"
printf -- '---\ncontact-id: rig-admin\ndisplay-name: Rig Admin\ntier: tier-admin\nslack-id: URIGADMIN\n---\n' > "$rigData/contacts/persons/rig-admin.md"
rigConfirmed rb-g "The rig gate opens at seven." URIGOTHER
rigOp w5 --record-decision --team-member keeper-myx "$rigTask" --kind resolved --text "The rig gate opens at seven." --readback rb-g
[ "$rigRc" = "0" ] || rigRefuse "the gate line was not recorded: $( cat "$rigTmp/w5.err" )"
rigConfirmed rb-s11 "the gate moved" URIGADMIN
rigOp s11 --record-decision --team-member keeper-myx "$rigTask" --strike "$( rigLine 'The rig gate opens at seven.' )" --reason "the gate moved" --readback rb-s11
rigAssert "a tier-admin contact's confirmation strikes it" "$( [ "$rigRc" -eq 0 ] && echo struck || echo refused ):$( rigLine 'The rig gate opens at seven.' | LC_ALL=C grep -c 'struck by keeper-myx: the gate moved' )" struck:1
echo "-- a fake, struck, is to be asked again --"
rigToolsOp f1 --intern-op-decisions-append keeper-myx "$rigTask" --kind resolved --text "The rig fake was never confirmed."
[ "$rigRc" = "0" ] || rigRefuse "the fake line was not written: $( cat "$rigTmp/f1.err" )"
rigConfirmed rb-f "no one confirmed it"
rigOp s10 --record-decision --team-member keeper-myx "$rigTask" --strike "$( rigLine 'The rig fake was never confirmed.' )" --reason "no one confirmed it" --readback rb-f
rigAssert "a struck fake says to ask it again"        "$rigRc:$( LC_ALL=C grep -c '^NEXT: the struck line had no confirmed readback' "$rigTmp/s10" ):$( LC_ALL=C grep -c '^NEXT: ' "$rigTmp/s8" )" 0:1:0
echo "-- a later body write keeps the mark --"
rigToolsOp b1 --intern-op-board-upsert-move-edit running "$rigTask.md" --from-state:running \
	--edit-patch-from-stdin <<'RIGPATCH'
[{"old":"rig item for the strike","new":"rig item for the strike, edited"}]
RIGPATCH
[ "$rigRc" = "0" ] || rigRefuse "the body write failed: $( cat "$rigTmp/b1.err" )"
rigAssert "the mark survives the body write"          "$( rigLine 'The rig contract clause stays.' | LC_ALL=C grep -c '\[struck by keeper-myx: the clause was withdrawn the next day\]$' )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DECISION STRIKE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "✅ DECISION STRIKE CHECK PASSED: $rigPassCount assertion(s)"
