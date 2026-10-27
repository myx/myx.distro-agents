#!/usr/bin/env bash
## Behavioural check on the floor of a plain Wait: the replies to the run's own posts (F3.3, pulled ahead as
## a field fix). A member posted a question with SendMessage, then watched the Slack channel, and the reply
## came in the thread of its post, which a channel read does not return. Held here, run and not read:
##   0. A BARE CONVERSATION as a source -- the field case watched DMs so -- returns a message newer than
##      its floor: its read prints formatted text, which was formatted again as JSON and so printed nothing.
##   1. THE FIELD CASE. A plain Wait, with no sources, returns the reply given in the thread of the run's post
##      that a watch of the channel misses; it returns it once; the floor is always in, and the sources a Wait
##      names are added to it, so a Wait that names the channel returns the reply too, once.
##   2. THE ROOT FOLLOW-UP. For a root post, a message of an addressee in the same conversation after it is
##      returned and a bystander's is not; every reply in the thread is, and the run's own posts are not; a
##      post that is a reply has its thread alone.
##   3. LIMIT 1, THE TTL. A thread is looked at only on some loop runs, ever more rarely while it stays quiet,
##      and its watch never ends by time alone. A post a question opened is its pending record's, and a thread
##      that cannot be read is tried again by its TTL, not at every round.
##   4. LIMIT 2, TEN SIBLINGS. For a root post the next messages in its channel are watched until ten have
##      followed it; after that only a mention of the run is looked for there; its thread stays watched.
##   5. LIMIT 3. A reaction to the run's post and a mention of the run are returned, a post whose channel
##      watch has ended included for the reaction.
##   6. THE FLOOR IS DELIVERED ONCE. What another source of the same Wait already returns is not returned again.
##   7. THE NEXT LINE of SendMessage and of the tools that ask says only to call Wait; the record of the run's
##      own posts (sessions/<id>/last-own-post) keeps the latest first, with its first two words as ever.
## Offline: a Slack-shaped fake curl is first on PATH, every workspace is a folder of the rig's own, and no
## model CLI is started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigFixtures="$rigTest/check-fixtures"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigMember="rig-member"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitOwnPostRepliesCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/askbin" "$rigTmp/skills/$rigMember"
printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
cp "$rigFixtures/wait-own-post-replies.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
cp "$rigFixtures/harness-ask-check.curl.stub.sh" "$rigTmp/askbin/curl" || rigRefuse "the posting fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl" "$rigTmp/askbin/curl"
rigWaitPath="$rigTmp/bin:$PATH"
rigAskPath="$rigTmp/askbin:$PATH"
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

