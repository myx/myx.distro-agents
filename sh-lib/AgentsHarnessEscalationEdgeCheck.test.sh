#!/usr/bin/env bash
## Edges of the refusal and escalation records beside AgentsHarnessPermissionCheck: the
## session's first event-track thread opened once under concurrent refusals, malformed
## planned allows reported once and never admitting, a backtick in a target kept out of
## the post's fence, an answer pinned to one session, and one answer applied when two
## race. Offline: a Slack-shaped fake curl, first on PATH, answers every request.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to record under"

rigTmp="$( mktemp -d -t AgentsHarnessEscalationEdgeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigHere/check-fixtures/harness-escalation-edge.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigScenarioDir=""
RIG_DATA_ROOT=""
rigStart(){ ## scenario directory name, event-track configured (yes|no)
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/IN" "$rigScenarioDir/ws/OUT"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	[ "$2" != "yes" ] || printf 'SLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n' >> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
## One served tool call; its output lands in the file named last.
rigTool(){ ## session id, tool, argument object, output file
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u MDAT_SESSION_UNATTENDED -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID \
		MDAT_SPAWN_SESSION_ID="$1" ${RIG_DATA_ROOT:+MDAT_DATA_ROOT="$RIG_DATA_ROOT"} RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" ) \
		> "$4" 2> "$4.err"
}
rigRefusalId(){ ## output file
	LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$1" | head -1
}
## Posts that carry text, and how many of them sit outside any thread.
rigPostsWith(){ ## fixed text
	local postCount=0 postFile
	for postFile in "$rigScenarioDir"/post.[0-9]* ; do
		[ -f "$postFile" ] || continue
		LC_ALL=C grep -q -F -- "$1" "$postFile" && postCount=$(( postCount + 1 ))
	done
	printf '%s' "$postCount"
}
rigTopLevelPosts(){
	local postCount=0 postFile
	for postFile in "$rigScenarioDir"/post.[0-9]* ; do
		[ -f "$postFile" ] || continue
		LC_ALL=C grep -q -F '"thread_ts"' "$postFile" || postCount=$(( postCount + 1 ))
	done
	printf '%s' "$postCount"
}
rigOp(){ ## caller session (may be empty), output file, operation and its arguments
	local opSession="$1" opOut="$2" ; shift 2
	( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID ${opSession:+MDAT_SPAWN_SESSION_ID="$opSession"} \
		MMDAPP="$rigScenarioDir/ws" RIG_SCENARIO="$rigScenarioDir" bash "$rigTools" "$@" ) > "$opOut" 2> "$opOut.err"
}

echo "-- two first refusals at once open one event-track thread --"
## The first post is answered a second late, so a thread opened outside the lock opens twice every round.
for rigRound in 1 2 3 ; do
	rigStart "race-$rigRound" yes
	: > "$rigScenarioDir/post-delay-first"
	rigTool "rig-race-$rigRound" Write "{\"path\":\"$rigScenarioDir/ws/OUT/a\",\"content\":\"x\"}" "$rigScenarioDir/out.a" &
	rigTool "rig-race-$rigRound" Write "{\"path\":\"$rigScenarioDir/ws/OUT/b\",\"content\":\"x\"}" "$rigScenarioDir/out.b" &
	wait
	rigThreadFile="$rigScenarioDir/ws/.local/agents/sessions/rig-race-$rigRound/event-track.thread"
	rigAssert "round $rigRound: two posts"               "$( LC_ALL=C grep -c '^chat.postMessage$' "$RIG_CURL_LOG" )" 2
	rigAssert "round $rigRound: one of them opens the thread" "$( rigTopLevelPosts )" 1
	rigAssert "round $rigRound: the thread is recorded once" "$( LC_ALL=C awk 'END { print NR ; }' "$rigThreadFile" 2>/dev/null || printf none )" 1
	rigThreadTs="$( sed -n 's/^[^:]*:\([0-9.]*\)$/\1/p' "$rigThreadFile" 2>/dev/null )"
	rigAssert "round $rigRound: the other post is in that thread" "$( rigPostsWith "\"thread_ts\":\"$rigThreadTs\"" )" 1
