#!/usr/bin/env bash
## Behavioural check on the communications reader and writer (F9.3 of the refactorings epic): one process of a workspace on a host
## that keeps the session chat files up to date with Slack, and Slack with them (--intern-session-comms,
## sh-lib/session/AgentsTools.SessionComms.include). Held, run and not read:
##   1. THE READER. A pass reads the thread of each session whose control thread lives, as the team bot, from the newest ts the
##      file holds (`oldest`), and brings what is new into the file: a message once, the ones from before the run's launch as
##      history; the next pass asks from the newest. A quiet pass writes nothing in the session's folder. A session with no
##      control thread, or no thread, is not read; a session named is read whatever.
##   2. THE WRITER, for a post that failed. The send operation leaves the message in the file and its post in the outbox of the
##      session: `retry` where Slack was not reached, `unknown` where it may have been (never posted again), `refused` where
##      Slack answered and said no (never posted again); the last two are said in the index. The writer posts a `retry` once
##      Slack answers, as the same sender under the same identity, stamps the block, and takes it out of the outbox; one that
##      Slack answers with a rate limit stays, nothing behind it overtakes it, and the Retry-After is waited out. No token is
##      kept in the outbox.
##   3. THE CONSOLE. A message the console leaves for a session (--inject) is taken by the writer: recorded as the console's,
##      posted to the session thread, stamped; one that cannot be sent is kept aside with the reason.
##   4. THE BUDGET AND THE CADENCE. Reads are counted over the last minute and stop at twenty; a session a wait is blocked on, or
##      that spoke in the last minute, is looked at every five seconds, a quiet one after 30, 60, ... 300.
##   5. THE PROCESS. One for the workspace on the host, started detached, holding a lock that names it; a second start is told it
##      lives; TERM ends it in order; a lock whose holder is gone is taken over; it ends by itself when no session has wanted it
##      for a while; it is never started where MDAT_COMMS_READER is `off`. It imports what a thread says while it runs.
##   6. THE WAIT STANDS DOWN while the reader is current, and says it is blocked: a wait touches the session's marker, and reads
##      the thread itself only when the reader's last look is older than its own TTL and ten seconds more.
##   7. THE FLOOR WAITS FOR A POST THAT IS NOT YET: a block of another member that has no ts yet is not passed by the pointer of a
##      reader, until it has one, or five minutes have gone, or it is given up (`refused`, `unknown`); the reader's own is no stop.
##   8. THE PLACES that start it, end it in a rig, and keep it out of the runner.
## Offline: a Slack-shaped fake curl is first on PATH, every workspace is a folder of the rig's own, no model CLI is started, and
## every process this check starts is ended by it, through the rig's process helper.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTest="$rigPackage/sh-test"
rigFixtures="$rigTest/check-fixtures"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
. "$rigFixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionCommsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
mkdir -p "$rigTmp/bin" "$rigTmp/bin-fast" "$rigTmp/skills/keeper-rig" "$rigTmp/skills/keeper-addr" "$rigTmp/skills/keeper-exec" "$rigTmp/skills/keeper-old"
for rigMember in keeper-rig keeper-addr keeper-exec keeper-old ; do printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md" ; done
cp "$rigFixtures/session-comms.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
printf '#!/bin/sh\nexit 0\n' > "$rigTmp/bin-fast/sleep"
chmod +x "$rigTmp/bin-fast/sleep"
[ "$( PATH="$rigTmp/bin:$PATH" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on its PATH"
rigPath="$rigTmp/bin:$PATH"

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

rigNow="$( date +%s )"
rigDir="" rigSession="" rigSessDir="" rigThread="" rigRoot="" rigChat="" rigRc=0 rigStandPid=""
rigOwnMeta='"metadata":{"event_type":"rig","event_payload":{"sender":"keeper-old"}}'
rigStamp(){ ## epoch -- a touch -t stamp of it, BSD or GNU date
	date -r "$1" +%Y%m%d%H%M.%S 2> /dev/null || date -d "@$1" +%Y%m%d%H%M.%S
}
rigIso(){ ## seconds back from now -- the UTC time of a header
	date -u -r "$(( rigNow - $1 ))" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null || date -u -d "@$(( rigNow - $1 ))" +%Y-%m-%dT%H:%M:%SZ
}
rigAt(){ ## seconds back from now, microseconds
	printf '%s.%06d' "$(( rigNow - $1 ))" "$2"
}
rigMsg(){ ## ts user text [thread ts] [fields]
	printf '{"ts":"%s","user":"%s","text":"%s"%s%s}' "$1" "$2" "$3" "${4:+,\"thread_ts\":\"$4\"}" "${5:+,$5}"
}
rigJoin(){ ## messages... -- comma-joined
	local joinOut="" joinOne
	for joinOne in "$@" ; do joinOut="$joinOut${joinOut:+,}$joinOne" ; done
	printf '%s' "$joinOut"
}
rigThreadData(){ ## its messages (root first) -- the thread of the scene
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$( rigJoin "$@" )" > "$rigDir/replies.CRIGSES01.$rigRoot.json"
}
rigScene(){ ## scenario name -- a workspace with one session: its folder, thread, record, launch marker and the settings
	rigNow="$( date +%s )"
	rigDir="$rigTmp/$1"
	rigSession="rig-comm-$1"
	rm -rf "$rigDir"
	rigSessDir="$rigDir/ws/.local/agents/sessions/$rigSession"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/temp" "$rigSessDir" "$rigDir/ws/.local/agents/spawned/trk" "$rigDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=DRIGOWN01\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigDir/ws/.local/.agents/keeper-rig.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-ADDR\n' > "$rigDir/ws/.local/.agents/keeper-addr.agent.env"
	rigRoot="$(( rigNow - 400 )).000001"
	rigThread="CRIGSES01:$rigRoot"
	printf '%s\n' "$rigThread" > "$rigSessDir/session.thread"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: rig\nworkspace: rigws\nowner: keeper-rig\nstatus: spawn-started\nstarted-at: 2026-10-19 09:00 +0300\n---\n\n# Spawn session: %s\n' "$rigSession" "$rigSession" "$rigSession" > "$rigDir/ws/.local/agents/spawned/trk/$rigSession.spawn.md"
	: > "$rigSessDir/launch"
	touch -t "$( rigStamp $(( rigNow - 300 )) )" "$rigSessDir/launch"
	: > "$rigDir/api.log"
	rigChat="$rigSessDir/session.chat"
	rigThreadData "$( rigMsg "$rigRoot" URIGOWNER RIG-ROOT "$rigRoot" )"
}
rigLive(){ ## the control thread of the scene's session lives: a stand-in process, and the pid file that names it
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigStandPid=$!
	rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
	disown "$rigStandPid" 2> /dev/null || :
	mkdir -p "$rigSessDir/control"
	rigProcBegan "$rigStandPid" > "$rigSessDir/control/pid"
}
## The operation, in the scene's workspace; its output and errors kept as <name>.out and <name>.err, the status in rigRc.
rigOpEnv=""
rigOp(){ ## output basename, then the arguments of --intern-session-comms
	local opName="$1"
	shift
	( cd "$rigDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_COMMS_READER -u MDAT_COMMS_IDLE_SECONDS \
		"PATH=$rigPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDAT_DATA_ROOT=$rigDir/data" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" $rigOpEnv \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 90 -- bash "$rigTool" --intern-session-comms "$@" ) > "$rigDir/$opName.out" 2> "$rigDir/$opName.err"
	rigRc=$?
}
rigPass(){ ## output basename -- one pass over the scene's session
	rigOp "$1" --one --session-id "$rigSession" < /dev/null
}
## One send of keeper-rig into the session thread, with the body on its standard input. A sleep that returns at once is first on PATH.
rigSend(){ ## body, send options...
	local sendBody="$1"
	shift
	printf '%s' "$sendBody" | ( cd "$rigDir/ws" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_THREAD -u CLAUDE_CODE_SESSION_ID \
		"PATH=$rigTmp/bin-fast:$rigPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" "MDAT_SESSION_ID=$rigSession" \
		bash "$rigTool" --slack-send-message keeper-rig "$rigThread" "$@" --from-stdin ) > "$rigDir/send.out" 2> "$rigDir/send.err"
	rigRc=$?
}
rigBlocks(){ ## how many header lines the chat file holds
	[ -f "$rigChat" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk '/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; } END { print count + 0 ; }' "$rigChat"
}
rigNth(){ ## the Nth header line of the chat file, without its time
	[ -f "$rigChat" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk -v want="$1" '/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; if ( count == want ) { sub(/^[^ ]* /, "") ; print ; exit ; } }' "$rigChat"
}
rigBody(){ ## the first body line of block N
	[ -f "$rigChat" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk -v want="$1" '/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; next ; } count == want { print ; exit ; }' "$rigChat"
}
rigIndex(){ ## ts, where and origin of block N
	[ -f "$rigChat.index" ] || { printf 'no-index' ; return 0 ; }
	LC_ALL=C awk -F'\t' -v want="$1" '$1 == want { print $2 " " $3 " " $4 ; found = 1 ; exit ; } END { if ( ! found ) { print "no-such-block" ; } }' "$rigChat.index"
}
rigCalls(){ ## method -- how many calls of it the log holds
	LC_ALL=C awk -v want="$1" '$2 == want { count++ ; } END { print count + 0 ; }' "$rigDir/api.log"
}
rigLastCall(){ ## method, field number -- that field of the last call of it
	LC_ALL=C awk -v want="$1" -v field="$2" '$2 == want { last = $field ; } END { print last ; }' "$rigDir/api.log"
}
rigFloor(){ ## member -- the blocks of its floor from its pointer, then the number the pointer would move to
	MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" env -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID bash -c ". '$rigHere/session/AgentsTools.SessionChat.include' ; AgentsToolsSessionChatFloor '$rigSession' '$1' > '$rigDir/floor.out' ; LC_ALL=C grep -c -E '^[0-9T:Z-]+ .* -> .*:\$' '$rigDir/floor.out' ; printf 'newest=%s\n' \"\${agentsSessionChatNewest:-}\""
}
rigFloorHolds(){ ## member, text -- whether the floor of the member holds the text
	MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" env -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID bash -c ". '$rigHere/session/AgentsTools.SessionChat.include' ; AgentsToolsSessionChatFloor '$rigSession' '$1' | LC_ALL=C grep -c -F -e '$2'"
}
rigPointerSet(){ ## reader, value
	MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c ". '$rigHere/session/AgentsTools.SessionChat.include' ; AgentsToolsSessionChatPointerSet '$rigSession' '$1' '$2'"
}
rigFn(){ ## the body of a shell command run with the comms functions defined, in the scene's workspace
	MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" env -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID bash -c ". '$rigHere/session/AgentsTools.SessionComms.include' || exit 9 ; $1"
}
## A chat file written by hand: block N is `<time back> <from> <to> <ts> <where> <origin>` and a body word.
rigChatBlock(){ ## number, seconds back, from, to, ts, where, origin, body word
	local blockLine=1
	[ ! -f "$rigChat" ] || blockLine=$(( $( LC_ALL=C wc -l < "$rigChat" | LC_ALL=C tr -d ' ' ) + 1 ))
	printf '%s %s -> %s:\n%s\n\n' "$( rigIso "$2" )" "$3" "$4" "$8" >> "$rigChat"
	printf '%s\t%s\t%s\t%s\t%s\t-\n' "$1" "$5" "$6" "$7" "$blockLine" >> "$rigChat.index"
}

echo "-- 1. the reader --"
rigScene read
rigLive
rigThreadData "$( rigMsg "$rigRoot" URIGOWNER RIG-ROOT "$rigRoot" )" \
	"$( rigMsg "$(( rigNow - 100 )).000001" URIGHUM1 RIG-REPLY-ONE "$rigRoot" "$rigOwnMeta" )" \
	"$( rigMsg "$(( rigNow - 90 )).000001" URIGOWNER RIG-REPLY-TWO "$rigRoot" )"
rigOp pass-1 --one < /dev/null
rigAssert "a pass over the live sessions ends well"                    "$rigRc" 0
rigAssert "the thread was read once, as the team bot, from the start"  "$( rigCalls conversations.replies ):$( rigLastCall conversations.replies 6 ):$( rigLastCall conversations.replies 5 )" "1:rig-bot-token-TEAM:-"
rigAssert "three blocks: the root, and the two replies"                "$( rigBlocks )" 3
rigAssert "the one from before the launch is history, the others come as slack" "$( rigIndex 1 | LC_ALL=C awk '{ print $3 }' )/$( rigIndex 2 | LC_ALL=C awk '{ print $3 }' )/$( rigIndex 3 | LC_ALL=C awk '{ print $3 }' )" "history/slack/slack"
rigAssert "from is the sender the tooling recorded"                    "$( rigNth 2 )" "keeper-old -> all:"
rigAssert "and the body is its text"                                   "$( rigBody 2 )" "RIG-REPLY-ONE"
rigAssert "the floor of the executor is the two replies, not the root" "$( rigFloor keeper-exec | LC_ALL=C tr '\n' ' ' )" "0 newest= "
rigPointerSet read:keeper-exec 0
rigAssert "from a pointer at the start"                                "$( rigFloor keeper-exec | LC_ALL=C tr '\n' ' ' )" "2 newest=3 "
touch "$rigDir/marker" ; sleep 1.2
rigPass pass-2
rigAssert "the next pass asks from the newest ts the file holds"       "$( rigCalls conversations.replies ):$( rigLastCall conversations.replies 5 )" "2:$(( rigNow - 90 )).000001"
rigAssert "and adds nothing"                                           "$( rigBlocks )" 3
rigAssert "a pass that finds nothing writes nothing in the session's folder" "$( find "$rigSessDir" -type f -newer "$rigDir/marker" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0
rigThreadData "$( rigMsg "$rigRoot" URIGOWNER RIG-ROOT "$rigRoot" )" "$( rigMsg "$(( rigNow - 100 )).000001" URIGHUM1 RIG-REPLY-ONE "$rigRoot" "$rigOwnMeta" )" \
	"$( rigMsg "$(( rigNow - 90 )).000001" URIGOWNER RIG-REPLY-TWO "$rigRoot" )" "$( rigMsg "$(( rigNow - 5 )).000001" URIGHUM1 RIG-REPLY-THREE "$rigRoot" )"
rigPass pass-3
rigAssert "a message that came in since is added, once"                "$( rigBlocks ):$( rigBody 4 )" "4:RIG-REPLY-THREE"
rigScene dead
rigPass dead-1
rigAssert "a session with no control thread is read when it is named"  "$( rigCalls conversations.replies )" 1
rigOp dead-2 --one < /dev/null
rigAssert "and is not read when the pass is over the live ones"        "$( rigCalls conversations.replies )" 1
rigScene nothread
rigLive
rm -f "$rigSessDir/session.thread"
rigOp nothread-1 --one < /dev/null
rigAssert "a live session with no thread is not read"                  "$( rigCalls conversations.replies )" 0

echo "-- 2. the writer, for a post that failed --"
rigScene retry
rigLive
printf 'curl:7\ncurl:7\ncurl:7\ncurl:7\ncurl:7\n' > "$rigDir/post-script"
rigSend "RIG-RETRY-BODY"
rigAssert "a send that Slack was not reached for fails as it did"      "$( [ "$rigRc" != 0 ] && printf failed )" failed
rigAssert "and is in the file, with no ts yet"                         "$( rigBlocks ):$( rigIndex 1 )" "1:- - own"
rigAssert "its post waits in the outbox, as a retry"                   "$( ls "$rigSessDir/chat.outbox" 2> /dev/null | LC_ALL=C tr '\n' ' ' )" "1.retry "
rigAssert "naming the sender, the identity it posts under and the method" "$( LC_ALL=C head -1 "$rigSessDir/chat.outbox/1.retry" 2> /dev/null | LC_ALL=C tr '\t' ' ' )" "keeper-rig user chat.postMessage"
rigAssert "with the payload Slack was to get"                          "$( LC_ALL=C tail -n +3 "$rigSessDir/chat.outbox/1.retry" 2> /dev/null | LC_ALL=C grep -c -F -e RIG-RETRY-BODY -e "thread_ts" )" 1
rigAssert "and no token"                                               "$( LC_ALL=C grep -c -F -e rig-user-token -e rig-bot-token -e 'Bearer' "$rigSessDir/chat.outbox/1.retry" 2> /dev/null )" 0
rigAssert "the floor of another reader does not pass it by"            "$( rigPointerSet read:keeper-exec 0 ; rigFloor keeper-exec | LC_ALL=C tr '\n' ' ' )" "0 newest=0 "
rigPass retry-1
rigAssert "a pass posts it: as the sender, under its token, the same payload" "$( rigCalls chat.postMessage ):$( rigLastCall chat.postMessage 6 ):$( cmp -s "$rigDir/post.6" "$rigDir/post.1" && printf same )" "6:rig-user-token-RIG:same"
rigAssert "the block has its ts and its conversation now"              "$( rigIndex 1 )" "1760000000.000106 CRIGSES01:$rigRoot own"
rigAssert "and the outbox is empty"                                    "$( ls "$rigSessDir/chat.outbox" 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0
rigAssert "the floor of another reader has it now, and the thread's root the pass read after it is no floor" "$( rigFloor keeper-exec | LC_ALL=C tr '\n' ' ' )" "1 newest=2 "
rigScene unknown
rigLive
printf 'curl:28\n' > "$rigDir/post-script"
rigSend "RIG-UNKNOWN-BODY"
rigAssert "a curl that failed after the request may have gone out is unknown" "$( ls "$rigSessDir/chat.outbox" 2> /dev/null | LC_ALL=C tr '\n' ' ' ):$( rigIndex 1 )" "1.unknown :- unknown own"
rigPass unknown-1
rigAssert "and is never posted again"                                  "$( rigCalls chat.postMessage )" 1
rigScene refused
rigLive
printf 'error:is_archived\n' > "$rigDir/post-script"
rigSend "RIG-REFUSED-BODY"
rigAssert "a post Slack answers and refuses is refused"                "$( ls "$rigSessDir/chat.outbox" 2> /dev/null | LC_ALL=C tr '\n' ' ' ):$( rigIndex 1 )" "1.refused :- refused own"
rigPass refused-1
rigAssert "and is never posted again"                                  "$( rigCalls chat.postMessage )" 1
rigAssert "the floor of another reader reads past a post given up"     "$( rigPointerSet read:keeper-exec 0 ; rigFloor keeper-exec | LC_ALL=C tr '\n' ' ' )" "0 newest=2 "
rigScene rate
rigLive
printf 'curl:7\ncurl:7\ncurl:7\ncurl:7\ncurl:7\n' > "$rigDir/post-script"
rigSend "RIG-FIRST-BODY"
printf 'curl:7\ncurl:7\ncurl:7\ncurl:7\ncurl:7\n' > "$rigDir/post-script"
rigSend "RIG-SECOND-BODY"
rigAssert "two posts wait, in the order they were sent"                "$( ls "$rigSessDir/chat.outbox" | LC_ALL=C tr '\n' ' ' )" "1.retry 2.retry "
printf 'rate:2\n' > "$rigDir/post-script"
rigPass rate-1
rigAssert "Slack says wait: the first stays, the second is not tried"   "$( rigCalls chat.postMessage ):$( ls "$rigSessDir/chat.outbox" | LC_ALL=C tr '\n' ' ' )" "11:1.retry 2.retry "
rigPause="$( LC_ALL=C cat "$rigDir/ws/.local/agents/comms/pause" 2> /dev/null )"
case "$rigPause" in ''|*[!0123456789]*) rigPause=0 ;; esac
rigAssert "the Retry-After is kept as a time to wait for, two seconds on" "$( [ "$rigPause" -ge $(( rigNow + 1 )) ] && [ "$rigPause" -le $(( $( date +%s ) + 3 )) ] && printf ok )" ok
## Under load the two seconds can pass before the next pass starts: the pause is set ten minutes on, so that pass is inside it.
printf '%s\n' "$(( $( date +%s ) + 600 ))" > "$rigDir/ws/.local/agents/comms/pause"
rigPass rate-2
rigAssert "a pass inside it posts nothing"                             "$( rigCalls chat.postMessage )" 11
printf '%s\n' "$(( rigNow - 5 ))" > "$rigDir/ws/.local/agents/comms/pause"
rigPass rate-3
rigAssert "once it has passed, both go, the first first"               "$( rigCalls chat.postMessage ):$( ls "$rigSessDir/chat.outbox" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( LC_ALL=C grep -c RIG-FIRST-BODY "$rigDir/post.12" ):$( LC_ALL=C grep -c RIG-SECOND-BODY "$rigDir/post.13" )" "13:0:1:1"

echo "-- 3. the console --"
rigScene inject
rigLive
printf 'RIG-CONSOLE-BODY' | { cd "$rigDir/ws" && env MDAT_COMMS_READER=off "PATH=$rigPath" "MMDAPP=$rigDir/ws" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" bash "$rigTool" --intern-session-comms --inject --session-id "$rigSession" --from keeper-rig --to keeper-addr ; } > "$rigDir/inject.out" 2> "$rigDir/inject.err"
rigAssert "a message is left for the session in its inbox"             "$( ls "$rigSessDir/chat.inbox" 2> /dev/null | LC_ALL=C grep -c '\.msg$' ):$( LC_ALL=C head -1 "$rigSessDir/chat.inbox"/*.msg 2> /dev/null )" "1:keeper-rig -> keeper-addr:"
rigPass inject-1
rigAssert "a pass takes it: recorded as the console's, from and to as left" "$( rigNth 1 ):$( rigBody 1 ):$( rigIndex 1 | LC_ALL=C awk '{ print $3 }' )" "keeper-rig -> keeper-addr::RIG-CONSOLE-BODY:console"
rigAssert "posted to the session thread, and stamped"                  "$( rigCalls chat.postMessage ):$( LC_ALL=C grep -c -F -e RIG-CONSOLE-BODY -e "\"thread_ts\":\"$rigRoot\"" "$rigDir/post.1" ):$( rigIndex 1 | LC_ALL=C awk '{ print $1 " " $2 }' )" "1:1:1760000000.000101 CRIGSES01:$rigRoot"
rigAssert "and the inbox is empty"                                     "$( ls "$rigSessDir/chat.inbox" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0
printf 'RIG-NOBODY-BODY' | { cd "$rigDir/ws" && env MDAT_COMMS_READER=off "PATH=$rigPath" "MMDAPP=$rigDir/ws" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" bash "$rigTool" --intern-session-comms --inject --session-id "$rigSession" --from nobody-here ; } > /dev/null 2> /dev/null
rigPass inject-2
rigAssert "one from nobody the team knows is kept aside, with the reason" "$( ls "$rigSessDir/chat.inbox" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/[0-9TZ]*\.[A-Za-z0-9]*\.msg/N.msg/' ):$( LC_ALL=C head -1 "$rigSessDir/chat.inbox"/*.refused | LC_ALL=C cut -c1-2 ):$( rigCalls chat.postMessage )" "N.msg.refused :# :1"
rigAssert "and records nothing: the thread's root, which a pass reads, is the only block beside the console's" "$( rigBlocks )" 2
## A person at a console acts as user-<account> (F6.10, F11.6): no member and no skill folder, and sent all the same, as the team bot with the account as its sender.
printf 'RIG-PERSON-BODY' | { cd "$rigDir/ws" && env MDAT_COMMS_READER=off "PATH=$rigPath" "MMDAPP=$rigDir/ws" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" bash "$rigTool" --intern-session-comms --inject --session-id "$rigSession" --from user-rig-acct --to keeper-addr ; } > /dev/null 2> /dev/null
rigPass inject-3
rigAssert "one from the account at a console, user-<account>, is sent: recorded from that account to its addressee, posted to the thread, the account its sender, and the inbox empty" \
	"$( LC_ALL=C grep -c -x '[0-9T:Z-]* user-rig-acct -> keeper-addr:' "$rigSessDir/session.chat" ):$( rigCalls chat.postMessage ):$( LC_ALL=C grep -c -F '"sender":"user-rig-acct"' "$rigDir/post.2" ):$( ls "$rigSessDir/chat.inbox" | LC_ALL=C grep -c -v '\.refused$' )" "1:2:1:0"
rigOp inject-none --inject --session-id "no-such-session" --from keeper-rig < /dev/null
rigAssert "a session that has no folder is refused, with a line saying so" "$( [ "$rigRc" != 0 ] && printf failed ):$( LC_ALL=C grep -c 'no-such-session' "$rigDir/inject-none.err" )" "failed:1"
rigScene inject-start
printf 'RIG-AUTO-BODY' | rigOp inject-start-1 --inject --session-id "$rigSession" --from keeper-rig
rigWaited=0
while [ "$rigWaited" -lt 40 ] && [ "$( rigBlocks )" != "1" ] ; do sleep 0.5 ; rigWaited=$(( rigWaited + 1 )) ; done
rigDaemon4="$( readlink "$rigDir/ws/.local/agents/comms/lock" 2> /dev/null | LC_ALL=C awk '{ print $1 }' )"
[ -z "$rigDaemon4" ] || { rigProcNote "$rigDaemon4" ; rigStarted="$rigStarted $rigDaemon4" ; }
rigAssert "an inject starts the reader where none lives, which sends the message" "$( LC_ALL=C grep -c -E 'the reader: (started|alive) ' "$rigDir/inject-start-1.err" ):$( rigBlocks ):$( rigBody 1 )" "1:1:RIG-AUTO-BODY"
rigProcSignal TERM "${rigDaemon4:-0}"

echo "-- 4. the budget and the cadence --"
rigScene budget
mkdir -p "$rigDir/ws/.local/agents/comms"
for rigAtOne in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 ; do printf '%s\n' "$(( rigNow - rigAtOne ))" ; done > "$rigDir/ws/.local/agents/comms/calls"
rigPass budget-1
rigAssert "twenty reads in the last minute: no twenty-first"           "$( rigCalls conversations.replies )" 0
rigAssert "and the pass ends well"                                     "$rigRc" 0
sed -i.bak '1d' "$rigDir/ws/.local/agents/comms/calls" 2> /dev/null || { tail -n +2 "$rigDir/ws/.local/agents/comms/calls" > "$rigDir/calls.next" && mv -f "$rigDir/calls.next" "$rigDir/ws/.local/agents/comms/calls" ; }
rigPass budget-2
rigAssert "nineteen: one more"                                         "$( rigCalls conversations.replies ):$( LC_ALL=C wc -l < "$rigDir/ws/.local/agents/comms/calls" | LC_ALL=C tr -d ' ' )" "1:20"
for rigAtOne in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 ; do printf '%s\n' "$(( rigNow - 100 - rigAtOne ))" ; done > "$rigDir/ws/.local/agents/comms/calls"
rigPass budget-3
rigAssert "reads of more than a minute ago are not counted, and are dropped" "$( rigCalls conversations.replies ):$( LC_ALL=C wc -l < "$rigDir/ws/.local/agents/comms/calls" | LC_ALL=C tr -d ' ' )" "2:1"
rigScene cadence
rigNowNow="$( date +%s )"
rigDue(){ ## looked line (may be empty), then `wait` for a marker touched now, `chat` for a chat file written now, else a quiet session
	mkdir -p "$rigDir/ws/.local/agents/comms/looked"
	rm -f "$rigDir/ws/.local/agents/comms/looked/$rigSession" "$rigSessDir/session.chat.waiting" "$rigSessDir/session.chat"
	[ -z "$1" ] || printf '%s\n' "$1" > "$rigDir/ws/.local/agents/comms/looked/$rigSession"
	case "${2:-}" in wait) : > "$rigSessDir/session.chat.waiting" ;; chat) : > "$rigSessDir/session.chat" ;; esac
	rigFn "AgentsToolsSessionCommsDue '$rigSession' $( date +%s ) && printf due || printf wait"
}
rigAssert "a session never looked at is due"                           "$( rigDue "" )" due
rigAssert "a quiet one looked at 6 seconds ago, a gap of 30, is not"   "$( rigDue "$(( $( date +%s ) - 6 )) 30" )" wait
rigAssert "one looked at 31 seconds ago is"                            "$( rigDue "$(( $( date +%s ) - 31 )) 30" )" due
rigAssert "a wait is blocked on it: due after 5 seconds"               "$( rigDue "$(( $( date +%s ) - 6 )) 30" wait )" due
rigAssert "not before"                                                 "$( rigDue "$(( $( date +%s ) - 3 )) 30" wait )" wait
rigAssert "it spoke in the last minute: due after 5 seconds"           "$( rigDue "$(( $( date +%s ) - 6 )) 120" chat )" due
rigAssert "the last look is what the wait stands down for"             "$( printf '%s\n' "$(( rigNowNow - 7 )) 30" > "$rigDir/ws/.local/agents/comms/looked/$rigSession" ; MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c ". '$rigHere/session/AgentsTools.SessionChat.include' ; AgentsToolsSessionChatReaderLooked '$rigSession'" )" "$(( rigNowNow - 7 ))"
rigScene order
mkdir -p "$rigDir/ws/.local/agents/comms/looked"
printf '%s 30\n' "$(( $( date +%s ) - 5 ))" > "$rigDir/ws/.local/agents/comms/looked/rig-a"
printf '%s 30\n' "$(( $( date +%s ) - 100 ))" > "$rigDir/ws/.local/agents/comms/looked/rig-c"
rigAssert "a pass reaches the session looked at longest ago first, and one never read before all, so the budget goes round" "$( printf 'rig-a CT1:1.1\nrig-b CT2:2.2\nrig-c CT3:3.3\n' | rigFn 'AgentsToolsSessionCommsOrder' | LC_ALL=C awk '{ printf "%s=%s ", $1, $2 }' )" "rig-b=CT2:2.2 rig-c=CT3:3.3 rig-a=CT1:1.1 "
rigScene gaps
rigLive
rigGap(){ ## the gap kept for the scene's session
	LC_ALL=C awk '{ print $2 }' "$rigDir/ws/.local/agents/comms/looked/$rigSession" 2> /dev/null
}
rigPass gaps-0
rigAssert "a pass that brought something in: back to 5"                "$( rigGap )" 5
touch -t "$( rigStamp $(( rigNow - 3000 )) )" "$rigChat"
rigPass gaps-1
rigAssert "a quiet pass: the next look is 30 seconds on"               "$( rigGap )" 30
rigPass gaps-2
rigAssert "and 60 after the next"                                      "$( rigGap )" 60
for rigAtOne in 1 2 3 4 5 6 ; do rigPass gaps-n ; done
rigAssert "up to 300 and no more"                                      "$( rigGap )" 300
: > "$rigSessDir/session.chat.waiting"
rigPass gaps-3
rigAssert "a wait blocked on it brings it back to 5"                   "$( rigGap )" 5

echo "-- 5. the process --"
rigScene proc
rigLive
rigOpEnv="MDAT_COMMS_READER=off"
rigOp proc-off --start < /dev/null
rigOpEnv=""
rigAssert "never started where MDAT_COMMS_READER is off"                "$( LC_ALL=C head -1 "$rigDir/proc-off.out" ):$( [ -e "$rigDir/ws/.local/agents/comms/lock" ] && printf lock )" "off:"
rigThreadData "$( rigMsg "$rigRoot" URIGOWNER RIG-ROOT "$rigRoot" )"
rigOp proc-start --start < /dev/null
rigDaemon="$( LC_ALL=C sed -n 's/^started \([0-9][0-9]*\)$/\1/p' "$rigDir/proc-start.out" | head -1 )"
rigAssert "a start says it started a process"                          "$( [ -n "$rigDaemon" ] && printf started )" started
[ -z "$rigDaemon" ] || { rigProcNote "$rigDaemon" ; rigStarted="$rigStarted $rigDaemon" ; }
rigWaited=0
while [ "$rigWaited" -lt 20 ] && [ ! -L "$rigDir/ws/.local/agents/comms/lock" ] ; do sleep 0.5 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "the lock names it: its pid, and when it began"              "$( readlink "$rigDir/ws/.local/agents/comms/lock" 2> /dev/null | LC_ALL=C awk '{ print $1 }' ):$( readlink "$rigDir/ws/.local/agents/comms/lock" 2> /dev/null | LC_ALL=C awk 'NF == 2 { print "two" }' )" "${rigDaemon:-none}:two"
rigAssert "it shows in the process list as its operation, a process of its own" "$( LC_ALL=C ps -ww -o args= -p "${rigDaemon:-0}" 2> /dev/null | LC_ALL=C grep -c -F -e '--intern-session-comms --run' )" 1
rigAssert "it is no run of any session, by the rule that tells a run"   "$( cd "$rigDir/ws" && MDLT_ORIGIN="$MDLT_ORIGIN" bash -c ". '$rigHere/team-data/AgentsTools.Registries.include' ; ps -ww -o pid=,args= -p ${rigDaemon:-0} | AgentsToolsRegistryRunWords | wc -l | tr -d ' '" )" 0
rigOp proc-again --start < /dev/null
rigAssert "a second start is told it lives, and starts nothing"        "$( LC_ALL=C head -1 "$rigDir/proc-again.out" )" "alive ${rigDaemon:-none}"
rigWaited=0
while [ "$rigWaited" -lt 40 ] && [ "$( rigBlocks )" = "no-file" ] ; do sleep 0.5 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "it reads the thread by itself: the root is in the file, as history" "$( rigBlocks ):$( rigIndex 1 | LC_ALL=C awk '{ print $3 }' )" "1:history"
rigThreadData "$( rigMsg "$rigRoot" URIGOWNER RIG-ROOT "$rigRoot" )" "$( rigMsg "$(( $( date +%s ) - 1 )).000001" URIGHUM1 RIG-WHILE-IT-RUNS "$rigRoot" )"
: > "$rigSessDir/session.chat.waiting"
rigWaited=0
while [ "$rigWaited" -lt 40 ] && [ "$( rigBlocks )" != "2" ] ; do sleep 0.5 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "and what the thread says while it runs"                     "$( rigBlocks ):$( rigBody 2 )" "2:RIG-WHILE-IT-RUNS"
rigAssert "its log says it started"                                    "$( LC_ALL=C grep -c 'the communications reader' "$rigDir/ws/.local/agents/comms/log" 2> /dev/null | LC_ALL=C awk '{ print ( $1 > 0 ) ? "yes" : "no" }' )" yes
rigProcSignal TERM "${rigDaemon:-0}"
rigWaited=0
while [ "$rigWaited" -lt 30 ] && [ -L "$rigDir/ws/.local/agents/comms/lock" ] ; do sleep 0.5 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "TERM ends it in order: its lock is given back"              "$( [ -L "$rigDir/ws/.local/agents/comms/lock" ] && printf held || printf given )" given
rigAssert "and the process is gone"                                    "$( rigProcStill "${rigDaemon:-0}" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0
ln -s "999999 Mon_Jan__1_00:00:00_2001" "$rigDir/ws/.local/agents/comms/lock"
rigOp proc-take --start < /dev/null
rigDaemon2="$( LC_ALL=C sed -n 's/^started \([0-9][0-9]*\)$/\1/p' "$rigDir/proc-take.out" | head -1 )"
[ -z "$rigDaemon2" ] || { rigProcNote "$rigDaemon2" ; rigStarted="$rigStarted $rigDaemon2" ; }
rigWaited=0
while [ "$rigWaited" -lt 20 ] && [ "$( readlink "$rigDir/ws/.local/agents/comms/lock" 2> /dev/null | LC_ALL=C awk '{ print $1 }' )" != "${rigDaemon2:-none}" ] ; do sleep 0.5 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "a lock whose holder is gone is taken over"                  "$( readlink "$rigDir/ws/.local/agents/comms/lock" 2> /dev/null | LC_ALL=C awk '{ print $1 }' )" "${rigDaemon2:-none}"
rigProcSignal TERM "${rigDaemon2:-0}"
rigScene idle
rigOpEnv="MDAT_COMMS_IDLE_SECONDS=3"
rigOp idle-start --start < /dev/null
rigOpEnv=""
rigDaemon3="$( LC_ALL=C sed -n 's/^started \([0-9][0-9]*\)$/\1/p' "$rigDir/idle-start.out" | head -1 )"
[ -z "$rigDaemon3" ] || { rigProcNote "$rigDaemon3" ; rigStarted="$rigStarted $rigDaemon3" ; }
rigWaited=0
while [ "$rigWaited" -lt 40 ] && [ -n "$( rigProcStill "${rigDaemon3:-0}" )" ] ; do sleep 0.5 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "with no live session for the time set, it ends by itself, and gives its lock back" "$( rigProcStill "${rigDaemon3:-0}" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( [ -L "$rigDir/ws/.local/agents/comms/lock" ] && printf held || printf given )" "0:given"
rigAssert "and says why in its log"                                    "$( LC_ALL=C grep -c 'no live session' "$rigDir/ws/.local/agents/comms/log" 2> /dev/null )" 1
rigOp mode-none < /dev/null
rigAssert "no mode: a usage, and a failure"                            "$( [ "$rigRc" != 0 ] && printf failed ):$( LC_ALL=C grep -c -F -e '--run' "$rigDir/mode-none.err" | LC_ALL=C awk '{ print ( $1 > 0 ) ? "usage" : "none" }' )" "failed:usage"

echo "-- 6. the wait stands down --"
rigWaitOp(){ ## output basename -- a wait of keeper-exec on the session, bounded, with the reader's last look as the scene left it
	( cd "$rigDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_WAIT_POLL_SECONDS -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS \
		"PATH=$rigPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDAT_DATA_ROOT=$rigDir/data" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" "MDAT_SESSION_ID=$rigSession" \
		"MDAT_SPAWN_LAUNCH_MARKER=$rigSessDir/launch" MDAT_WAIT_POLL_SECONDS=1 MDAT_WAIT_SETTLE_SECONDS=1 MDAT_WAIT_REMIND=off \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 60 -- bash "$rigTool" --wait-for-input keeper-exec --wait-default --wait-session-id "$rigSession" --wait-timeout 2 --wait-source "file:$rigDir/none" ) > "$rigDir/$1.out" 2> "$rigDir/$1.err"
}
rigScene wait-fresh
mkdir -p "$rigDir/ws/.local/agents/comms/looked"
printf '%s 30\n' "$(( $(date +%s) - 1 ))" > "$rigDir/ws/.local/agents/comms/looked/$rigSession"
rigWaitOp wait-fresh
rigAssert "the reader looked a second ago: the wait reads no thread"    "$( rigCalls conversations.replies )" 0
rigAssert "and says it is blocked on the session, for the reader to see" "$( [ -f "$rigSessDir/session.chat.waiting" ] && printf marker )" marker
rigScene wait-late
mkdir -p "$rigDir/ws/.local/agents/comms/looked"
printf '%s 30\n' "$(( $(date +%s) - 100 ))" > "$rigDir/ws/.local/agents/comms/looked/$rigSession"
rigWaitOp wait-late
rigAssert "the reader looked 100 seconds ago: the wait reads the thread itself" "$( rigCalls conversations.replies )" 1
rigScene wait-none
rigWaitOp wait-none
rigAssert "the reader never looked: the wait reads the thread itself"   "$( rigCalls conversations.replies )" 1

echo "-- 7. the floor waits for a post that is not yet --"
rigScene floor
rigChatBlock 1 200 keeper-old all 1760000000.000101 "CRIGSES01:$rigRoot" slack ONE
rigChatBlock 2 100 keeper-old all - - own TWO
rigChatBlock 3 50 keeper-old all 1760000000.000103 "CRIGSES01:$rigRoot" slack THREE
rigPointerSet read:keeper-exec 0
rigAssert "a pending block of another member stops the floor before it"  "$( rigFloor keeper-exec | LC_ALL=C tr '\n' ' ' )" "1 newest=1 "
MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c ". '$rigHere/session/AgentsTools.SessionChat.include' ; AgentsToolsSessionChatStamp '$rigSession' 2 1760000000.000102 'CRIGSES01:$rigRoot'"
rigPointerSet read:keeper-exec 1
rigAssert "once it has a ts, the floor goes on through it"              "$( rigFloor keeper-exec | LC_ALL=C tr '\n' ' ' )" "2 newest=3 "
rigScene floor-old
rigChatBlock 1 200 keeper-old all 1760000000.000101 "CRIGSES01:$rigRoot" slack ONE
rigChatBlock 2 1000 keeper-old all - - own TWO
rigChatBlock 3 50 keeper-old all 1760000000.000103 "CRIGSES01:$rigRoot" slack THREE
rigPointerSet read:keeper-exec 0
rigAssert "one that has waited more than five minutes is read past"      "$( rigFloor keeper-exec | LC_ALL=C tr '\n' ' ' ):$( rigFloorHolds keeper-exec TWO )" "2 newest=3 :0"
rigScene floor-own
rigChatBlock 1 200 keeper-old all 1760000000.000101 "CRIGSES01:$rigRoot" slack ONE
rigChatBlock 2 100 keeper-exec all - - own TWO
rigChatBlock 3 50 keeper-old all 1760000000.000103 "CRIGSES01:$rigRoot" slack THREE
rigPointerSet read:keeper-exec 0
rigAssert "a pending block of the reader's own is no stop"               "$( rigFloor keeper-exec | LC_ALL=C tr '\n' ' ' )" "2 newest=3 "
rigScene floor-dead
rigChatBlock 1 200 keeper-old all 1760000000.000101 "CRIGSES01:$rigRoot" slack ONE
rigChatBlock 2 100 keeper-old all - refused own TWO
rigChatBlock 3 50 keeper-old all - unknown own THREE
rigPointerSet read:keeper-exec 0
rigAssert "a post given up is no stop, and is not delivered"             "$( rigFloor keeper-exec | LC_ALL=C tr '\n' ' ' )" "1 newest=3 "

echo "-- 8. the places --"
rigProxy="$rigHere/session/AgentsTools.InternOpAgentSpawnProxy.include"
rigAssert "the spawner starts the reader once, beside the control thread" "$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigProxy" | LC_ALL=C grep -c '"\$( AgentsToolsSessionCommsStart' )" 1
rigAssert "the runner keeps it out of the checks it runs"                "$( LC_ALL=C grep -c '^[[:space:]]*export MDAT_COMMS_READER=off$' "$rigTest/AgentsRunTests.sh" )" 1
rigAssert "a rig's fixture that ends threads ends this one too"          "$( LC_ALL=C grep -c -F -e "'*/comms/log'" "$rigFixtures/rig-control-threads.include.sh" )" 1
rigAssert "the arm is in the dispatcher"                                 "$( LC_ALL=C grep -c -F -e '--intern-session-comms)' "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION COMMS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_COMMS: OK (%d assertions, offline)\n' "$rigPassCount"
