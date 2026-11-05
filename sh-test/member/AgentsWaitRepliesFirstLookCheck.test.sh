#!/usr/bin/env bash
## Behavioural check on the FIRST LOOK of the replies floor (S6.39, the human-owner's report of `eyes` on old messages).
##
## The defect: a post's thread floor and conversation floor are recorded as `-` until a look has happened, and the look
## read from the POST'S OWN TS. So the first look after a run starts read back to that post and handed the whole thread
## over as new: every old message was delivered as an arrival and took a seen `eyes`. Measured for claims written on
## 3 November: on MDV 373 of 373 were for messages over 6 hours old, on MEL 684 of 813.
##
## The rule held here: A POST THAT WAS NEVER LOOKED AT STARTS AT THE RUN'S OWN BEGINNING, never at its own ts. That is
## the same floor a spawn's thread source already takes (AgentsTools.MemberWaitSources.include: the launch marker's
## mtime, else the wait's own start), so the family keeps one rule and not two. What follows from it, and is held here:
##   a. A message already in the thread when the run began is not returned as new, and takes no `eyes`.
##   b. A message that truly arrived after the run began is returned, and is marked: the fix drops history, not work.
##   c. A later look still returns what arrived while the run was working, so nothing is lost by the new floor.
##   d. A thread with nothing after the run's start returns nothing and marks nothing.
##   e. The floor the record keeps is the run's beginning, so the post is not re-read from its own ts on every TTL.
##   f. The react path logs one line per attempt, with the member, the account used and the result.
##   g. A failure a second identity cannot fix is not retried (message_not_found: one call, not two).
##   h. Control: a failure a second identity CAN fix still gets its retry, and the mark lands
##      (channel_not_found under the member's account, then the bot's own success).
## Offline: a Slack-shaped fake curl is first on PATH, every workspace is a folder of the rig's own, no model CLI runs.
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
[ -f "$rigHere/member/AgentsTools.MemberWaitReplies.include" ] || rigRefuse "the replies include is missing from the package"
[ -f "$rigHere/comms/AgentsTools.SeenReaction.include" ] || rigRefuse "the seen-reaction include is missing from the package"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitRepliesFirstLookCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/skills/$rigMember"
printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
cp "$rigFixtures/wait-first-look.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package: $rigFixtures/wait-first-look.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
rigWaitPath="$rigTmp/bin:$PATH"
[ "$( PATH="$rigWaitPath" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on its PATH"

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
rigDir="" rigSession="" rigOut="" rigChat=""
rigOwnMeta='"metadata":{"event_type":"rig","event_payload":{"sender":"rig-member"}}'
rigStamp(){ ## epoch -- a touch -t stamp of it, BSD or GNU date
	date -r "$1" +%Y%m%d%H%M.%S 2> /dev/null || date -d "@$1" +%Y%m%d%H%M.%S
}
rigScene(){ ## scenario name
	rigNow="$( date +%s )"
	rigDir="$rigTmp/$1"
	rigSession="rig-sess-$1"
	rm -rf "$rigDir"
	rigChat="$rigDir/ws/.local/agents/sessions/$rigSession"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/temp" "$rigChat" "$rigDir/data/inboxes/$rigMember/incoming" "$rigDir/data/board/pending"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=DRIGOWN01\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIGMEMBER\n' > "$rigDir/ws/.local/.agents/$rigMember.agent.env"
	: > "$rigDir/api.log"
	: > "$rigDir/reactions"
	: > "$rigDir/launch.marker"
	touch -t "$( rigStamp $(( rigNow - 300 )) )" "$rigDir/launch.marker"
	printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigDir/history.CRIG00001.json"
	printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigDir/history.DRIGOWN01.json"
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
## The record of the run's own posts, and the floor fields as the wait keeps them.
rigRecord(){ ## record lines, newest first
	printf '%s\n' "$@" > "$rigChat/last-own-post"
}
rigField(){ ## line, field
	LC_ALL=C awk -v wantLine="$1" -v wantField="$2" 'NR == wantLine { print $wantField ; found = 1 ; exit ; } END { if ( ! found ) { print "no-such-line" ; } }' "$rigChat/last-own-post" 2> /dev/null
}
## A floor field of a record line, said by the run's own beginning: none, the post's own ts, the run's start or later, or older.
## Given the post's ts as a third word, it answers yes or no instead: is the floor that very ts.
rigFloorOf(){ ## line, field, [the post's ts]
	local floorValue
	floorValue="$( rigField "$1" "$2" )"
	if [ -n "${3:-}" ] ; then
		[ "$floorValue" != "$3" ] && printf no || printf yes
		return 0
	fi
	case "$floorValue" in
		'-') printf 'none' ; return 0 ;;
		"$rigPost") printf 'post-ts' ; return 0 ;;
		''|*[!0-9.]*) printf 'unreadable' ; return 0 ;;
	esac
	if [ "${floorValue%%.*}" -ge "$(( rigNow - 300 ))" ] ; then printf 'run-start-or-later' ; else printf 'older' ; fi
}
## Every line of the record due again: the check time back to the start of time.
rigDue(){
	LC_ALL=C awk '{ $8 = 0 ; print ; }' "$rigChat/last-own-post" > "$rigChat/last-own-post.due" && mv -f "$rigChat/last-own-post.due" "$rigChat/last-own-post"
}
## The operation under the scenario's workspace, with a guard: a wait that does not return is killed.
rigWait(){ ## output basename, then the operation's arguments after the member
	local waitName="$1" waitPid waitWatch
	shift
	rigOut="$rigDir/$waitName.out"
	env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_WAIT_POLL_SECONDS -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS \
		"PATH=$rigWaitPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDAT_DATA_ROOT=$rigDir/data" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_SPAWN_LAUNCH_MARKER=$rigDir/launch.marker" \
		MDAT_WAIT_POLL_SECONDS=1 MDAT_WAIT_SETTLE_SECONDS=1 MDAT_WAIT_REMIND=off \
		"$rigTool" --wait-for-input --team-member "$rigMember" --wait-default --wait-session-id "$rigSession" --wait-timeout "${2:-3}" > "$rigOut" 2> "$rigDir/$waitName.err" &
	waitPid=$!
	## The guard ends the sleep it is in as well as itself, so the scenario leaves no process behind.
	( watchSleep="" ; trap 'kill "$watchSleep" 2> /dev/null ; exit 0' TERM ; waitLeft=60
	  while [ "$waitLeft" -gt 0 ] ; do
		kill -0 "$waitPid" 2> /dev/null || exit 0
		sleep 1 & watchSleep=$! ; wait "$watchSleep" 2> /dev/null
		waitLeft=$(( waitLeft - 1 ))
	  done
	  printf 'rig: the wait did not return within 60s, and was killed\n' >> "$rigDir/$waitName.err" ; kill -TERM "$waitPid" 2> /dev/null ; sleep 2 ; kill -KILL "$waitPid" 2> /dev/null ) &
	waitWatch=$!
	wait "$waitPid" 2>/dev/null
	kill -TERM "$waitWatch" 2>/dev/null
	wait "$waitWatch" 2>/dev/null || :
}
rigFirstLine(){
	[ -f "$rigOut" ] || { printf 'no-such-output' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { print ; exit ; }' "$rigOut"
}
rigHolds(){ ## text
	[ -f "$rigOut" ] || { printf 'no-such-output' ; return 0 ; }
	case "$( cat "$rigOut" )" in *"$1"*) printf yes ;; *) printf no ;; esac
}
rigSeenClaims(){ ## ts -- the claim file the seen store holds for that message
	[ -f "$rigDir/ws/.local/agents/schedule/seen/$rigMember/$1" ] && printf claim || printf none
}
rigReactAttempts(){ ## ts -- how many reaction requests the fake Slack was asked for that message
	[ -f "$rigDir/reactions" ] || { printf 0 ; return 0 ; }
	LC_ALL=C awk -v want="$1" '$3 == want { hitCount++ ; } END { print hitCount + 0 ; }' "$rigDir/reactions"
}
rigReactResultOf(){ ## ts, channel of the attempt -- "<account> <result>" of the last attempt on it
	LC_ALL=C awk -v want="$1" -v wantChannel="$2" '$2 == wantChannel && $3 == want { account = $1 ; result = $5 ; } END { print ( account == "" ? "no-attempt" : account " " result ) ; }' "$rigDir/reactions" 2> /dev/null
}
## The log the react path keeps: one line per attempt. Read whole, as a table of fields.
rigReactLog(){ ## -- the attempts log of the scenario's workspace, one line a step
	cat "$rigDir/ws/.local/agents/comms-slack-react."*.log 2> /dev/null
}
rigReactLogCount(){ ## ts, field to match -- how many logged attempts match
	rigReactLog | LC_ALL=C awk -v want="$1" -v field="$2" 'index($0, want) > 0 && ( field == "" || index($0, field) > 0 ) { hitCount++ ; } END { print hitCount + 0 ; }'
}

