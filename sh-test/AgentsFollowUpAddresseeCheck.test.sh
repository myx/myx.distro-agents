#!/usr/bin/env bash
## Behavioural check on who the tooling's own follow-ups are addressed to, run rather than
## read. A follow-up of an ask carries the addressee of that ask, by name, in the one shape
## the member send gives a named addressee, whatever conversation it stands in: the
## confirmation of an answer, read from Slack or given through the team operation; the note
## that a question is withdrawn; the note that a review is settled another way. In the
## thread of a forward it is the human-owner, whom the forward was addressed to. An answer
## given through the team operation gets that one confirmation, and the answering member
## posts no line of its own beside it. The line that tells a Permission set is answered is addressed to
## the participants of the set, each one the send can address. A record that names nobody
## leaves the post as it always was, and no follow-up is lost over a name.
## Offline: the Slack-shaped fake curl is first on PATH, the skillset is a fixture, and
## everything runs in a workspace under the workspace's .local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
## The member that asks, the member asked, two participants, and a name no member carries.
rigAsker="rig-asker"
rigAnswerer="rig-answerer"
rigGhost="rig-ghost"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsFollowUpAddresseeCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigStore="$rigWs/.local/agents/pending"
mkdir -p "$rigStore" "$rigWs/.local/.agents" "$rigTmp/home" "$rigTmp/data" "$rigTmp/bin" "$rigTmp/skills"
for rigName in "$rigAsker" "$rigAnswerer" rig-part-a rig-part-b human-owner magic-coordinator ; do
	mkdir -p "$rigTmp/skills/$rigName"
	printf '%s\n' "$rigName" > "$rigTmp/skills/$rigName/$rigName.basic.md"
done
cp "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## Each scenario keeps its own posts, numbered from 1.
rigStart(){ ## scenario directory name
	RIG_SCENARIO="$rigTmp/$1"
	RIG_CURL_LOG="$RIG_SCENARIO/curl.log"
	export RIG_SCENARIO RIG_CURL_LOG
	mkdir -p "$RIG_SCENARIO"
	: > "$RIG_CURL_LOG"
}
## One team operation. RIG_AGENT and RIG_SESSION, when set, are the spawned session it comes
## from; unset, it comes from the console.
RIG_AGENT=""
RIG_SESSION=""
rigOp(){ ## operation and its arguments -- stdin is passed on
	( cd "$rigWs" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD \
		HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" \
		${RIG_AGENT:+MDAT_SPAWN_AGENT="$RIG_AGENT"} ${RIG_SESSION:+MDAT_SPAWN_SESSION_ID="$RIG_SESSION"} \
		bash "$rigTool" "$@" ) > "$RIG_SCENARIO/op.out" 2> "$RIG_SCENARIO/op.err"
}
## An in-context helper, with no operation of its own, as a script for --intern-mcp-execute,
## which runs it inside the tool's own set-up context: its include, then the call.
rigHelper(){ ## include, function, arguments...
	{
		printf '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/%s"\n' "$1"
		printf '%s' "$2" ; shift 2
		[ $# -eq 0 ] || printf ' %q' "$@"
		printf '\n'
	} | rigOp --intern-mcp-execute
}
## An ask on record as the tools that ask leave it, posted in a thread of its own. Prints its id.
rigAsk(){ ## kind, address-to (empty for none), thread ts, further options of the open operation...
	local askKind="$1" askTo="$2" askTs="$3" ; shift 3
	printf '# Question\n\nMay the rig go on?\n' | rigOp --intern-op-pending-reply-open "$rigAsker" --to DRIGASK01 --session-id rig-ask-run --kind "$askKind" \
		${askTo:+--address-to "$askTo"} --channel DRIGASK01 --question-ts "$askTs" --thread-ts "$askTs" --asking-accounts ' URIGSELF1 ' --ask-identity bot "$@"
	LC_ALL=C sed -n '1p' "$RIG_SCENARIO/op.out"
}
## A thread as Slack returns it: the question, then what else a scenario puts in it.
rigThread(){ ## thread ts, further messages (a JSON list body, may be empty)
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"the question"}%s],"has_more":false}\n' "$1" "${2:+,$2}" > "$RIG_SCENARIO/replies.$1.json"
}
## The posts of the scenario that hold a text: how many, and of the first of them its header,
## the first line of its text as the member send wrote it, and the thread it went into.
rigPostOf(){ ## fixed text
	local postFile
	for postFile in "$RIG_SCENARIO"/post.[0-9]* ; do
		[ -f "$postFile" ] && LC_ALL=C grep -q -F -- "$1" "$postFile" || continue
		printf '%s\n' "$postFile"
	done
}
rigCount(){ ## fixed text
	rigPostOf "$1" | LC_ALL=C awk 'END { print NR + 0 ; }'
}
rigHeader(){ ## fixed text
	local headerFile
	headerFile="$( rigPostOf "$1" | LC_ALL=C sed -n '1p' )"
	[ -n "$headerFile" ] || { printf 'not-posted' ; return 0 ; }
	LC_ALL=C awk -v path=text -v optional=1 -f "$rigHere/AgentsHarnessJsonField.awk" < "$headerFile" 2>/dev/null | LC_ALL=C sed -n '1p'
}
rigThreadOf(){ ## fixed text
	local threadFile
	threadFile="$( rigPostOf "$1" | LC_ALL=C sed -n '1p' )"
	[ -n "$threadFile" ] || { printf 'not-posted' ; return 0 ; }
	LC_ALL=C awk -v path=thread_ts -v optional=1 -f "$rigHere/AgentsHarnessJsonField.awk" < "$threadFile" 2>/dev/null
}
## The header the member send writes, with no row in the names registry: each member by its
## member name, said once, with the default icon of its prefix group, which for a member of
## this rig is the one of a member of no listed group.
rigTo(){ ## from, the addressees as the header says them
	printf '🤖 *_%s_* → %s.' "$1" "$2"
}
rigNamed(){ ## member
	printf '🤖 *_%s_*' "$1"
}
## The human-owner as the send names him, which is the header of every ask addressed to him.
rigOwner='👤 *_human-owner_* <@URIGOWNER>'

