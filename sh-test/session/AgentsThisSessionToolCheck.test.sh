#!/usr/bin/env bash
## Behavioural check on the ThisSession tool (F7.2 of the refactorings epic): the one harness tool
## through which a running session asks of its own session, declared on the tool floor
## (sh-lib/harness/AgentsOpenAiChatWire.sh) and dispatched by the harness to
## DistroAgentsSession.fn.sh. ONE tool, the operation as its argument, like the other subsystem
## tools: never a tool per operation, and no read, since every Wait already brings the thread's
## replies. Held, run and not read:
##   1. A POST LANDS IN THE THREAD: from a session, operation post sends the message to the session
##      thread and to nowhere else -- the send's own report names the thread and the message in it,
##      and the session chat file holds the message, recorded from the member before the post.
##   2. AND IT SAYS SO: the result is one clear line naming the thread, the message in it and the
##      member it was posted as, never a bare response body, and the content is not repeated.
##   3. A SESSION WITH NO THREAD IS REFUSED WITH ERROR, and nothing is posted.
##   4. THE OPERATION IS THE ARGUMENT: an operation the tool has not is refused, naming the ones it
##      has, and a required argument it is given none of is refused before anything runs.
## Offline: a Slack-shaped fake curl is first on PATH, the workspace and its session are folders of
## the rig's own, and no model CLI is started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigWire="$rigHere/harness/AgentsOpenAiChatWire.sh"
unset MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SESSION_THREAD MDAT_SPAWN_AGENT MDAT_SPAWN_SANDBOX_ROOT CLAUDE_CODE_SESSION_ID harnessSessionId harnessAgent
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHarness" "$rigWire" "$rigFixtures/session-chat.curl.stub.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsThisSessionToolCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/rig-member" "$rigTmp/skills/rig-part"
for rigMember in rig-member rig-part ; do printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md" ; done
cp "$rigFixtures/session-chat.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"

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

rigWs="" rigSession="" rigChat="" rigScn="" rigThread="CRIG00001:1760000000.000050"
## A workspace of the rig's own: a session with its thread, the team's channel settings, the
## members' Slack accounts, and the fake curl every send reaches.
rigScene(){ ## scenario name
	rigScn="$rigTmp/$1"
	rigWs="$rigScn/ws"
	rigSession="rig-sess-$1"
	rm -rf "$rigScn"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/sessions/$rigSession" "$rigScn/data"
	rigChat="$rigWs/.local/agents/sessions/$rigSession"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/rig-member.agent.env"
	printf 'rig-member=URIGMEM01=m=M=M=d\nrig-part=URIGPART01=p=P=P=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
	: > "$rigScn/calls"
	printf '%s\n' "$rigThread" > "$rigChat/session.thread"
}
## The chat file's first block, as the write path leaves it: "<ts> <from> -> <to>:", then the body.
rigChatFirst(){ LC_ALL=C sed -n '1s/^[^ ]* //p' "$rigChat/session.chat" 2> /dev/null ; }
## How many lines the chat file held at the moment of a post: the fake curl records it, so a post
## whose message was recorded first is told from one recorded after.
rigHeldAtPost(){ LC_ALL=C awk -v want="${1:-1}" '$1 == want { print $2 ; exit }' "$rigScn/at-post" 2> /dev/null ; }
## How many posts the fake curl answered.
rigPosts(){ cat "$rigScn/posts" 2> /dev/null || printf '0' ; }