## ---------------------------------------------------------------------------
## 1. The first look: the run's beginning is the floor, not the post's own ts.
## ---------------------------------------------------------------------------
echo "-- 1. a post never looked at: the run's beginning is the floor --"
rigScene firstlook
rigPost="$( rigAt 21600 100 )"
rigOld="$( rigAt 7200 200 )"
rigFresh="$( rigAt 120 300 )"
rigThreadData CRIGDM001 "$rigPost" \
	"$( rigMsg "$rigPost" URIGSELF1 RIG-OLD-QUESTION '' "$rigOwnMeta" )" \
	"$( rigMsg "$rigOld" URIGADDR1 RIG-OLD-REPLY "$rigPost" )" \
	"$( rigMsg "$rigFresh" URIGADDR1 RIG-FRESH-REPLY "$rigPost" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-OLD-QUESTION '' "$rigOwnMeta" )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigWait firstlook 4
rigAssert "control: a reply that arrived after the run began is returned"  "$( rigHolds 'RIG-FRESH-REPLY' )" yes
rigAssert "a reply that was already there when the run began is not new"    "$( rigHolds 'RIG-OLD-REPLY' )" no
rigAssert "and it takes no seen mark"                                      "$( rigReactAttempts "$rigOld" ):$( rigSeenClaims "$rigOld" )" "0:none"
rigAssert "the reply that is new takes exactly one"                        "$( rigReactAttempts "$rigFresh" ):$( rigSeenClaims "$rigFresh" )" "1:claim"
rigAssert "the post stays watched: its record line is still the post"      "$( rigField 1 1 ) $( rigField 1 2 )" "CRIGDM001:$rigPost $rigPost"
rigAssert "the thread floor the record keeps is never the post's own ts"   "$( rigFloorOf 1 4 ):$( rigFloorOf 1 4 "$rigPost" )" "run-start-or-later:no"
rigAssert "and the conversation floor is the same"                        "$( rigFloorOf 1 5 ):$( rigFloorOf 1 5 "$rigPost" )" "run-start-or-later:no"