done

echo "-- malformed planned allows are reported once and never admit --"
rigStart planned yes
mkdir -p "$rigScenarioDir/ws/DATA/board/running"
rigOk="$rigScenarioDir/ws/OUT/ok"
rigBad="$rigScenarioDir/ws/OUT/bad"
printf -- '---\nstatus: dispatch-started\nowner: %s\nsession-id: rig-plan\nallows: rig-garbage,once:Write:%s:magic-coordinator:20260928T2200Z,session:Write:%s::20260928T2200Z,session:Write:%s:%s:20260928T2200Z,session:Write:%s:magic-coordinator:20260928T2200Z\n---\n\n# Dispatch\n' \
	"$rigMember" "$rigBad" "$rigBad" "$rigBad" "$rigMember" "$rigOk" > "$rigScenarioDir/ws/DATA/board/running/dispatch-rig.md"
RIG_DATA_ROOT="$rigScenarioDir/ws/DATA"
rigTool rig-plan Write "{\"path\":\"$rigBad\",\"content\":\"x\"}" "$rigScenarioDir/out.1"
rigAssert "the malformed entries admit nothing"        "$( [ -e "$rigBad" ] && printf written || printf refused )" refused
rigAssert "each malformed entry is reported"           "$( rigPostsWith 'Planned allow ignored for' )" 4
rigAssert "one says it is not the entry form"          "$( rigPostsWith 'is not <kind>:<tool>:<target>:<granted-by>:<time>' )" 1
rigAssert "one says its kind is once"                  "$( rigPostsWith 'its kind is once' )" 1
rigAssert "one says it names nobody"                   "$( rigPostsWith 'it names nobody who granted it' )" 1
rigAssert "one says it is self-signed"                 "$( rigPostsWith "signed by the session's own member" )" 1
rigTool rig-plan Write "{\"path\":\"$rigBad\",\"content\":\"x\"}" "$rigScenarioDir/out.2"
rigAssert "the same session is not told twice"         "$( rigPostsWith 'Planned allow ignored for' )" 4
rigTool rig-plan Write "{\"path\":\"$rigOk\",\"content\":\"x\"}" "$rigScenarioDir/out.3"
rigAssert "control: the well-formed entry admits its call" "$( LC_ALL=C sed -n '1s/^\(OK: wrote\).*/\1/p' "$rigScenarioDir/out.3" )" "OK: wrote"
RIG_DATA_ROOT=""

echo "-- a backtick in a target stays out of the post's fence --"
rigStart backtick yes
rigTickTarget="$rigScenarioDir/ws/OUT/a\`b"
rigTool rig-tick Write "{\"path\":\"$rigTickTarget\",\"content\":\"x\"}" "$rigScenarioDir/out"
rigTickId="$( rigRefusalId "$rigScenarioDir/out" )"
rigAssert "the refusal is posted"                      "$( rigPostsWith "$rigTickId" )" 1
rigAssert "the post carries the target escaped"        "$( rigPostsWith 'a%60b' )" 1
rigAssert "and no raw backtick of it"                  "$( rigPostsWith 'a`b' )" 0
rigAssert "the stored record keeps the target as requested" \
	"$( LC_ALL=C sed -n 's/^target: //p' "$rigScenarioDir/ws/.local/agents/sessions/rig-tick/$rigTickId.md" 2>/dev/null )" "$rigTickTarget"