## ---------------------------------------------------------------------------
## The rig: one workspace per scenario, its own session, and a thread or a conversation the fake Slack serves.
## ---------------------------------------------------------------------------
rigNow="$( date +%s )"
rigDir=""
rigSession=""
rigSessionThread=""
rigOut=""
rigOwnMeta='"metadata":{"event_type":"rig","event_payload":{"sender":"rig-member"}}'
rigReactEyes='"reactions":[{"name":"eyes","count":1,"users":["URIGADDR1"]}]'
rigScene(){ ## scenario name
	## The moment every time of the scenario is counted back from, fresh for each: a TTL is measured against the clock.
	rigNow="$( date +%s )"
	rigDir="$rigTmp/$1"
	rigSession="rig-sess-$1"
	rigSessionThread=""
	rm -rf "$rigDir"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/temp" "$rigDir/ws/.local/agents/sessions/$rigSession" "$rigDir/data/inboxes/$rigMember/incoming" "$rigDir/data/board/pending"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=DRIGOWN01\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigDir/ws/.local/.agents/$rigMember.agent.env"
	: > "$rigDir/api.log"
}
## A message of the fake Slack: ts, user, text, optional thread ts, optional more JSON fields.
rigMsg(){ ## ts user text [thread ts] [fields]
	printf '{"ts":"%s","user":"%s","text":"%s"%s%s}' "$1" "$2" "$3" "${4:+,\"thread_ts\":\"$4\"}" "${5:+,$5}"
}
rigJoin(){ ## messages... -- comma-joined
	local joinOut="" joinOne
	for joinOne in "$@" ; do joinOut="$joinOut${joinOut:+,}$joinOne" ; done
	printf '%s' "$joinOut"
}
rigThread(){ ## channel, thread root ts, then its messages (root first)
	local threadChannel="$1" threadTs="$2"
	shift 2
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$( rigJoin "$@" )" > "$rigDir/replies.$threadChannel.$threadTs.json"
}
rigHistory(){ ## channel, then its top-level messages
	local historyChannel="$1"
	shift
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$( rigJoin "$@" )" > "$rigDir/history.$historyChannel.json"
}
rigRecord(){ ## record lines, newest first
	printf '%s\n' "$@" > "$rigDir/ws/.local/agents/sessions/$rigSession/last-own-post"
}
rigRecordFile(){
	printf '%s' "$rigDir/ws/.local/agents/sessions/$rigSession/last-own-post"
}
## One field of one line of the record: line number, field number.
rigField(){ ## line, field
	[ -f "$( rigRecordFile )" ] || { printf 'no-record' ; return 0 ; }
	LC_ALL=C awk -v wantLine="$1" -v wantField="$2" 'NR == wantLine { print $wantField ; found = 1 ; exit ; } END { if ( ! found ) { print "no-such-line" ; } }' "$( rigRecordFile )"
}
## Every line of the record due again: the check time (field 8) back to the start of time.
rigDue(){
	LC_ALL=C awk '{ $8 = 0 ; print ; }' "$( rigRecordFile )" > "$( rigRecordFile ).due" && mv -f "$( rigRecordFile ).due" "$( rigRecordFile )"
}
## The operation under the scenario's workspace, with the guard rigNew has: a wait that does not return is killed.
rigWait(){ ## output basename, then the operation's arguments after the member
	local waitName="$1" waitPid waitWatch
	shift
	rigOut="$rigDir/$waitName.out"
	env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_WAIT_POLL_SECONDS -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS \
		"PATH=$rigWaitPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDAT_DATA_ROOT=$rigDir/data" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		MDAT_WAIT_POLL_SECONDS=1 MDAT_WAIT_SETTLE_SECONDS=1 MDAT_WAIT_REMIND=off ${rigSessionThread:+MDAT_SESSION_THREAD=$rigSessionThread} \
		"$rigTool" --wait-for-input "$rigMember" "$@" > "$rigOut" 2> "$rigDir/$waitName.err" &
	waitPid=$!
	( waitLeft=40 ; while [ "$waitLeft" -gt 0 ] ; do kill -0 "$waitPid" 2>/dev/null || exit 0 ; sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
	  printf 'rig: the wait did not return within 40s, and was killed\n' >> "$rigDir/$waitName.err" ; kill -TERM "$waitPid" 2>/dev/null ; sleep 2 ; kill -KILL "$waitPid" 2>/dev/null ) &
	waitWatch=$!
	wait "$waitPid" 2>/dev/null
	kill -TERM "$waitWatch" 2>/dev/null
	wait "$waitWatch" 2>/dev/null || :
}
## The plain Wait: no source named, a session of its own, a bound short enough for a quiet scenario.
rigPlain(){ ## output basename
	rigWait "$1" --wait-default --wait-session-id "$rigSession" --wait-timeout "${2:-3}"
}
rigHolds(){ ## text -- whether the last output holds it
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
## How many times the fake Slack was asked for a thread or a conversation.
rigReads(){ ## method, channel, optional ts
	LC_ALL=C awk -v wantMethod="$1" -v wantChannel="$2" -v wantTs="${3:-}" '$1 == wantMethod && $2 == wantChannel && ( wantTs == "" || $3 == wantTs ) { hitCount++ ; } END { print hitCount + 0 ; }' "$rigDir/api.log"
}
rigAt(){ ## seconds back from now, microseconds
	printf '%s.%06d' "$(( rigNow - $1 ))" "$2"
}

## ---------------------------------------------------------------------------
## 0. A bare conversation as a source (the field case watched DMs so): a message newer than its floor
##    is an arrival. The read of a conversation prints formatted text, which was formatted again as JSON
##    and so printed nothing: no such source ever returned.
## ---------------------------------------------------------------------------
echo "-- 0. a bare conversation source returns what is newer --"
rigScene bare
rigHistory CRIG00001 "$( rigMsg "$( rigAt 100 100 )" URIGOTHER RIG-BARE-NEWER )"
rigWait bare-id --wait-source slack:CRIG00001 --wait-since-utime "$(( rigNow - 300 ))" --wait-timeout 4
rigAssert "a conversation named by its id: a newer message is RECEIVED"  "$( rigFirstLine ):$( rigHolds RIG-BARE-NEWER )" "WAIT-RESULT: RECEIVED:yes"
rigWait bare-name --wait-source slack:magic-team --wait-since-utime "$(( rigNow - 300 ))" --wait-timeout 4
rigAssert "a conversation named by its name: the same"                  "$( rigFirstLine ):$( rigHolds RIG-BARE-NEWER )" "WAIT-RESULT: RECEIVED:yes"
rigWait bare-after --wait-source slack:CRIG00001 --wait-since-utime "$(( rigNow - 50 ))" --wait-timeout 3
rigAssert "control: a floor past the message: nothing arrives"           "$( rigFirstLine ):$( rigHolds RIG-BARE-NEWER )" "WAIT-RESULT: TIMEOUT:no"

## ---------------------------------------------------------------------------
## 1. The field case.
## ---------------------------------------------------------------------------
echo "-- 1. the field case: a reply in the thread of the run's post --"
rigScene field
rigPost="$( rigAt 120 100 )"
rigReply="$( rigAt 100 200 )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" "$( rigMsg "$rigReply" URIGADDR1 RIG-FIELD-REPLY "$rigPost" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )"
rigPlain field-plain
rigAssert "a plain Wait returns RECEIVED"                      "$( rigFirstLine )" "WAIT-RESULT: RECEIVED"
rigAssert "with the reply given in the thread"                 "$( rigHolds 'RIG-FIELD-REPLY' )" yes
rigAssert "from the floor, which names the post it replies to" "$( rigHolds "# replies to your post CRIGDM001:$rigPost" )" yes
rigAssert "the floor is a source of the plain Wait"            "$( rigHolds "replies:$rigSession" )" yes
rigAssert "the post itself is not returned as a reply"         "$( rigHolds 'RIG-QUESTION' )" no
rigAssert "the reply was read in the thread of the post"       "$( rigReads conversations.replies CRIGDM001 "$rigPost" )" 1
rigDue
rigPlain field-again 3
rigAssert "the reply is returned once: the next plain Wait finds none" "$( rigFirstLine ):$( rigHolds 'RIG-FIELD-REPLY' )" "WAIT-RESULT: TIMEOUT:no"
rigAssert "the record keeps the newest reply of the thread as its floor" "$( rigField 1 4 )" "$rigReply"
rigFieldScene(){ ## scenario name -- the post, its thread with the reply, and its conversation with the post alone
	rigScene "$1"
	rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
	rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" "$( rigMsg "$rigReply" URIGADDR1 RIG-FIELD-REPLY "$rigPost" )"
	rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )"
}
rigFieldScene field-channel
rigWait field-channel --wait-source slack:CRIGDM001 --wait-timeout 3
rigAssert "control: the channel watch of the field case, with no floor, misses the reply" "$( rigFirstLine ):$( rigHolds 'RIG-FIELD-REPLY' )" "WAIT-RESULT: TIMEOUT:no"
rigFieldScene field-named
rigWait field-named --wait-default --wait-session-id "$rigSession" --wait-source slack:CRIGDM001 --wait-timeout 3
rigAssert "the same watch in a session: the floor is always in, and returns the reply" "$( rigFirstLine ):$( rigHolds 'RIG-FIELD-REPLY' )" "WAIT-RESULT: RECEIVED:yes"
rigAssert "the sources named are added to the floor, behind it"  "$( LC_ALL=C sed -n 's/^# sources: //p' "$rigOut" )" "replies:$rigSession slack:magic-team slack:human-owner slack:CRIGDM001"
rigAssert "the conversation the Wait names is not read twice: the floor leaves it" "$( [ "$( rigReads conversations.history CRIGDM001 )" -le 1 ] && printf 1 || printf more )" 1