echo "-- the note that a question is withdrawn carries the addressee of the question --"
rigStart withdrawOwner
rigId="$( rigAsk question human-owner 1700000001.000101 )"
[ -n "$rigId" ] || rigRefuse "no ask could be put on record, so nothing below would be measured: $( head -2 "$RIG_SCENARIO/op.err" )"
RIG_AGENT="$rigAsker" rigOp --member-pending-reply-settle "$rigAsker" "$rigId" --reason "the task was cancelled" --withdraw
LC_ALL=C grep -q -x -F "WITHDRAWN $rigId" "$RIG_SCENARIO/op.out" || rigRefuse "the withdraw never answered: $( head -2 "$RIG_SCENARIO/op.err" )"
rigAssert "asked of the human-owner: one note, in the thread of the question, addressed to him by name" \
	"$( rigCount "Withdrawn by $rigAsker: the task was cancelled" ):$( rigThreadOf 'Withdrawn by' ):$( rigHeader 'Withdrawn by' )" "1:1700000001.000101:$( rigTo "$rigAsker" "$rigOwner" )"
rigStart withdrawMember
rigId="$( rigAsk question "$rigAnswerer" 1700000001.000201 )"
RIG_AGENT="$rigAsker" rigOp --member-pending-reply-settle "$rigAsker" "$rigId" --reason "asked the wrong member" --withdraw
rigAssert "asked of a member: addressed to that member"             "$( rigCount 'Withdrawn by' ):$( rigHeader 'Withdrawn by' )" "1:$( rigTo "$rigAsker" "$( rigNamed "$rigAnswerer" )" )"
rigStart withdrawNobody
rigId="$( rigAsk question "" 1700000001.000301 )"
RIG_AGENT="$rigAsker" rigOp --member-pending-reply-settle "$rigAsker" "$rigId" --reason "no longer needed" --withdraw
rigAssert "a record that names nobody: the note is posted as it always was" "$( rigCount 'Withdrawn by' ):$( rigHeader 'Withdrawn by' )" "1:$( rigTo "$rigAsker" '@here' )"