echo "-- an answer pinned to one session, and two answers at once --"
rigStart answers no
rigAskPid=""
## A permission escalation to the coordinator, waiting in the background until answered.
rigAsk(){ ## target path
	## Earlier asks of this scenario stay pending once stopped, so only a new record is this ask's.
	local rigBefore=" $( cd "$rigScenarioDir/ws/.local/agents/pending" 2>/dev/null && printf '%s ' *.md ) "
	rigTool rig-asker Write "{\"path\":\"$1\",\"content\":\"x\"}" "$rigScenarioDir/refused"
	set -m
	rigTool rig-asker AskUserQuestion "{\"to\":\"magic-team\",\"question\":\"May this task write the refused file?\",\"address_to\":\"magic-coordinator\",\"kind\":\"permission\",\"refusal_id\":\"$( rigRefusalId "$rigScenarioDir/refused" )\",\"reason\":\"rig\",\"task_ref\":\"dispatch-rig\"}" "$rigScenarioDir/ask" &
	rigAskPid=$!
	set +m
	local waitLeft=20
	rigPending=""
	while [ -z "$rigPending" ] && [ "$waitLeft" -gt 0 ] ; do
		sleep 1 ; waitLeft=$(( waitLeft - 1 ))
		for rigPendingFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
			[ -f "$rigPendingFile" ] || continue
			case "$rigBefore" in *" ${rigPendingFile##*/} "*) continue ;; esac
			LC_ALL=C grep -q '^status: reply-pending$' "$rigPendingFile" || continue
			rigPending="${rigPendingFile##*/}" ; rigPending="${rigPending%.md}"
		done
	done
	[ -n "$rigPending" ] || rigRefuse "no pending escalation appeared, so no answer can be tested"
}
## Grant lines naming one refusal; no grants file is none.
rigGrantCount(){ ## refusal id
	[ -f "$rigScenarioDir/ws/.local/agents/sessions/rig-asker/grants" ] || { printf 0 ; return 0 ; }
	LC_ALL=C grep -c -F -- "$1" "$rigScenarioDir/ws/.local/agents/sessions/rig-asker/grants" || :
}
rigAskStop(){
	{ kill -TERM -- "-$rigAskPid" ; sleep 1 ; kill -KILL -- "-$rigAskPid" ; wait "$rigAskPid" ; } 2>/dev/null
}
rigAsk "$rigScenarioDir/ws/OUT/p"
rigPendingFile="$rigScenarioDir/ws/.local/agents/pending/$rigPending.md"
LC_ALL=C awk 'NR == 1 { print ; print "answerer-session: rig-pinned" ; next ; } { print ; }' "$rigPendingFile" > "$rigPendingFile.new" && mv "$rigPendingFile.new" "$rigPendingFile"
rigOp rig-coordinator "$rigScenarioDir/op" --member-escalation-answer magic-coordinator "$rigPending" allow-once
rigAssert "an answer from another session than the pinned one is refused" "$( LC_ALL=C grep -c 'may be answered only from session rig-pinned' "$rigScenarioDir/op.err" )" 1
rigAssert "and the record stays open"                  "$( LC_ALL=C grep -c '^status: reply-pending$' "$rigPendingFile" )" 1
rigOp rig-pinned "$rigScenarioDir/op" --member-escalation-answer magic-coordinator "$rigPending" allow-once
rigAssert "control: the pinned session's answer is applied" "$( LC_ALL=C grep -c "^ESCALATION: $rigPending answered" "$rigScenarioDir/op" )" 1
rigAskStop

## The claim held: an answer arriving while another is mid-apply is not applied.
rigAsk "$rigScenarioDir/ws/OUT/q"
rigPendingFile="$rigScenarioDir/ws/.local/agents/pending/$rigPending.md"
mkdir "${rigPendingFile%.md}.answered"
rigOp rig-coordinator "$rigScenarioDir/op" --member-escalation-answer magic-coordinator "$rigPending" allow-once
rigAssert "an answer while another holds the claim is not applied" "$( LC_ALL=C grep -c "^ESCALATION: $rigPending being-answered$" "$rigScenarioDir/op" )" 1
rigAssert "and no grant is written"                    "$( rigGrantCount "$( rigRefusalId "$rigScenarioDir/refused" )" )" 0
rmdir "${rigPendingFile%.md}.answered"
rigAskStop