## ---------------------------------------------------------------------------
## 2. The root follow-up, and what a thread returns.
## ---------------------------------------------------------------------------
echo "-- 2. a root post: its thread, and its addressees in the conversation --"
rigScene follow
rigPost="$( rigAt 300 100 )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" \
	"$( rigMsg "$( rigAt 250 100 )" URIGOTHER RIG-THREAD-BYSTANDER "$rigPost" )" \
	"$( rigMsg "$( rigAt 240 100 )" URIGSELF1 RIG-OWN-IN-THREAD "$rigPost" "$rigOwnMeta" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" \
	"$( rigMsg "$( rigAt 200 100 )" URIGADDR1 RIG-FOLLOW-UP )" \
	"$( rigMsg "$( rigAt 190 100 )" URIGOTHER RIG-BYSTANDER-CHANNEL )"
rigPlain follow 4
rigAssert "RECEIVED"                                           "$( rigFirstLine )" "WAIT-RESULT: RECEIVED"
rigAssert "the message of the addressee in the conversation"   "$( rigHolds 'RIG-FOLLOW-UP' )" yes
rigAssert "not the bystander's in the conversation"            "$( rigHolds 'RIG-BYSTANDER-CHANNEL' )" no
rigAssert "every reply in the thread, a bystander's too"       "$( rigHolds 'RIG-THREAD-BYSTANDER' )" yes
rigAssert "never the run's own post"                           "$( rigHolds 'RIG-OWN-IN-THREAD' )" no
rigAssert "the record keeps the conversation floor"            "$( rigField 1 5 )" "$( rigAt 190 100 )"
rigScene replypost
rigRoot="$( rigAt 400 100 )"
rigPost="$( rigAt 300 100 )"
rigRecord "CRIGDM001:$rigRoot $rigPost URIGADDR1 - - 0 - 0"
rigThread CRIGDM001 "$rigRoot" "$( rigMsg "$rigRoot" URIGOTHER RIG-ROOT )" \
	"$( rigMsg "$( rigAt 350 100 )" URIGADDR1 RIG-BEFORE-POST "$rigRoot" )" \
	"$( rigMsg "$rigPost" URIGSELF1 RIG-OWN-POST "$rigRoot" "$rigOwnMeta" )" \
	"$( rigMsg "$( rigAt 250 100 )" URIGADDR1 RIG-AFTER-POST "$rigRoot" )"
