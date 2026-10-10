#!/usr/bin/env bash
## Behavioural check on a board item's `## Decisions` (AgentsTools.ItemDecisions.include):
## --member-decision-record creates the section, then appends inside it ahead of a later
## heading; an ask records its item from task_ref, else from the session's `spawns:`; a
## closed ask writes its answer to that item and clears the blocker naming it, and leaves
## an unrelated blocker; an earlier answer is found by the same session's closed record or
## by the item's Decisions, and AskUserQuestion then posts nothing; a collect closes a
## question its Decisions answer; the spawn's conversation.md and a named-item scan show
## the Decisions first. Offline: a temp workspace and data root under .local/temp, no Slack.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsItemDecisionsCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigStore="$rigTmp/ws/.local/agents/pending"
rigBoard="$rigTmp/data/board"
mkdir -p "$rigStore" "$rigTmp/home" "$rigTmp/skills" "$rigTmp/bin" "$rigTmp/tmp" "$rigTmp/scenario" "$rigTmp/ws/.local/.agents" \
	"$rigTmp/ws/.local/agents/spawned/rig-spawn-1" "$rigTmp/ws/.local/agents/spawned/rig-spawn-1/input"
for rigState in backlog pending running review blocked parked processed archived retained ; do mkdir -p "$rigBoard/$rigState" ; done
## Nothing here should reach Slack; the Slack-shaped fake curl is first on PATH in case anything tries.
cp "${MDLT_ORIGIN}/myx/myx.distro-agents/sh-test/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
RIG_SCENARIO="$rigTmp/scenario"
RIG_CURL_LOG="$rigTmp/scenario/curl.log"
export PATH RIG_SCENARIO RIG_CURL_LOG
: > "$RIG_CURL_LOG"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigTmp/ws/.local/.agents/$rigMember.agent.env"

rigTask="task-20261008T1200Z-rig-decisions"
rigDispatch="dispatch-20261008T1201Z-spawn-proxy-1"
printf -- '---\ntype: task\nowner: magic-tester\ncondition: has the human-owner answered pending reply PENDING-ID?\nblocked-on: the vendor contract\n---\n\n# Rig task\n\nBody text.\n\n## Notes\n\nA later section.\n' > "$rigBoard/blocked/$rigTask.md"
printf -- '---\ntype: dispatch\nowner: magic-tester\n---\n\n# Rig dispatch\n' > "$rigBoard/running/$rigDispatch.md"
printf -- '---\nsession-id: rig-spawn-1\nowner: magic-tester\nstatus: spawn-succeeded\nspawns: %s\n---\n' "$rigDispatch" > "$rigTmp/ws/.local/agents/spawned/rig-spawn-1/rig-spawn-1.md"

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
	LC_ALL=C grep -q -F -- "$2" "$1" 2>/dev/null && printf yes || printf no
}
rigOp(){ ## output name, op, arguments... (stdin passes through); RIG_AGENT, when set, is the spawned session's member
	local opOut="$1" ; shift
	rigRc=0
	( cd "$rigTmp/ws" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" ${RIG_AGENT:+MDAT_SPAWN_AGENT="$RIG_AGENT"} \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" \
		bash "$rigTool" "$@" ) > "$rigTmp/$opOut" 2> "$rigTmp/$opOut.err" || rigRc=$?
}
rigField(){ ## file, field
	LC_ALL=C awk -v key="$2" 'NR > 1 && $0 == "---" { exit } index($0, key ": ") == 1 { print substr($0, length(key) + 3) ; exit }' "$1"
}
rigSection(){ ## item file -> its Decisions lines, in file order
	LC_ALL=C awk '/^## Decisions[ \t]*$/ { on = 1 ; next } on && /^##? / { on = 0 } on && /^- / { print }' "$1"
}
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ItemDecisions.include"

