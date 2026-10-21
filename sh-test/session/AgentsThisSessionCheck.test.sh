#!/usr/bin/env bash
## Behavioural check on ThisSession's session-channel operations (F7.2 of the refactorings epic, DistroAgentsSession.fn.sh): a tool of
## its own whose operations are locked to the session of the call. Nothing existing is renamed into it: every operation is a new
## name, and the names of the existing tools still answer as they did. Held, run and not read:
##   1. NOTHING IS RENAMED. DistroAgentsSession.fn.sh answers none of the names that already belong to Wait or to the Slack send, and
##      those still answer in DistroAgentsTools.fn.sh.
##   2. --get-session-channel-id prints the thread of the session (<channel>:<ts>), the one the session-current alias names; refused,
##      with a plain line, where the session has none, or the call has no session.
##   3. --post-session-channel posts to the session thread and to nowhere else: it takes no target, the first word is text, and the
##      send is the team's own (recorded in the session chat file first, from the member, to the addressees it names). Refused, and
##      nothing posted, where the call has no member, no session, or the session has no thread.
##   4. --get-session-thread reads the session thread from the session chat file, no network call and no change of any pointer:
##      all of it, history included, in the order of the file; with --own the messages sent by the caller, addressed to it, or
##      mentioning it (@member, or its Slack account). The messages of other threads, the replies to posts and the messages not
##      posted are not the thread. Refused with a plain line where it cannot be read.
##   5. --wait-session-channel is Wait, on the session channel alone (the chat: source, one pointer with Wait's floor): a timeout is
##      TIMEOUT; no option is the caller's floor (the executor every message, a participant the ones that name it); --to-@me the
##      messages addressed to or mentioning the caller, --to-@here the ones addressed to all, --to-@any every one, combined as a
##      union; a message the options pass over that the floor owes the caller stays for the floor, what the call delivered beyond it
##      is marked delivered, so nothing is lost and nothing comes twice; the caller's own posts never come back.
##   6. --get-dispatch-text prints the dispatch of the session from the sandbox's input/: dispatch.md, the board item's copy and
##      input-scan.md mixed by the markdown merge of F2.1, each a section of its own; conversation.md, pointers.md and the MAGIC
##      copies are not the dispatch. Alone, dispatch.md is printed as it is. Refused where there is none.
##   7. THE LINE OF IT: --get-session-thread [--own] stands in the tooling block of both kind routines, and in the brief of a start
##      with no routine, and with it the one short line of BatchTools (F7.8's, which was not there); every operation has its help entry.
## Offline: a Slack-shaped fake curl is first on PATH, every workspace is a folder of the rig's own, and no model CLI is started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigSessionFn="$rigPackage/sh-scripts/DistroAgentsSession.fn.sh"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHelp="$rigHere/help/Help.DistroAgentsTools.help.md"
unset MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SESSION_THREAD MDAT_SPAWN_AGENT MDAT_SPAWN_SANDBOX_ROOT CLAUDE_CODE_SESSION_ID harnessSessionId harnessAgent
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSessionFn" ] || rigRefuse "ThisSession is not at the origin this workspace resolves: $rigSessionFn"
[ -x "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsThisSessionCheck )" || exit 1
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

rigWs="" rigSession="" rigChat="" rigScn="" rigThread="CRIG00001:1760000000.000050" rigOther="CRIGOTH01:1760000000.000070"
rigScene(){ ## scenario name -- a workspace of its own with a session, its thread, and the members' accounts
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
## One block of the chat file, as the write path leaves it: from, to, ts, where, origin, body, seen (default none).
rigGuard(){ ## nothing of the rig is written outside the rig's own tree
	case "$rigWs" in "$rigTmp"/*) ;; *) rigRefuse "the rig's workspace is outside its tree: $rigWs" ;; esac
}
rigBlock(){
	rigGuard
	printf '%s' "$6" | ( export MMDAPP="$rigWs" ; . "$rigHere/session/AgentsTools.SessionChat.include" && AgentsToolsSessionChatAppend "$rigSession" "$1" "$2" "$3" "$4" "$5" "" "${7:--}" > /dev/null )
}
rigPointerSet(){ ## reader, value
	rigGuard
	( export MMDAPP="$rigWs" ; . "$rigHere/session/AgentsTools.SessionChat.include" && AgentsToolsSessionChatPointerSet "$rigSession" "$1" "$2" )
}
rigPointer(){ ## reader
	LC_ALL=C awk -F'\t' -v want="$1" '$1 == want { print $2 ; found = 1 ; } END { if ( ! found ) { print "none" ; } }' "$rigChat/session.chat.pointers" 2> /dev/null || printf 'no-pointers'
}
rigSeenOf(){ ## block number -- the seen field of its index line
	LC_ALL=C awk -F'\t' -v want="$1" '$1 == want { print $6 ; found = 1 ; } END { if ( ! found ) { print "no-such-block" ; } }' "$rigChat/session.chat.index" 2> /dev/null || printf 'no-index'
}
## The thread as the wait scenes leave it: block 1 is old, and the pointer of the member is just past it.
rigSeedWait(){
	rigBlock keeper-old all 1760000000.000001 "$rigThread" slack "RIG-OLD before the member's first read"
	rigPointerSet read:rig-member 1
	rigBlock keeper-old all 1760000000.000101 "$rigThread" slack "RIG-A to all"
	rigBlock keeper-old rig-member 1760000000.000102 "$rigThread" slack "RIG-B to the member"
	rigBlock keeper-old keeper-x 1760000000.000103 "$rigThread" slack "RIG-C to somebody else"
	rigBlock keeper-old keeper-x 1760000000.000104 "$rigThread" slack "RIG-D mentions @rig-member in its body"
	rigBlock keeper-old all 1760000000.000105 "$rigOther" slack "RIG-X in another thread"
}
rigOut="" rigErr="" rigRc="" rigStdin=""
## One call of an operation of ThisSession. role: executor (the session's founder), participant, none (a call with no session).
rigCall(){ ## name, member (empty: none), role, operation and its arguments...
	local callName="$1" callMember="$2" callRole="$3" callEnv=() callRc=0
	shift 3
	[ "$callRole" = none ] || callEnv+=( "MDAT_SESSION_ID=$rigSession" )
	[ "$callRole" != participant ] || callEnv+=( "MDAT_SPAWN_SESSION_ID=rig-spawn-participant" )
	[ -z "$callMember" ] || callEnv+=( "MDAT_SPAWN_AGENT=$callMember" )
	[ -z "${rigSandbox:-}" ] || callEnv+=( "MDAT_SPAWN_SANDBOX_ROOT=$rigSandbox" )
	[ -z "${rigThreadEnv:-}" ] || callEnv+=( "MDAT_SESSION_THREAD=$rigThreadEnv" )
	rigOut="$rigScn/$callName.out" rigErr="$rigScn/$callName.err"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" "PATH=$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" "MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" \
		"MDAT_SKILLSET_ROOT=$rigTmp/skills" "MDAT_DATA_ROOT=$rigScn/data" "RIG_SCENARIO=$rigScn" "RIG_CHAT=$rigChat/session.chat" \
		MDAT_WAIT_POLL_SECONDS=1 MDAT_WAIT_SETTLE_SECONDS=1 MDAT_WAIT_REMIND=off ${callEnv[@]+"${callEnv[@]}"} \
		perl -e 'alarm 90 ; exec @ARGV' bash "$rigSessionFn" "$@" ) > "$rigOut" 2> "$rigErr" < "${rigStdin:-/dev/null}" || callRc=$?
	rigRc="$callRc"
}
rigMarks(){ ## the RIG- marks the last output holds, comma-joined, in order
	LC_ALL=C awk '/^RIG-/ { printf "%s%s", ( n++ ? "," : "" ), $1 ; }' "$rigOut"
}
rigFloor(){ ## member, role (executor|participant) -- what the floor of the member delivers now, the pointer moved once it is
	( export MMDAPP="$rigWs" ; unset MDAT_SPAWN_SESSION_ID ; [ "$2" != participant ] || export MDAT_SPAWN_SESSION_ID=rig-spawn-participant ; . "$rigHere/session/AgentsTools.SessionChat.include" \
		&& AgentsToolsSessionChatFloor "$rigSession" "$1" "" deliver ) | LC_ALL=C awk '/^RIG-/ { printf "%s%s", ( n++ ? "," : "" ), $1 ; }'
}
rigHolds(){ ## fixed string -- how many lines of the last output hold it
	LC_ALL=C grep -c -F -- "$1" "$rigOut" || :
}
rigErrHolds(){ ## fixed string -- how many lines of the last error output hold it
	LC_ALL=C grep -c -F -- "$1" "$rigErr" || :
}
rigFirst(){ LC_ALL=C awk 'NR == 1 { print ; exit ; }' "$rigOut" ; }
rigSources(){ LC_ALL=C sed -n 's/^# sources: //p' "$rigOut" ; }

echo "-- 1. nothing existing is renamed into it --"
rigScene names
## --wait-for-input is this tool's own now (the table of the tool files); the operations of the other tool files are not answered here.
for rigOld in --slack-send-message --slack-read ; do
	rigCall "old-${rigOld#--member-}" rig-member executor "$rigOld" rig-member
	rigAssert "ThisSession does not answer the existing name $rigOld" "$rigRc:$( rigErrHolds 'invalid option' )" "1:1"
done
rigScene names2
( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" "PATH=$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" "MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
	perl -e 'alarm 60 ; exec @ARGV' bash "$rigTool" --wait-for-input rig-member --wait-list-sources ) > "$rigScn/list.out" 2> "$rigScn/list.err" < /dev/null
rigAssert "Wait still answers as it did, with the chat source"      "$( LC_ALL=C sed -n '1p' "$rigScn/list.out" ):$( LC_ALL=C grep -c '^chat	' "$rigScn/list.out" )" "WAIT-RESULT: RECEIVED:1"

echo "-- 2. --get-session-channel-id --"
rigScene id
rigCall id-1 rig-member executor --get-session-channel-id
rigAssert "it prints the thread of the session"                     "$rigRc:$( cat "$rigOut" )" "0:$rigThread"
rigThreadEnv="CRIG00002:1760000000.000099"
rigCall id-2 rig-member executor --get-session-channel-id
rigAssert "the thread a run is given is the thread of the session"  "$rigRc:$( cat "$rigOut" )" "0:$rigThreadEnv"
rigThreadEnv=""
rigCall id-3 rig-member executor --get-session-channel-id extra
rigAssert "an argument is refused"                                  "$rigRc:$( rigErrHolds 'syntax is' )" "1:1"
rm -f "$rigChat/session.thread"
rigCall id-4 rig-member executor --get-session-channel-id
rigAssert "a session with no thread: a plain line, nothing printed" "$rigRc:$( wc -c < "$rigOut" | LC_ALL=C tr -d ' ' ):$( rigErrHolds 'no session thread' )" "1:0:1"
printf '%s\n' "$rigThread" > "$rigChat/session.thread"
rigCall id-5 rig-member none --get-session-channel-id
rigAssert "a call with no session: a plain line"                    "$rigRc:$( rigErrHolds 'no session' )" "1:1"

echo "-- 3. --post-session-channel --"
rigScene post
rigCall post-1 rig-member executor --post-session-channel RIG-POST-ONE hello
rigAssert "it posts, once"                                          "$rigRc:$( cat "$rigScn/posts" 2> /dev/null )" "0:1"
rigAssert "to the session thread: its channel and its thread ts"    "$( LC_ALL=C grep -c -F -e '"channel":"CRIG00001"' -e '"thread_ts":"1760000000.000050"' "$rigScn/post.1" )" 1
rigAssert "with the words as its text"                              "$( LC_ALL=C grep -c 'RIG-POST-ONE hello' "$rigScn/post.1" )" 1
rigAssert "recorded first in the session chat file, from the member, to all" "$( LC_ALL=C sed -n '1s/^[^ ]* //p' "$rigChat/session.chat" )" "rig-member -> all:"
rigAssert "and indexed by the session thread"                       "$( LC_ALL=C awk -F'\t' '$1 == 1 { print $3 }' "$rigChat/session.chat.index" )" "$rigThread"
printf 'RIG-POST-TWO from stdin\n' > "$rigScn/stdin.txt"
rigStdin="$rigScn/stdin.txt"
rigCall post-2 rig-member executor --post-session-channel --address-to rig-part --from-stdin
rigStdin=""
rigAssert "the send's own options pass: stdin and the addressee"    "$rigRc:$( LC_ALL=C grep -c 'RIG-POST-TWO from stdin' "$rigScn/post.2" ):$( LC_ALL=C sed -n '$p' "$rigChat/session.chat.index" | LC_ALL=C cut -f1 )" "0:1:2"
rigAssert "the second block is to the addressee"                    "$( LC_ALL=C grep -c -E '^[0-9T:Z-]+ rig-member -> rig-part:$' "$rigChat/session.chat" )" 1
rigCall post-3 rig-member executor --post-session-channel magic-team RIG-NOT-A-TARGET
rigAssert "it takes no target: the first word is text, the thread is the session's" "$rigRc:$( LC_ALL=C grep -c -F -e 'magic-team RIG-NOT-A-TARGET' -e '"thread_ts":"1760000000.000050"' "$rigScn/post.3" )" "0:1"
rigAssert "three posts in all"                                      "$( cat "$rigScn/posts" )" 3
rigScene post-refused
rigCall postr-1 "" executor --post-session-channel RIG-NO-MEMBER
rigAssert "from no member's session: refused, nothing posted"       "$rigRc:$( rigErrHolds 'no member' ):$( [ -f "$rigScn/posts" ] && printf posted || printf none )" "1:1:none"
rigCall postr-2 rig-member none --post-session-channel RIG-NO-SESSION
rigAssert "from no session: refused, nothing posted"                "$rigRc:$( rigErrHolds 'no session' ):$( [ -f "$rigScn/posts" ] && printf posted || printf none )" "1:1:none"
rm -f "$rigChat/session.thread"
rigCall postr-3 rig-member executor --post-session-channel RIG-NO-THREAD
rigAssert "a session with no thread: refused, nothing posted"       "$rigRc:$( rigErrHolds 'no session thread' ):$( [ -f "$rigScn/posts" ] && printf posted || printf none )" "1:1:none"
rigCall postr-4 rig-member executor --post-session-channel
rigAssert "no text: refused"                                        "$rigRc" 1

echo "-- 4. --get-session-thread --"
rigScene read
rigBlock keeper-old all 1760000000.000001 "$rigThread" history "RIG-H0 before the run began"
rigBlock keeper-old all 1760000000.000101 "$rigThread" slack "RIG-A to all"
rigBlock keeper-old rig-member 1760000000.000102 "$rigThread" slack "RIG-B to the member"
rigBlock keeper-old keeper-x 1760000000.000103 "$rigThread" slack "RIG-C to somebody else"
rigBlock keeper-old keeper-x 1760000000.000104 "$rigThread" slack "RIG-D mentions @rig-member in its body"
rigBlock keeper-old keeper-x 1760000000.000105 "$rigThread" slack "RIG-E has the account <@URIGMEM01> in its body"
rigBlock rig-member all 1760000000.000106 "$rigThread" own "RIG-F sent by the member"
rigBlock keeper-old all 1760000000.000107 "$rigOther" slack "RIG-X in another thread"
rigBlock keeper-old all 1760000000.000108 "$rigOther" reply:rig-member "RIG-Y a reply to the member's post"
rigBlock rig-member all - - own "RIG-Z never posted"
rigBlock keeper-old rig-part 1760000000.000109 "$rigThread" slack "RIG-G to the other member"
( cd "$rigChat" && cksum session.chat session.chat.index > "$rigScn/before.cksum" 2> /dev/null )
rigPointerSet read:rig-member 3
rigCall read-1 rig-member executor --get-session-thread
rigAssert "all of the thread, history included, in the order of the file" "$rigRc:$( rigMarks )" "0:RIG-H0,RIG-A,RIG-B,RIG-C,RIG-D,RIG-E,RIG-F,RIG-G"
rigAssert "it is the blocks of the file: header, body"              "$( LC_ALL=C grep -c -E '^[0-9T:Z-]+ keeper-old -> all:$' "$rigOut" ):$( LC_ALL=C grep -c -x -F 'RIG-A to all' "$rigOut" )" 2:1
rigAssert "the other thread, the reply and the unposted are not the thread" "$( LC_ALL=C grep -c -e 'RIG-X' -e 'RIG-Y' -e 'RIG-Z' "$rigOut" )" 0
rigCall read-2 rig-member participant --get-session-thread --own
rigAssert "--own: sent by the caller, addressed to it, mentioning it"  "$rigRc:$( rigMarks )" "0:RIG-B,RIG-D,RIG-E,RIG-F"
rigCall read-3 rig-part executor --get-session-thread --own
rigAssert "--own is the caller's, whoever it is"                    "$rigRc:$( rigMarks )" "0:RIG-G"
rigAssert "no network call was made"                                "$( wc -c < "$rigScn/calls" | LC_ALL=C tr -d ' ' )" 0
( cd "$rigChat" && cksum session.chat session.chat.index > "$rigScn/after.cksum" 2> /dev/null )
rigAssert "nothing was changed: the file and its index are as they were" "$( cmp -s "$rigScn/before.cksum" "$rigScn/after.cksum" && printf same || printf changed )" same
rigAssert "nor the pointer of the caller"                           "$( rigPointer read:rig-member )" 3
rigCall read-4 rig-member executor --get-session-thread --bogus
rigAssert "an option it has not is refused"                         "$rigRc:$( rigErrHolds 'invalid option' )" "1:1"
rigCall read-5 rig-member none --get-session-thread
rigAssert "from no session: a plain line"                           "$rigRc:$( rigErrHolds 'no session' )" "1:1"
rigCall read-6 "" executor --get-session-thread --own
rigAssert "--own from no member's session: a plain line"            "$rigRc:$( rigErrHolds 'no member' )" "1:1"
rigCall read-7 "" executor --get-session-thread
rigAssert "the whole thread needs no member"                        "$rigRc" 0
rm -f "$rigChat/session.thread"
rigCall read-8 rig-member executor --get-session-thread
rigAssert "a session with no thread: a plain line"                  "$rigRc:$( rigErrHolds 'no session thread' )" "1:1"
printf '%s\n' "$rigThread" > "$rigChat/session.thread"
rm -f "$rigChat/session.chat" "$rigChat/session.chat.index"
rigCall read-9 rig-member executor --get-session-thread
rigAssert "a thread with nothing in the file yet: nothing, and no fault" "$rigRc:$( wc -c < "$rigOut" | LC_ALL=C tr -d ' ' )" "0:0"

echo "-- 5. --wait-session-channel --"
rigScene wait-quiet
rigSeedWait
rigPointerSet read:rig-member 6
rigCall wq-1 rig-member executor --wait-session-channel --wait-timeout 2
rigAssert "nothing new: a timeout, which is an answer"              "$rigRc:$( rigFirst )" "0:WAIT-RESULT: TIMEOUT"
rigAssert "it waited on the session channel alone"                  "$( rigSources )" "chat:$rigSession"
rigScene wait-exec
rigSeedWait
rigCall we-1 rig-member executor --wait-session-channel --wait-timeout 5
rigAssert "no option, the executor: every message of the thread"    "$rigRc:$( rigFirst ):$( rigMarks )" "0:WAIT-RESULT: RECEIVED:RIG-A,RIG-B,RIG-C,RIG-D"
rigAssert "behind the source it is of, the session thread"          "$( LC_ALL=C sed -n 's/^# arrived on: //p' "$rigOut" | LC_ALL=C sort -u )" "slack:$rigThread"
rigAssert "the pointer moved to the end"                            "$( rigPointer read:rig-member )" 6
rigCall we-2 rig-member executor --wait-session-channel --wait-timeout 2
rigAssert "and the next wait finds nothing: nothing twice"          "$( rigFirst )" "WAIT-RESULT: TIMEOUT"
rigScene wait-part
rigSeedWait
rigCall wp-1 rig-member participant --wait-session-channel --wait-timeout 5
rigAssert "no option, a participant: the ones that name it"         "$rigRc:$( rigMarks )" "0:RIG-B,RIG-D"
rigScene wait-me
rigSeedWait
rigCall wm-1 rig-member executor --wait-session-channel --to-@me --wait-timeout 5
rigAssert "--to-@me: addressed to the caller, or mentioning it"     "$rigRc:$( rigMarks )" "0:RIG-B,RIG-D"
rigAssert "what it passed over, the floor still owes: the pointer waits in front of it" "$( rigPointer read:rig-member )" 1
rigAssert "what it delivered beyond is marked delivered to the caller" "$( rigSeenOf 3 ) $( rigSeenOf 5 ) $( rigSeenOf 2 ) $( rigSeenOf 4 )" "rig-member rig-member - -"
rigCall wm-2 rig-member executor --wait-session-channel --to-@me --wait-timeout 2
rigAssert "asked again, nothing comes twice"                        "$( rigFirst )" "WAIT-RESULT: TIMEOUT"
rigAssert "the floor delivers the rest, and only the rest"          "$( rigFloor rig-member executor )" "RIG-A,RIG-C"
rigAssert "and the pointer is at the end"                           "$( rigPointer read:rig-member )" 6
rigScene wait-here
rigSeedWait
rigCall wh-1 rig-member executor --wait-session-channel --to-@here --wait-timeout 5
rigAssert "--to-@here: the ones addressed to all"                   "$rigRc:$( rigMarks )" "0:RIG-A"
rigAssert "the pointer is past it, in front of what the floor owes" "$( rigPointer read:rig-member )" 2
rigAssert "the floor delivers the rest"                             "$( rigFloor rig-member executor )" "RIG-B,RIG-C,RIG-D"
rigScene wait-any
rigSeedWait
rigCall wa-1 rig-member participant --wait-session-channel --to-@any --wait-timeout 5
rigAssert "--to-@any: every message of the thread, a participant too" "$rigRc:$( rigMarks )" "0:RIG-A,RIG-B,RIG-C,RIG-D"
rigAssert "nothing of the thread is left for the floor"             "$( rigFloor rig-member participant ):$( rigPointer read:rig-member )" ":6"
rigScene wait-union
rigSeedWait
rigCall wu-1 rig-member executor --wait-session-channel --to-@me --to-@here --wait-timeout 5
rigAssert "the options combine: the union of them"                  "$rigRc:$( rigMarks )" "0:RIG-A,RIG-B,RIG-D"
rigAssert "the pointer stops in front of what is owed (RIG-C)"      "$( rigPointer read:rig-member )" 3
rigAssert "RIG-D, beyond it, is marked delivered"                   "$( rigSeenOf 5 )" rig-member
rigAssert "the floor gives RIG-C and nothing twice"                 "$( rigFloor rig-member executor )" "RIG-C"
rigScene wait-own
rigSeedWait
rigBlock rig-member all 1760000000.000106 "$rigThread" own "RIG-OWN posted by the caller"
rigCall wo-1 rig-member executor --wait-session-channel --to-@any --wait-timeout 5
rigAssert "the caller's own posts never come back"                  "$( rigMarks )" "RIG-A,RIG-B,RIG-C,RIG-D"
rigScene wait-reply
rigSeedWait
rigBlock keeper-old all 1760000000.000106 "$rigOther" reply:rig-member "RIG-R a reply to the caller's post"
rigCall wr-1 rig-member executor --wait-session-channel --to-@any --wait-timeout 5
rigAssert "a reply to a post of the caller is not the session channel" "$( rigMarks )" "RIG-A,RIG-B,RIG-C,RIG-D"
rigAssert "it stays for the floor, which delivers it once"          "$( rigFloor rig-member executor )" "RIG-R"
rigScene wait-refuse
rigSeedWait
rigCall wx-1 rig-member executor --wait-session-channel --to-@nobody --wait-timeout 2
rigAssert "an option it has not is refused, nothing waited on"      "$rigRc:$( rigErrHolds 'invalid option' ):$( LC_ALL=C grep -c 'WAIT-RESULT' "$rigOut" )" "1:1:0"
rigCall wx-2 rig-member none --wait-session-channel --wait-timeout 2
rigAssert "from no session: refused, nothing waited on"             "$rigRc:$( rigErrHolds 'no session' ):$( LC_ALL=C grep -c 'WAIT-RESULT' "$rigOut" )" "1:1:0"
rigCall wx-3 "" executor --wait-session-channel --wait-timeout 2
rigAssert "from no member's session: refused, nothing waited on"    "$rigRc:$( rigErrHolds 'no member' ):$( LC_ALL=C grep -c 'WAIT-RESULT' "$rigOut" )" "1:1:0"
rigCall wx-4 rig-member executor --wait-session-channel --wait-timeout soon
rigAssert "a bound that is no number is refused"                    "$rigRc:$( LC_ALL=C grep -c 'WAIT-RESULT' "$rigOut" )" "1:0"
rm -f "$rigChat/session.thread"
rigCall wx-5 rig-member executor --wait-session-channel --wait-timeout 2
rigAssert "a session with no thread: refused, nothing waited on"    "$rigRc:$( rigErrHolds 'no session thread' ):$( LC_ALL=C grep -c 'WAIT-RESULT' "$rigOut" )" "1:1:0"

echo "-- 6. --get-dispatch-text --"
rigScene dispatch
rigSandbox="$rigScn/sandbox"
mkdir -p "$rigSandbox/input" "$rigSandbox/output"
printf '# Brief\n\nRIG-DISPATCH the task as given.\n\n## Your sandbox\n\nRIG-SANDBOX lines\n' > "$rigSandbox/input/dispatch.md"
rigCall d-1 rig-member executor --get-dispatch-text
rigAssert "alone, dispatch.md is printed as it is"                  "$rigRc:$( cmp -s "$rigOut" "$rigSandbox/input/dispatch.md" && printf same || printf differs )" "0:same"
printf -- '---\nowner: rig-member\n---\n# Item\n\nRIG-ITEM the board item.\n' > "$rigSandbox/input/dispatch-20261019T1000Z-rig.md"
printf '# Scan\n\nRIG-SCAN the input scan.\n' > "$rigSandbox/input/input-scan.md"
printf 'RIG-CONV the conversation.\n' > "$rigSandbox/input/conversation.md"
printf '# Pointers\n\nRIG-POINTERS the pointers.\n' > "$rigSandbox/input/pointers.md"
printf '# Magic\n\nRIG-MAGIC a copy.\n' > "$rigSandbox/input/MAGIC.rigrepo--rigpkg.md"
printf '# Inline\n\nRIG-INLINE an inline routine scan.\n' > "$rigSandbox/input/input-scan.some.routine.md"
rigCall d-2 rig-member executor --get-dispatch-text
rigAssert "mixed: the dispatch, the item, the scan, in that order"  "$rigRc:$( LC_ALL=C grep -o -E 'RIG-(DISPATCH|ITEM|SCAN)' "$rigOut" | LC_ALL=C tr '\n' ',' )" "0:RIG-DISPATCH,RIG-ITEM,RIG-SCAN,"
rigAssert "each a section of its own"                               "$( LC_ALL=C grep -c -x -e '# Dispatch' -e '# Board item' -e '# Input scan' "$rigOut" )" 3
rigAssert "the dispatch's own headings sit below its section"       "$( LC_ALL=C grep -c -x -e '## Brief' -e '### Your sandbox' "$rigOut" )" 2
rigAssert "the conversation, the pointers, the MAGIC copy and an inline scan are not the dispatch" "$( LC_ALL=C grep -c -e 'RIG-CONV' -e 'RIG-POINTERS' -e 'RIG-MAGIC' -e 'RIG-INLINE' "$rigOut" )" 0
rigSandbox="" ; mkdir -p "$rigWs/.local/agents/spawned/rig-spawn/input"
printf '# Brief\n\nRIG-FALLBACK found by the spawn id.\n' > "$rigWs/.local/agents/spawned/rig-spawn/input/dispatch.md"
( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" "PATH=/usr/bin:/bin:/usr/sbin:/sbin" "MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SPAWN_AGENT=rig-member" "MDAT_SPAWN_SESSION_ID=rig-spawn" \
	perl -e 'alarm 60 ; exec @ARGV' bash "$rigSessionFn" --get-dispatch-text ) > "$rigScn/d-3.out" 2> "$rigScn/d-3.err" < /dev/null
rigAssert "with no sandbox variable, the sandbox of the spawn id"   "$( LC_ALL=C grep -c 'RIG-FALLBACK' "$rigScn/d-3.out" )" 1
rm -f "$rigWs/.local/agents/spawned/rig-spawn/input/dispatch.md"
( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" "PATH=/usr/bin:/bin:/usr/sbin:/sbin" "MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SPAWN_AGENT=rig-member" "MDAT_SPAWN_SESSION_ID=rig-spawn" \
	perl -e 'alarm 60 ; exec @ARGV' bash "$rigSessionFn" --get-dispatch-text ) > "$rigScn/d-4.out" 2> "$rigScn/d-4.err" < /dev/null
rigAssert "a sandbox with no dispatch: a plain line, nothing printed" "$?:$( wc -c < "$rigScn/d-4.out" | LC_ALL=C tr -d ' ' ):$( LC_ALL=C grep -c 'no dispatch' "$rigScn/d-4.err" )" "1:0:1"
( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" "PATH=/usr/bin:/bin:/usr/sbin:/sbin" "MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" \
	perl -e 'alarm 60 ; exec @ARGV' bash "$rigSessionFn" --get-dispatch-text ) > "$rigScn/d-5.out" 2> "$rigScn/d-5.err" < /dev/null
rigD5Rc=$?
rigAssert "from no spawned session: a plain line"                   "$rigD5Rc:$( LC_ALL=C grep -c 'no spawned session' "$rigScn/d-5.err" )" "1:1"

echo "-- 7. the line of it, and the help --"
rigBlockOf(){ ## routine file -- the lines of its # Routine-specific tooling block
	LC_ALL=C awk '/^# Routine-specific tooling$/ { inBlock = 1 ; next } /^# / { inBlock = 0 } inBlock { print }' "$1"
}
for rigKind in coworking standalone ; do
	rigAssert "the $rigKind routine's tooling block names --get-session-thread [--own]" "$( rigBlockOf "$rigPackage/skillset/magic-team/magic-team/magic-team.$rigKind.routine.md" | LC_ALL=C grep -c -x -F -e '- `--get-session-thread [--own]`' )" 1
	rigAssert "and BatchTools, in one short line (F7.8's line, which was missing)" "$( rigBlockOf "$rigPackage/skillset/magic-team/magic-team/magic-team.$rigKind.routine.md" | LC_ALL=C grep -c -x -F -e 'BatchTools: several tool calls in one round, much quicker for calls that do not depend on each other.' )" 1
done
for rigOp in --wait-session-channel --get-session-channel-id --post-session-channel --get-session-thread --get-dispatch-text --executor-checkpoint-push --executor-checkpoint-rewind --executor-checkpoint-exit --idle-wait ; do
	rigAssert "the help describes $rigOp"                           "$( LC_ALL=C grep -c -E "^		$rigOp( |\$)" "$rigHelp" )" 1
done
rigAssert "--idle-wait is routed here (F10.5 gate B), once"            "$( LC_ALL=C grep -c -e '^		--idle-wait)' "$rigSessionFn" )" 1

echo "-- 8. a start with no routine gets the line in its brief --"
rigScene brief
rigBriefWs="$rigScn/ws"
mkdir -p "$rigBriefWs/.local/.agents" "$rigScn/data" "$rigScn/home" "$rigBriefWs/source/rigrepo/rigpkg"
printf 'SLACK_BOT_TOKEN=rig-SECRET-1\nSPAWN_TIER_NORMAL=rig-cli\n' > "$rigBriefWs/.local/.agents/magic-team.agent.env" ; printf 'PRESET_CLI_SERVICE=rig-cli\n' > "$rigBriefWs/.local/.agents/preset-rig-cli.agent.env"
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\ncat "$MDAT_SPAWN_SANDBOX_ROOT"/input/dispatch.md > "%s/dispatch-while-running"\n' "$rigScn" > "$rigBriefWs/DistroAgentsConsole.sh"
chmod +x "$rigBriefWs/DistroAgentsConsole.sh"
printf 'Work on rigrepo/rigpkg following no routine at all.\n' \
	| env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigScn/home" PATH="/usr/bin:/bin" MMDAPP="$rigBriefWs" MDAT_DATA_ROOT="$rigScn/data" MDLT_ORIGIN="$rigOrigin" \
		MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c 'cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --wait' > "$rigScn/spawn.out" 2> "$rigScn/spawn.err"
[ -f "$rigScn/dispatch-while-running" ] || rigRefuse "the console never ran, so the brief was never observed: $( tail -3 "$rigScn/spawn.err" )"
rigAssert "the brief names --get-session-thread [--own], once"      "$( LC_ALL=C grep -c -F -e '--get-session-thread [--own]' "$rigScn/dispatch-while-running" )" 1
rigAssert "and it is the only line of it"                           "$( LC_ALL=C grep -c -F -e 'DistroAgentsSession.fn.sh' "$rigScn/dispatch-while-running" )" 1
rigAssert "BatchTools in one short line, once (F7.8's line)"        "$( LC_ALL=C grep -c -x -F -e 'BatchTools: several tool calls in one round, much quicker for calls that do not depend on each other.' "$rigScn/dispatch-while-running" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ THIS SESSION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'THIS_SESSION: OK (%d assertions, offline)\n' "$rigPassCount"
