#!/usr/bin/env bash
## Behavioural check on a board item's `## Decisions` (AgentsTools.ItemDecisions.include):
## --record-decision creates the section, then appends inside it ahead of a later
## heading; an ask records its item from task_ref, else from the session's `spawns:`; a
## closed ask writes its answer to that item and clears the blocker naming it, and leaves
## an unrelated blocker; an earlier answer is found by the same session's closed record or
## by the item's Decisions, and AskQuestion then posts nothing; a collect closes a
## question its Decisions answer; the spawn's conversation.md and a named-item scan show
## the Decisions first; a decision asked of a member party or a contact party is landed by
## that party's own yes, and a contact's project tier decides it there and nowhere else.
## Offline: a temp workspace and data root under .local/temp, no Slack.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsItemDecisionsCheck.XXXXXX" )" || exit 1
## Calls here start the rig's schedule thread, a detached process: it is ended before the tree goes.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends its threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigStore="$rigTmp/ws/.local/agents/pending"
rigBoard="$rigTmp/data/board"
mkdir -p "$rigStore" "$rigTmp/home" "$rigTmp/skills" "$rigTmp/bin" "$rigTmp/tmp" "$rigTmp/scenario" "$rigTmp/ws/.local/.agents" \
	"$rigTmp/ws/.local/agents/spawned/rig-spawn-1" "$rigTmp/ws/.local/agents/spawned/rig-spawn-1/input"
for rigState in backlog pending running review blocked parked processed archived retained ; do mkdir -p "$rigBoard/$rigState" ; done
## Nothing here should reach Slack; the Slack-shaped fake curl is first on PATH in case anything tries.
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
## The persona row an external send reads, and the member registry its client member is found in.
printf 'client-rig\t:robot_face:\tRig\tAdmin\tRig_Admin\n' > "$rigTmp/ws/.local/agents/team-members-names.registry"
printf '%s\t%s\tsource\trig\t%s\n' "$rigTmp/ws" client-rig "$rigTmp/skills/client-rig" > "$rigTmp/ws/.local/agents/members.registry"

rigTask="task-20261008T1200Z-rig-decisions"
rigDispatch="dispatch-20261008T1201Z-spawn-proxy-1"
printf -- '---\ntype: task\nowner: magic-tester\ncondition: has the human-owner answered pending reply PENDING-ID?\nblocked-on: the vendor contract\n---\n\n# Rig task\n\nBody text.\n\n## Notes\n\nA later section.\n' > "$rigBoard/blocked/$rigTask.md"
printf -- '---\ntype: dispatch\nowner: magic-tester\n---\n\n# Rig dispatch\n' > "$rigBoard/running/$rigDispatch.md"
printf -- '---\nsession-id: rig-spawn-1\nowner: magic-tester\nstatus: spawn-succeeded\nspawns: %s\n---\n' "$rigDispatch" > "$rigTmp/ws/.local/agents/spawned/rig-spawn-1/rig-spawn-1.spawn.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, fixed string
	[ -f "$1" ] || set -- "${1%/*}/closed/${1##*/}" "$2"
	LC_ALL=C grep -q -F -- "$2" "$1" 2>/dev/null && printf yes || printf no
}
## The rig is a team rig: a workspace in the default mode, just-agents, keeps no team data, and the board edit a decision is is refused there.
rigOp(){ ## output name, op, arguments... (stdin passes through); RIG_AGENT, when set, is the spawned session's member
	local opOut="$1" ; shift
	rigRc=0
	( cd "$rigTmp/ws" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" ${RIG_AGENT:+MDAT_SPAWN_AGENT="$RIG_AGENT"} \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" \
		bash "$rigTool" "$@" ) > "$rigTmp/$opOut" 2> "$rigTmp/$opOut.err" || rigRc=$?
}
rigField(){ ## file, field
	[ -f "$1" ] || set -- "${1%/*}/closed/${1##*/}" "$2"
	LC_ALL=C awk -v key="$2" 'NR > 1 && $0 == "---" { exit ; } index($0, key ": ") == 1 { print substr($0, length(key) + 3) ; exit ; }' "$1"
}
rigSection(){ ## item file -> its Decisions lines, in file order
	LC_ALL=C awk '/^## Decisions[ \t]*$/ { on = 1 ; next ; } on && /^##? / { on = 0 ; } on && /^- / { print ; }' "$1"
}
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.ItemDecisions.include"
## A closed readback, as the questions store keeps one: the one a decision was made with answered it.
rigConfirmed(){ ## pending id, item, understood text, verdict (default yes), the correction's words
	mkdir -p "$rigTmp/ws/.local/questions"
	printf -- '---\nstatus: reply-received\nowner: magic-tester\nkind: readback\naddress-to: human-owner\nitem: %s\nverdict: %s\nverdict-text: %s\nanswered-by: URIGOWNER\nresolved-at: 2026-10-08 12:30 +0300\n---\n\n# Question asked\n\n# 🔁 Readback\n\nConfirm my reading.\n\n**📥 What I understood**\n%s\n\n**📎 Where it came from**\nthe rig\n' \
		"$2" "${4:-yes}" "${5:-}" "$3" > "$rigTmp/ws/.local/questions/$1.md"
}

echo "-- helper: create, then append --"
## The acting member is the operation's own argument, `--team-member`: a member is named by the
## family's one rule (Help.DistroAgentsQuestions.help.md: `--record-decision [--team-member
## <team-member>] <item-filename>`), and a bare name before the item is refused as an option.
rigConfirmed rb-rec1 "$rigTask" "The rig scope is the decisions helper only."
rigOp rec1 --record-decision --team-member "$rigMember" "$rigTask.md" --kind clarification --text "The rig scope is the decisions helper only." --source 1700000009.000001 --readback rb-rec1
[ "$rigRc" = "0" ] || rigRefuse "the decision op failed: $( cat "$rigTmp/rec1.err" )"
rigAssert "it says recorded"                      "$( head -1 "$rigTmp/rec1" )" "DECISION-RECORDED $rigTask blocked"
rigAssert "the section is created"                "$( rigHolds "$rigBoard/blocked/$rigTask.md" '## Decisions' )" yes
rigAssert "with the line in its shape"            "$( rigSection "$rigBoard/blocked/$rigTask.md" | LC_ALL=C grep -c -E '^- [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}Z magic-tester clarification: The rig scope is the decisions helper only\. \(readback rb-rec1, confirmed by URIGOWNER at 2026-10-08 12:30 \+0300, 1700000009\.000001\)$' )" 1
rigAssert "the blockers are left"                 "$( rigField "$rigBoard/blocked/$rigTask.md" blocked-on )" "the vendor contract"
rigConfirmed rb-rec2 "$rigTask" "Second line."
rigOp rec2 --record-decision --team-member "$rigMember" "$rigTask" --kind resolved --text "Second line." --readback rb-rec2
rigAssert "a second line is appended"             "$( rigSection "$rigBoard/blocked/$rigTask.md" | wc -l | tr -d ' ' )" 2
rigAssert "after the first"                       "$( rigSection "$rigBoard/blocked/$rigTask.md" | tail -1 | LC_ALL=C sed -E 's/.* resolved: //; s/ \(readback .*$//' )" "Second line."
rigAssert "one section only"                      "$( LC_ALL=C grep -c '^## Decisions' "$rigBoard/blocked/$rigTask.md" )" 1
rigAssert "the read shows newest first"           "$( AgentsToolsDecisionsLines "$rigBoard/blocked/$rigTask.md" 30 | head -1 | LC_ALL=C sed -E 's/.* resolved: //; s/ \(readback .*$//' )" "Second line."
rigOp rec3 --record-decision --team-member "$rigMember" "$rigTask" --kind answer --text "not a member kind"
rigAssert "a member may not record an answer"     "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken )" refused
rigOp rec4 --record-decision --team-member "$rigMember" task-20261008T1300Z-missing --kind clarification --text "x"
rigAssert "an item not on the board is refused"   "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken )" refused

echo "-- ask -> item link --"
printf '# ❓ Question Q1\n\nShould the rig keep the vendor contract clause?\n' | rigOp open1 --intern-op-pending-reply-open "$rigMember" --to human-owner \
	--session-id rig-session-a --kind question --address-to human-owner --question-tag Q1 --question-key 111-11 --task-ref "for $rigTask.md, please"