echo "-- helper: create, then append --"
rigOp rec1 --member-decision-record "$rigMember" "$rigTask.md" --kind clarification --text "The rig scope is the decisions helper only." --source 1700000009.000001
[ "$rigRc" = "0" ] || rigRefuse "the decision op failed: $( cat "$rigTmp/rec1.err" )"
rigAssert "it says recorded"                      "$( head -1 "$rigTmp/rec1" )" "DECISION-RECORDED $rigTask blocked"
rigAssert "the section is created"                "$( rigHolds "$rigBoard/blocked/$rigTask.md" '## Decisions' )" yes
rigAssert "with the line in its shape"            "$( rigSection "$rigBoard/blocked/$rigTask.md" | LC_ALL=C grep -c -E '^- [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}Z magic-tester clarification: The rig scope is the decisions helper only\. \(1700000009\.000001\)$' )" 1
rigAssert "the blockers are left"                 "$( rigField "$rigBoard/blocked/$rigTask.md" blocked-on )" "the vendor contract"
rigOp rec2 --member-decision-record "$rigMember" "$rigTask" --kind resolved --text "Second line."
rigAssert "a second line is appended"             "$( rigSection "$rigBoard/blocked/$rigTask.md" | wc -l | tr -d ' ' )" 2
rigAssert "after the first"                       "$( rigSection "$rigBoard/blocked/$rigTask.md" | tail -1 | LC_ALL=C sed 's/.* resolved: //' )" "Second line."
rigAssert "one section only"                      "$( LC_ALL=C grep -c '^## Decisions' "$rigBoard/blocked/$rigTask.md" )" 1
rigAssert "the read shows newest first"           "$( AgentsToolsDecisionsLines "$rigBoard/blocked/$rigTask.md" 30 | head -1 | LC_ALL=C sed 's/.* resolved: //' )" "Second line."
rigOp rec3 --member-decision-record "$rigMember" "$rigTask" --kind answer --text "not a member kind"
rigAssert "a member may not record an answer"     "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken )" refused
rigOp rec4 --member-decision-record "$rigMember" task-20261008T1300Z-missing --kind clarification --text "x"
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

echo "-- AskUserQuestion posts nothing for an answered question --"
( cd "$rigTmp/ws" && printf '%s' '{"to":"human-owner","address_to":"human-owner","question":"Should the rig keep the vendor contract clause?","wait":false}' \
	| env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT HOME="$rigTmp/home" TMPDIR="$rigTmp/tmp" MDAT_SPAWN_SESSION_ID=rig-session-a MMDAPP="$rigTmp/ws" \
		MDAT_SKILLSET_ROOT="${MDAT_SKILLSET_ROOT:-$rigTmp/skills}" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool AskUserQuestion ) > "$rigTmp/ask1" 2> "$rigTmp/ask1.err"