## ---------------------------------------------------------------------------
## 2. Nothing after the run's beginning: nothing returned, nothing marked.
## ---------------------------------------------------------------------------
echo "-- 2. a thread with nothing new --"
rigScene quiet
rigPost="$( rigAt 21600 100 )"
rigOld="$( rigAt 7200 200 )"
rigThreadData CRIGDM001 "$rigPost" \
	"$( rigMsg "$rigPost" URIGSELF1 RIG-OLD-QUESTION '' "$rigOwnMeta" )" \
	"$( rigMsg "$rigOld" URIGADDR1 RIG-OLD-REPLY "$rigPost" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-OLD-QUESTION '' "$rigOwnMeta" )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigWait quiet 3
rigAssert "a thread whose messages all predate the run: TIMEOUT"          "$( rigFirstLine )" "WAIT-RESULT: TIMEOUT"
rigAssert "and nothing was delivered"                                     "$( rigHolds 'RIG-OLD-REPLY' )" no
rigAssert "and nothing was marked"                                        "$( LC_ALL=C awk 'NF { hitCount++ } END { print hitCount + 0 }' "$rigDir/reactions" )" 0

## ---------------------------------------------------------------------------
## 3. A reply that arrives while the run works still arrives (no loss by the new floor).
## ---------------------------------------------------------------------------
echo "-- 3. a reply that arrives during the run --"
rigScene duringrun
rigPost="$( rigAt 21600 100 )"
rigOld="$( rigAt 7200 200 )"
rigFresh="$( rigAt 120 300 )"
rigLate="$( rigAt 60 400 )"
rigThreadData CRIGDM001 "$rigPost" \
	"$( rigMsg "$rigPost" URIGSELF1 RIG-OLD-QUESTION '' "$rigOwnMeta" )" \
	"$( rigMsg "$rigOld" URIGADDR1 RIG-OLD-REPLY "$rigPost" )" \
	"$( rigMsg "$rigFresh" URIGADDR1 RIG-FRESH-REPLY "$rigPost" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-OLD-QUESTION '' "$rigOwnMeta" )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigWait duringrun-first 4
