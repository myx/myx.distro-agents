#!/usr/bin/env bash
## Behavioural check: a verdict with words. A reply that gives a verdict is not only a verdict:
## what the person wrote with it -- the rest of the line his answer stands on, every line under
## it, and each later reply of his in the thread -- reaches the asking member with the verdict,
## whole and in his words, and is kept on the record. The words never change the verdict: an
## allow with words after it is still that allow.
## Three parts. The verdict reader alone (AgentsEscalationVerdict.awk), every kind: asked for
## the words (MDAT_VERDICT_WORDS) it carries the rest of the verdict's line as "<verdict> --
## <words>"; not asked, as a process started before this still runs it, it prints the verdict
## as before. The read of an answer (--intern-op-escalation-read), every kind -- permission,
## permission set, proposal, review, readback, decision, and a question with each answer form:
## its result gives the verdict, the words on its line and each message the person wrote
## beside it, and the record keeps the three. Then the other paths an answer is taken on,
## through the tools: the ask's own close, the answer taken by Wait, a later reply arriving on
## Wait, and the collect of a question nobody waited on.
## Red recipe: take MDAT_VERDICT_WORDS out of AgentsToolsEscalationThreadVerdict, and every
## "the words on its line" assertion fails while every verdict still passes.
## Offline: a Slack-shaped fake curl is first on PATH, the process list is the rig's own, and
## everything runs in workspaces under this check's temp tree. Never the live team data.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTools" ] || rigRefuse "dispatcher not found at the origin this workspace resolves: $rigTools"
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
for rigNeed in magic-tester magic-developer magic-coordinator ; do
	[ -r "${MDAT_SKILLSET_ROOT:-}/$rigNeed/$rigNeed.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigNeed"
done
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessAskVerdictWordsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLivePids=""
trap 'rigProcSignalWithChildren TERM $rigLivePids ; chmod -R u+w "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT

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
## The words a person writes with his answer, on its line; the lines under it, one of them
## starting as a heading does; and a later reply of his.
rigWords='but only for the report'
rigUnder='# a note\nand tell me when done'
rigLaterText='one more thing\n# keep a copy'
rigOptions="alpha -- the unit checks"$'\n'"beta -- the lint"

echo "-- the verdict reader, every kind: asked for the words it carries them, the verdict is the same --"
rigVerdict(){ ## kind, select, the reply's first line, words wanted (1|empty) -> "<verdict>|<author>"
	printf '1700000001.000200 | URIGOWNER | %s\nand a line under it\n' "$3" | MDAT_VERDICT_WORDS="$4" MDAT_VERDICT_KIND="$1" MDAT_VERDICT_SELECT="$2" MDAT_VERDICT_OPTIONS="$rigOptions" MDAT_VERDICT_AUTHORS=URIGOWNER MDAT_VERDICT_ASKING=URIGSELF1 \
		LC_ALL=C awk -f "$rigHere/AgentsEscalationVerdict.awk" 2>&1 | LC_ALL=C tr '\t' '|' | LC_ALL=C cut -d'|' -f1-2
}
## kind | answer form | the reply's first line | its verdict | the verdict as a caller that does not ask for the words gets it
for rigRow in "permission||allow-once, $rigWords|allow-once|allow-once" "permission||deny, $rigWords|deny|deny" "permission-set||allow-set - $rigWords|allow-set|allow-set" \
	"proposal||approved, $rigWords|approved|approved -- $rigWords" "review||accept: $rigWords|accept|accept -- $rigWords" \
	"readback||yes, $rigWords|yes|yes" "readback||I confirm, $rigWords|yes|yes" "decision||beta, $rigWords|beta|beta" "decision||2 $rigWords|beta|beta" \
	"question|yes-no|yes, $rigWords|yes|yes" "question|one|beta, $rigWords|beta|beta" ; do
	IFS='|' read -r rigKind rigForm rigLine rigWant rigAsBefore <<< "$rigRow"
	rigAssert "$rigKind${rigForm:+ ($rigForm)} [$rigLine]: the verdict, and the words on its line" "$( rigVerdict "$rigKind" "$rigForm" "$rigLine" 1 )" "$rigWant -- $rigWords|URIGOWNER"
	rigAssert "$rigKind${rigForm:+ ($rigForm)} [$rigLine]: not asked for the words, the verdict as before" "$( rigVerdict "$rigKind" "$rigForm" "$rigLine" "" )" "$rigAsBefore|URIGOWNER"
done
rigAssert "a verdict with no word after it carries none" "$( rigVerdict permission "" 'allow-once' 1 ):$( rigVerdict decision "" 'beta.' 1 )" "allow-once|URIGOWNER:beta|URIGOWNER"
rigAssert "a selection of several is its whole line, and carries none" "$( rigVerdict question many 'alpha beta' 1 )" "alpha beta|URIGOWNER"
rigAssert "words never make a verdict of a reply that names none" "$( rigVerdict permission "" "sure, $rigWords" 1 )" "RETURNED|"

## THE RIG'S OWN PROCESS LIST AND SLACK, for the operations below. A spawn is found running by
## the host's process list: the ps first on PATH answers the whole-host listing from the rig's
## own list and hands every other call to the real ps. The fake curl opens no socket.
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
RIG_PS_REAL="$( command -v ps )" || rigRefuse "no ps on PATH to hand the other calls to"
RIG_PS_LIST="$rigTmp/ps.list"
export RIG_PS_REAL RIG_PS_LIST
: > "$RIG_PS_LIST"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "$RIG_PS_LIST" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "$RIG_PS_LIST" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "$RIG_PS_REAL" "$@"
RIGPS
chmod +x "$rigTmp/bin/curl" "$rigTmp/bin/ps"
rigPathBefore="$PATH"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] || rigRefuse "the rig's own ps is not first on PATH, so this check would read the host's process list"