rigHistory CRIGDM001 "$( rigMsg "$( rigAt 200 100 )" URIGADDR1 RIG-CHANNEL-LEVEL )"
rigPlain replypost 4
rigAssert "a post that is a reply: what follows it in its thread"  "$( rigHolds 'RIG-AFTER-POST' )" yes
rigAssert "not what came before it"                                "$( rigHolds 'RIG-BEFORE-POST' )" no
rigAssert "nor the thread's root"                                  "$( rigHolds 'RIG-ROOT' )" no
rigAssert "and it has no conversation of its own: never read"      "$( rigReads conversations.history CRIGDM001 )" 0

## ---------------------------------------------------------------------------
## 3. Limit 1: the TTL grows while a thread stays quiet, and the watch never ends by time alone.
## ---------------------------------------------------------------------------
echo "-- 3. limit 1: ever more rarely, never expired --"
## A post whose thread holds one reply; quiet seconds back, checked seconds back.
rigTtl(){ ## scenario, seconds the post is old, seconds since it was last looked at
	rigScene "$1"
	rigPost="$( rigAt "$2" 100 )"
	rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - $(( rigNow - $3 ))"
	rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" "$( rigMsg "$( rigAt $(( $2 - 5 )) 200 )" URIGADDR1 RIG-TTL-REPLY "$rigPost" )"
	rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )"
}
rigTtl ttl-wait 3600 60
rigPlain ttl-wait 3
rigAssert "quiet an hour, looked at a minute ago (TTL 185s): not looked at again" "$( rigReads conversations.replies CRIGDM001 )" 0
rigAssert "so its reply waits"                                 "$( rigFirstLine )" "WAIT-RESULT: TIMEOUT"
rigTtl ttl-due 3600 400
rigPlain ttl-due 3
rigAssert "control: looked at 400s ago, past its TTL: looked at"  "$( rigReads conversations.replies CRIGDM001 )" 1
rigAssert "and its reply comes"                                "$( rigHolds 'RIG-TTL-REPLY' )" yes
rigAssert "the record keeps when it was looked at"             "$( rigField 1 8 | LC_ALL=C awk -v floorNow="$rigNow" '{ print ( $1 >= floorNow ? "now" : "old" ) ; }' )" now
rigTtl ttl-grows 600 40
rigPlain ttl-grows 3
rigAssert "quiet 10 minutes (TTL 35s), looked at 40s ago: looked at"  "$( rigReads conversations.replies CRIGDM001 )" 1
rigTtl ttl-grows-hour 3600 40
rigPlain ttl-grows-hour 3
rigAssert "the same 40s, quiet an hour: not yet, the TTL has grown"   "$( rigReads conversations.replies CRIGDM001 )" 0
rigTtl ttl-old 2592000 2592000
rigPlain ttl-old 3
rigAssert "a post a month old is not expired: it is looked at"     "$( rigReads conversations.replies CRIGDM001 )" 1
rigAssert "and its reply comes"                                "$( rigHolds 'RIG-TTL-REPLY' )" yes
rigScene ttl-rounds
rigPost="$( rigAt 600 100 )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )"
rigPlain ttl-rounds 5
rigAssert "a quiet thread is looked at on some loop runs: once in five rounds, not every round" "$( rigReads conversations.replies CRIGDM001 )" 1

