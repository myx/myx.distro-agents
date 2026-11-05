#!/usr/bin/env bash
## Behavioural check on answering a PLAIN QUESTION THAT CARRIES OPTIONS through the answer
## operation (--answer-escalation): an `AskQuestion` with `select=one` or `select=many` posts
## options a person clicks or names, so an option's first word is a verdict of that question as
## it is of a decision (AgentsTools.MemberEscalation.include, the `<kind>:<verdict>` arms).
##
## Held as four rows, each through the real operations:
##   A. `select: one`, answered `Ship`: the answer is applied, the record closes `reply-received`
##      with `ship`, and the question's thread gets one closing reply carrying that word.
##   B. The same question answered `sail`, a word no option names: refused as no verdict of it,
##      the record open, nothing posted. The options list is read, not any word.
##   C. `select: many`, answered `hold`: applied with `hold`.
##   D. A question with NO options file (`select: yes-no`): a bare word is refused exactly as
##      before, so the widening is held to the option list and a missing file is no fault.
##
## RED RECIPE, on the code before the fix: A and C are red. The only option-list arm was
## `decision:*`, so a `question` record's `.options` was never read, and every option word was
## refused at `is not a verdict of this question`. B and D pass on both trees: they are the
## control on what the widening must not accept.
##
## Offline: a Slack-shaped fake curl is first on PATH, a ps that lists the rig's own runs only is
## beside it, and every record, thread and workspace is this check's own under its temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTools"
for rigNeed in magic-tester magic-developer magic-coordinator ; do
	[ -r "${MDAT_SKILLSET_ROOT:-}/$rigNeed/$rigNeed.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigNeed"
done

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsQuestionOptionAnswerCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
## THE RIG'S OWN PROCESS LIST: a spawn is found running by its spawn id in the host's process list,
## so the ps first on PATH answers the whole-host listing from the rig's own list and hands every
## other call to the real ps.
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
chmod +x "$rigTmp/bin/ps"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] || rigRefuse "the rig's own ps is not first on PATH, so this check would read the host's process list"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHas(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in *"$2"*) printf yes ;; *) printf no ;; esac
}

## The rig workspace: a session rig-cow with the coordinator, the developer and the tester. The
## developer is the one every question below is addressed to, and it runs now.
rigWs="$rigTmp/ws"
rigData="$rigWs/DATA"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig-cow" "$rigWs/.local/agents/sessions/rig-cow" "$rigWs/.local/agents/pending" "$rigData/board/running"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'magic-developer:ws:workspace:Edit(/%s/**)\n' "$rigWs" > "$rigWs/.local/agents/permissions.registry"
rigHost="$( hostname -s 2>/dev/null || echo unknown )"
rigSpawnRecord(){ ## spawn id, owner, parent session id
	printf -- '---\nsession-id: rig-cow\nspawn-id: %s\n%shost: %s\nowner: %s\nstatus: spawn-started\n---\n\n# Spawn session\n' \
		"$1" "${3:+parent-spawn-id: $3$'\n'}" "$rigHost" "$2" > "$rigWs/.local/agents/spawned/rig-cow/$1.spawn.md"
}
rigSpawnRecord rig-coord magic-coordinator ""
rigSpawnRecord rig-dev magic-developer rig-coord
rigSpawnRecord rig-tester magic-tester rig-coord
printf '%s rig-run --session-id %s\n' "$(( 900000 + RANDOM ))" rig-dev >> "$RIG_PS_LIST"
## The session's own thread, which is not the thread any question below is asked in.
printf 'CRIG00001:1700000000.000900\n' > "$rigWs/.local/agents/sessions/rig-cow/session.thread"
RIG_CURL_LOG="$rigTmp/curl.log"
export RIG_CURL_LOG
: > "$RIG_CURL_LOG"