rigOut="" rigErr="" rigRc=""
## One call of the ThisSession tool: from a session by the member named (role none: no session and
## no member; nomember: a session and no member; nosession: a member and no session), as the
## harness serves it.
rigCall(){ ## name, arguments json, role
	local callName="$1" callArgs="$2" callRole="$3" callRc=0
	local -a callEnv=( "MDAT_SESSION_ID=$rigSession" "MDAT_SPAWN_AGENT=rig-member" )
	case "$callRole" in
		none) callEnv=() ;;
		nomember) callEnv=( "MDAT_SESSION_ID=$rigSession" ) ;;
		nosession) callEnv=( "MDAT_SPAWN_AGENT=rig-member" ) ;;
	esac
	rigOut="$rigScn/$callName.out" rigErr="$rigScn/$callName.err"
	( cd "$rigWs" && printf '%s' "$callArgs" | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" "PATH=$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" "MDAT_DATA_ROOT=$rigScn/data" \
		"RIG_SCENARIO=$rigScn" "RIG_CHAT=$rigChat/session.chat" ${callEnv[@]+"${callEnv[@]}"} \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 120 -- bash "$rigHarness" --intern-tool ThisSession ) > "$rigOut" 2> "$rigErr" || callRc=$?
	rigRc="$callRc"
}
rigFirst(){ LC_ALL=C awk 'NR == 1 { print ; exit ; }' "$rigOut" ; }
rigLines(){ LC_ALL=C awk 'END { print NR + 0 }' "$rigOut" ; }
rigOutHolds(){ ## fixed text -- how many lines of the result hold it
	LC_ALL=C grep -c -F -- "$1" "$rigOut" 2> /dev/null || :
}
rigErrHolds(){ ## fixed text -- how many lines of the harness's own stderr hold it
	LC_ALL=C grep -c -F -- "$1" "$rigErr" 2> /dev/null || :
}

echo "-- 0. the tool is on the floor, declared as one tool --"
rigAssert "ThisSession is declared on the harness tool floor"       "$( LC_ALL=C grep -c -F -- '{"type":"function","function":{"name":"ThisSession","description":"Post to your own session thread.' "$rigWire" )" 1
rigAssert "and it is the tool that posts, the operation its argument" "$( LC_ALL=C grep -c -F -- 'operation post sends message there and nowhere else, with address_to naming who it is for.' "$rigWire" )" 1
rigAssert "it is served over MCP by the mirror, derived from that floor" "$( MMDAPP="$rigTmp" MDLT_ORIGIN="$rigOrigin" bash "$rigHere/harness/AgentsHarnessMcpMirror.sh" 2> /dev/null | LC_ALL=C grep -c '"name":"ThisSession"' )" 1

echo "-- 1. a post from a session lands in its thread --"
rigScene post
rigCall post-1 '{"operation":"post","message":"RIG-TOOL-ONE hello"}' session
rigAssert "it posts, once"                                          "$rigRc:$( rigPosts )" "0:1"
rigAssert "to the session thread: its channel and its thread ts"    "$( LC_ALL=C grep -c -F -e '"channel":"CRIG00001"' -e '"thread_ts":"1760000000.000050"' "$rigScn/post.1" )" 1
rigAssert "with the words as its text, and nowhere else as a target" "$( LC_ALL=C grep -c -F 'RIG-TOOL-ONE hello' "$rigScn/post.1" ):$( LC_ALL=C grep -c -F '"channel":"CRIGOTHER"' "$rigScn/post.1" )" "1:0"
rigAssert "recorded in the session chat file, from the member, to all" "$( rigChatFirst )" "rig-member -> all:"
rigAssert "the chat file holds the message itself"                  "$( LC_ALL=C grep -c -x -F 'RIG-TOOL-ONE hello' "$rigChat/session.chat" )" 1
rigAssert "and it was recorded BEFORE the post went out"            "$( [ "$( rigHeldAtPost 1 )" -gt 0 ] 2> /dev/null && printf first || printf after )" first
rigAssert "indexed by the session thread"                           "$( LC_ALL=C awk -F'\t' '$1 == 1 { print $3 }' "$rigChat/session.chat.index" )" "$rigThread"

echo "-- 2. and it returns a clear result --"
rigAssert "one line, naming the thread, the message in it and the member" "$( rigFirst )" "POSTED to your own session thread $rigThread at CRIG00001:1760000000.000101 as rig-member, and recorded in the session chat file first, then posted."
rigAssert "and nothing else on stdout: no response body repeated"   "$( rigLines ):$( rigOutHolds 'RIG-TOOL-ONE hello' )" "1:0"
rigAssert "the harness announced the call as a post on its own line" "$( rigErrHolds '📮' ):$( rigErrHolds 'ThisSession post RIG-TOOL-ONE hello' )" "1:1"

