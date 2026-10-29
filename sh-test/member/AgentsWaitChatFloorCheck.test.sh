#!/usr/bin/env bash
## Behavioural check on the session chat file as a source of Wait (F3.3's floor in Wait, F9.2): `chat:<session>` is the floor of a
## run beside the replies to its own posts, read from the file by pointer; Wait brings the file up to date itself; both paths run
## together and a message comes once; the floor first, then the rest of what arrived in one group sorted by time, each message
## naming its source. Held, run and not read:
##   1. THE FLOOR IS IN. No TTL is said in the return. A plain Wait of a session that has a chat file carries `chat:<session>` after the replies, ahead of the
##      sources it names; a session with no folder carries none.
##   2. THE FILE IS BROUGHT UP TO DATE. The session thread is read into the file by the floor where the call names its own set (sketch 3.2); the
##      messages from before the run's launch are history and are not returned, a later one is, behind the source it is of; its
##      TTL (5s and 1s more for 20 quiet) keeps a second wait inside it from reading the thread again; the pointer moves, so a
##      message is returned once.
##   3. BOTH PATHS RUN. A default wait reads the session thread itself (slack:<thread>:conversation) and brings it into the file
##      too; the message comes once, and the file holds it as delivered, so a tool return does not carry it again.
##   4. THE REPLIES come into the file as replies to the member's post, delivered by its own wait.
##   5. THE ORDER. The floor first, then the other sources' messages together, sorted by time, consecutive ones of one source under
##      one `# arrived on:` line.
##   6. THE SHAPE OF THE WAIT is the caller's: a timeout of 0 reads every source once and returns at once.
##   7. A source that does not exist is refused at second zero.
## Offline: a Slack-shaped fake curl is first on PATH, every workspace is a folder of the rig's own, and no model CLI is started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigFixtures="$rigTest/check-fixtures"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="rig-member"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
[ -f "$rigHere/session/AgentsTools.SessionChat.include" ] || rigRefuse "the chat include is missing"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitChatFloorCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/skills/$rigMember"
printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
cp "$rigFixtures/wait-own-post-replies.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
rigWaitPath="$rigTmp/bin:$PATH"

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
rigDir="" rigSession="" rigThread="" rigOut="" rigChat=""
rigOwnMeta='"metadata":{"event_type":"rig","event_payload":{"sender":"rig-member"}}'
rigOtherMeta='"metadata":{"event_type":"rig","event_payload":{"sender":"keeper-old"}}'
rigStamp(){ ## epoch -- a touch -t stamp of it, BSD or GNU date
	date -r "$1" +%Y%m%d%H%M.%S 2> /dev/null || date -d "@$1" +%Y%m%d%H%M.%S
}
rigScene(){ ## scenario name
	rigNow="$( date +%s )"
	rigDir="$rigTmp/$1"
	rigSession="rig-sess-$1"
	rm -rf "$rigDir"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/temp" "$rigDir/ws/.local/agents/sessions/$rigSession" "$rigDir/data/inboxes/$rigMember/incoming" "$rigDir/data/board/pending"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=DRIGOWN01\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigDir/ws/.local/.agents/$rigMember.agent.env"
	: > "$rigDir/api.log"
	rigChat="$rigDir/ws/.local/agents/sessions/$rigSession"
	rigThread="CRIGSES01:$(( rigNow - 400 )).000001"
	printf '%s\n' "$rigThread" > "$rigChat/session.thread"
	: > "$rigDir/launch.marker"
	## the default sources (the team channel, the owner DM) read as quiet
	printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigDir/history.CRIG00001.json"
	printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigDir/history.DRIGOWN01.json"
	touch -t "$( rigStamp $(( rigNow - 300 )) )" "$rigDir/launch.marker"
}
rigMsg(){ ## ts user text [thread ts] [fields]
	printf '{"ts":"%s","user":"%s","text":"%s"%s%s}' "$1" "$2" "$3" "${4:+,\"thread_ts\":\"$4\"}" "${5:+,$5}"
}
rigJoin(){ ## messages... -- comma-joined
	local joinOut="" joinOne
	for joinOne in "$@" ; do joinOut="$joinOut${joinOut:+,}$joinOne" ; done
	printf '%s' "$joinOut"
}
rigThreadData(){ ## channel, thread ts, then its messages (root first)
	local threadChannel="$1" threadTs="$2"
	shift 2
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$( rigJoin "$@" )" > "$rigDir/replies.$threadChannel.$threadTs.json"
}
rigHistory(){ ## channel, then its top-level messages
	local historyChannel="$1"
	shift
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$( rigJoin "$@" )" > "$rigDir/history.$historyChannel.json"
}
rigAt(){ ## seconds back from now, microseconds
	printf '%s.%06d' "$(( rigNow - $1 ))" "$2"
}
## The operation under the scenario's workspace: a wait that does not return is killed.
rigWait(){ ## output basename, then the operation's arguments after the member
	local waitName="$1" waitPid waitWatch
	shift
	rigOut="$rigDir/$waitName.out"
	env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_WAIT_POLL_SECONDS -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS \
		"PATH=$rigWaitPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDAT_DATA_ROOT=$rigDir/data" "MDAT_SKILLSET_ROOT=$rigTmp/skills" "MDAT_SESSION_ID=${rigKey:-$rigSession}" "MDAT_SPAWN_LAUNCH_MARKER=$rigDir/launch.marker" \
		MDAT_WAIT_POLL_SECONDS=1 MDAT_WAIT_SETTLE_SECONDS=1 MDAT_WAIT_REMIND=off ${rigWithThread:+MDAT_SESSION_THREAD=$rigThread} \
		"$rigTool" --wait-for-input "$rigMember" "$@" > "$rigOut" 2> "$rigDir/$waitName.err" &
	waitPid=$!
	( waitLeft=60 ; while [ "$waitLeft" -gt 0 ] ; do kill -0 "$waitPid" 2>/dev/null || exit 0 ; sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
	  printf 'rig: the wait did not return within 60s, and was killed\n' >> "$rigDir/$waitName.err" ; kill -TERM "$waitPid" 2>/dev/null ; sleep 2 ; kill -KILL "$waitPid" 2>/dev/null ) &
	waitWatch=$!
	wait "$waitPid" 2>/dev/null
	kill -TERM "$waitWatch" 2>/dev/null
	wait "$waitWatch" 2>/dev/null || :
}
rigWithThread="" rigKey=""
rigPlain(){ ## output basename, bound, sources...
	local plainName="$1" plainBound="$2"
	shift 2
	rigWait "$plainName" --wait-default --wait-session-id "$rigSession" --wait-timeout "$plainBound" "$@"
}
rigHolds(){ ## text
	[ -f "$rigOut" ] || { printf 'no-such-output' ; return 0 ; }
	case "$( cat "$rigOut" )" in *"$1"*) printf yes ;; *) printf no ;; esac
}
rigCount(){ ## text -- how many lines of the last output hold it
	[ -f "$rigOut" ] || { printf 'no-such-output' ; return 0 ; }
	LC_ALL=C awk -v wantText="$1" 'index($0, wantText) > 0 { hitCount++ ; } END { print hitCount + 0 ; }' "$rigOut"
}
rigFirstLine(){
	[ -f "$rigOut" ] || { printf 'no-such-output' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { print ; exit ; }' "$rigOut"
}
rigArrived(){ ## the sources of the `# arrived on:` lines, in order, spaced
	LC_ALL=C awk '/^# arrived on: / { printf "%s ", substr($0, 15) ; }' "$rigOut"
}
rigReads(){ ## method, channel, optional ts
	LC_ALL=C awk -v wantMethod="$1" -v wantChannel="$2" -v wantTs="${3:-}" '$1 == wantMethod && $2 == wantChannel && ( wantTs == "" || $3 == wantTs ) { hitCount++ ; } END { print hitCount + 0 ; }' "$rigDir/api.log"
}
rigIndexOf(){ ## ts -- origin and seen of the index line of that message
	LC_ALL=C awk -F'\t' -v want="$1" '$2 == want { print $4 " " $6 ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$rigChat/session.chat.index" 2> /dev/null || printf 'no-index'
}
rigPointer(){ ## reader
	LC_ALL=C awk -F'\t' -v want="$1" '$1 == want { print $2 ; found = 1 ; } END { if ( ! found ) { print "none" ; } }' "$rigChat/session.chat.pointers" 2> /dev/null || printf 'no-pointers'
}
rigSeed(){ ## the thread of the session: its root before the launch, a reply of a person after it
	rigThreadData CRIGSES01 "$(( rigNow - 400 )).000001" \
		"$( rigMsg "$(( rigNow - 400 )).000001" URIGHUM1 RIG-ROOT-BEFORE-LAUNCH )" \
		"$( rigMsg "$(( rigNow - 100 )).000001" URIGHUM1 RIG-NEW-ONE "$(( rigNow - 400 )).000001" )"
	rigHistory CRIGSES01 "$( rigMsg "$(( rigNow - 400 )).000001" URIGHUM1 RIG-ROOT-BEFORE-LAUNCH )"
}

echo "-- 1. the floor is in --"
rigScene floor
rigSeed
rigPlain floor-in 2 --wait-source "file:$rigDir/none"
rigAssert "a session that has a folder: no replies source, the chat file, then the sources named, then the rest of the floor" "$( LC_ALL=C sed -n 's/^# sources: //p' "$rigOut" )" "chat:$rigSession file:$rigDir/none dms:$rigMember mentions:$rigMember wake:$rigMember"
rigAssert "no TTL is said in the return: an agent never needs them"  "$( LC_ALL=C grep -c '^# ttl:' "$rigOut" )" 0
rigKey="rig-sess-nofolder"
rigWait floor-none --wait-default --wait-session-id "rig-sess-nofolder" --wait-timeout 2 --wait-source "file:$rigDir/none"
rigKey=""
rigAssert "a session with no folder: no chat source (the replies alone, as ever)" "$( LC_ALL=C sed -n 's/^# sources: //p' "$rigOut" )" "replies:rig-sess-nofolder file:$rigDir/none dms:$rigMember mentions:$rigMember wake:$rigMember"

echo "-- 2. the file is brought up to date by the wait --"
rigScene topup
rigSeed
rigPlain topup-1 4 --wait-source "file:$rigDir/none"
rigAssert "RECEIVED, with the message that came after the launch"     "$( rigFirstLine ):$( rigHolds RIG-NEW-ONE )" "WAIT-RESULT: RECEIVED:yes"
rigAssert "behind the source it is of, the session thread, through the floor: a named set does not read the thread itself"             "$( rigArrived )" "slack:$rigThread "
rigAssert "not the root, which was there before the run began"         "$( rigHolds RIG-ROOT-BEFORE-LAUNCH )" no
rigAssert "it came once, in the body of its source's part"             "$( rigCount RIG-NEW-ONE )" 1
## a named set is the wait's own (sketch 3.2): the session thread is no source of it, and the floor's chat file is brought up to date from the thread itself
rigAssert "the thread was read once for the wait, into the file"       "$( [ "$( rigReads conversations.replies CRIGSES01 "$(( rigNow - 400 )).000001" )" -le 2 ] && echo ok || echo more )" ok
rigAssert "the root is in the file as history, the reply as new, read in by the floor"       "$( rigIndexOf "$(( rigNow - 400 )).000001" ) / $( rigIndexOf "$(( rigNow - 100 )).000001" )" "history - / slack -"
rigAssert "the floor delivered it: the member's read pointer is past it" "$( rigPointer read:$rigMember )" 2
rigTopupBefore="$( rigReads conversations.replies CRIGSES01 "$(( rigNow - 400 )).000001" )"
rigPlain topup-2 2 --wait-source "file:$rigDir/none"
rigAssert "the next wait: nothing new, the message is returned once"  "$( rigFirstLine ):$( rigHolds RIG-NEW-ONE )" "WAIT-RESULT: TIMEOUT:no"
## the floor reads the thread into the file once its TTL has passed (5 s and more), and the next wait comes inside it
rigAssert "and the next wait, inside the thread's TTL, does not read it again" "$( [ "$( rigReads conversations.replies CRIGSES01 "$(( rigNow - 400 )).000001" )" -gt "$rigTopupBefore" ] && echo yes || echo no )" no

echo "-- 3. both paths run together --"
rigScene both
rigSeed
rigWithThread=1
rigPlain both-1 4
rigWithThread=""
rigAssert "a default wait reads the session thread itself, and returns the message"  "$( rigFirstLine ):$( rigHolds RIG-NEW-ONE )" "WAIT-RESULT: RECEIVED:yes"
rigAssert "once"                                                       "$( rigCount RIG-NEW-ONE )" 1
rigAssert "under the source the wait read it by"                       "$( rigArrived )" "slack:${rigThread}:conversation "
rigAssert "and the file holds it, delivered by the wait itself"        "$( rigIndexOf "$(( rigNow - 100 )).000001" )" "slack $rigMember"
rigAssert "a tool return does not carry it again: the floor of the member is empty" "$( MMDAPP="$rigDir/ws" MDAT_SESSION_ID="$rigSession" bash -c ". '$rigHere/session/AgentsTools.SessionChat.include' ; AgentsToolsSessionChatFloor '$rigSession' '$rigMember' | wc -c | tr -d ' '" )" 0

echo "-- 4. the replies come into the file --"
rigScene replies
rigSeed
rigPost="$(( rigNow - 250 )).000001"
printf '%s\n' "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0" > "$rigChat/last-own-post"
rigThreadData CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" "$( rigMsg "$(( rigNow - 200 )).000001" URIGADDR1 RIG-REPLY-TO-POST "$rigPost" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )"
rigPlain replies-1 4 --wait-source "file:$rigDir/none"
rigAssert "the reply to the post is returned by the floor"             "$( rigHolds RIG-REPLY-TO-POST )" yes
rigAssert "and is in the chat file, a reply to the member's post that its wait delivered" "$( rigIndexOf "$(( rigNow - 200 )).000001" )" "reply:$rigMember $rigMember"

echo "-- 5. the order --"
rigScene order
rigSeed
rigPost="$(( rigNow - 250 )).000001"
printf '%s\n' "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0" > "$rigChat/last-own-post"
rigThreadData CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" "$( rigMsg "$(( rigNow - 200 )).000001" URIGADDR1 RIG-FLOOR-REPLY "$rigPost" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )"
rigHistory CRIGXXX01 "$( rigMsg "$(( rigNow - 90 )).000001" URIGOTHER RIG-X-FIRST )" "$( rigMsg "$(( rigNow - 70 )).000001" URIGOTHER RIG-X-THIRD )"
rigHistory CRIGYYY01 "$( rigMsg "$(( rigNow - 80 )).000001" URIGOTHER RIG-Y-SECOND )"
rigPlain order-1 25 --wait-source slack:CRIGYYY01 --wait-source slack:CRIGXXX01 --wait-since-utime "$(( rigNow - 120 ))"
rigAssert "the floor first: no replies source, the session thread; then the rest by time, a source under one line while its messages run" "$( rigArrived )" "slack:$rigThread slack:CRIGXXX01 slack:CRIGYYY01 slack:CRIGXXX01 "
rigAssert "each message once, oldest first among the rest"              "$( LC_ALL=C grep -o -E 'RIG-(X-FIRST|Y-SECOND|X-THIRD)' "$rigOut" | LC_ALL=C tr '\n' ' ' )" "RIG-X-FIRST RIG-Y-SECOND RIG-X-THIRD "
rigAssert "and every block closed"                                     "$( LC_ALL=C grep -c '^# --- end ---$' "$rigOut" )" 4

echo "-- 6. the shape of the wait is the caller's --"
rigScene shape
rigSeed
rigStarted="$( date +%s )"
rigPlain shape-0 0 --wait-source "file:$rigDir/none"
rigAssert "timeout 0 reads every source once and returns at once, with the floor's message" "$( rigFirstLine ):$( rigHolds RIG-NEW-ONE ):$( [ $(( $( date +%s ) - rigStarted )) -le 15 ] && echo quick || echo slow )" "WAIT-RESULT: RECEIVED:yes:quick"

echo "-- 7. what is refused --"
rigScene refuse
rigWait refuse-1 --wait-source scan:no-such-scan --wait-timeout 0
rigAssert "a scan that is none of the tooling's"                       "$( rigFirstLine ):$( LC_ALL=C grep -c 'names no scan of the tooling' "$rigDir/refuse-1.err" )" "WAIT-RESULT: ERROR:1"
rigWait refuse-2 --wait-source tagged:somebody-else --wait-timeout 0
rigAssert "the tags of another member"                                 "$( rigFirstLine ):$( LC_ALL=C grep -c 'own tags only' "$rigDir/refuse-2.err" )" "WAIT-RESULT: ERROR:1"
rigWait refuse-3 --wait-source chat:bad/name --wait-timeout 0
rigAssert "a chat that is no session folder name"                      "$( rigFirstLine )" "WAIT-RESULT: ERROR"
rigWait refuse-4 --wait-list-sources
rigAssert "the kinds this build carries name the three new ones"       "$( LC_ALL=C grep -c -E '^(chat|scan|tagged)	' "$rigOut" )" 3

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT CHAT FLOOR CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_CHAT_FLOOR: OK (%d assertions, offline)\n' "$rigPassCount"