echo "-- 3b. a question's post is the pending record's; a thread that cannot be read is retried by its TTL --"
rigScene asked
rigPost="$( rigAt 120 100 )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
mkdir -p "$rigDir/ws/.local/agents/pending"
printf -- '---\nstatus: reply-pending\nchannel: CRIGDM001\nquestion-ts: %s\nthread-ts: %s\n---\n\n# Question asked\n' "$rigPost" "$rigPost" > "$rigDir/ws/.local/agents/pending/rig-ask.md"
rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" "$( rigMsg "$( rigAt 100 200 )" URIGADDR1 RIG-ASKED-REPLY "$rigPost" )"
rigPlain asked 3
rigAssert "a post the ask tools opened is left to its pending record: not looked at"  "$( rigReads conversations.replies CRIGDM001 )$( rigHolds 'RIG-ASKED-REPLY' )" 0no
rigScene asked-thread
rigRoot="$( rigAt 130 100 )"
rigPost="$( rigAt 120 100 )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0" "CRIGDM001:$rigRoot $rigRoot URIGADDR1 - - 0 - 0"
mkdir -p "$rigDir/ws/.local/agents/pending"
printf -- '---\nstatus: reply-pending\nchannel: CRIGDM001\nquestion-ts: %s\nthread-ts: %s\n---\n\n# Question asked\n' "$rigPost" "$rigRoot" > "$rigDir/ws/.local/agents/pending/rig-ask.md"
rigThread CRIGDM001 "$rigRoot" "$( rigMsg "$rigRoot" URIGSELF1 RIG-ROOT '' "$rigOwnMeta,$rigReactEyes" )" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION "$rigRoot" "$rigOwnMeta" )"
rigPlain asked-thread 3
rigAssert "a proposal: its root and its reply are the pending record's, and a click on the root is its verdict, not a reaction to return" "$( rigReads conversations.replies CRIGDM001 )$( rigHolds 'reactions on your post' )" 0no
rigScene unreadable
rigPost="$( rigAt 120 100 )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigPlain unreadable 5
rigAssert "a thread that cannot be read is tried once in five rounds, not at every round" "$( rigReads conversations.replies CRIGDM001 )" 1
rigAssert "and its check time moves, so its TTL paces the next try"  "$( rigField 1 8 | LC_ALL=C awk -v floorNow="$rigNow" '{ print ( $1 >= floorNow ? "now" : "old" ) ; }' )" now
rigAssert "the Wait says the source could not run"              "$( rigHolds 'probes that could not run' )" yes