rigAssert "control: the first look returns the reply after the run began"  "$( rigHolds 'RIG-FRESH-REPLY' )" yes
rigThreadData CRIGDM001 "$rigPost" \
	"$( rigMsg "$rigPost" URIGSELF1 RIG-OLD-QUESTION '' "$rigOwnMeta" )" \
	"$( rigMsg "$rigOld" URIGADDR1 RIG-OLD-REPLY "$rigPost" )" \
	"$( rigMsg "$rigFresh" URIGADDR1 RIG-FRESH-REPLY "$rigPost" )" \
	"$( rigMsg "$rigLate" URIGADDR1 RIG-LATE-REPLY "$rigPost" )"
rigDue
rigWait duringrun-second 4
rigAssert "the reply that arrived while the run worked is returned"        "$( rigHolds 'RIG-LATE-REPLY' )" yes
rigAssert "and it takes one seen mark"                                    "$( rigReactAttempts "$rigLate" ):$( rigSeenClaims "$rigLate" )" "1:claim"
rigAssert "the reply already handed over is not handed over again"         "$( rigHolds 'RIG-FRESH-REPLY' )" no

## ---------------------------------------------------------------------------
## 4. The react path: one log line per attempt, and no retry that cannot help.
## ---------------------------------------------------------------------------
echo "-- 4. the react path's log, and the retry it should not make --"
rigScene logok
rigPost="$( rigAt 21600 100 )"
rigFresh="$( rigAt 120 300 )"
rigThreadData CRIGDM001 "$rigPost" \
	"$( rigMsg "$rigPost" URIGSELF1 RIG-OLD-QUESTION '' "$rigOwnMeta" )" \
	"$( rigMsg "$rigFresh" URIGADDR1 RIG-FRESH-REPLY "$rigPost" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-OLD-QUESTION '' "$rigOwnMeta" )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigWait logok 4
rigAssert "a mark that lands is logged once, naming the member and the account used"  "$( rigReactLogCount "$rigFresh" "rig-member" ):$( rigReactLogCount "$rigFresh" "user" ):$( rigReactLogCount "$rigFresh" "ok" )" "1:1:1"
rigScene logdead
rigPost="$( rigAt 21600 100 )"
rigFresh="$( rigAt 120 300 )"
rigThreadData CRIGDM001 "$rigPost" \
	"$( rigMsg "$rigPost" URIGSELF1 RIG-OLD-QUESTION '' "$rigOwnMeta" )" \
	"$( rigMsg "$rigFresh" URIGADDR1 RIG-FRESH-REPLY "$rigPost" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-OLD-QUESTION '' "$rigOwnMeta" )"
printf '%s message_not_found\n' "$rigFresh" > "$rigDir/react-errors"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigWait logdead 4
rigAssert "a failure no second account can fix is tried once, not twice"   "$( rigReactAttempts "$rigFresh" )" 1
rigAssert "and the log says what failed, and under which account"         "$( rigReactLogCount "$rigFresh" "message_not_found" ):$( rigReactLogCount "$rigFresh" "rig-member" )" "1:1"
rigAssert "and the claim is taken back, so a later look offers it again"    "$( rigSeenClaims "$rigFresh" )" none
rigScene logretry
rigPost="$( rigAt 21600 100 )"
rigFresh="$( rigAt 120 300 )"
rigThreadData CRIGDM001 "$rigPost" \
	"$( rigMsg "$rigPost" URIGSELF1 RIG-OLD-QUESTION '' "$rigOwnMeta" )" \
	"$( rigMsg "$rigFresh" URIGADDR1 RIG-FRESH-REPLY "$rigPost" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-OLD-QUESTION '' "$rigOwnMeta" )"
printf '%s ekm_access_denied user\n' "$rigFresh" > "$rigDir/react-errors"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigWait logretry 4
rigAssert "control: a failure a second account CAN fix is retried, and the mark lands" \
	"$( rigReactAttempts "$rigFresh" ):$( rigSeenClaims "$rigFresh" ):$( rigReactLogCount "$rigFresh" "bot:bot" )" "2:claim:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT REPLIES FIRST LOOK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_REPLIES_FIRST_LOOK: OK (%d assertions, offline)\n' "$rigPassCount"
exit 0