echo "-- an answer given through the team operation: its confirmation, and no line of the answering member's own --"
rigStart answerMember
rigId="$( rigAsk readback "$rigAnswerer" 1700000002.000101 )"
RIG_AGENT="$rigAnswerer" RIG_SESSION=rig-answer-run rigOp --member-escalation-answer "$rigAnswerer" "$rigId" yes
[ "$( rigCount 'Read: `yes`' )" != 0 ] || rigRefuse "the answer was not said in the thread at all, so there is no header to read: $( LC_ALL=C grep -m1 ERROR "$RIG_SCENARIO/op.err" )"
rigAssert "the confirmation, the asker's: addressed to the member asked, as the question was" \
	"$( rigCount 'Read: `yes` by '"$rigAnswerer" ):$( rigThreadOf 'Read: `yes`' ):$( rigHeader 'Read: `yes`' )" "1:1700000002.000101:$( rigTo "$rigAsker" "$( rigNamed "$rigAnswerer" )" )"
rigAssert "one answer, one reply: the member that answered posts no line of its own beside the confirmation" \
	"$( rigCount 'Answered by' ):$( LC_ALL=C grep -c '^chat.postMessage$' "$RIG_CURL_LOG" 2>/dev/null )" "0:1"
rigStart answerGhost
rigId="$( rigAsk readback "$rigAnswerer" 1700000002.000201 )"
LC_ALL=C sed "s/^owner: $rigAsker\$/owner: $rigGhost/" "$rigStore/$rigId.md" > "$rigStore/$rigId.md.new" && mv "$rigStore/$rigId.md.new" "$rigStore/$rigId.md"
RIG_AGENT="$rigAnswerer" RIG_SESSION=rig-answer-run rigOp --member-escalation-answer "$rigAnswerer" "$rigId" yes
rigAssert "an asker that is no member the send can post as: the answer is applied all the same, and no line is posted in the answering member's name" \
	"$( LC_ALL=C grep -c -x -F "ESCALATION: $rigId answered" "$RIG_SCENARIO/op.out" ):$( rigCount 'Answered by' )" "1:0"

echo "-- an answer read from Slack: its confirmation carries the addressee of the ask, in one shape --"
rigStart readOwner
rigId="$( rigAsk readback human-owner 1700000003.000101 --addressees URIGOWNER )"
rigThread 1700000003.000101 '{"ts":"1700000003.000102","user":"URIGOWNER","text":"yes"}'
rigOp --intern-op-escalation-read "$rigAsker" "$rigId"
LC_ALL=C grep -q -x -F "ESCALATION: $rigId answered" "$RIG_SCENARIO/op.out" || rigRefuse "the read took no answer, so no confirmation is to be expected: $( head -3 "$RIG_SCENARIO/op.out" "$RIG_SCENARIO/op.err" | LC_ALL=C tr '\n' ' ' )"
rigAssert "asked of the human-owner: one confirmation, in the thread of the ask, addressed to him by name and account" \
	"$( rigCount 'Read: `yes` by human-owner' ):$( rigThreadOf 'Read: `yes`' ):$( rigHeader 'Read: `yes`' )" "1:1700000003.000101:$( rigTo "$rigAsker" "$rigOwner" )"
rigStart readForward
rigId="$( rigAsk readback "$rigAnswerer" 1700000003.000201 --addressees URIGANSW1 )"
LC_ALL=C awk '$0 == "asked-at: " substr( $0, 11 ) && ! done { print "forward-channel: DRIGFWD01" ; print "forward-ts: 1700000003.000301" ; print "forward-addressees: URIGOWNER" ; done = 1 ; } { print ; }' "$rigStore/$rigId.md" > "$rigStore/$rigId.md.new" && mv "$rigStore/$rigId.md.new" "$rigStore/$rigId.md"
rigThread 1700000003.000201 ''
rigThread 1700000003.000301 '{"ts":"1700000003.000302","user":"URIGOWNER","text":"yes"}'
rigOp --intern-op-escalation-read "$rigAsker" "$rigId"
rigAssert "read in the thread of a forward: confirmed there, to the human-owner the forward was addressed to" \
	"$( rigCount 'Read: `yes` by human-owner' ):$( rigThreadOf 'Read: `yes`' ):$( rigHeader 'Read: `yes`' )" "1:1700000003.000301:$( rigTo "$rigAsker" "$rigOwner" )"