## ---------------------------------------------------------------------------
## 4. Limit 2: the next ten siblings of a root post in its channel.
## ---------------------------------------------------------------------------
echo "-- 4. limit 2: ten siblings --"
## The siblings after the root post: the first of an addressee, the others of a bystander, then one of an addressee.
rigSiblings(){ ## how many siblings, the text of the first one's addressee message, the text of the one after the last
	local sibIndex=1 sibOut="" sibText
	while [ "$sibIndex" -le "$1" ] ; do
		if [ "$sibIndex" = 1 ] ; then
			sibOut="$sibOut${sibOut:+,}$( rigMsg "$( rigAt $(( 300 - sibIndex )) 100 )" URIGADDR1 "$2" )"
		else
			sibOut="$sibOut${sibOut:+,}$( rigMsg "$( rigAt $(( 300 - sibIndex )) 100 )" URIGOTHER "RIG-SIB-$sibIndex" )"
		fi
		sibIndex=$(( sibIndex + 1 ))
	done
	sibOut="$sibOut,$( rigMsg "$( rigAt 100 100 )" URIGADDR1 "$3" )"
	printf '%s' "$sibOut"
}
rigScene ten
rigPost="$( rigAt 400 100 )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" "$( rigSiblings 10 RIG-SIB-FIRST-ADDRESSEE RIG-SIB-ELEVENTH-ADDRESSEE )"
rigPlain ten 4
rigAssert "within the first ten: an addressee's message is returned"  "$( rigHolds 'RIG-SIB-FIRST-ADDRESSEE' )" yes
rigAssert "after the tenth: an addressee's message is not"            "$( rigHolds 'RIG-SIB-ELEVENTH-ADDRESSEE' )" no
rigAssert "the record keeps the count, ten"                          "$( rigField 1 6 )" 10
rigAssert "the channel was read once"                                "$( rigReads conversations.history CRIGDM001 )" 1
rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" "$( rigMsg "$( rigAt 50 100 )" URIGADDR1 RIG-LATE-THREAD-REPLY "$rigPost" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" "$( rigSiblings 10 RIG-SIB-FIRST-ADDRESSEE RIG-SIB-ELEVENTH-ADDRESSEE )" "$( rigMsg "$( rigAt 40 100 )" URIGADDR1 RIG-SIB-TWELFTH-ADDRESSEE )" \
	"$( rigMsg "$( rigAt 30 100 )" URIGOTHER '🤖 *_other-member_* → 🤖 *_rig-member_*. RIG-LATE-MENTION' )"
rigDue
rigPlain ten-later 4
rigAssert "its thread stays watched: a later reply there comes"      "$( rigHolds 'RIG-LATE-THREAD-REPLY' )" yes
rigAssert "the channel's later messages are not watched any more"    "$( rigHolds 'RIG-SIB-TWELFTH-ADDRESSEE' )" no
rigAssert "but a mention of the run there is still caught"           "$( rigHolds 'RIG-LATE-MENTION' )" yes
rigAssert "found by reading the channel on, once more"               "$( rigReads conversations.history CRIGDM001 )" 2
rigAssert "the count stays at ten"                                   "$( rigField 1 6 )" 10
rigScene nine
rigPost="$( rigAt 400 100 )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" "$( rigSiblings 8 RIG-SIB-FIRST-ADDRESSEE RIG-SIB-NINTH-ADDRESSEE )"
rigPlain nine 4
rigAssert "control: nine siblings, the ninth an addressee's: returned"   "$( rigHolds 'RIG-SIB-NINTH-ADDRESSEE' )" yes
rigAssert "control: the watch goes on, and counts nine"                 "$( rigField 1 6 )" 9
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" "$( rigSiblings 8 RIG-SIB-FIRST-ADDRESSEE RIG-SIB-NINTH-ADDRESSEE )" \
	"$( rigMsg "$( rigAt 90 100 )" URIGADDR1 RIG-SIB-TENTH-ADDRESSEE )" "$( rigMsg "$( rigAt 80 100 )" URIGADDR1 RIG-SIB-AFTER-TENTH )"
rigDue
rigPlain nine-later 4
rigAssert "control: the tenth is returned the next time round"          "$( rigHolds 'RIG-SIB-TENTH-ADDRESSEE' )" yes
rigAssert "control: the one after the tenth is not"                     "$( rigHolds 'RIG-SIB-AFTER-TENTH' )" no
rigAssert "control: and then the count is ten"                          "$( rigField 1 6 )" 10

## ---------------------------------------------------------------------------
## 5. Limit 3: reactions to the run's posts and mentions of the run.
## ---------------------------------------------------------------------------
echo "-- 5. limit 3: reactions and mentions --"
rigScene react
rigPost="$( rigAt 300 100 )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta,$rigReactEyes" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta,$rigReactEyes" )"
rigPlain react 4
rigAssert "a reaction to the run's post is returned"                "$( rigHolds "reactions on your post $rigPost: [reactions: eyes x1 (URIGADDR1)]" )" yes
rigAssert "the record keeps it as seen"                              "$( rigField 1 7 | LC_ALL=C awk '{ print ( $1 == "-" ? "none" : "kept" ) ; }' )" kept
rigDue
rigPlain react-again 3
rigAssert "the same reaction is not returned twice"                 "$( rigFirstLine ):$( rigHolds 'reactions on your post' )" "WAIT-RESULT: TIMEOUT:no"
rigReactMore='"reactions":[{"name":"eyes","count":1,"users":["URIGADDR1"]},{"name":"white_check_mark","count":1,"users":["URIGADDR1"]}]'
rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta,$rigReactMore" )"
rigDue
rigPlain react-more 4
rigAssert "a reaction added later is"                               "$( rigHolds 'white_check_mark x1 (URIGADDR1)' )" yes
rigScene react-closed
rigPost="$( rigAt 300 100 )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 10 - 0"
rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta,$rigReactEyes" )"
rigPlain react-closed 4
rigAssert "a post whose channel watch has ended still has its reactions watched" "$( rigHolds 'reactions on your post' )" yes
rigAssert "and its channel is read on, for a mention alone"          "$( rigReads conversations.history CRIGDM001 )" 1
rigScene mention
rigPost="$( rigAt 400 100 )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )"
rigHistory CRIGDM001 "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" \
	"$( rigMsg "$( rigAt 300 100 )" URIGOTHER '🤖 *_other-member_* → 🤖 *_rig-member_*. RIG-MENTION-SIBLING' )" \
	"$( rigMsg "$( rigAt 290 100 )" URIGOTHER RIG-PLAIN-SIBLING )"
rigPlain mention 4
rigAssert "a message that mentions the run is returned, whoever wrote it" "$( rigHolds 'RIG-MENTION-SIBLING' )" yes
rigAssert "control: one that does not, from a bystander, is not"        "$( rigHolds 'RIG-PLAIN-SIBLING' )" no

## ---------------------------------------------------------------------------
## 6. Delivered once: what another source of the same Wait returns is not returned again.
## ---------------------------------------------------------------------------
echo "-- 6. delivered once --"
rigScene covered-thread
rigSessionThread="CSESS001:$( rigAt 900 100 )"
rigPost="$( rigAt 300 100 )"
rigRecord "CSESS001:${rigSessionThread#*:} $rigPost URIGADDR1 - - 0 - 0"
rigThread CSESS001 "${rigSessionThread#*:}" "$( rigMsg "${rigSessionThread#*:}" URIGOTHER RIG-SESSION-ROOT )" \
	"$( rigMsg "$rigPost" URIGSELF1 RIG-OWN-POST "${rigSessionThread#*:}" "$rigOwnMeta" )" \
	"$( rigMsg "$( rigAt 200 100 )" URIGADDR1 RIG-COVERED-REPLY "${rigSessionThread#*:}" )"
rigPlain covered-thread 4
rigAssert "a reply in the session thread, which the Wait reads as a source: once" "$( rigCount 'RIG-COVERED-REPLY' )" 1
rigScene covered-channel
rigPost="$( rigAt 300 100 )"
rigRecord "CRIG00001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigThread CRIG00001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )"
rigHistory CRIG00001 "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" "$( rigMsg "$( rigAt 200 100 )" URIGADDR1 RIG-COVERED-FOLLOW-UP )"
mkdir -p "$rigDir/ws/.local/agents/sessions/$rigSession/wait"
printf 'sources: slack:magic-team slack:human-owner replies:%s \naddressee: \ninclude-own: false\nfloor slack:magic-team %s\nfloor slack:human-owner %s\n' "$rigSession" "$rigPost" "$rigPost" > "$rigDir/ws/.local/agents/sessions/$rigSession/wait/state"
rigPlain covered-channel 4
rigAssert "a conversation the Wait reads by name: its follow-up is returned once" "$( rigCount 'RIG-COVERED-FOLLOW-UP' )" 1

## ---------------------------------------------------------------------------
## 7. The floor in the sources, and a continued wait.
## ---------------------------------------------------------------------------
echo "-- 7. the sources --"
rigScene sources
rigPost="$( rigAt 300 100 )"
rigRecord "CRIGDM001:$rigPost $rigPost URIGADDR1 - - 0 - 0"
rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )"
rigPlain sources 2
rigAssert "the plain Wait names the floor among its sources, first" "$( LC_ALL=C sed -n 's/^# sources: //p' "$rigOut" )" "replies:$rigSession slack:magic-team slack:human-owner"
rigWait sources-continue --wait-continue --wait-session-id "$rigSession" --wait-timeout 2
rigAssert "a continued wait keeps it"                                "$( LC_ALL=C sed -n 's/^# sources: //p' "$rigOut" )" "replies:$rigSession slack:magic-team slack:human-owner"
rigWait sources-named --wait-default --wait-session-id "$rigSession" --wait-source "file:$rigDir/nothing" --wait-timeout 2
rigAssert "a Wait that names a source has the floor too, first"      "$( LC_ALL=C sed -n 's/^# sources: //p' "$rigOut" )" "replies:$rigSession slack:magic-team slack:human-owner file:$rigDir/nothing"
rigWait sources-none --wait-timeout 2
rigAssert "a call with no session has no record of posts to read: no floor"  "$( rigHolds 'replies:' )" no

## ---------------------------------------------------------------------------
## 8. The tools: the NEXT line, and the record of the run's own posts. The harness is called as a tool of
##    a spawned session of the member, as a served call is.
## ---------------------------------------------------------------------------
echo "-- 8. the tools --"
rigToolDir=""
rigToolStart(){ ## scenario name
	rigToolDir="$rigTmp/tool-$1"
	rm -rf "$rigToolDir"
	mkdir -p "$rigToolDir/ws/.local/.agents" "$rigToolDir/ws/.local/agents/pending" "$rigToolDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigToolDir/ws/.local/.agents/magic-team.agent.env"
	RIG_CURL_LOG="$rigToolDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
rigToolCall(){ ## tool name, arguments JSON, output basename
	( cd "$rigToolDir/ws" && printf '%s' "$2" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u MDAT_SESSION_ID \
		"PATH=$rigAskPath" RIG_SCENARIO="$rigToolDir" MMDAPP="$rigToolDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigToolDir/data" \
		MDAT_SESSION_THREAD="CSESS001:1700000002.000202" MDAT_SPAWN_SESSION_ID=rig-child-id MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash "$rigHarness" --intern-tool "$1" > "$rigToolDir/$3.out" 2> "$rigToolDir/$3.err" )
}
rigLastLine(){ ## file
	LC_ALL=C awk 'END { print ; }' "$1"
}
rigRecordOf(){ ## line -- of the tool scenario's record
	LC_ALL=C sed -n "${1}p" "$rigToolDir/ws/.local/agents/sessions/rig-child-id/last-own-post" 2>/dev/null
}
rigToolStart send
rigToolCall SendMessage '{"to":"magic-team","address_to":"URIGSOME1","message":"m"}' first
rigAssert "SendMessage ends with a NEXT: line that says only to call Wait"  "$( rigLastLine "$rigToolDir/first.out" )" "NEXT: call Wait"
rigAssert "the record of the run's own posts has the post, with its addressee" "$( rigRecordOf 1 )" "CRIG00001:1700000001.000101 1700000001.000101 URIGSOME1 - - 0 - 0"
rigToolCall SendMessage '{"to":"CRIG00001:1700000001.000101","address_to":"URIGSOME2","message":"m"}' second
rigAssert "a reply in a thread: the same line"                               "$( rigLastLine "$rigToolDir/second.out" )" "NEXT: call Wait"
rigAssert "the latest post is the first line, as its first two words always were" "$( rigRecordOf 1 )" "CRIG00001:1700000001.000101 1700000001.000102 URIGSOME2 - - 0 - 0"
rigAssert "the earlier post is kept under it"                                "$( rigRecordOf 2 )" "CRIG00001:1700000001.000101 1700000001.000101 URIGSOME1 - - 0 - 0"
rigToolStart ask
rigToolCall AskQuestion '{"to":"magic-team","address_to":"URIGSOME1","question":"May the rig go on?","wait":false}' ask
rigAssert "a tool that asks ends with a NEXT: line that says only to call Wait" "$( rigLastLine "$rigToolDir/ask.out" )" "NEXT: call Wait"
rigAssert "its post is in the record of the run's own posts, whatever tool posted it" "$( rigRecordOf 1 | LC_ALL=C awk '{ print $1 " " $3 ; }' )" "CRIG00001:1700000001.000101 URIGSOME1"

rigToolStart wait-tool
mkdir -p "$rigToolDir/ws/.local/agents/sessions/rig-child-id"
rigDir="$rigToolDir"
rigNow="$( date +%s )"
rigPost="$( rigAt 120 100 )"
printf 'CRIGDM001:%s %s URIGADDR1 - - 0 - 0\n' "$rigPost" "$rigPost" > "$rigToolDir/ws/.local/agents/sessions/rig-child-id/last-own-post"
rigThread CRIGDM001 "$rigPost" "$( rigMsg "$rigPost" URIGSELF1 RIG-QUESTION '' "$rigOwnMeta" )" "$( rigMsg "$( rigAt 100 200 )" URIGADDR1 RIG-TOOL-REPLY "$rigPost" )"
printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigToolDir/ws/.local/.agents/$rigMember.agent.env"
: > "$rigToolDir/api.log"
rigAskPath="$rigTmp/bin:$PATH"
rigToolCall Wait '{"timeout":4}' wait
rigAskPath="$rigTmp/askbin:$PATH"
rigAssert "the Wait tool with no sources carries the floor, first"          "$( LC_ALL=C grep -c -E '^# sources: replies:rig-child-id ' "$rigToolDir/wait.out" )" 1
rigAssert "and returns the reply given in the thread"                        "$( LC_ALL=C grep -c -F 'RIG-TOOL-REPLY' "$rigToolDir/wait.out" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT OWN POST REPLIES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a reply to the run's own post can be missed by a plain Wait, or is returned twice, or the" >&2
	echo "        three limits do not hold, or a NEXT line names more than the call to Wait" >&2
	echo "  fix:  repair the floor of the Wait or the tool -- never the assertion" >&2
	exit 1
fi
printf 'WAIT_OWN_POST_REPLIES: OK (%d assertions, offline, no model)\n' "$rigPassCount"