## The workspace of the permission question and the Permission set: a session rig-set of three
## participants, a dispatch that tracks a task, the workspace registered as the place rig-ws.
rigWs="$rigTmp/ws"
rigData="$rigWs/DATA"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig-set" "$rigData/board/running" "$rigData/board/processed" "$rigWs/DEV" "$rigWs/ELSE"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'magic-developer:ws:workspace:Edit(/%s/DEV/**)\n' "$rigWs" > "$rigWs/.local/agents/permissions.registry"
printf '%s\t%s\t%s\t%s\t%s\n' rig-ws workspace read-write "$rigWs" workspace > "$rigWs/.local/agents/directories.registry"
rigHost="$( hostname -s 2>/dev/null || echo unknown )"
rigSetRecord(){ ## spawn id, owner, further header lines (may be empty)
	printf -- '---\nsession-id: rig-set\nspawn-id: %s\nowner: %s\nhost: %s\ndescription: rig\n%sstatus: spawn-started\n---\n\n# Spawn session\n' \
		"$1" "$2" "$rigHost" "${3:-}" > "$rigWs/.local/agents/spawned/rig-set/$1.md"
}
rigSetRecord rig-set magic-coordinator $'session-thread: CRIG00001:1700000000.000500\n'
rigSetRecord rig-set-dev magic-developer
rigSetRecord rig-set-tester magic-tester
printf '900001 rig-run --session-id rig-set-dev\n900002 rig-run --session-id rig-set-tester\n900003 rig-run --session-id rig-set\n' >> "$RIG_PS_LIST"
rigSetThree=( --participant magic-coordinator --participant magic-developer --participant magic-tester )
printf -- '---\nstatus: task\nowner: magic-developer\n---\n\n# Fix the vars loader\n\nThe loader drops a variable.\n' > "$rigData/board/running/task-rig-set.md"
printf -- '---\nstatus: dispatch-started\nowner: magic-developer\nsession-id: rig-set\ntracks: task-rig-set\n---\n\n# Spawn-proxy dispatch: magic-developer\n\n## Brief\n\nthe brief.\n' \
	> "$rigData/board/running/dispatch-rig-set.md"
RIG_CURL_LOG="$rigTmp/curl.log"
export RIG_CURL_LOG
: > "$RIG_CURL_LOG"