echo "-- the note that a review is settled another way carries the addressee of its prompt --"
rigStart reviewSettled
rigId="$( rigAsk review human-owner 1700000004.000101 --addressees URIGOWNER )"
rigHelper AgentsTools.ReviewFlow.include AgentsReviewPromptClose "$rigStore/$rigId.md" "$rigId" "$rigAsker" "the item was accepted by $rigAsker"
rigAssert "one note, in the thread of the prompt, addressed to the human-owner by name" \
	"$( rigCount 'This review is settled another way: the item was accepted by' ):$( rigThreadOf 'This review is settled another way' ):$( rigHeader 'This review is settled another way' )" "1:1700000004.000101:$( rigTo "$rigAsker" "$rigOwner" )"

echo "-- a Permission set answered: the line that tells it is addressed to its participants --"
rigSetThread="CRIG00001:1700000005.000500"
mkdir -p "$rigWs/.local/agents/sessions/rig-cow"
printf '%s\n' "$rigSetThread" > "$rigWs/.local/agents/sessions/rig-cow/session.thread"
rigSet(){ ## request id, participants -- a set request on record, as the request operation leaves it
	printf -- '---\nstatus: reply-received\nowner: %s\nkind: permission-set\naddress-to: human-owner\n---\n\n# Question asked\n\nthe set\n' "$rigAsker" > "$rigStore/$1.md"
	printf 'scope: session\nsession-id: rig-cow\nparticipants: %s\nentry: Read:/rig/SET/**\n' "$2" > "$rigStore/$1.set"
}
rigStart toldAllowed
rigSet rig-set-allowed "rig-part-a rig-part-b"
rigHelper AgentsTools.InternOpPermission.include AgentsToolsPermissionSetTold rig-set-allowed allowed human-owner
rigAssert "allowed: one line in the session's thread, addressed to each participant" \
	"$( rigCount 'Permission set `rig-set-` is allowed by human-owner' ):$( rigThreadOf 'Permission set `rig-set-` is allowed' ):$( rigHeader 'Permission set `rig-set-` is allowed' )" \
	"1:${rigSetThread#*:}:$( rigTo "$rigAsker" "$( rigNamed rig-part-a ); $( rigNamed rig-part-b )" )"
rigStart toldDenied
rigSet rig-set-denied "rig-part-a rig-part-b"
rigHelper AgentsTools.InternOpPermission.include AgentsToolsPermissionSetTold rig-set-denied denied human-owner
rigAssert "denied: the same addressees"                             "$( rigCount 'Permission set `rig-set-` is denied by human-owner' ):$( rigHeader 'Permission set `rig-set-` is denied' )" \
	"1:$( rigTo "$rigAsker" "$( rigNamed rig-part-a ); $( rigNamed rig-part-b )" )"
rigStart toldGhost
rigSet rig-set-ghost "rig-part-a $rigGhost rig-part-b"
rigHelper AgentsTools.InternOpPermission.include AgentsToolsPermissionSetTold rig-set-ghost allowed human-owner
rigAssert "a participant the send cannot address is left out of the header, and the line is posted" \
	"$( rigCount "are granted to rig-part-a, $rigGhost, rig-part-b. A call refused before can be made again." ):$( rigHeader 'Permission set `rig-set-` is allowed' )" \
	"1:$( rigTo "$rigAsker" "$( rigNamed rig-part-a ); $( rigNamed rig-part-b )" )"
rigStart toldNone
rigSet rig-set-none "$rigGhost"
rigHelper AgentsTools.InternOpPermission.include AgentsToolsPermissionSetTold rig-set-none allowed human-owner
rigAssert "none of them can be addressed: the line is posted as it always was" \
	"$( rigCount 'Permission set `rig-set-` is allowed by human-owner' ):$( rigHeader 'Permission set `rig-set-` is allowed' )" "1:$( rigTo "$rigAsker" '@here' )"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ FOLLOW-UP ADDRESSEE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a follow-up of an ask does not carry the addressee of that ask, or the line that" >&2
	echo "        tells a Permission set is answered does not name its participants" >&2
	echo "  fix:  repair the operation that posts it -- never the assertion" >&2
	exit 1
fi
printf 'FOLLOW_UP_ADDRESSEE: OK (%d assertions, offline)\n' "$rigPassCount"