rigId1="$( head -1 "$rigTmp/open1" )"
[ -f "$rigStore/$rigId1.md" ] || rigRefuse "the open op wrote no record: $( cat "$rigTmp/open1.err" )"
rigAssert "task_ref names the item"               "$( rigField "$rigStore/$rigId1.md" item )" "$rigTask"
printf 'Another question for the rig to ask?\n' | rigOp open2 --intern-op-pending-reply-open "$rigMember" --to human-owner --session-id rig-spawn-1 --task-ref "no item named here"
rigId2="$( head -1 "$rigTmp/open2" )"
rigAssert "else the session spawns: item"         "$( rigField "$rigStore/$rigId2.md" item )" "$rigDispatch"
printf 'A third question for the rig?\n' | rigOp open3 --intern-op-pending-reply-open "$rigMember" --to human-owner --session-id rig-session-none
rigId3="$( head -1 "$rigTmp/open3" )"
rigAssert "else none"                             "$( rigField "$rigStore/$rigId3.md" item )" ""

echo "-- answer -> Decisions, and the blocker it resolves cleared --"
LC_ALL=C sed -i.bak "s/PENDING-ID/$rigId1/" "$rigBoard/blocked/$rigTask.md" && rm -f "$rigBoard/blocked/$rigTask.md.bak"
rigOp close1 --intern-op-pending-reply-close "$rigId1" --if-open --status reply-received --verdict "keep it, signed off" --answered-by URIGOWNER
[ "$rigRc" = "0" ] || rigRefuse "the close failed: $( cat "$rigTmp/close1.err" )"
rigAssert "the answer is on the item"             "$( rigSection "$rigBoard/blocked/$rigTask.md" | tail -1 | LC_ALL=C sed -E 's/^- [^ ]+ //' )" "URIGOWNER answer: Q1 Should the rig keep the vendor contract clause? -> keep it, signed off ($rigId1)"
rigAssert "the condition naming the ask is gone"  "$( rigField "$rigBoard/blocked/$rigTask.md" condition )" ""
rigAssert "the unrelated blocked-on stays"        "$( rigField "$rigBoard/blocked/$rigTask.md" blocked-on )" "the vendor contract"
rigOp close3 --intern-op-pending-reply-close "$rigId3" --if-open --status reply-received --verdict "fine"
rigAssert "an ask with no item still closes"      "$( rigField "$rigStore/$rigId3.md" status )" reply-received

echo "-- re-ask: the earlier answer is found --"
printf 'Should the rig keep the vendor contract clause?\n' | rigOp early1 --intern-op-pending-reply-earlier "$rigMember" --session-id rig-session-a --kind question --address-to human-owner
rigAssert "the same session's closed record"      "$( cut -d' ' -f1-2 "$rigTmp/early1" )" "EARLIER-RECORD $rigId1"
printf 'should the rig KEEP the vendor-contract clause\n' | rigOp early2 --intern-op-pending-reply-earlier "$rigMember" --session-id rig-session-other --kind question --task-ref "$rigTask"
rigAssert "another session: the item's Decisions" "$( cut -d' ' -f1-2 "$rigTmp/early2" )" "EARLIER-DECISION $rigTask"
printf 'Should the rig keep the vendor contract clause?\n' | rigOp early3 --intern-op-pending-reply-earlier "$rigMember" --session-id rig-session-other --kind question
rigAssert "no session record, no item: nothing"   "$( cat "$rigTmp/early3" )" ""
printf 'Should the rig keep the vendor contract clause?\n' | rigOp early4 --intern-op-pending-reply-earlier "$rigMember" --session-id rig-session-a --kind permission --refusal-id other
rigAssert "a permission needs the same refusal"   "$( cat "$rigTmp/early4" )" ""