rigAssert "it reads received"                     "$( head -1 "$rigTmp/ask1" )" "ASK-RESULT: RECEIVED"
rigAssert "it says not asked again"               "$( rigHolds "$rigTmp/ask1" 'NOT ASKED AGAIN' )" yes
rigAssert "with the earlier answer"               "$( rigHolds "$rigTmp/ask1" 'keep it, signed off' )" yes
rigAssert "nothing was posted"                    "$( LC_ALL=C grep -c 'chat.postMessage' "$RIG_CURL_LOG" )" 0
rigAssert "no new record"                         "$( ls "$rigStore"/*.md | wc -l | tr -d ' ' )" 3

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
( cd "$rigTmp/ws" && env HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" bash -c '
	DistroAgentsTools(){ return 1 ; }
	MDSC_CMD=rig
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include"
	AgentsToolsSpawnConversationHistory "$MMDAPP/.local/agents/spawned/rig-spawn-1/input/conversation.md" magic-tester "CRIG00001:1700000002.000101" "$1"
' rig "$rigBoard/blocked/$rigTask.md" ) 2> /dev/null
rigConv="$rigTmp/ws/.local/agents/spawned/rig-spawn-1/input/conversation.md"
rigAssert "conversation.md shows the Decisions"   "$( rigHolds "$rigConv" "### Decisions (from $rigTask)" )" yes
rigAssert "ahead of the threads"                  "$( LC_ALL=C awk '/^### Decisions \(from / { d = NR } /^## Thread / { t = NR } END { print ( d && t && d < t ) ? "first" : "not first" }' "$rigConv" )" first
rigAssert "newest first"                          "$( LC_ALL=C awk '/^### Decisions \(from / { on = 1 ; next } on && /^- / { print ; exit }' "$rigConv" | LC_ALL=C grep -c ' answer: Q1 ' )" 1
rigAssert "never under a heading that collides"   "$( LC_ALL=C grep -c '^## Decisions' "$rigConv" )" 0
rigOp scan1 --intern-op-session-context-scan "$rigMember" --state blocked --all-types --item "$rigTask.md" --context rig
rigAssert "the named-item scan shows them"        "$( rigHolds "$rigTmp/scan1" "### Decisions (from $rigTask)" )" yes
rigAssert "right under the item heading"          "$( LC_ALL=C awk -v want="## blocked/$rigTask.md" '$0 == want { getline ; print ; exit }' "$rigTmp/scan1" | cut -c1-24 )" "### Decisions (from task"

echo "-- clarifications on an answer, and a withdrawn ask, reach the item --"
printf '1700000009.000200\tURIGOWNER\tonly the clause in section 4\n1700000009.000300\tURIGOWNER\tand keep the signature page\n' | rigOp clar1 --intern-op-pending-reply-clarify "$rigId1" --from-stdin
rigAssert "two are kept"                          "$( head -1 "$rigTmp/clar1" )" "CLARIFIED $rigId1 2"
rigAssert "on the record"                         "$( rigHolds "$rigStore/$rigId1.md" '- 1700000009.000200 URIGOWNER: only the clause in section 4' )" yes
rigAssert "as clarification lines on the item"    "$( rigSection "$rigBoard/blocked/$rigTask.md" | LC_ALL=C grep -c "URIGOWNER clarification: on $rigId1 (Q1): " )" 2
rigAssert "the record stays answered as it was"   "$( rigField "$rigStore/$rigId1.md" verdict )" "keep it, signed off"
printf '1700000009.000300\tURIGOWNER\tand keep the signature page\n' | rigOp clar2 --intern-op-pending-reply-clarify "$rigId1" --from-stdin
rigAssert "a message kept once is not kept twice" "$( head -1 "$rigTmp/clar2" ):$( rigSection "$rigBoard/blocked/$rigTask.md" | LC_ALL=C grep -c "clarification: on $rigId1 " )" "CLARIFIED $rigId1 0:2"
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
rigOp rec5 --member-decision-record "$rigMember" "$rigDispA" --kind clarification --text "The rig port is fixed for this task."
rigAssert "a member record on a dispatch: both"   "$( LC_ALL=C grep -c '^DECISION-RECORDED ' "$rigTmp/rec5" )/$( AgentsToolsDecisionsLines "$rigBoard/running/$rigTracked.md" 30 | LC_ALL=C grep -c 'port is fixed' )" 2/1

echo "-- only the item's own section: never a quoted copy --"
rigAssert "the brief's quotes are untouched"      "$( diff <( LC_ALL=C sed -n '/^## Brief/,/^## Result/p' "$rigTmp/dispA.before" ) <( LC_ALL=C sed -n '/^## Brief/,/^## Result/p' "$rigBoard/running/$rigDispA.md" ) > /dev/null && echo same || echo changed )" same
rigAssert "its own section is new, at the end"    "$( LC_ALL=C awk -v m="<!-- decisions-of: $rigDispA -->" '$0 == m { at = NR } END { print ( at > 0 ) ? "marked" : "none" }' "$rigBoard/running/$rigDispA.md" )" marked
rigAssert "the read takes no quoted line"         "$( AgentsToolsDecisionsLines "$rigBoard/running/$rigDispA.md" 30 | LC_ALL=C grep -c QUOTED )" 0
rigAssert "and both own lines"                    "$( AgentsToolsDecisionsLines "$rigBoard/running/$rigDispA.md" 30 | wc -l | tr -d ' ' )" 2
rigLegacy="task-20261008T1404Z-rig-legacy"
printf -- '---\ntype: task\nowner: magic-tester\n---\n\n# Rig legacy\n\n## Decisions\n\n- 2026-10-01T00:00Z someone answer: LEGACY-LINE\n\n## Notes\n\nlater\n' > "$rigBoard/running/$rigLegacy.md"
rigOp rec6 --member-decision-record "$rigMember" "$rigLegacy" --kind clarification --text "Appended to the legacy section."
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
rigOp fwd1 --magic-escalation-forward magic-coordinator 33333333-0000-0000-0000-000000000001
rigAssert "answered in Decisions: not forwarded"  "$( head -1 "$rigTmp/fwd1" )" "ESCALATION: 33333333-0000-0000-0000-000000000001 answered-earlier"
rigAssert "it prints the earlier answer"          "$( sed -n 2p "$rigTmp/fwd1" | cut -d' ' -f1-2 )/$( rigHolds "$rigTmp/fwd1" '-> option-b' )" "EARLIER-DECISION $rigTask/yes"
rigEsc 33333333-0000-0000-0000-000000000002 reply-received rig-session-g "" "verdict: option-a
answered-by: URIGOWNER
resolved-at: 2026-10-08 12:05 +0300
resolved-epoch: 1700000000
"
rigEsc 33333333-0000-0000-0000-000000000003 reply-pending rig-session-g "" ""
rigOp fwd2 --magic-escalation-forward magic-coordinator 33333333-0000-0000-0000-000000000003
rigAssert "answered in a closed record: not forwarded" "$( head -1 "$rigTmp/fwd2" )" "ESCALATION: 33333333-0000-0000-0000-000000000003 answered-earlier"
rigAssert "it prints that record's answer"        "$( sed -n 2p "$rigTmp/fwd2" )" "EARLIER-RECORD 33333333-0000-0000-0000-000000000002 | option-a | URIGOWNER | 2026-10-08 12:05 +0300"
rigAssert "nothing was posted, nothing recorded"  "$( LC_ALL=C grep -c 'chat.postMessage' "$RIG_CURL_LOG" )/$( LC_ALL=C grep -c '^forward-ts: ' "$rigStore/33333333-0000-0000-0000-000000000001.md" "$rigStore/33333333-0000-0000-0000-000000000003.md" | LC_ALL=C awk -F: '{ s += $NF } END { print s }' )" "$rigCurlBefore/0"
rigAssert "both stay open"                        "$( rigField "$rigStore/33333333-0000-0000-0000-000000000001.md" status )/$( rigField "$rigStore/33333333-0000-0000-0000-000000000003.md" status )" reply-pending/reply-pending

echo "-- who records: the item's own parties, as themselves --"
rigParty="task-20261008T1500Z-rig-parties"
printf -- '---\ntype: task\nowner: magic-tester\nreview-by: keeper-rev\nspawn-id: rig-spawn-p\nblocked-on: the rig gate\n---\n\n# Rig parties\n' > "$rigBoard/running/$rigParty.md"
mkdir -p "$rigTmp/ws/.local/agents/spawned/rig-spawn-p" "$rigTmp/ws/.local/agents/spawned/rig-spawn-q"
printf -- '---\nsession-id: rig-spawn-p\nowner: keeper-exec\nstatus: spawn-started\n---\n' > "$rigTmp/ws/.local/agents/spawned/rig-spawn-p/rig-spawn-p.md"
printf -- '---\nsession-id: rig-spawn-q\nowner: keeper-link\nstatus: spawn-started\nspawned-by: %s\n---\n' "$rigParty" > "$rigTmp/ws/.local/agents/spawned/rig-spawn-q/rig-spawn-q.md"
rigPartyLines(){ rigSection "$rigBoard/running/$rigParty.md" | wc -l | tr -d ' ' ; }
rigOp par1 --member-decision-record keeper-other "$rigParty" --kind clarification --text "not a party"
rigAssert "a member that is no party is refused"   "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigPartyLines ):$( LC_ALL=C grep -c 'is not the owner, executor or reviewer' "$rigTmp/par1.err" )" refused:0:1
rigOp par2 --member-decision-record keeper-other "$rigParty" --kind resolved --text "clearing it" --clears-blocker
rigAssert "and clears no blocker"                  "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigField "$rigBoard/running/$rigParty.md" blocked-on )" "refused:the rig gate"
rigOp par3 --member-decision-record keeper-rev "$rigParty" --kind clarification --text "by the reviewer"
rigAssert "its review-by reviewer records"         "$rigRc:$( rigPartyLines )" 0:1
rigOp par4 --member-decision-record keeper-exec "$rigParty" --kind clarification --text "by its spawned session's member"
rigAssert "its spawned session's member records"   "$rigRc:$( rigPartyLines )" 0:2
rigOp par5 --member-decision-record keeper-link "$rigParty" --kind resolved --text "by the executor" --clears-blocker
rigAssert "a spawn working it records and clears"  "$rigRc:$( rigPartyLines ):$( rigField "$rigBoard/running/$rigParty.md" blocked-on )" 0:3:
RIG_AGENT=keeper-other rigOp par6 --member-decision-record magic-tester "$rigParty" --kind clarification --text "naming the owner"
rigAssert "a session naming another member is refused" "$( [ "$rigRc" -ne 0 ] && echo refused || echo taken ):$( rigPartyLines ):$( LC_ALL=C grep -c 'this session acts as keeper-other' "$rigTmp/par6.err" )" refused:3:1
RIG_AGENT=magic-tester rigOp par7 --member-decision-record magic-tester "$rigParty" --kind clarification --text "the owner itself"
rigAssert "the owner's own session records"        "$rigRc:$( rigPartyLines )" 0:4

echo
printf 'ITEM_DECISIONS: %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || { echo "⛔ ITEM DECISIONS CHECK FAILED" >&2 ; exit 1 ; }