RIG_OP_AGENT=""
RIG_OP_SESSION=""
rigOp(){
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID \
		${RIG_OP_SESSION:+MDAT_SPAWN_SESSION_ID="$RIG_OP_SESSION"} ${RIG_OP_AGENT:+MDAT_SPAWN_AGENT="$RIG_OP_AGENT"} \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" RIG_SCENARIO="$rigTmp" bash "$rigTools" "$@" ) > "$rigTmp/op.out" 2> "$rigTmp/op.err"
}
rigField(){ ## file, field
	LC_ALL=C awk -F': ' -v wantField="$2" '$1 == wantField { print substr( $0, length( wantField ) + 3 ) ; exit ; }' "$1" 2>/dev/null
}
## A record closed by its answer moves to pending/closed/ (retention, T9), so both readers look in
## either store: a check that read the live folder alone would report a closed record as missing.
rigRecordFile(){ ## pending id
	if [ -f "$rigWs/.local/agents/pending/$1.md" ] ; then printf '%s' "$rigWs/.local/agents/pending/$1.md"
	else printf '%s' "$rigWs/.local/agents/pending/closed/$1.md" ; fi
}
rigStatus(){ LC_ALL=C sed -n 's/^status: //p' "$( rigRecordFile "$1" )" 2>/dev/null | head -1 ; }
rigVerdict(){ LC_ALL=C sed -n 's/^verdict: //p' "$( rigRecordFile "$1" )" 2>/dev/null | head -1 ; }
## Each question has a thread of its own, named by its number: 1700000000.0001<n>.
rigAskNo=0
rigThread=""
rigPend=""
rigAsk(){ ## addressee, select (may be empty), options (may be empty) -> rigPend, rigThread
	rigAskNo=$(( rigAskNo + 1 ))
	rigThread="1700000000.0001$( printf '%02d' "$rigAskNo" )"
	rigPend="$( printf '# Ask\n\nWhich way for the rig?\n' | ( cd "$rigWs" && env -u MDAT_SPAWN_AGENT MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" RIG_SCENARIO="$rigTmp" bash "$rigTools" \
		--intern-op-pending-reply-open magic-tester --to CRIG00001 --session-id rig-tester --kind question --address-to "$1" \
		${2:+--select "$2"} ${3:+--options "$3"} \
		--channel CRIG00001 --question-ts "$rigThread" --thread-ts "$rigThread" --addressees URIGOWNER --asking-accounts ' URIGSELF1 ' 2>/dev/null ) )"
	[ -n "$rigPend" ] || rigRefuse "no pending reply record could be opened"
}
## The posts made since a mark, as their numbers: the fake curl numbers each post it takes.
rigPostMark=0
rigMark(){ rigPostMark="$( cat "$rigTmp/posts" 2>/dev/null || printf 0 )" ; }
## How many of the posts made since the mark hold every text given.
rigNew(){ ## fixed text...
	local newNo newText newAll newCount=0 newLast
	newLast="$( cat "$rigTmp/posts" 2>/dev/null || printf 0 )"
	newNo="$rigPostMark"
	while [ "$newNo" -lt "$newLast" ] ; do
		newNo=$(( newNo + 1 ))
		[ -f "$rigTmp/post.$newNo" ] || continue
		newAll=1
		for newText in "$@" ; do LC_ALL=C grep -q -F -- "$newText" "$rigTmp/post.$newNo" || { newAll="" ; break ; } ; done
		[ -z "$newAll" ] || newCount=$(( newCount + 1 ))
	done
	printf '%s' "$newCount"
}
rigInThread(){ printf '"thread_ts":"%s"' "$1" ; }
rigAnswer(){ ## answering member, its session, verdict
	rigMark
	RIG_OP_AGENT="$1" RIG_OP_SESSION="$2" rigOp --answer-escalation "$1" "$rigPend" "$3"
}