echo "-- AskQuestion posts nothing for an answered question --"
( cd "$rigTmp/ws" && printf '%s' '{"to":"human-owner","address_to":"human-owner","question":"Should the rig keep the vendor contract clause?","wait":false}' \
	| env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" MDAT_SPAWN_SESSION_ID=rig-session-a MMDAPP="$rigTmp/ws" \
		MDAT_SKILLSET_ROOT="${MDAT_SKILLSET_ROOT:-$rigTmp/skills}" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool AskQuestion ) > "$rigTmp/ask1" 2> "$rigTmp/ask1.err"
rigAssert "it reads received"                     "$( head -1 "$rigTmp/ask1" )" "ASK-RESULT: RECEIVED"
rigAssert "it says not asked again"               "$( rigHolds "$rigTmp/ask1" 'NOT ASKED AGAIN' )" yes
rigAssert "with the earlier answer"               "$( rigHolds "$rigTmp/ask1" 'keep it, signed off' )" yes
rigAssert "nothing was posted"                    "$( LC_ALL=C grep -c 'chat.postMessage' "$RIG_CURL_LOG" )" 0
rigAssert "no new record"                         "$( ls "$rigStore"/*.md "$rigStore"/closed/*.md 2> /dev/null | wc -l | tr -d ' ' )" 3

echo "-- collect closes a question its Decisions answer --"
printf '# ❓ Question Q2\n\nShould the rig keep the vendor contract clause?\n' | rigOp open4 --intern-op-pending-reply-open "$rigMember" --to human-owner \
	--session-id rig-session-b --kind question --channel CRIG00001 --question-ts 1700000002.000102 --thread-ts 1700000002.000101 --addressees URIGOWNER --item "$rigTask"
rigId4="$( head -1 "$rigTmp/open4" )"
rigLinesBefore="$( rigSection "$rigBoard/blocked/$rigTask.md" | wc -l | tr -d ' ' )"
rigOp collect1 --intern-op-pending-reply-collect --id "$rigId4"
rigAssert "it is answered"                        "$( cut -d' ' -f1-2 "$rigTmp/collect1" | head -1 )" "ANSWERED $rigId4"
rigAssert "closed from the Decisions"             "$( rigField "$rigStore/$rigId4.md" answered-by )" decisions
rigAssert "with the answer read there"            "$( rigField "$rigStore/$rigId4.md" verdict )" "keep it, signed off (from the Decisions of $rigTask)"
rigAssert "and not written there twice"           "$( rigSection "$rigBoard/blocked/$rigTask.md" | wc -l | tr -d ' ' )" "$rigLinesBefore"

echo "-- shown first: conversation.md and a named-item scan --"
( cd "$rigTmp/ws" && env MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" bash -c '
	DistroAgentsTools(){ return 1 ; }
	MDSC_CMD=rig
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.SpawnSandbox.include"
	AgentsToolsSpawnConversationHistory "$MMDAPP/.local/agents/spawned/rig-spawn-1/input/conversation.md" magic-tester "CRIG00001:1700000002.000101" "$1"
' rig "$rigBoard/blocked/$rigTask.md" ) 2> /dev/null
rigConv="$rigTmp/ws/.local/agents/spawned/rig-spawn-1/input/conversation.md"
rigAssert "conversation.md shows the Decisions"   "$( rigHolds "$rigConv" "### Decisions (from $rigTask)" )" yes
rigAssert "ahead of the threads"                  "$( LC_ALL=C awk '/^### Decisions \(from / { d = NR ; } /^## Thread / { t = NR ; } END { print ( d && t && d < t ) ? "first" : "not first" ; }' "$rigConv" )" first
rigAssert "newest first"                          "$( LC_ALL=C awk '/^### Decisions \(from / { on = 1 ; next ; } on && /^- / { print ; exit ; }' "$rigConv" | LC_ALL=C grep -c ' answer: Q1 ' )" 1
rigAssert "never under a heading that collides"   "$( LC_ALL=C grep -c '^## Decisions' "$rigConv" )" 0
rigOp scan1 --intern-op-session-context-scan "$rigMember" --state blocked --all-types --item "$rigTask.md" --context rig
rigAssert "the named-item scan shows them"        "$( rigHolds "$rigTmp/scan1" "### Decisions (from $rigTask)" )" yes
rigAssert "right under the item heading"          "$( LC_ALL=C awk -v want="## blocked/$rigTask.md" '$0 == want { getline ; print ; exit ; }' "$rigTmp/scan1" | cut -c1-24 )" "### Decisions (from task"

echo "-- clarifications on an answer, and a withdrawn ask, reach the item --"
printf '1700000009.000200\tURIGOWNER\tonly the clause in section 4\n1700000009.000300\tURIGOWNER\tand keep the signature page\n' | rigOp clar1 --intern-op-pending-reply-clarify "$rigId1" --from-stdin
rigAssert "two are kept"                          "$( head -1 "$rigTmp/clar1" )" "CLARIFIED $rigId1 2"
rigAssert "on the record"                         "$( rigHolds "$rigStore/$rigId1.md" '- 1700000009.000200 URIGOWNER: only the clause in section 4' )" yes
rigAssert "as clarification lines on the item"    "$( rigSection "$rigBoard/blocked/$rigTask.md" | LC_ALL=C grep -c "URIGOWNER clarification: on $rigId1 (Q1): " )" 2
rigAssert "the record stays answered as it was"   "$( rigField "$rigStore/$rigId1.md" verdict )" "keep it, signed off"
printf '1700000009.000300\tURIGOWNER\tand keep the signature page\n' | rigOp clar2 --intern-op-pending-reply-clarify "$rigId1" --from-stdin
rigAssert "a message kept once is not kept twice" "$( head -1 "$rigTmp/clar2" ):$( rigSection "$rigBoard/blocked/$rigTask.md" | LC_ALL=C grep -c "clarification: on $rigId1 " )" "CLARIFIED $rigId1 0:2"
rigRec1="$rigStore/$rigId1.md" ; [ -f "$rigRec1" ] || rigRec1="$rigStore/closed/$rigId1.md"
LC_ALL=C awk 'NR == 2 { print "asking-accounts:  URIGSELF1 " ; } { print ; }' "$rigRec1" > "$rigTmp/r1a" && mv "$rigTmp/r1a" "$rigRec1" || rigRefuse "the record of $rigId1 took no asking account"
printf '1700000009.000400\tURIGSELF1\tthe ask itself, posted again\n' | rigOp clar3 --intern-op-pending-reply-clarify "$rigId1" --from-stdin
rigAssert "a post of the asking account is no clarification on the item" "$( rigSection "$rigBoard/blocked/$rigTask.md" | LC_ALL=C grep -c "clarification: on $rigId1 " )" 2
printf 'Should the rig also sign the side letter?\n' | rigOp open6 --intern-op-pending-reply-open "$rigMember" --to human-owner \
	--session-id rig-session-a --kind decision --address-to human-owner --item "$rigTask"
rigId6="$( head -1 "$rigTmp/open6" )"
rigOp close6 --intern-op-pending-reply-close "$rigId6" --if-open --status withdrawn --withdrawn-by "$rigMember" --withdraw-reason "the side letter was dropped"
rigAssert "a withdrawn ask is dismissed on the item, with no answer" "$( rigSection "$rigBoard/blocked/$rigTask.md" | tail -1 | LC_ALL=C sed -E 's/^- [^ ]+ //' )" "$rigMember dismissed: Should the rig also sign the side letter? -> withdrawn by its asker, no answer taken: the side letter was dropped ($rigId6)"
rigOp close6v --intern-op-pending-reply-close "$rigId6" --status withdrawn --withdrawn-by "$rigMember" --withdraw-reason "x" --verdict "yes"
rigAssert "withdrawn never carries a verdict"     "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigField "$rigStore/$rigId6.md" verdict )" "refused:"

echo "-- tracks: a dispatch item's decision is on its task too, one level --"
rigTracked="task-20261008T1400Z-rig-tracked"
rigBeyond="task-20261008T1401Z-rig-beyond"
rigDispA="dispatch-20261008T1402Z-spawn-proxy-2"
rigDispB="dispatch-20261008T1403Z-spawn-proxy-3"
rigFence='```'
printf -- '---\ntype: task\nowner: magic-tester\ntracks: %s\n---\n\n# Rig tracked task\n' "$rigBeyond" > "$rigBoard/running/$rigTracked.md"
printf -- '---\ntype: task\nowner: magic-tester\n---\n\n# Rig beyond\n' > "$rigBoard/running/$rigBeyond.md"
## A brief that quotes other items' sections three ways: marked for another item, unmarked, fenced.
printf -- '---\ntype: dispatch\nowner: magic-tester\ntracks: %s\n---\n\n## Brief\n\nQuoted from the task:\n\n## Decisions\n<!-- decisions-of: %s -->\n\n- 2026-10-01T00:00Z someone answer: QUOTED-MARKED\n\n## Decisions\n\n- 2026-10-01T00:00Z someone answer: QUOTED-PLAIN\n\n%s\n## Decisions\n- 2026-10-01T00:00Z someone answer: QUOTED-FENCED\n%s\n\n## Result\n\nstatus: running\n' \
	"$rigTracked" "$rigTracked" "$rigFence" "$rigFence" > "$rigBoard/running/$rigDispA.md"
printf -- '---\ntype: dispatch\nowner: magic-tester\ntracks: %s\n---\n\n## Brief\n\nA later dispatch on the same task.\n' "$rigTracked" > "$rigBoard/running/$rigDispB.md"
cp "$rigBoard/running/$rigDispA.md" "$rigTmp/dispA.before"
printf 'Which rig port should the tracked task use?\n' | rigOp open5 --intern-op-pending-reply-open "$rigMember" --to human-owner \
	--session-id rig-session-c --kind question --address-to human-owner --item "$rigDispA"
rigId5="$( head -1 "$rigTmp/open5" )"
rigOp close5 --intern-op-pending-reply-close "$rigId5" --if-open --status reply-received --verdict "port 8443" --answered-by URIGOWNER
rigAssert "the answer is on the dispatch"         "$( AgentsToolsDecisionsLines "$rigBoard/running/$rigDispA.md" 30 | LC_ALL=C grep -c 'port 8443' )" 1
rigAssert "and on the task it tracks"             "$( AgentsToolsDecisionsLines "$rigBoard/running/$rigTracked.md" 30 | LC_ALL=C grep -c "port 8443 ($rigId5, via $rigDispA)" )" 1
rigAssert "never on the item the task tracks"     "$( LC_ALL=C grep -c 'port 8443' "$rigBoard/running/$rigBeyond.md" )" 0
rigAssert "the task's section is marked as its own" "$( LC_ALL=C grep -c -x -F "<!-- decisions-of: $rigTracked -->" "$rigBoard/running/$rigTracked.md" )" 1
printf 'Which rig port should the tracked task use?\n' | rigOp early5 --intern-op-pending-reply-earlier "$rigMember" --session-id rig-session-d --kind question --item "$rigDispB"
rigAssert "a new dispatch finds it on the task"   "$( cut -d' ' -f1-2 "$rigTmp/early5" )" "EARLIER-DECISION $rigTracked"
printf 'Which rig port should the tracked task use?\n' | rigOp early6 --intern-op-pending-reply-earlier "$rigMember" --session-id rig-session-d --kind question --item "$rigBeyond"
rigAssert "tracks: is followed one level only"    "$( cat "$rigTmp/early6" )" ""
rigConfirmed rb-rec5 "$rigDispA" "The rig port is fixed for this task."
rigOp rec5 --record-decision --team-member "$rigMember" "$rigDispA" --kind clarification --text "The rig port is fixed for this task." --readback rb-rec5
rigAssert "a member record on a dispatch: both"   "$( LC_ALL=C grep -c '^DECISION-RECORDED ' "$rigTmp/rec5" )/$( AgentsToolsDecisionsLines "$rigBoard/running/$rigTracked.md" 30 | LC_ALL=C grep -c 'port is fixed' )" 2/1

echo "-- only the item's own section: never a quoted copy --"
rigAssert "the brief's quotes are untouched"      "$( diff <( LC_ALL=C sed -n '/^## Brief/,/^## Result/p' "$rigTmp/dispA.before" ) <( LC_ALL=C sed -n '/^## Brief/,/^## Result/p' "$rigBoard/running/$rigDispA.md" ) > /dev/null && echo same || echo changed )" same
rigAssert "its own section is new, at the end"    "$( LC_ALL=C awk -v m="<!-- decisions-of: $rigDispA -->" '$0 == m { at = NR ; } END { print ( at > 0 ) ? "marked" : "none" ; }' "$rigBoard/running/$rigDispA.md" )" marked
rigAssert "the read takes no quoted line"         "$( AgentsToolsDecisionsLines "$rigBoard/running/$rigDispA.md" 30 | LC_ALL=C grep -c QUOTED )" 0
rigAssert "and both own lines"                    "$( AgentsToolsDecisionsLines "$rigBoard/running/$rigDispA.md" 30 | wc -l | tr -d ' ' )" 2
rigLegacy="task-20261008T1404Z-rig-legacy"
printf -- '---\ntype: task\nowner: magic-tester\n---\n\n# Rig legacy\n\n## Decisions\n\n- 2026-10-01T00:00Z someone answer: LEGACY-LINE\n\n## Notes\n\nlater\n' > "$rigBoard/running/$rigLegacy.md"
rigConfirmed rb-rec6 "$rigLegacy" "Appended to the legacy section."
rigOp rec6 --record-decision --team-member "$rigMember" "$rigLegacy" --kind clarification --text "Appended to the legacy section." --readback rb-rec6
rigAssert "an unmarked section from before is still its own" "$( LC_ALL=C grep -c '^## Decisions' "$rigBoard/running/$rigLegacy.md" )/$( rigSection "$rigBoard/running/$rigLegacy.md" | wc -l | tr -d ' ' )" 1/2

echo "-- the coordinator's forward refuses an escalation already answered --"
rigEsc(){ ## id, status, session, item, extra header lines
	printf -- '---\nstatus: %s\nowner: magic-tester\nhost: rig\ncommunication-channel-id: slack:magic-coordinator\nblocked-on: reply from magic-coordinator\nsession-id: %s\nkind: decision\naddress-to: magic-coordinator\n%s%sasked-at: 2026-10-08 12:00 +0300\n---\n\n# Question asked\n\n# ❓ Decision D1\n\nWhich rig release train should ship the fix?\n' \
		"$2" "$3" "${4:+item: $4
}" "$5" > "$rigStore/$1.md"
	printf -- '- option-a: the current train\n- option-b: the next train\n' > "$rigStore/$1.options"
}
rigCurlBefore="$( LC_ALL=C grep -c 'chat.postMessage' "$RIG_CURL_LOG" )"
rigOp dec1 --intern-op-decisions-append magic-coordinator "$rigTask" --kind verdict --text "D1 Which rig release train should ship the fix? -> option-b" --source rig-earlier
rigEsc 33333333-0000-0000-0000-000000000001 reply-pending rig-session-f "$rigTask" ""
rigOp fwd1 --forward-escalation --team-member magic-coordinator 33333333-0000-0000-0000-000000000001
rigAssert "answered in Decisions: not forwarded"  "$( head -1 "$rigTmp/fwd1" )" "ESCALATION: 33333333-0000-0000-0000-000000000001 answered-earlier"
rigAssert "it prints the earlier answer"          "$( sed -n 2p "$rigTmp/fwd1" | cut -d' ' -f1-2 )/$( rigHolds "$rigTmp/fwd1" '-> option-b' )" "EARLIER-DECISION $rigTask/yes"
rigEsc 33333333-0000-0000-0000-000000000002 reply-received rig-session-g "" "verdict: option-a
answered-by: URIGOWNER
resolved-at: 2026-10-08 12:05 +0300
resolved-epoch: 1700000000
"
rigEsc 33333333-0000-0000-0000-000000000003 reply-pending rig-session-g "" ""
rigOp fwd2 --forward-escalation --team-member magic-coordinator 33333333-0000-0000-0000-000000000003
rigAssert "answered in a closed record: not forwarded" "$( head -1 "$rigTmp/fwd2" )" "ESCALATION: 33333333-0000-0000-0000-000000000003 answered-earlier"
rigAssert "it prints that record's answer"        "$( sed -n 2p "$rigTmp/fwd2" )" "EARLIER-RECORD 33333333-0000-0000-0000-000000000002 | option-a | URIGOWNER | 2026-10-08 12:05 +0300"
rigAssert "nothing was posted, nothing recorded"  "$( LC_ALL=C grep -c 'chat.postMessage' "$RIG_CURL_LOG" )/$( LC_ALL=C grep -c '^forward-ts: ' "$rigStore/33333333-0000-0000-0000-000000000001.md" "$rigStore/33333333-0000-0000-0000-000000000003.md" | LC_ALL=C awk -F: '{ s += $NF ; } END { print s ; }' )" "$rigCurlBefore/0"
rigAssert "both stay open"                        "$( rigField "$rigStore/33333333-0000-0000-0000-000000000001.md" status )/$( rigField "$rigStore/33333333-0000-0000-0000-000000000003.md" status )" reply-pending/reply-pending

echo "-- who records: the item's own parties, as themselves --"
rigParty="task-20261008T1500Z-rig-parties"
printf -- '---\ntype: task\nowner: magic-tester\nreview-by: keeper-rev\nspawn-id: rig-spawn-p\nblocked-on: the rig gate\n---\n\n# Rig parties\n' > "$rigBoard/running/$rigParty.md"
mkdir -p "$rigTmp/ws/.local/agents/spawned/rig-spawn-p" "$rigTmp/ws/.local/agents/spawned/rig-spawn-q"
printf -- '---\nsession-id: rig-spawn-p\nowner: keeper-exec\nstatus: spawn-started\n---\n' > "$rigTmp/ws/.local/agents/spawned/rig-spawn-p/rig-spawn-p.spawn.md"
printf -- '---\nsession-id: rig-spawn-q\nowner: keeper-link\nstatus: spawn-started\nspawned-by: %s\n---\n' "$rigParty" > "$rigTmp/ws/.local/agents/spawned/rig-spawn-q/rig-spawn-q.spawn.md"
rigPartyLines(){ rigSection "$rigBoard/running/$rigParty.md" | wc -l | tr -d ' ' ; }
rigOp par1 --record-decision --team-member keeper-other "$rigParty" --kind clarification --text "not a party"
rigAssert "a member that is no party is refused"   "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigPartyLines ):$( LC_ALL=C grep -c 'is not the owner, executor or reviewer' "$rigTmp/par1.err" )" refused:0:1
rigOp par2 --record-decision --team-member keeper-other "$rigParty" --kind resolved --text "clearing it" --clears-blocker
rigAssert "and clears no blocker"                  "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigField "$rigBoard/running/$rigParty.md" blocked-on )" "refused:the rig gate"
rigConfirmed rb-par3 "$rigParty" "by the reviewer"
rigOp par3 --record-decision --team-member keeper-rev "$rigParty" --kind clarification --text "by the reviewer" --readback rb-par3
rigAssert "its review-by reviewer records"         "$rigRc:$( rigPartyLines )" 0:1
rigConfirmed rb-par4 "$rigParty" "by its spawned session's member"
rigOp par4 --record-decision --team-member keeper-exec "$rigParty" --kind clarification --text "by its spawned session's member" --readback rb-par4
rigAssert "its spawned session's member records"   "$rigRc:$( rigPartyLines )" 0:2
rigConfirmed rb-par5 "$rigParty" "by the executor"
rigOp par5 --record-decision --team-member keeper-link "$rigParty" --kind resolved --text "by the executor" --clears-blocker --readback rb-par5
rigAssert "a spawn working it records and clears"  "$rigRc:$( rigPartyLines ):$( rigField "$rigBoard/running/$rigParty.md" blocked-on )" 0:3:
RIG_AGENT=keeper-other rigOp par6 --record-decision --team-member magic-tester "$rigParty" --kind clarification --text "naming the owner"
rigAssert "a session naming another member is refused" "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigPartyLines ):$( LC_ALL=C grep -c 'this session acts as keeper-other' "$rigTmp/par6.err" )" refused:3:1
rigConfirmed rb-par7 "$rigParty" "the owner itself"
RIG_AGENT=magic-tester rigOp par7 --record-decision --team-member magic-tester "$rigParty" --kind clarification --text "the owner itself" --readback rb-par7
rigAssert "the owner's own session records"        "$rigRc:$( rigPartyLines )" 0:4

echo "-- a decision lands only through its confirmed readback --"
rigGate="task-20261008T1600Z-rig-readback-gate"
printf -- '---\ntype: task\nowner: magic-tester\n---\n\n# Rig readback gate\n' > "$rigBoard/running/$rigGate.md"
rigGateLines(){ rigSection "$rigBoard/running/$rigGate.md" | wc -l | tr -d ' ' ; }
rigOp gate1 --record-decision --team-member "$rigMember" "$rigGate" --kind resolved --text "The rig ships on the next train."
rigAssert "no readback: refused, nothing recorded" "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigGateLines ):$( LC_ALL=C grep -c 'only through its confirmed readback' "$rigTmp/gate1.err" )" refused:0:1
rigConfirmed rb-other "$rigParty" "The rig ships on the next train."
rigOp gate2 --record-decision --team-member "$rigMember" "$rigGate" --kind resolved --text "The rig ships on the next train." --readback rb-other
rigAssert "another item's readback: refused"        "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigGateLines )" refused:0
rigConfirmed rb-gate "$rigGate" "The rig ships on the next train."
rigOp gate3 --record-decision --team-member "$rigMember" "$rigGate" --kind resolved --text "The rig ships on the current train." --readback rb-gate
rigAssert "a text not the confirmed one: refused"   "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigGateLines ):$( LC_ALL=C grep -c 'differs from what readback rb-gate confirmed' "$rigTmp/gate3.err" )" refused:0:1
rigConfirmed rb-gate-no "$rigGate" "The rig ships on the next train." no
rigOp gate4 --record-decision --team-member "$rigMember" "$rigGate" --kind resolved --text "The rig ships on the next train." --readback rb-gate-no
rigAssert "an unconfirmed readback: refused"        "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigGateLines )" refused:0
rigOp gate5 --record-decision --team-member "$rigMember" "$rigGate" --kind resolved --text "The rig ships on the next train." --readback rb-gate
rigAssert "the confirmed text lands, naming who confirmed" "$rigRc:$( rigGateLines ):$( rigSection "$rigBoard/running/$rigGate.md" | LC_ALL=C grep -c -F 'resolved: The rig ships on the next train. (readback rb-gate, confirmed by URIGOWNER at 2026-10-08 12:30 +0300)' )" 0:1:1
rigOp gate6 --record-decision --team-member "$rigMember" "$rigGate" --kind resolved --text "The rig ships on the next train." --readback rb-gate
rigAssert "one readback lands once"                 "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigGateLines )" refused:1
rigConfirmed rb-gate-edit "$rigGate" "The rig ships on the next train." edit "The rig ships after the audit."
rigOp gate7 --record-decision --team-member "$rigMember" "$rigGate" --kind resolved --text "The rig ships on the next train." --readback rb-gate-edit
rigAssert "an edit lands the person's own words"   "$rigRc:$( rigSection "$rigBoard/running/$rigGate.md" | tail -1 | LC_ALL=C sed -E 's/.* resolved: //; s/ \(readback .*$//' )" "0:The rig ships after the audit."

echo "-- a readback asked again, changed: the understanding it now holds is the one it records --"
rigRbItem="task-20261008T2000Z-rig-revised-readback"
printf -- '---\ntype: task\nowner: magic-tester\n---\n\n# Rig revised readback\n' > "$rigBoard/running/$rigRbItem.md"
rigRbRecorded(){ ## text -- the item's lines recording it through a readback
	rigSection "$rigBoard/running/$rigRbItem.md" | LC_ALL=C grep -c -F "resolved: $1 (readback " || :
}
rigRbBody(){ ## understanding text -- one readback body, as the post carries it
	printf '# 🔁 Readback\n\nConfirm my reading.\n\n**📥 What I understood**\n%s\n\n**📎 Where it came from**\nthe rig\n' "$1"
}
## The revised record is driven through the store's own writers: the readback opened, then asked again changed.
rigRbBody "The rig keeps the red wire on the left." \
	| rigOp rev1 --intern-op-pending-reply-open "$rigMember" --to human-owner --session-id rig-session-rev --kind readback --address-to human-owner --item "$rigRbItem" \
		--fields "$( printf 'understood\tThe rig keeps the red wire on the left.' )"
rigRbId="$( head -1 "$rigTmp/rev1" )"
[ -f "$rigStore/$rigRbId.md" ] || rigRefuse "the readback asked again was not opened: $( cat "$rigTmp/rev1.err" )"
rigRbBody "The rig keeps the red wire on the left, and the blue one on the right." \
	| rigOp rev2 --intern-op-pending-reply-revise "$rigRbId" --revision-ts 1700000300.000100 --revised-by "$rigMember" \
		--fields "$( printf 'understood\tThe rig keeps the red wire on the left, and the blue one on the right.' )"
rigAssert "the record keeps both versions"         "$rigRc:$( rigField "$rigStore/$rigRbId.md" revisions ):$( LC_ALL=C grep -c '^## Revision ' "$rigStore/$rigRbId.md" )" "0:1:1"
rigOp rev3 --intern-op-pending-reply-close "$rigRbId" --if-open --status reply-received --verdict yes --answered-by URIGOWNER
rigAssert "it is answered"                        "$( rigField "$rigStore/$rigRbId.md" status )" reply-received
rigOp rev4 --record-decision --team-member "$rigMember" "$rigRbItem" --kind resolved --text "The rig keeps the red wire on the left." --readback "$rigRbId"
rigAssert "the version it replaced records nothing" "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigRbRecorded 'The rig keeps the red wire on the left.' ):$( LC_ALL=C grep -c 'differs from what readback' "$rigTmp/rev4.err" )" "refused:0:1"
rigOp rev5 --record-decision --team-member "$rigMember" "$rigRbItem" --kind resolved --text "The rig keeps the red wire on the left, and the blue one on the right." --readback "$rigRbId"
rigAssert "the understanding it now holds is recorded" "$rigRc:$( rigRbRecorded 'The rig keeps the red wire on the left, and the blue one on the right.' ):$( rigSection "$rigBoard/running/$rigRbItem.md" | LC_ALL=C grep -c -F '(readback '"$rigRbId"', confirmed by URIGOWNER at ' )" "0:1:1"
## The control: a readback never asked again records the one understanding it holds, as before.
rigRbBody "The rig keeps the white wire in the middle." \
	| rigOp rev6 --intern-op-pending-reply-open "$rigMember" --to human-owner --session-id rig-session-rev --kind readback --address-to human-owner --item "$rigRbItem" \
		--fields "$( printf 'understood\tThe rig keeps the white wire in the middle.' )"
rigRbPlainId="$( head -1 "$rigTmp/rev6" )"
[ -f "$rigStore/$rigRbPlainId.md" ] || rigRefuse "the control readback was not opened: $( cat "$rigTmp/rev6.err" )"
rigOp rev7 --intern-op-pending-reply-close "$rigRbPlainId" --if-open --status reply-received --verdict yes --answered-by URIGOWNER
rigOp rev8 --record-decision --team-member "$rigMember" "$rigRbItem" --kind resolved --text "The rig keeps the white wire in the middle." --readback "$rigRbPlainId"
rigAssert "one understanding records as it always has" "$rigRc:$( rigRbRecorded 'The rig keeps the white wire in the middle.' ):$( rigSection "$rigBoard/running/$rigRbItem.md" | LC_ALL=C grep -c -F '(readback '"$rigRbPlainId"', confirmed by URIGOWNER at ' )" "0:1:1"

echo "-- answer -> every other item that waits on the ask by name --"
printf 'May the rig read the vendor tree?\n' | rigOp open7 --intern-op-pending-reply-open "$rigMember" --to human-owner \
	--session-id rig-session-a --kind question --address-to human-owner --question-tag Q7 --question-key 777-77 --task-ref "for $rigTask.md, please"
rigId7="$( head -1 "$rigTmp/open7" )"
rigWaiter="task-20261008T1400Z-rig-waiter"
rigBystander="task-20261008T1401Z-rig-bystander"
printf -- '---\ntype: task\nowner: magic-tester\ncondition: the ask %s is answered and the pace allows\n---\n\n# Rig waiter\n' "$rigId7" > "$rigBoard/pending/$rigWaiter.md"
printf -- '---\ntype: task\nowner: magic-tester\ncondition: the pace allows\n---\n\n# Rig bystander\n\nNames %s in its body only.\n' "$rigId7" > "$rigBoard/pending/$rigBystander.md"
rigOp close7 --intern-op-pending-reply-close "$rigId7" --if-open --status reply-received --verdict "yes, read it" --answered-by URIGOWNER
rigAssert "the waiting item has the answer"       "$( rigSection "$rigBoard/pending/$rigWaiter.md" | tail -1 | LC_ALL=C sed -E 's/^- [^ ]+ //' )" "URIGOWNER answer: Q7 May the rig read the vendor tree? -> yes, read it ($rigId7, asked on $rigTask)"
rigAssert "its condition naming the ask is gone"  "$( rigField "$rigBoard/pending/$rigWaiter.md" condition )" ""
rigAssert "an item naming it in its body only stays" "$( rigSection "$rigBoard/pending/$rigBystander.md" | wc -l | tr -d ' ' ):$( rigField "$rigBoard/pending/$rigBystander.md" condition )" "0:the pace allows"

echo "-- a decision asked: its readback goes to the party, and its answer lands it --"
rigAsked="task-20261008T1700Z-rig-decision-asked"
printf -- '---\ntype: task\nowner: magic-tester\n---\n\n# Rig decision asked\n' > "$rigBoard/running/$rigAsked.md"
rigAskedLines(){ rigSection "$rigBoard/running/$rigAsked.md" | wc -l | tr -d ' ' ; }
rigAskedId(){ LC_ALL=C grep -o -E '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$rigTmp/$1" | head -1 ; }
## The person answers an open decision readback as a person does: once it is posted, in the thread its record names, the
## reply after the question. Waits up to 120 s for the record. rc 1 where none came.
rigReplyCount=0
rigAnswerAsked(){ ## reply text, replying account (default URIGOWNER), seconds to wait (default 120)
	local answerFile="" answerLeft="${3:-120}" answerBy="${2:-URIGOWNER}" answerQ answerT answerRoot=""
	while [ "$answerLeft" -gt 0 ] ; do
		## The newest decision readback first: a row that leaves an older readback open, as a contact's escalation does,
		## must not take the answer meant for the one the call just opened.
		for answerFile in $( ls -t "$rigStore"/*.md 2> /dev/null ) "" ; do
			[ -n "$answerFile" ] || break
			[ "$( rigField "$answerFile" status )" = reply-pending ] && LC_ALL=C grep -q '^decision-kind	' "${answerFile%.md}.fields" 2> /dev/null && [ -n "$( rigField "$answerFile" question-ts )" ] && break
		done
		[ -z "$answerFile" ] || break
		sleep 1 ; answerLeft=$(( answerLeft - 1 ))
	done
	[ -n "$answerFile" ] || return 1
	answerQ="$( rigField "$answerFile" question-ts )" ; answerT="$( rigField "$answerFile" thread-ts )" ; answerT="${answerT:-$answerQ}"
	rigReplyCount=$(( rigReplyCount + 1 ))
	[ "$answerT" = "$answerQ" ] || answerRoot="$( printf '{"ts":"%s","user":"URIGSELF1","text":"root"},' "$answerT" )"
	printf '{"ok":true,"messages":[%s{"ts":"%s","user":"URIGSELF1","text":"question","thread_ts":"%s"},{"ts":"1700000002.00020%s","user":"%s","text":"%s","thread_ts":"%s"}],"has_more":false}\n' \
		"$answerRoot" "$answerQ" "$answerT" "$rigReplyCount" "$answerBy" "$1" "$answerT" > "$RIG_SCENARIO/replies.$answerT.json"
}
## The member set root the rig runs its own calls with: the members the runner hands it, plus the client member that reaches a
## contact. A client operation reads a member from this root, and the runner's own root holds none of it.
rigMembers="${MDAT_SKILLSET_ROOT:-}"
mkdir -p "$rigTmp/members"
for rigMemberDir in "$rigMembers"/*/ ; do
	rigMemberDir="${rigMemberDir%/}"
	[ -d "$rigMemberDir" ] || continue
	[ -e "$rigTmp/members/${rigMemberDir##*/}" ] || cp -R "$rigMemberDir" "$rigTmp/members/${rigMemberDir##*/}"
done
ln -sfn "$rigTmp/skills/client-rig" "$rigTmp/members/client-rig"
## As rigOp, with the skillset that gives the asking member its identity, as the AskQuestion block above has it: a readback is posted.
rigDecOp(){ ## output name, op, arguments...
	local opOut="$1" ; shift
	rigRc=0
	( cd "$rigTmp/ws" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" \
		MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/members" MDAT_DATA_ROOT="$rigTmp/data" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigTool" "$@" ) > "$rigTmp/$opOut" 2> "$rigTmp/$opOut.err" || rigRc=$?
	return "$rigRc"
}
## A waited call in the background, answered while it waits, and waited out: its limit is soft, and the runner's timeout bounds a hang.
## rigAnswerAccount names the account that answers, where the party is not the human-owner: empty answers as URIGOWNER does.
## rigAnswerWait bounds how long a row waits for its ask to appear, for a route that posts none.
rigAnswerAccount=""
rigAnswerWait=""
rigDecWaited(){ ## reply text, output name, op, arguments...
	local waitedReply="$1" waitedPid ; shift
	rigDecOp "$@" &
	waitedPid=$!
	rigAnswerAsked "$waitedReply" "$rigAnswerAccount" "${rigAnswerWait:-120}" || :
	rigRc=0 ; wait "$waitedPid" 2> /dev/null || rigRc=$?
}
rigDecOp dask1 --record-decision --team-member "$rigMember" "$rigAsked" --kind resolved --text "The rig asks before it records." --with human-owner
rigDid1="$( rigAskedId dask1 )"
rigAssert "asked: nothing recorded yet, and said so" "$rigRc:$( rigAskedLines ):$( LC_ALL=C grep -c "^DECISION-ASKED $rigDid1 human-owner: " "$rigTmp/dask1" )" 0:0:1
rigAssert "a readback on the item, keeping its kind" "$( rigField "$rigStore/$rigDid1.md" kind ):$( rigField "$rigStore/$rigDid1.md" item ):$( rigField "$rigStore/$rigDid1.md" status ):$( LC_ALL=C awk -F'\t' '$1 == "decision-kind" { print $2 ; }' "$rigStore/$rigDid1.fields" 2> /dev/null )" "readback:$rigAsked:reply-pending:resolved"
rigAssert "the exact text is what was posted"        "$( LC_ALL=C grep -c -F 'The rig asks before it records.' "$RIG_SCENARIO/post.$( cat "$RIG_SCENARIO/posts" 2> /dev/null )" 2> /dev/null )" 1
rigAnswerAsked "yes"
## Its asker is gone: another member's read of the thread takes the answer, and the decision lands.
rigDecOp dread1 --intern-op-escalation-read magic-coordinator "$rigDid1"
rigAssert "confirmed by whoever reads it: it lands"  "$( rigAskedLines ):$( rigSection "$rigBoard/running/$rigAsked.md" | LC_ALL=C grep -c -F "magic-tester resolved: The rig asks before it records. (readback $rigDid1, confirmed by " )" 1:1
rigDecOp dread2 --intern-op-escalation-read magic-coordinator "$rigDid1"
rigAssert "read again, it lands once"                "$( rigAskedLines )" 1
rigDecWaited "edit: The rig asks first, then records." dask2 --record-decision --team-member "$rigMember" "$rigAsked" --kind clarification --text "The rig records after asking." --with human-owner --wait
rigAssert "waited: an edit lands the person's words" "$rigRc:$( tail -1 "$rigTmp/dask2" | cut -d' ' -f1 ):$( rigSection "$rigBoard/running/$rigAsked.md" | tail -1 | LC_ALL=C sed -E 's/.* clarification: //; s/ \(readback .*$//' )" "0:DECISION-RECORDED:The rig asks first, then records."
rigDecWaited "no" dask3 --record-decision --team-member "$rigMember" "$rigAsked" --kind clarification --text "The rig records without asking." --with human-owner --wait
rigAssert "a no lands nothing, and says what next"   "$rigRc:$( rigAskedLines ):$( tail -1 "$rigTmp/dask3" | cut -d' ' -f1 ):$( LC_ALL=C grep -c 'then ask it again' "$rigTmp/dask3" )" 0:2:DECISION-NOT-RECORDED:1
[ "$( rigAskedLines )" = 2 ] || rigSection "$rigBoard/running/$rigAsked.md" | LC_ALL=C sed 's/^/        | /'
rigDecOp dask4 --record-decision --team-member "$rigMember" "$rigAsked" --kind clarification --text "Both." --with human-owner --readback "$rigDid1"
rigAssert "--with and --readback together: refused"  "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigAskedLines )" refused:2

echo "-- a strike asked: its readback goes to the party, and its answer strikes the line --"
rigAskedLine(){ rigSection "$rigBoard/running/$rigAsked.md" | LC_ALL=C grep -F -- "$1" | head -1 ; }
rigDecWaited "no" dstr1 --record-decision --team-member "$rigMember" "$rigAsked" --strike "$( rigAskedLine 'resolved: The rig asks before it records.' )" --reason "The rig records it a better way now." --with human-owner --wait
rigAssert "a no keeps the line, and says so"       "$rigRc:$( tail -1 "$rigTmp/dstr1" | cut -d' ' -f1 ):$( rigAskedLine 'resolved: The rig asks before it records.' | LC_ALL=C grep -c 'struck by' )" 0:DECISION-NOT-RECORDED:0
rigDecWaited "yes" dstr2 --record-decision --team-member "$rigMember" "$rigAsked" --strike "$( rigAskedLine 'resolved: The rig asks before it records.' )" --reason "The rig records it a better way now." --with human-owner --wait
rigDid4="$( LC_ALL=C grep -o -E '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$rigTmp/dstr2" | head -1 )"
rigAssert "a yes strikes it, naming the readback"   "$rigRc:$( tail -1 "$rigTmp/dstr2" | cut -d' ' -f1 ):$( rigAskedLine 'resolved: The rig asks before it records.' | LC_ALL=C grep -c 'struck by magic-tester: The rig records it a better way now.' ):$( rigSection "$rigBoard/running/$rigAsked.md" | LC_ALL=C grep -c "dismissed: the line struck: .* (readback $rigDid4, confirmed by " )" 0:DECISION-RECORDED:1:1

echo "-- the rig's contacts reach their organisation through a client member --"
## A contact is reached through the client-* member of its organisation (AgentsTools.Contacts.include), so the rig holds
## that member, the organisation it stands for, and each contact's Slack coordinate of that member's own team. The member
## lives in the rig's member set root, which is where a session started here reads its members.
mkdir -p "$rigTmp/data/contacts/persons" "$rigTmp/data/contacts/organisations" "$rigTmp/skills/client-rig"
printf -- '---\ntype: contact-organisation\norganisation-id: rig-org\ndisplay-name: Rig Organisation\ndomain: rig.slack.invalid\n---\n# Organisation: Rig Organisation\n\n## Log\n\n' > "$rigTmp/data/contacts/organisations/rig-org.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigTmp/skills/client-rig/client-rig.basic.md"
printf '# rig armed\n' > "$rigTmp/skills/client-rig/client-rig.armed.md"
printf -- '---\nname: client-rig\n---\n\n# client-rig, set up in the rig workspace\n' > "$rigTmp/skills/client-rig/SKILL.md"
printf 'CLIENT_SLACK_USER_TOKEN=rig-user-token-RIGADMIN\nCLIENT_SLACK_WORKSPACE_DOMAIN=rig.slack.invalid\n' > "$rigTmp/ws/.local/.agents/client-rig.agent.env"

echo "-- who decides it himself: a contact by its tier --"
printf -- '---\ntype: contact\ncontact-id: rig-admin\ndisplay-name: Rig Admin\norganisation: rig-org\ntier: tier-admin\nreached-by: client-rig\nslack-id: client-rig:URIGADMIN1\n---\n' > "$rigTmp/data/contacts/persons/rig-admin.md"
printf -- '---\ncontact-id: rig-guest\ndisplay-name: Rig Guest\norganisation: rig-org\n---\n' > "$rigTmp/data/contacts/persons/rig-guest.md"
rigDecides(){ ( MDAT_DATA_ROOT="$rigTmp/data" AgentsToolsDecisionPartyDecides "$1" "${2:-}" ) && echo decides || echo goes-up ; }
rigAssert "a tier-admin contact decides, a plain contact and a member outside it go up" "$( rigDecides contact:rig-admin ):$( rigDecides contact:rig-guest ):$( rigDecides contact:rig-nobody ):$( rigDecides keeper-myx )" "decides:goes-up:goes-up:goes-up"
printf -- '---\ntype: contact\ncontact-id: rig-projadmin\ndisplay-name: Rig Project Admin\norganisation: rig-org\nscope-tiers: rig-proj=tier-admin\nreached-by: client-rig\nslack-id: client-rig:URIGPROJA\n---\n' > "$rigTmp/data/contacts/persons/rig-projadmin.md"
printf -- '---\ntype: task\nowner: magic-tester\nprojects: rig-other, rig-proj\n---\n\n# Rig project item\n' > "$rigTmp/rig-proj-item.md"
printf -- '---\ntype: task\nowner: magic-tester\nprojects: rig-other\n---\n\n# Rig other item\n' > "$rigTmp/rig-other-item.md"
rigAssert "an admin of a project the item names decides it, and only there" "$( rigDecides contact:rig-projadmin "$rigTmp/rig-proj-item.md" ):$( rigDecides contact:rig-projadmin "$rigTmp/rig-other-item.md" ):$( rigDecides contact:rig-projadmin )" "decides:goes-up:goes-up"

echo "-- a party asked through the operation: its own yes lands the line --"
## A member party's readback reaches its Slack account, as the tooling's identity cache keeps it. The cache's first
## line is its lock generation, which this rig writes empty so its own rows are the ones read.
mkdir -p "$rigTmp/ws/.local/agents/cache"
printf '%s\n' "$( printf '' | LC_ALL=C cksum )" 'magic-coordinator=UCOORD0001=-=-=-=-' > "$rigTmp/ws/.local/agents/cache/slack-identities.cache"
rigReadbackField(){ ## readback id, field -- an ask that never opened reads empty
	[ -n "$1" ] || return 0
	local rbFile="$rigStore/$1.md" ; [ -f "$rbFile" ] || rbFile="$rigStore/closed/$1.md"
	[ -f "$rbFile" ] || return 0
	rigField "$rbFile" "$2"
}
rigReadbackSlots(){ ## readback id -- its own fields, wherever the record now sits
	[ -n "$1" ] || return 0
	cat "$rigStore/$1.fields" "$rigStore/closed/$1.fields" 2> /dev/null
}
rigPartyLines(){ rigSection "$rigBoard/running/$1.md" | wc -l | tr -d ' ' ; }
rigPartyConfirmedBy(){ ## item, account -- the party's own yes named on a line
	rigSection "$rigBoard/running/$1.md" | LC_ALL=C grep -c -F "confirmed by $2 at " ;
}
rigMemberParty="task-20261008T2100Z-rig-member-party"
printf -- '---\ntype: task\nowner: magic-tester\nreview-by: magic-coordinator\n---\n\n# Rig member party\n' > "$rigBoard/running/$rigMemberParty.md"
rigAnswerAccount="UCOORD0001"
rigDecWaited "yes" mparty1 --record-decision --team-member "$rigMember" "$rigMemberParty" --kind resolved --text "The rig member party decides this." --with magic-coordinator --wait
rigMemberPartyId="$( rigAskedId mparty1 )"
rigAssert "a member party is asked, and its own yes lands exactly one line" "$rigRc:$( rigReadbackField "$rigMemberPartyId" address-to ):$( rigPartyLines "$rigMemberParty" )" "0:magic-coordinator:1"
rigAssert "that line names the member's own confirmation"          "$( rigPartyConfirmedBy "$rigMemberParty" UCOORD0001 )" 1
rigContactDecided="task-20261008T2200Z-rig-contact-decided"
printf -- '---\ntype: task\nowner: magic-tester\n---\n\n# Rig contact decided\n' > "$rigBoard/running/$rigContactDecided.md"
## A contact asked here is never posted to, so its row waits seconds rather than minutes for the ask that never comes.
rigAnswerAccount="URIGADMIN1" ; rigAnswerWait=8
rigDecWaited "yes" cparty1 --record-decision --team-member "$rigMember" "$rigContactDecided" --kind clarification --text "The rig contact decides this." --with contact:rig-admin --wait
rigContactDecidedId="$( rigAskedId cparty1 )"
rigAssert "a contact party is asked, and its own yes lands exactly one line" "$rigRc:$( rigReadbackField "$rigContactDecidedId" address-to ):$( rigPartyLines "$rigContactDecided" )" "0:contact:rig-admin:1"
rigAssert "that line names the contact's own confirmation"             "$( rigPartyConfirmedBy "$rigContactDecided" URIGADMIN1 )" 1
rigContactScope="task-20261008T2201Z-rig-contact-scope"
printf -- '---\ntype: task\nowner: magic-tester\nprojects: rig-other, rig-proj\n---\n\n# Rig contact scope\n' > "$rigBoard/running/$rigContactScope.md"
rigContactElsewhere="task-20261008T2202Z-rig-contact-elsewhere"
printf -- '---\ntype: task\nowner: magic-tester\nprojects: rig-other\n---\n\n# Rig contact elsewhere\n' > "$rigBoard/running/$rigContactElsewhere.md"
rigAnswerAccount="URIGPROJA"
rigDecWaited "yes" cscope1 --record-decision --team-member "$rigMember" "$rigContactScope" --kind resolved --text "The rig project admin decides this." --with contact:rig-projadmin --wait
rigContactScopeId="$( rigAskedId cscope1 )"
rigAssert "a contact holding the item's project decides it there, with nothing going up" "$( rigPartyConfirmedBy "$rigContactScope" URIGPROJA ):$( rigReadbackSlots "$rigContactScopeId" | LC_ALL=C grep -c '^decision-escalate' )" "1:0"
rigDecWaited "yes" celsewhere1 --record-decision --team-member "$rigMember" "$rigContactElsewhere" --kind resolved --text "The rig project admin decides this too." --with contact:rig-projadmin --wait
rigContactElsewhereId="$( rigAskedId celsewhere1 )"
rigContactUpId="$( rigReadbackSlots "$rigContactElsewhereId" | LC_ALL=C awk -F'\t' '$1 == "escalated" { print $2 ; exit }' )"
rigAssert "the same contact outside that scope lands nothing, and goes up to the human-owner" "$( rigPartyLines "$rigContactElsewhere" ):$( [ -n "$rigContactUpId" ] && echo up ):$( rigReadbackField "$rigContactUpId" address-to )" "0:up:human-owner"
rigAnswerAccount="" ; rigAnswerWait=""
echo "-- confirmed by one who cannot decide it: it goes up to the human-owner, and his answer lands it --"
rigAssert "asked of the human-owner, nothing goes up" "$( cat "$rigStore/$rigDid1.fields" "$rigStore/closed/$rigDid1.fields" 2> /dev/null | LC_ALL=C grep -c '^decision-escalate' )" 0
rigEsc="task-20261008T1800Z-rig-decision-escalated"
printf -- '---\ntype: task\nowner: magic-tester\n---\n\n# Rig decision escalated\n' > "$rigBoard/running/$rigEsc.md"
printf '# 🔁 Readback\n\nConfirm my reading.\n\n**📥 What I understood**\nThe rig vendor is the blue one.\n' | rigOp esc1 --intern-op-pending-reply-open "$rigMember" --to client:rig-contact \
	--session-id rig-session-esc --kind readback --address-to client:rig-contact --item "$rigEsc" \
	--fields "$( printf 'decision-kind\tresolved\nunderstood\tThe rig vendor is the blue one.\ndecision-escalate\thuman-owner' )"
rigEscId="$( head -1 "$rigTmp/esc1" )"
[ -f "$rigStore/$rigEscId.md" ] || rigRefuse "the escalating readback was not opened: $( cat "$rigTmp/esc1.err" )"
rigDecOp esc2 --intern-op-pending-reply-close "$rigEscId" --if-open --status reply-received --verdict yes --answered-by URIGCONTACT
rigEscNew="$( cat "$rigStore/$rigEscId.fields" "$rigStore/closed/$rigEscId.fields" 2> /dev/null | LC_ALL=C awk -F'\t' '$1 == "escalated" { print $2 ; exit ; }' )"
rigAssert "confirmed, it goes up and records nothing" "$( rigSection "$rigBoard/running/$rigEsc.md" | wc -l | tr -d ' ' ):$( [ -n "$rigEscNew" ] && rigField "$rigStore/$rigEscNew.md" status ):$( rigField "$rigStore/$rigEscNew.md" item ):$( LC_ALL=C grep -c '^decision-escalate' "$rigStore/$rigEscNew.fields" 2> /dev/null )" "0:reply-pending:$rigEsc:0"
rigAnswerAsked "yes"
rigDecOp esc3 --intern-op-escalation-read magic-coordinator "$rigEscNew"
rigAssert "his yes lands it, naming both confirmations" "$( rigSection "$rigBoard/running/$rigEsc.md" | LC_ALL=C grep -c -F "magic-tester resolved: The rig vendor is the blue one. (readback $rigEscNew, confirmed by URIGOWNER at " ):$( rigSection "$rigBoard/running/$rigEsc.md" | LC_ALL=C grep -c -F "confirmed by URIGCONTACT in readback $rigEscId)" )" 1:1

echo "-- a review: every unconfirmed line as one list, and its answer applied line by line --"
rigRev="task-20261008T1900Z-rig-review"
{
	printf -- '---\ntype: task\nowner: magic-tester\n---\n\n# Rig review\n\n## Decisions\n<!-- decisions-of: %s -->\n\n' "$rigRev"
	printf -- '- 2026-11-01T10:00Z magic-tester clarification: The rig keeps the red wire. (ask rig-a, withdrawn)\n'
	printf -- '- 2026-11-01T10:01Z magic-tester resolved: The rig ships on Friday. (ask rig-b, answered by URIGOWNER (settled))\n'
	printf -- '- 2026-11-01T10:02Z magic-tester clarification: The rig drops the old port. (no source)\n'
	printf -- '- 2026-11-01T10:03Z magic-tester resolved: The rig is confirmed already. (readback rig-c, confirmed by URIGOWNER at 2026-11-01T10:03Z)\n'
	printf -- '- 2026-11-01T10:04Z magic-tester clarification: The rig long line keeps every word: word01 word02 word03 word04 word05 word06 word07 word08 word09 word10 word11 word12 word13 word14 word15 word16 word17 word18 word19 word20 word21 word22 word23 word24 word25 word26 word27 word28 word29 word30 word31 word32 word33 word34 word35 word36 word37 word38 word39 word40 word41 word42 word43 word44 word45 word46 word47 word48 word49 word50 word51 word52 word53 word54 word55 word56 word57 word58 word59. (no source)\n'
} > "$rigBoard/running/$rigRev.md"
rigRevLine(){ rigSection "$rigBoard/running/$rigRev.md" | LC_ALL=C grep -F -- "$1" | head -1 ; }
rigDecOp drev0 --record-decision --team-member "$rigMember" "$rigRev" --review --kind resolved --with human-owner
rigAssert "a review with --kind: refused"            "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken )" refused
rigDecOp drev1 --record-decision --team-member "$rigMember" "$rigRev" --review --with human-owner
rigRevId="$( rigAskedId drev1 )"
rigAssert "the list: each unconfirmed line with its action, the confirmed one left out" "$rigRc:$( LC_ALL=C awk -F'\t' '$1 == "understood" { print ( index( $0, "1. re-ask: magic-tester, clarification, 2026-11-01\\n> The rig keeps the red wire." ) ? "re-ask" : "-" ) ":" ( index( $0, "2. confirm: magic-tester, resolved, 2026-11-01" ) ? "confirm" : "-" ) ":" ( index( $0, "3. prune: magic-tester, clarification, 2026-11-01" ) ? "prune" : "-" ) ":" ( index( $0, "confirmed already" ) ? "listed" : "left" ) ":" ( index( $0, "(ask rig-" ) ? "raw" : "plain" ) ; }' "$rigStore/$rigRevId.fields" 2> /dev/null )" "0:re-ask:confirm:prune:left:plain"
rigAnswerAsked "edit: 3 confirm"
rigDecOp drev2 --intern-op-escalation-read magic-coordinator "$rigRevId"
rigAssert "edited: the withdrawn one struck and asked again, the settled and the edited one confirmed" "$( rigRevLine 'The rig keeps the red wire. (ask' | LC_ALL=C grep -c 'struck by magic-tester: asked again' ):$( rigRevLine 'The rig ships on Friday.' | LC_ALL=C grep -c -F "[confirmed by URIGOWNER: readback $rigRevId, at " ):$( rigRevLine 'The rig drops the old port.' | LC_ALL=C grep -c -F "[confirmed by URIGOWNER: readback $rigRevId, at " ):$( rigRevLine 'The rig is confirmed already.' | LC_ALL=C grep -c -F '[' )" "1:1:1:0"
rigAssert "the re-ask is a readback of its text"     "$( cat "$rigStore"/*.fields 2> /dev/null | LC_ALL=C grep -c -x -F "$( printf 'understood\tThe rig keeps the red wire.' )" )" 1
rigDecOp drev3 --intern-op-escalation-read magic-coordinator "$rigRevId"
rigAssert "a line longer than 300 characters is struck whole" "$( rigRevLine 'The rig long line keeps every word' | LC_ALL=C grep -c -F 'word59. (no source) [struck by magic-tester: pruned' )" 1
rigAssert "read again, it applies once"              "$( rigSection "$rigBoard/running/$rigRev.md" | LC_ALL=C grep -c 'struck by' ):$( rigSection "$rigBoard/running/$rigRev.md" | LC_ALL=C grep -c '\[confirmed by ' )" "2:2"
rigDecOp drev6 --record-decision --team-member magic-coordinator "$rigRev" --review --with human-owner
rigAssert "magic-coordinator reviews an item it is no party of" "$rigRc:$( LC_ALL=C grep -c -E '^DECISION-(ASKED|REVIEW-NONE) ' "$rigTmp/drev6" )" "0:1"
rigDecOp drev7 --record-decision --team-member keeper-myx "$rigRev" --review --with human-owner
rigAssert "a member that is no party of it reviews nothing" "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken )" refused
rigRev2="task-20261008T1901Z-rig-review-up"
{
	printf -- '---\ntype: task\nowner: magic-tester\n---\n\n# Rig review up\n\n## Decisions\n<!-- decisions-of: %s -->\n\n' "$rigRev2"
	printf -- '- 2026-11-01T11:00Z magic-tester clarification: The rig paints it blue. (no source)\n'
} > "$rigBoard/running/$rigRev2.md"
rigDecOp drev4 --record-decision --team-member "$rigMember" "$rigRev2" --review --with human-owner
rigRevUp="$( rigAskedId drev4 )"
rigDecOp drev5 --intern-op-pending-reply-close "$rigRevUp" --if-open --status reply-received --verdict yes --answered-by URIGCONTACT
rigRevNew="$( cat "$rigStore/$rigRevUp.fields" "$rigStore/closed/$rigRevUp.fields" 2> /dev/null | LC_ALL=C awk -F'\t' '$1 == "escalated" { print $2 ; exit ; }' )"
rigAssert "answered by one without rights: nothing changes, and the list goes up" "$( rigSection "$rigBoard/running/$rigRev2.md" | LC_ALL=C grep -c -F '[' ):$( [ -n "$rigRevNew" ] && rigField "$rigStore/$rigRevNew.md" item ):$( LC_ALL=C grep -c -F "$( printf 'understood\t1. prune: magic-tester, clarification, 2026-11-01' )" "$rigStore/$rigRevNew.fields" 2> /dev/null )" "0:$rigRev2:1"

echo
printf 'ITEM_DECISIONS: %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || { echo "⛔ ITEM DECISIONS CHECK FAILED" >&2 ; exit 1 ; }