echo "-- 3. the address_to argument --"
rigScene post-addressed
rigCall post-2 '{"operation":"post","message":"RIG-TOOL-TWO for one","address_to":"rig-part"}' session
rigAssert "the addressee is passed to the send"                     "$rigRc:$( LC_ALL=C grep -c -E '^[0-9T:Z-]+ rig-member -> rig-part:$' "$rigChat/session.chat" )" "0:1"
rigAssert "the post is still the session thread's"                  "$( LC_ALL=C grep -c -F '"thread_ts":"1760000000.000050"' "$rigScn/post.1" )" 1
rigAssert "and the result is the same clear line"                   "$( rigFirst )" "POSTED to your own session thread $rigThread at CRIG00001:1760000000.000101 as rig-member, and recorded in the session chat file first, then posted."

echo "-- 4. a session with no thread is refused with ERROR --"
rigScene no-thread
rm -f "$rigChat/session.thread"
rigCall nr-1 '{"operation":"post","message":"RIG-TOOL-NO-THREAD"}' session
rigAssert "refused"                                                 "$rigRc" 1
rigAssert "with ERROR, naming the missing thread"                   "$( rigOutHolds 'ERROR:' ):$( rigOutHolds 'no session thread' ):$( rigErrHolds 'refused' )" "1:1:1"
rigAssert "and nothing was posted"                                  "$( [ -f "$rigScn/posts" ] && cat "$rigScn/posts" || printf 0 )" 0
rigAssert "nor written to a chat file that has no thread"           "$( [ -f "$rigChat/session.chat" ] && printf written || printf none )" none

echo "-- 5. the operation is the argument --"
rigScene refusals
rigCall r-1 '{"operation":"read","message":"RIG-TOOL-READ"}' session
rigAssert "an operation it has not is refused, naming the ones it has" "$rigRc:$( rigOutHolds 'unknown operation' ):$( rigOutHolds 'post' ):$( [ -f "$rigScn/posts" ] && cat "$rigScn/posts" || printf 0 )" "1:1:1:0"
rigCall r-2 '{"message":"RIG-TOOL-NO-OP"}' session
rigAssert "no operation at all is refused the same way"             "$rigRc:$( rigOutHolds 'unknown operation' ):$( [ -f "$rigScn/posts" ] && cat "$rigScn/posts" || printf 0 )" "1:1:0"
rigCall r-3 '{"operation":"post"}' session
rigAssert "post with no message is refused before anything runs"    "$rigRc:$( rigOutHolds 'message is required' ):$( [ -f "$rigScn/posts" ] && cat "$rigScn/posts" || printf 0 )" "1:1:0"
rigCall r-4 '{"operation":"routine-run-inline"}' session
rigAssert "routine-run-inline with no routine is refused"           "$rigRc:$( rigOutHolds 'routine is required' ):$( [ -f "$rigScn/posts" ] && cat "$rigScn/posts" || printf 0 )" "1:1:0"
rigCall r-5 '{"operation":"routine-run-inline","routine":"rig-no-such-routine"}' session
rigAssert "a routine it cannot resolve is refused, by the one file that runs routines" "$rigRc:$( rigFirst | LC_ALL=C grep -c '^ERROR: ' ):$( [ -f "$rigScn/posts" ] && cat "$rigScn/posts" || printf 0 )" "1:1:0"
rigCall r-6 '{"operation":"post","message":"RIG-TOOL-NO-MEMBER"}' nomember
rigAssert "from no member's session: refused, nothing posted"       "$rigRc:$( rigOutHolds 'no member' ):$( [ -f "$rigScn/posts" ] && cat "$rigScn/posts" || printf 0 )" "1:1:0"
rigCall r-7 '{"operation":"post","message":"RIG-TOOL-NO-SESSION"}' nosession
rigAssert "from no session: refused, nothing posted"                "$rigRc:$( rigOutHolds 'no session' ):$( [ -f "$rigScn/posts" ] && cat "$rigScn/posts" || printf 0 )" "1:1:0"
rigCall r-8 '{"operation":"post","message":"RIG-TOOL-NEITHER"}' none
rigAssert "from no member's session and no session: refused, nothing posted" "$rigRc:$( rigOutHolds 'ERROR:' ):$( [ -f "$rigScn/posts" ] && cat "$rigScn/posts" || printf 0 )" "1:1:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ THIS SESSION TOOL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'THIS_SESSION_TOOL: OK (%d assertions, offline)\n' "$rigPassCount"