## One team operation as RIG_OP_AGENT in session RIG_OP_SESSION; out and err kept.
RIG_OP_AGENT=""
RIG_OP_SESSION=""
rigOp(){
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID \
		${RIG_OP_SESSION:+MDAT_SPAWN_SESSION_ID="$RIG_OP_SESSION"} ${RIG_OP_AGENT:+MDAT_SPAWN_AGENT="$RIG_OP_AGENT"} \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" RIG_SCENARIO="$rigTmp" bash "$rigTools" "$@" ) > "$rigTmp/op.out" 2> "$rigTmp/op.err"
}
rigField(){ ## pending id, field
	LC_ALL=C awk -F': ' -v wantField="$2" '$1 == wantField { print substr( $0, length( wantField ) + 3 ) ; exit ; }' "$rigWs/.local/agents/pending/$1.md" 2>/dev/null
}
rigGrantRead(){ ## member, session, tool, target -> the kind of the grant that allows it, or nothing
	rigOp --intern-op-permission-grant-read "$1" --session-id "$2" --tool "$3" --target "$4"
	LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*$/\1/p' "$rigTmp/op.out" | head -1
}
## A thread as Slack returns it: the question, with the clicks a scenario puts on it, then the
## later messages.
rigThreadOf(){ ## the question's ts, later messages (JSON objects, each a comma ahead; may be empty), clicks (a JSON list body; may be empty), the question's own text
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"%s"%s}%s],"has_more":false}\n' "$1" "${4:-the question}" "${3:+,\"reactions\":[$3]}" "$2" > "$rigTmp/replies.$1.json"
}
rigReplyOf(){ ## the question's ts, ts suffix, user, text as a JSON string body
	printf ',{"ts":"%s","user":"%s","text":"%s","thread_ts":"%s"}' "${1%.*}.$2" "$3" "$4" "$1"
}
rigClickOf(){ ## emoji name, user
	printf '{"name":"%s","count":1,"users":["%s"]}' "$1" "$2"
}
## What a read of one request says: whether it is answered or open, and its verdict line.
rigRead(){ ## reading member, pending id -> "<answered|open|...>:<verdict line or none>"
	rigOp --intern-op-escalation-read "$1" "$2"
	printf '%s:%s' "$( LC_ALL=C sed -n "s/^ESCALATION: $2 //p" "$rigTmp/op.out" | head -1 )" "$( LC_ALL=C grep -m1 '^VERDICT: ' "$rigTmp/op.out" || printf none )"
}