echo "-- A. a question with one answer form: its option's first word is the answer --"
rigAsk magic-developer one $'ship: go on\nhold: wait\n'
rigAskA="$rigPend" ; rigThreadA="$rigThread"
rigAssert "the record is a question with a form, and its options beside it" \
	"$( rigField "$( rigRecordFile "$rigAskA" )" kind ):$( rigField "$( rigRecordFile "$rigAskA" )" select ):$( [ -f "$rigWs/.local/agents/pending/$rigAskA.options" ] && printf yes || printf no )" "question:one:yes"
rigAnswer magic-developer rig-dev Ship
rigAssert "A. the answer is applied"                       "$( rigHas "$rigTmp/op.out" "ESCALATION: $rigAskA answered" )" yes
rigAssert "A. with the option's own word as the verdict"   "$( rigHas "$rigTmp/op.out" "VERDICT: ship" )" yes
rigAssert "A. the record closes carrying that word"        "$( rigStatus "$rigAskA" ):$( rigVerdict "$rigAskA" )" "reply-received:ship"
rigAssert "A. one closing reply, in the question's thread, carrying the word" \
	"$( rigNew "$( rigInThread "$rigThreadA" )" ):$( rigNew "$( rigInThread "$rigThreadA" )" '`ship` by magic-developer' )" "1:1"
rigAssert "A. and nothing else was posted for that answer" "$( rigNew '"channel"' )" 1

echo "-- B. a word that is no option of that question is still refused --"
rigAsk magic-developer one $'ship: go on\nhold: wait\n'
rigAskB="$rigPend"
rigAnswer magic-developer rig-dev sail
rigAssert "B. it is refused as no verdict of that question" "$( rigHas "$rigTmp/op.err" "sail is not a verdict of this question" )" yes
rigAssert "B. the record stays open"                       "$( rigStatus "$rigAskB" )" reply-pending
rigAssert "B. and nothing is posted for it"                "$( rigNew '"channel"' )" 0

echo "-- C. a question with many answer form: its option's word is the answer --"
rigAsk magic-developer many $'ship: go on\nhold: wait\n'
rigAskC="$rigPend" ; rigThreadC="$rigThread"
rigAnswer magic-developer rig-dev hold
rigAssert "C. the answer is applied, with that word"        "$( rigHas "$rigTmp/op.out" "VERDICT: hold" )" yes
rigAssert "C. the record closes carrying that word"        "$( rigStatus "$rigAskC" ):$( rigVerdict "$rigAskC" )" "reply-received:hold"
rigAssert "C. one closing reply, in the question's thread, carrying the word" \
	"$( rigNew "$( rigInThread "$rigThreadC" )" ):$( rigNew "$( rigInThread "$rigThreadC" )" '`hold` by magic-developer' )" "1:1"

echo "-- D. a question with no options file: a bare word is still refused, and no fault is raised --"
rigAsk magic-developer yes-no ""
rigAskD="$rigPend"
rigAssert "D. the record has an answer form and no options file" \
	"$( rigField "$( rigRecordFile "$rigAskD" )" select ):$( [ -f "$rigWs/.local/agents/pending/$rigAskD.options" ] && printf yes || printf no )" "yes-no:no"
rigAnswer magic-developer rig-dev sail
rigAssert "D. it is refused as no verdict of that question" "$( rigHas "$rigTmp/op.err" "sail is not a verdict of this question" )" yes
rigAssert "D. no file-not-found fault is raised on the way" "$( rigHas "$rigTmp/op.err" 'No such file' )" no
rigAssert "D. the record stays open"                       "$( rigStatus "$rigAskD" )" reply-pending
rigAssert "D. and nothing is posted for it"                "$( rigNew '"channel"' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ QUESTION OPTION ANSWER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: an option word of a plain question is refused as no verdict of it, so its asker waits for an answer that never comes" >&2
	echo "  fix:  repair the option-list arm of --answer-escalation in sh-lib/questions/AgentsTools.MemberEscalation.include -- never the assertion" >&2
	exit 1
fi
printf 'QUESTION_OPTION_ANSWER: OK (%d assertions, offline)\n' "$rigPassCount"
