#!/usr/bin/env bash
## Where a message lands, by the team rules (magic-team.basic.md, Channels and threads): a person outside the team is answered in
## the thread of their own message and only a known person is written to; a work-duty posts in its own session thread, the day-first
## greeting excepted; an account id written plain is said as the person the contact store names. The rig holds the person as a contact
## in its own data root, a machine-wide members registry in its own home, and a fake curl answering conversations.info,
## conversations.replies (from a file the row writes) and chat.postMessage. Nothing leaves the machine.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-contacts.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackOutsideReplyFloorCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/schedule/owed" "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/magic-team" "$rigTmp/scenario" "$rigTmp/data" "$rigTmp/spawn"
cat > "$rigTmp/bin/curl" <<'STUB'
#!/bin/sh
## The fake curl of this check: logs the method and answers the four the send makes. The thread is whatever the row wrote to replies.json.
## The header travels on stdin and each form value in a file named in argv (channel@<file>), so the conversation asked about is read
## from that file, from argv and from stdin alike.
for a in "$@" ; do case "$a" in https://slack.com/api/*) m="${a#https://slack.com/api/}" ;; esac ; done
in="" ; [ -t 0 ] || in="$( cat )"
for a in "$@" ; do case "$a" in channel@*) in="$in $( cat "${a#channel@}" 2> /dev/null )" ;; esac ; done
printf '%s\n' "$m" >> "$RIG_SCENARIO/calls.log"
case "$m" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	conversations.info)
		case "$* $in" in
			*DRIGOWNER1*) printf '{"ok":true,"channel":{"id":"DRIGOWNER1","is_im":true,"is_mpim":false,"user":"URIGOWNER"}}\n' ;;
			*CRIGCHAN01*) printf '{"ok":true,"channel":{"id":"CRIGCHAN01","is_im":false,"is_mpim":false}}\n' ;;
			*) printf '{"ok":true,"channel":{"id":"DRIGJULIA1","is_im":true,"is_mpim":false,"user":"URIGJULIA1"}}\n' ;;
		esac
	;;
	conversations.replies|conversations.history) cat "$RIG_SCENARIO/replies.json" ;;
	chat.postMessage) { for a in "$@" ; do case "$a" in *@/*) cat "${a#*@}" 2> /dev/null ; echo ;; esac ; done ; printf '%s\n' "$in" ; } >> "$RIG_SCENARIO/posts.log" ; printf '{"ok":true,"channel":"DRIGJULIA1","ts":"1.000001","message":{"ts":"1.000001","user":"URIGBOT01"}}\n' ;;
	*) printf '{"ok":true}\n' ;;
esac
STUB
chmod +x "$rigTmp/bin/curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-sentinel-%s-TOKEN\n' "$$" > "$rigWs/.local/.agents/magic-team.agent.env"
rigContactSeed "$rigTmp/data" magic-team julia URIGJULIA1 - || exit 1
printf '{"ok":true,"messages":[{"ts":"1700000000.000001","user":"URIGJULIA1","text":"комментарии в Jira, посмотрите"}],"has_more":false}\n' > "$rigTmp/scenario/replies.json"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSend(){ ## result file, target, body, [extra options...]
	local rigOut="$1" rigTarget="$2" rigBody="$3"
	shift 3
	printf '%s' "$rigBody" | ( cd "$rigWs" && env -i MDAT_SEND_FLOOR="hold" HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" RIG_SCENARIO="$rigTmp/scenario" ${RIG_DUTY:+MDAT_SPAWN_SESSION_ID=rig-duty MDAT_SPAWN_SANDBOX_ROOT="$rigTmp/spawn"} \
		bash "$rigFn" --slack-send-message --team-member magic-team "$rigTarget" --identity-bot "$@" --from-stdin ) > "$rigOut" 2>&1
	printf '%s' "$?" > "$rigOut.rc"
}
rigPosts(){ LC_ALL=C grep -c '^chat.postMessage$' "$rigTmp/scenario/calls.log" 2> /dev/null || : ; }
rigPostsSoFar=0

echo "-- 1. a person outside the team --"
rigSend "$rigTmp/a" DRIGJULIA1 "Здравствуйте."
rigPostsSoFar=$(( rigPostsSoFar + 1 ))
rigAssert "a known person, nothing asked yet: a post at the top of their conversation opens a new subject, as named" \
	"$( cat "$rigTmp/a.rc" ) $( rigPosts )" "0 $rigPostsSoFar"
printf '%s\tslack:DRIGJULIA1:1700000000.000001\tURIGJULIA1\tвопрос\n' "$( date +%s )" > "$rigWs/.local/agents/schedule/owed/magic-team"
rigSend "$rigTmp/b" DRIGJULIA1 "Комментарии прочитаны."
rigPostsSoFar=$(( rigPostsSoFar + 1 ))
rigAssert "the person asked in a thread: a top-level send goes into that thread, and the send says so" \
	"$( cat "$rigTmp/b.rc" ) $( LC_ALL=C grep -c 'asked in the thread slack:DRIGJULIA1:1700000000.000001' "$rigTmp/b" ) $( rigPosts )" "0 1 $rigPostsSoFar"
rigSend "$rigTmp/c" DRIGJULIA1:1700000000.000001 "Комментарии прочитаны."
rigPostsSoFar=$(( rigPostsSoFar + 1 ))
rigAssert "the thread named by the caller: posted there" "$( cat "$rigTmp/c.rc" ) $( rigPosts )" "0 $rigPostsSoFar"
rm -f "$rigTmp/data/contacts/persons/julia-magic-team.md"
rigSend "$rigTmp/d" DRIGJULIA1:1700000000.000001 "Здравствуйте."
rigAssert "a person the contact store does not know: refused by the contact gate, nothing posted" \
	"$( cat "$rigTmp/d.rc" ) $( LC_ALL=C grep -c 'is not a known contact' "$rigTmp/d" ) $( rigPosts )" "1 1 $rigPostsSoFar"
rigContactSeed "$rigTmp/data" magic-team julia URIGJULIA1 - || exit 1

echo "-- 1b. @here only where the caller means it --"
## A send naming nobody heads itself to the place in plain text; only --address-to @here pings everyone there.
: > "$rigTmp/scenario/posts.log"
rigSend "$rigTmp/l" CRIGCHAN01:1700000000.000001 "Ответ в ветке."
rigPostsSoFar=$(( rigPostsSoFar + 1 ))
rigAssert "a channel-thread reply naming nobody: posted, addressed to the author of the message it answers, no @here" \
	"$( cat "$rigTmp/l.rc" ) $( LC_ALL=C grep -c 'URIGJULIA1' "$rigTmp/scenario/posts.log" | LC_ALL=C awk '{ print ( $1 > 0 ) }' ) $( LC_ALL=C grep -c 'here' "$rigTmp/scenario/posts.log" ) $( rigPosts )" "0 1 0 $rigPostsSoFar"
: > "$rigTmp/scenario/posts.log"
rigSend "$rigTmp/m" CRIGCHAN01 "A post to the channel."
rigPostsSoFar=$(( rigPostsSoFar + 1 ))
rigAssert "a top-level post naming nobody: posted, headed to this conversation, no @here" \
	"$( cat "$rigTmp/m.rc" ) $( LC_ALL=C grep -c 'this conversation' "$rigTmp/scenario/posts.log" | LC_ALL=C awk '{ print ( $1 > 0 ) }' ) $( LC_ALL=C grep -c 'here' "$rigTmp/scenario/posts.log" ) $( rigPosts )" "0 1 0 $rigPostsSoFar"
: > "$rigTmp/scenario/posts.log"
rigSend "$rigTmp/n" CRIGCHAN01 "Everyone: the release is out." --address-to @here
rigPostsSoFar=$(( rigPostsSoFar + 1 ))
rigAssert "--address-to @here, said by the caller: posted with the broadcast" \
	"$( cat "$rigTmp/n.rc" ) $( LC_ALL=C grep -c '"range":"here"' "$rigTmp/scenario/posts.log" | LC_ALL=C awk '{ print ( $1 > 0 ) }' ) $( rigPosts )" "0 1 $rigPostsSoFar"

echo "-- 1c. a contact addressed by its id --"
## A contact's id names that person's Slack account from the record; a record with no Slack id is refused, never guessed.
: > "$rigTmp/scenario/posts.log"
rigSend "$rigTmp/o" CRIGCHAN01:1700000000.000001 "Ответ." --address-to julia-magic-team
rigPostsSoFar=$(( rigPostsSoFar + 1 ))
rigAssert "--address-to <contact id>: posted, addressed to the account its record holds" \
	"$( cat "$rigTmp/o.rc" ) $( LC_ALL=C grep -c '"user_id":"URIGJULIA1"' "$rigTmp/scenario/posts.log" | LC_ALL=C awk '{ print ( $1 > 0 ) }' ) $( rigPosts )" "0 1 $rigPostsSoFar"
rigContactSeed "$rigTmp/data" magic-team ilya - ilya@rig.invalid || exit 1
rigSend "$rigTmp/p" CRIGCHAN01 "Сообщение." --address-to ilya-magic-team
rigAssert "a message, not a reply, --address-to <contact id> whose record holds no Slack id: refused, nothing posted" \
	"$( cat "$rigTmp/p.rc" ) $( LC_ALL=C grep -c 'the contact record holds no Slack id' "$rigTmp/p" ) $( rigPosts )" "1 1 $rigPostsSoFar"

echo "-- 1d. a reply under a message of another conversation --"
## Slack answers thread_not_found: the ts is no message of this conversation, and a post would land at its top level. Refused, nothing posted.
cp "$rigTmp/scenario/replies.json" "$rigTmp/scenario/replies.kept"
printf '{"ok":false,"error":"thread_not_found"}\n' > "$rigTmp/scenario/replies.json"
rigSend "$rigTmp/q" CRIGCHAN01:1700000000.999999 "Ответ."
rigAssert "a reply whose thread is not in this conversation: refused, nothing posted" \
	"$( cat "$rigTmp/q.rc" ) $( LC_ALL=C grep -c 'is no thread of this conversation' "$rigTmp/q" ) $( rigPosts )" "1 1 $rigPostsSoFar"
mv -f "$rigTmp/scenario/replies.kept" "$rigTmp/scenario/replies.json"

echo "-- 2. the human-owner's conversation --"
rigLong="$( printf 'Measured: %s. ' 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 )"
rigSend "$rigTmp/e" DRIGOWNER1 "$rigLong
The measurement stands."
rigPostsSoFar=$(( rigPostsSoFar + 1 ))
rigAssert "a report to the owner: posted as written" "$( cat "$rigTmp/e.rc" ) $( rigPosts )" "0 $rigPostsSoFar"
rigSend "$rigTmp/f" DRIGOWNER1 "The note came from URIGJULIA1 this morning."
rigPostsSoFar=$(( rigPostsSoFar + 1 ))
rigAssert "a bare account id in the body is said as the person the store names, and the send says so" \
	"$( cat "$rigTmp/f.rc" ) $( LC_ALL=C grep -c "is said as 'rig julia'" "$rigTmp/f" ) $( rigPosts )" "0 1 $rigPostsSoFar"
rigSend "$rigTmp/g" DRIGOWNER1 "The note came from URIGNOBODY9 this morning."
rigPostsSoFar=$(( rigPostsSoFar + 1 ))
rigAssert "an account id the store does not know is said as an account with no record" \
	"$( cat "$rigTmp/g.rc" ) $( LC_ALL=C grep -c "is said as 'an account with no record'" "$rigTmp/g" ) $( rigPosts )" "0 1 $rigPostsSoFar"

echo "-- 3. a work-duty posts in its session thread --"
## The rig has no session thread, so a redirected send ends short of a post: the line and the unchanged post count are the evidence.
printf -- '---\nspawn-id: rig-duty\nowner: magic-team\nstatus: spawn-started\nroutine: magic-team.work-duty.routine.md\n---\n' > "$rigTmp/spawn/rig-duty.spawn.md"
RIG_DUTY=yes rigSend "$rigTmp/h" magic-team "Day first: on duty.
Three items read, two answered."
rigAssert "a work-duty's post to magic-team, nothing told it: delivered to its session thread instead, the channel untouched" \
	"$( LC_ALL=C grep -c 'never at the root of the team channel' "$rigTmp/h" ) $( rigPosts )" "1 $rigPostsSoFar"
RIG_DUTY=yes rigSend "$rigTmp/i" magic-team "Day first: on duty." --told
rigPostsSoFar=$(( rigPostsSoFar + 1 ))
rigAssert "the routine step that names the channel, with --told: posted to magic-team" "$( cat "$rigTmp/i.rc" ) $( rigPosts )" "0 $rigPostsSoFar"
printf -- '---\nspawn-id: rig-duty\nowner: magic-team\nstatus: spawn-started\nroutine: magic-team.work-duty.routine.md\nday-first: yes\n---\n' > "$rigTmp/spawn/rig-duty.spawn.md"
rm -f "$rigWs/.local/agents/comms-slack-send."*.log
RIG_DUTY=yes rigSend "$rigTmp/j" magic-team "Day first: on duty."
rigPostsSoFar=$(( rigPostsSoFar + 1 ))
rigAssert "a day-first run's first post to magic-team is the greeting: posted" "$( cat "$rigTmp/j.rc" ) $( rigPosts )" "0 $rigPostsSoFar"
RIG_DUTY=yes rigSend "$rigTmp/k" magic-team "Second word to the channel."
rigAssert "its second post to magic-team: delivered to the session thread instead" \
	"$( LC_ALL=C grep -c 'never at the root of the team channel' "$rigTmp/k" ) $( rigPosts )" "1 $rigPostsSoFar"

if [ "$rigFailCount" = "0" ] ; then
	printf 'SLACK_OUTSIDE_REPLY_FLOOR: OK (%s assertions, offline, rig tree only)\n' "$rigPassCount"
else
	printf '⛔ SLACK OUTSIDE REPLY FLOOR CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))"
	exit 1
fi