echo "-- the read of an answer, every kind: the verdict, the words on its line, and what he wrote beside it --"
## One request of a kind, opened as the asking tool leaves it, in a thread of its own.
rigOpen(){ ## kind, thread ts, further options of the open... -> the pending id
	local openKind="$1" openTs="$2"
	shift 2
	printf '# Question\n\nWhich?\n' | ( cd "$rigWs" && env -u MDAT_SPAWN_AGENT MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" RIG_SCENARIO="$rigTmp" bash "$rigTools" \
		--intern-op-pending-reply-open magic-tester --to CRIG00001 --session-id rig-set-tester --kind "$openKind" --address-to human-owner \
		--channel CRIG00001 --question-ts "$openTs" --thread-ts "$openTs" --addressees URIGOWNER --asking-accounts ' URIGSELF1 ' "$@" 2>/dev/null )
}
## The answer and the later reply, as the owner wrote them in the request's thread.
rigAnswered(){ ## the question's ts, the answer's first line
	rigThreadOf "$1" "$( rigReplyOf "$1" 000810 URIGOWNER "$2\\n$rigUnder" )$( rigReplyOf "$1" 000820 URIGOWNER "$rigLaterText" )" ""
}
## What a read of that request gives, and what its record keeps:
## "<verdict line>|<words line>|<how many of the two messages are given>|<record: verdict>|<record: words>|<how many of the two it keeps>".
rigReadWords(){ ## reading member, pending id, the question's ts
	local wordsA="${3%.*}.000810 URIGOWNER: # a note / and tell me when done" wordsB="${3%.*}.000820 URIGOWNER: one more thing / # keep a copy"
	rigOp --intern-op-escalation-read "$1" "$2"
	printf '%s|%s|%s|%s|%s|%s' "$( LC_ALL=C grep -m1 '^VERDICT: ' "$rigTmp/op.out" || printf none )" "$( LC_ALL=C grep -m1 '^VERDICT-TEXT: ' "$rigTmp/op.out" || printf none )" \
		"$( LC_ALL=C grep -c -x -F -e "CLARIFICATION: $wordsA" -e "CLARIFICATION: $wordsB" "$rigTmp/op.out" )" \
		"$( rigField "$2" verdict )" "$( rigField "$2" verdict-text )" \
		"$( LC_ALL=C grep -c -x -F -e "- $wordsA" -e "- $wordsB" "$rigWs/.local/agents/pending/$2.md" )"
}
rigTsNext=600
## kind | answer form | the answer's first word(s) | the verdict
for rigRow in 'readback||yes|yes' 'decision||beta|beta' 'question|yes-no|yes|yes' 'question|one|beta|beta' 'proposal||approved|approved' ; do
	IFS='|' read -r rigKind rigForm rigWord rigWant <<< "$rigRow"
	rigTsNext=$(( rigTsNext + 10 )) ; rigTs="1700000000.000$rigTsNext"
	rigId="$( rigOpen "$rigKind" "$rigTs" ${rigForm:+--select "$rigForm"} --options "$rigOptions" )"
	[ -n "$rigId" ] || rigRefuse "no $rigKind request could be opened"
	rigAnswered "$rigTs" "$rigWord, $rigWords"
	rigAssert "$rigKind${rigForm:+ ($rigForm)}: the verdict, the words on its line, both messages; and the record keeps the three" \
		"$( rigReadWords magic-tester "$rigId" "$rigTs" )" "VERDICT: $rigWant|VERDICT-TEXT: $rigWords|2|$rigWant|$rigWords|2"
done
rigTs="1700000000.000690"
rigId="$( rigOpen question "$rigTs" --select many --options "$rigOptions" )"
[ -n "$rigId" ] || rigRefuse "no question that takes several could be opened"
rigAnswered "$rigTs" "alpha beta"
rigAssert "question (many): the selection, no words on its line, both messages; and the record keeps them" \
	"$( rigReadWords magic-tester "$rigId" "$rigTs" )" "VERDICT: alpha beta|none|2|alpha beta||2"
## A permission: the allow with words after it is still the allow, and its grant is written.
rigTs="1700000000.000710"
rigOp --intern-op-permission-refusal-log magic-tester --session-id rig-set-tester --tool Write --target "$rigWs/ELSE/w1.txt" --reason rig
rigId="$( rigOpen permission "$rigTs" --refusal-id "$( LC_ALL=C sed -n 's/^\(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/op.out" | head -1 )" )"
[ -n "$rigId" ] || rigRefuse "no permission request could be opened"
rigAnswered "$rigTs" "allow-session, $rigWords"
rigAssert "permission: the allow, the words on its line, both messages; and the record keeps the three" \
	"$( rigReadWords magic-tester "$rigId" "$rigTs" )" "VERDICT: allow-session|VERDICT-TEXT: $rigWords|2|allow-session|$rigWords|2"
rigAssert "the words did not turn the allow into anything else: its grant is written" "$( rigGrantRead magic-tester rig-set-tester Write "$rigWs/ELSE/w1.txt" )" "session"
## A Permission set.
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-set
rigOp --magic-permission-set-request magic-coordinator dispatch-rig-set --entry "Read:$rigWs/SETW/**" --scope task --session-id rig-set "${rigSetThree[@]}"
RIG_OP_AGENT="" RIG_OP_SESSION=""
rigId="$( LC_ALL=C sed -n 's/^PERMISSION-SET: asked //p' "$rigTmp/op.out" )"
[ -n "$rigId" ] || rigRefuse "the rig's permission set request asked nothing: $( head -2 "$rigTmp/op.err" )"
rigTs="$( rigField "$rigId" question-ts )"
rigAnswered "$rigTs" "allow-set, $rigWords"
rigAssert "permission set: the allow, the words on its line, both messages; and the record keeps the three" \
	"$( rigReadWords magic-coordinator "$rigId" "$rigTs" )" "VERDICT: allow-set|VERDICT-TEXT: $rigWords|2|allow-set|$rigWords|2"
rigAssert "and its grants are written"                 "$( rigGrantRead magic-tester rig-set-tester Read "$rigWs/SETW/a.txt" )" "task"
rigAssert "no request of these left this box"              "$( LC_ALL=C awk '/^url:/ { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" )" 0

echo "-- the other paths an answer is taken on: the ask's own close, Wait, a later reply on Wait, the collect --"
## Each scenario in a workspace of its own, a served tool call at a time (AgentsUniversalHarness.sh --intern-tool).
rigToolDir="" ; rigToolWs="" ; rigToolName=""
rigToolStart(){ ## scenario name
	rigToolName="$1" ; rigToolDir="$rigTmp/tool-$1" ; rigToolWs="$rigToolDir/ws"
	mkdir -p "$rigToolWs/.local/.agents" "$rigToolWs/.local/agents" "$rigToolWs/IN" "$rigToolDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigToolWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigToolWs/.local/.agents/magic-tester.agent.env"
	RIG_CURL_LOG="$rigToolDir/curl.log"
	: > "$RIG_CURL_LOG"
	rigToolThread ""
}
rigToolThread(){ ## later messages (may be empty) -- the question's own thread, the question its root
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"the question"}%s],"has_more":false}\n' "$1" > "$rigToolDir/replies.json"
}
rigToolMsg(){ ## ts suffix, text
	printf ',{"ts":"1700000001.%s","user":"URIGOWNER","text":"%s","thread_ts":"1700000001.000101"}' "$1" "$2"
}
rigToolKilled=""
rigToolCall(){ ## guard seconds, tool, argument object
	local callPid callLeft="$1"
	rigToolKilled="no"
	set -m
	( cd "$rigToolWs" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_SPAWN_SESSION_ID="rig-words-$rigToolName" RIG_SCENARIO="$rigToolDir" MMDAPP="$rigToolWs" MDAT_SPAWN_AGENT=magic-tester MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigToolWs" --access-write-root "$rigToolWs/IN" ) > "$rigToolDir/out" 2> "$rigToolDir/err" &
	callPid=$!
	set +m
	while kill -0 "$callPid" 2>/dev/null && [ "$callLeft" -gt 0 ] ; do sleep 1 ; callLeft=$(( callLeft - 1 )) ; done
	if kill -0 "$callPid" 2>/dev/null ; then
		rigToolKilled="yes"
		{ kill -TERM -- "-$callPid" ; sleep 1 ; kill -KILL -- "-$callPid" ; wait "$callPid" ; } 2>/dev/null
	fi
	wait "$callPid" 2>/dev/null || :
}
rigToolRecord(){
	local recordFile
	for recordFile in "$rigToolWs/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] && { printf '%s' "$recordFile" ; return 0 ; }
	done
	printf '%s' "$rigToolDir/no-record"
}
rigToolField(){ ## field of the scenario's one record
	LC_ALL=C awk -v key="$1" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$( rigToolRecord )" 2>/dev/null || printf 'no-record'
}
## What the member reads and what the record keeps, of the answer and the later reply:
## "<verdict line>|<words line>|<how many of the five lines he wrote are in the output>|<record: verdict>|<record: words>|<how many of the two messages it keeps>".
rigToolWords(){ ## the answer's first line
	printf '%s|%s|%s|%s|%s|%s' "$( LC_ALL=C grep -m1 '^VERDICT: ' "$rigToolDir/out" || printf none )" "$( LC_ALL=C grep -m1 '^VERDICT-TEXT: ' "$rigToolDir/out" || printf none )" \
		"$( LC_ALL=C grep -c -x -F -e "1700000001.000200 | URIGOWNER | $1" -e '# a note' -e 'and tell me when done' -e '1700000001.000300 | URIGOWNER | one more thing' -e '# keep a copy' "$rigToolDir/out" )" \
		"$( rigToolField verdict )" "$( rigToolField verdict-text )" \
		"$( LC_ALL=C grep -c -x -F -e '- 1700000001.000200 URIGOWNER: # a note / and tell me when done' -e '- 1700000001.000300 URIGOWNER: one more thing / # keep a copy' "$( rigToolRecord )" )"
}
rigToolAnswer(){ ## the answer's first line -- the answer and the later reply in the thread
	rigToolThread "$( rigToolMsg 000200 "$1\\n$rigUnder" )$( rigToolMsg 000300 "$rigLaterText" )"
}
rigAsk='"to":"magic-team","address_to":"URIGOWNER"'
rigAskOptions='"options":"alpha -- the unit checks\nbeta -- the lint"'

## The ask's own close, a kind at a time.
rigToolStart close-decision
rigToolAnswer "beta, $rigWords"
rigToolCall 60 EscalateDecision "{$rigAsk,\"question\":\"Which check first?\",$rigAskOptions}"
rigAssert "the ask's own close, a decision: the verdict, the words on its line, every line he wrote; and the record keeps them" \
	"$rigToolKilled:$( rigToolWords "beta, $rigWords" )" "no:VERDICT: beta|VERDICT-TEXT: $rigWords|5|beta|$rigWords|2"
rigToolStart close-readback
rigToolAnswer "yes, $rigWords"
rigToolCall 60 ConfirmReadback "{$rigAsk,\"question\":\"Did I read it right?\",\"understood\":\"tag v1\",\"source\":\"the brief\",\"will_do\":\"tag it\"}"
rigAssert "the ask's own close, a readback: the same" \
	"$rigToolKilled:$( rigToolWords "yes, $rigWords" )" "no:VERDICT: yes|VERDICT-TEXT: $rigWords|5|yes|$rigWords|2"
rigToolStart close-question-one
rigToolAnswer "beta, $rigWords"
rigToolCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",\"select\":\"one\",$rigAskOptions}"
rigAssert "the ask's own close, a question that takes one: the same" \
	"$rigToolKilled:$( rigToolWords "beta, $rigWords" )" "no:VERDICT: beta|VERDICT-TEXT: $rigWords|5|beta|$rigWords|2"
rigToolStart close-permission
rigToolCall 60 Write '{"path":"/dev/null/rig-words/x","content":"x"}'
rigToolRefusal="$( LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$rigToolDir/out" | head -1 )"
[ -n "$rigToolRefusal" ] || rigRefuse "the rig produced no refusal to ask permission for"
rigToolAnswer "allow-once, $rigWords"
rigToolCall 60 RequestPermission "{$rigAsk,\"question\":\"May the rig write this file?\",\"refusal_id\":\"$rigToolRefusal\",\"reason\":\"the rig needs it\",\"task_ref\":\"dispatch-rig\"}"
rigAssert "the ask's own close, a permission: the allow with words after it is still the allow, and the words come with it" \
	"$rigToolKilled:$( rigToolWords "allow-once, $rigWords" )" "no:VERDICT: allow-once|VERDICT-TEXT: $rigWords|5|allow-once|$rigWords|2"