## Two answers at once: one applies, one grant.
rigAsk "$rigScenarioDir/ws/OUT/r"
rigRaceRefusal="$( rigRefusalId "$rigScenarioDir/refused" )"
rigOp rig-coordinator "$rigScenarioDir/op.x" --member-escalation-answer magic-coordinator "$rigPending" allow-once &
rigAnswerX=$!
rigOp rig-coordinator "$rigScenarioDir/op.y" --member-escalation-answer magic-coordinator "$rigPending" allow-once &
rigAnswerY=$!
wait "$rigAnswerX" "$rigAnswerY" 2>/dev/null
rigAssert "of two answers at once, exactly one is applied" "$( cat "$rigScenarioDir/op.x" "$rigScenarioDir/op.y" | LC_ALL=C grep -c "^ESCALATION: $rigPending answered" )" 1
rigAssert "and exactly one grant is written"           "$( rigGrantCount "$rigRaceRefusal" )" 1
rigAskStop

echo "-- only a reply's first word is an answer: one anywhere else is never taken --"
## The reader alone, over one rendered reply: "<verdict>|<author>".
rigVerdictOf(){ ## kind, options, reply text
	printf '1700000001.000200 | URIGOWNER | %s\n' "$3" \
		| MDAT_VERDICT_KIND="$1" MDAT_VERDICT_OPTIONS="$2" MDAT_VERDICT_AUTHORS=URIGOWNER LC_ALL=C awk -f "$rigHere/AgentsEscalationVerdict.awk" | tr '\t' '|'
}
rigDecisionOptions="- alpha the first way"$'\n'"- beta the second way"
rigAssert "control: a first-word answer is classified"   "$( rigVerdictOf permission '' 'allow-once' )" "allow-once|URIGOWNER"
rigAssert "control: a first-word answer still wins"      "$( rigVerdictOf readback '' 'YES, SURE allow' )" "yes|URIGOWNER"
rigAssert "permission: an answer after other words is not taken" "$( rigVerdictOf permission '' 'YES, SURE allow-once' )" "UNCLASSIFIED|"
rigAssert "permission: an answer mid-sentence is not taken" "$( rigVerdictOf permission '' 'sure, allow-session please' )" "UNCLASSIFIED|"
rigAssert "readback: an answer after other words is not taken" "$( rigVerdictOf readback '' 'sure yes' )" "UNCLASSIFIED|"
rigAssert "readback: \"not correct\" is not a correction" "$( rigVerdictOf readback '' 'not correct, the host is rig-host' )" "UNCLASSIFIED|"
rigAssert "decision: an option after other words is not taken" "$( rigVerdictOf decision "$rigDecisionOptions" 'I pick beta' )" "UNCLASSIFIED|"
rigAssert "\"do not deny\" is not deny"                   "$( rigVerdictOf permission '' 'do not deny' )" "UNCLASSIFIED|"
rigAssert "\"don't allow-session\" grants nothing"        "$( rigVerdictOf permission '' "don't allow-session" )" "UNCLASSIFIED|"
rigAssert "\"not allow-once\" grants nothing"             "$( rigVerdictOf permission '' 'not allow-once' )" "UNCLASSIFIED|"
rigAssert "\"allow-once please\" is allow-once"           "$( rigVerdictOf permission '' 'allow-once please' )" "allow-once|URIGOWNER"
rigAssert "\"deny\" is deny"                              "$( rigVerdictOf permission '' 'deny' )" "deny|URIGOWNER"
rigAssert "decision: the option's first word answers"    "$( rigVerdictOf decision "$rigDecisionOptions" 'beta, the second way' )" "beta|URIGOWNER"
rigAssert "a reply naming no answer stays unclassified"  "$( rigVerdictOf permission '' 'YES, SURE allow' )" "UNCLASSIFIED|"
rigAssert "a reply naming two answers stays unclassified" "$( rigVerdictOf decision "$rigDecisionOptions" 'I pick alpha or beta' )" "UNCLASSIFIED|"
rigAssert "an answer inside a longer word is not named"  "$( rigVerdictOf permission '' 'reallow-once-ish' )" "UNCLASSIFIED|"

rigAssert "no request left this box"                   "$( cat "$rigTmp"/*/curl.log | LC_ALL=C awk '/^url:/ { hitCount++ ; } END { print hitCount + 0 ; }' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ESCALATION EDGE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ESCALATION_EDGE: OK (%d assertions, offline)\n' "$rigPassCount"