rigToolStart close-text
rigToolAnswer "keep it, $rigWords"
rigToolCall 60 AskQuestion "{$rigAsk,\"question\":\"May the rig keep its report file?\"}"
rigAssert "the ask's own close, a question that takes any text: the answer is his whole first line, and every line he wrote comes with it" \
	"$rigToolKilled:$( rigToolWords "keep it, $rigWords" )" "no:none|none|5|keep it, $rigWords|none|2"

## The answer taken by Wait, then a later reply arriving on Wait.
rigToolStart wait-decision
rigToolCall 30 EscalateDecision "{$rigAsk,\"question\":\"Which check first?\",$rigAskOptions,\"wait\":false}"
rigToolThread "$( rigToolMsg 000200 "beta, $rigWords\\n$rigUnder" )"
rigToolCall 60 Wait '{"mode":"continue"}'
rigAssert "the answer taken by Wait: the verdict, the words on its line and the lines under it, in what the member reads and on the record" \
	"$rigToolKilled:$( LC_ALL=C grep -m1 '^VERDICT: ' "$rigToolDir/out" ):$( LC_ALL=C grep -m1 '^VERDICT-TEXT: ' "$rigToolDir/out" ):$( LC_ALL=C grep -c -x -F -e "1700000001.000200 | URIGOWNER | beta, $rigWords" -e '# a note' -e 'and tell me when done' "$rigToolDir/out" ):$( rigToolField verdict ):$( rigToolField verdict-text )" \
	"no:VERDICT: beta:VERDICT-TEXT: $rigWords:3:beta:$rigWords"
rigToolThread "$( rigToolMsg 000200 "beta, $rigWords\\n$rigUnder" )$( rigToolMsg 000300 "$rigLaterText" )"
rigToolCall 60 Wait '{"mode":"continue"}'
rigAssert "a later reply of his arriving on Wait: it reaches the member whole, as a clarification, and is kept" \
	"$rigToolKilled:$( LC_ALL=C grep -c -x -F 'ASK-RESULT: CLARIFIED' "$rigToolDir/out" ):$( LC_ALL=C grep -x -F -e '1700000001.000300 | URIGOWNER | one more thing' -e '# keep a copy' "$rigToolDir/out" | LC_ALL=C sort -u | LC_ALL=C grep -c . ):$( LC_ALL=C grep -c -x -F -e '- 1700000001.000200 URIGOWNER: # a note / and tell me when done' -e '- 1700000001.000300 URIGOWNER: one more thing / # keep a copy' "$( rigToolRecord )" )" \
	"no:1:2:2"

## The collect of a question nobody waited on: what it prints is what the member is given.
rigToolCollect(){
	( cd "$rigToolWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY \
		RIG_SCENARIO="$rigToolDir" MMDAPP="$rigToolWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigToolDir/data" \
		bash "$rigTools" --intern-op-pending-reply-collect --session-id "rig-words-$rigToolName" ) > "$rigToolDir/out" 2> "$rigToolDir/collect.err"
}
rigToolStart collect-question-one
rigToolCall 30 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",\"select\":\"one\",$rigAskOptions,\"wait\":false}"
rigToolAnswer "beta, $rigWords"
rigToolCollect
rigAssert "the collect, a question that takes one: answered with the verdict, and the words and both messages come with it" \
	"$( LC_ALL=C grep -c '^ANSWERED .* | beta$' "$rigToolDir/out" ):$( LC_ALL=C grep -c -x -F -e "  VERDICT-TEXT: $rigWords" -e '  CLARIFICATION: 1700000001.000200 URIGOWNER: # a note / and tell me when done' -e '  CLARIFICATION: 1700000001.000300 URIGOWNER: one more thing / # keep a copy' "$rigToolDir/out" ):$( rigToolField verdict ):$( rigToolField verdict-text )" \
	"1:3:beta:$rigWords"
rigToolStart collect-text
rigToolCall 30 AskQuestion "{$rigAsk,\"question\":\"May the rig keep its report file?\",\"wait\":false}"
rigToolAnswer "keep it, $rigWords"
rigToolCollect
rigAssert "the collect, a question that takes any text: answered with his whole first line, and both messages come with it" \
	"$( LC_ALL=C grep -c -F " | keep it, $rigWords" "$rigToolDir/out" ):$( LC_ALL=C grep -c -x -F -e '  CLARIFICATION: 1700000001.000200 URIGOWNER: # a note / and tell me when done' -e '  CLARIFICATION: 1700000001.000300 URIGOWNER: one more thing / # keep a copy' "$rigToolDir/out" ):$( rigToolField verdict )" \
	"1:2:keep it, $rigWords"
rigAssert "no request of these left this box"              "$( cat "$rigTmp"/tool-*/curl.log 2> /dev/null | LC_ALL=C awk '/^url:/ { hitCount++ ; } END { print hitCount + 0 ; }' )" 0

echo "-- a review prompt: the verdict, and everything he wrote with it --"
## The review prompt has a rig of its own (AgentsReviewPromptCheck.test.sh): a board, the
## session that hands back, a fake console, and every command guarded to this check's tree.
PATH="$rigPathBefore"
export PATH
revFixture="$rigTest/check-fixtures/review-prompt.curl.stub.sh"
[ -f "$revFixture" ] || rigRefuse "the fake curl fixture of the review prompt is missing: $revFixture"
mkdir -p "$rigTmp/revbin"
cp "$revFixture" "$rigTmp/revbin/curl" && chmod +x "$rigTmp/revbin/curl" || rigRefuse "could not install the fake curl of the review prompt"
revDir="" ; revWs="" ; revData="" ; revSpawn="" ; revItem=""
revEnv=()
revRun(){ ## result file, command...
	local runOut="$1" ; shift
	env -i HOME="$revDir" PATH="$rigTmp/revbin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$revWs" MDAT_DATA_ROOT="$revData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_SCENARIO="$revDir" RIG_CURL_LOG="$revDir/curl.log" "${revEnv[@]+"${revEnv[@]}"}" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ "$( command -v curl )" = "$RIG_TMP/revbin/curl" ] || exit 98
			cd "$MMDAPP" && exec "$@"
		' rig "$@" > "$runOut" 2>&1
	printf '%s' "$?" > "$runOut.rc"
}
revAsChild(){ ## result file, DistroAgentsTools.fn.sh args... -- as the session that handed back
	local childOut="$1" ; shift
	revEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID="$revSpawn" )
	revRun "$childOut" bash "$rigTools" "$@"
	revEnv=()
}
## One review prompt, asked of the human-owner by a handback of keeper-myx.
revStart(){ ## scenario name
	local startMember
	revDir="$rigTmp/review-$1" ; revWs="$revDir/ws" ; revData="$revDir/data"
	revSpawn="rig-child-$1" ; revItem="dispatch-20261012T0100Z-$1"
	mkdir -p "$revData/board/running" "$revData/board/review" "$revData/board/processed" "$revData/board/pending" \
		"$revWs/.local/.agents" "$revWs/.local/agents/spawned/$revSpawn" "$revWs/.local/agents/sessions/$revSpawn"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$revWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-KEEPER\n' > "$revWs/.local/.agents/keeper-myx.agent.env"
	for startMember in magic-coordinator keeper-myx magic-tester human-owner ; do
		mkdir -p "$revWs/.local/agents/members/$startMember"
		printf -- '---\nname: %s\ndescription: rig member\n---\n' "$startMember" > "$revWs/.local/agents/members/$startMember/SKILL.md"
		printf 'rig\n' > "$revWs/.local/agents/members/$startMember/$startMember.basic.md"
	done
	printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat >> "$RIG_TMP/console-in.$MDAT_SPAWN_SESSION_ID"\necho rig-child-output\nexit 0\n' > "$revWs/DistroAgentsConsole.sh"
	chmod +x "$revWs/DistroAgentsConsole.sh"
	: > "$revDir/curl.log"
	printf -- '---\ntype: task\nowner: keeper-myx\n---\n\n# Rework the rig widget\n\nThe widget drops its last line.\n' > "$revData/board/running/task-20261012T0000Z-$1.md"
	printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\nspawn-id: %s\ntracks: task-20261012T0000Z-%s\nreview-by: human-owner\n---\n\n# rig dispatch\n' \
		"$revSpawn" "$1" > "$revData/board/running/$revItem.md"
	printf -- '---\nsession-id: 5e55104a-rig-%s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: spawn-started\nsession-thread: CSES00001:1700000000.000100\nspawns: %s\ndescription: rework the rig widget\n---\n' \
		"$1" "$revSpawn" "$revSpawn" "$rigHost" "$revItem" > "$revWs/.local/agents/spawned/$revSpawn/$revSpawn.md"
	: > "$revDir/transcript.log"
	printf '%s\n' "$revDir/transcript.log" > "$revWs/.local/agents/sessions/$revSpawn/transcript"
	bash -c 'sleep 600 ; :' "$revSpawn" > /dev/null 2>&1 < /dev/null &
	rigLivePids="$rigLivePids $!" ; rigProcNote "$!"
	disown "$!" 2> /dev/null || :
	revAsChild "$revDir/handback" --intern-op-review-handback keeper-myx --session-id "$revSpawn" --message "rig work done"
}
revRecord(){ ls -tr "$revWs/.local/agents/pending"/*.md 2> /dev/null | tail -1 ; }
revId(){ local idFile ; idFile="$( revRecord )" ; idFile="${idFile##*/}" ; printf '%s' "${idFile%.md}" ; }
revField(){ ## field
	LC_ALL=C awk -v key="$1" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$( revRecord )" 2> /dev/null || printf 'no-record'
}
revLoc(){ ## -- the board state holding the scenario's item
	local stateDir
	for stateDir in "$revData"/board/*/ ; do
		[ -f "$stateDir$revItem.md" ] && { basename "$stateDir" ; return 0 ; }
	done
	printf 'not-found'
}
## The prompt's own thread: the prompt with the tooling's own three emoji and a scenario's
## clicks, then the replies.
revThread(){ ## clicks (JSON objects, each a comma ahead; may be empty), replies (the same; given the prompt's ts as %s)
	local threadTs
	threadTs="$( revField question-ts )"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"the prompt","reactions":[{"name":"+1","count":1,"users":["URIGBOT01"]},{"name":"leftwards_arrow_with_hook","count":1,"users":["URIGBOT01"]},{"name":"x","count":1,"users":["URIGBOT01"]}%s]}%s],"has_more":false}\n' \
		"$threadTs" "$1" "$( printf "$2" "$threadTs" )" > "$revDir/replies.$threadTs.json"
}
## The read of the prompt's answer, as the Wait of the session that handed back makes it:
## "<the verdict line or none>:<where the item is>:<the record's status>".
revRead(){
	revAsChild "$revDir/read" --intern-op-escalation-read keeper-myx "$( revId )"
	printf '%s:%s:%s' "$( LC_ALL=C grep -m1 '^VERDICT: ' "$revDir/read" 2> /dev/null || printf none )" "$( revLoc )" "$( revField status )"
}
revStart words
[ "$( revField kind ):$( revLoc )" = "review:review" ] || rigRefuse "the rig's handback asked for no review: $( head -3 "$revDir/handback" )"
revThread '' ",{\"ts\":\"1700000002.000001\",\"user\":\"URIGOWNER\",\"text\":\"accept, $rigWords\\\\n# a note\\\\nand tell me when done\",\"thread_ts\":\"%s\"},{\"ts\":\"1700000002.000002\",\"user\":\"URIGOWNER\",\"text\":\"one more thing\\\\n# keep a copy\"}"
rigAssert "the accept with words after it is the accept, and the item is processed" "$( revRead )" "VERDICT: accept:processed:reply-received"
rigAssert "its words are everything he wrote with it, the line that starts as a heading too" \
	"$( LC_ALL=C grep -m1 '^VERDICT-TEXT: ' "$revDir/read" )" "VERDICT-TEXT: $rigWords / # a note / and tell me when done / one more thing / # keep a copy"
rigAssert "each message he wrote beside the verdict is given, and kept on the record" \
	"$( LC_ALL=C grep -c -x -F -e 'CLARIFICATION: 1700000002.000001 URIGOWNER: # a note / and tell me when done' -e 'CLARIFICATION: 1700000002.000002 URIGOWNER: one more thing / # keep a copy' "$revDir/read" ):$( LC_ALL=C grep -c -x -F -e '- 1700000002.000001 URIGOWNER: # a note / and tell me when done' -e '- 1700000002.000002 URIGOWNER: one more thing / # keep a copy' "$( revRecord )" )" "2:2"
rigAssert "no request of these left this box either"       "$( cat "$rigTmp"/review-*/curl.log 2> /dev/null | LC_ALL=C awk '/^url:/ { hitCount++ ; } END { print hitCount + 0 ; }' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK VERDICT WORDS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ASK_VERDICT_WORDS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
