#!/usr/bin/env bash
## In a one-to-one direct message an account the caller names as the addressee must be the other party of that conversation (a reply to one person went
## out headed for another). The refusal posts nothing and names the right account. The right account, no address at all, and a team member's name go through.
## Temp workspace only, a fake curl of this check's own that answers conversations.info as a direct message with one other party. Nothing leaves the machine.
## A post of the tooling's own (no MDAT_SEND_FLOOR=hold) that names nobody, in a thread of the human-owner's conversation with the bot, names nobody: it is
## never addressed to him by inference, from the conversation's other party or from the author of the thread's first message. Named, it reaches him.
## A member's own post naming nobody never infers him either, whatever its target. Addressed to him in its session thread, found by the thread it resolves to, it is refused.
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
rigTmp="$( rigTempDir AgentsSlackDmAddresseeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/magic-team" "$rigTmp/scenario"
cat > "$rigTmp/bin/curl" <<'STUB'
#!/bin/sh
## The fake curl of this check: it logs the method it was asked for, answers the four the send makes, and keeps the body of the last post.
for a in "$@" ; do case "$a" in https://slack.com/api/*) m="${a#https://slack.com/api/}" ;; esac ; done
printf '%s
' "$m" >> "$RIG_SCENARIO/calls.log"
case "$m" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}
' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"%s","is_im":true,"is_mpim":false,"user":"%s"}}\n' "${RIG_DM:-DRIGJULIA1}" "${RIG_PARTY:-URIGJULIA1}" ;;
	conversations.replies|conversations.history) printf '{"ok":true,"messages":[{"ts":"1700000000.000001",%s"text":"hi"}],"has_more":false}\n' "${RIG_ROOT:-\"user\":\"URIGJULIA1\",}" ;;
	chat.postMessage)
		p=""
		for a in "$@" ; do [ "$p" != "--data-binary" ] || cat "${a#@}" > "$RIG_SCENARIO/post.body" ; p="$a" ; done
		printf '{"ok":true,"channel":"DRIGJULIA1","ts":"1.000001","message":{"ts":"1.000001","user":"URIGBOT01"}}
'
	;;
	*) printf '{"ok":true}
' ;;
esac
STUB
chmod +x "$rigTmp/bin/curl"
rigSentinel="rig-sentinel-$$-TOKEN"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=%s\n' "$rigSentinel" > "$rigWs/.local/.agents/magic-team.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSend(){ ## result file, session id (empty: none), body, [extra option]
	env -i ${2:+MDAT_SPAWN_SESSION_ID=$2} MDAT_SEND_FLOOR="${rigFloor:-}" HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		RIG_SCENARIO="$rigTmp/scenario" RIG_WS="$rigWs" RIG_MODE=ok RIG_SENTINEL="$rigSentinel" RIG_SENTINEL_B64=none RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_BODY="$3" RIG_OPT="${4:-}" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --slack-send-message --team-member magic-team magic-team --identity-bot ${RIG_OPT:+"$RIG_OPT"} "$RIG_BODY"
		' > "$1" 2>&1
	printf '%s' "$?" > "$1.rc"
}
rigPosts(){ LC_ALL=C grep -c 'chat.postMessage' "$rigTmp/scenario/argv.log" 2>/dev/null || :; }
rigRc(){ cat "$1.rc"; }

rigFloor=hold
## rigSend takes a body and an --address-to word through RIG_OPT, the channel being the direct message.
## The other party is a person outside the team, so the send also asks that the person be a known contact (the outside-person rule): the rig
## holds a contact record of URIGJULIA1 in its own data root. Its one message in the fake thread is the last word, so one reply is due.
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-contacts.include.sh" || exit 1
rigContactSeed "$rigTmp/data" magic-team julia URIGJULIA1 - || exit 1
rigDm(){ ## result file, the address-to word (may be empty); rigFloor, rigDmId, rigParty, rigRoot, rigBody, rigTarget and rigSess set the rest
	rm -f "$rigTmp/scenario/post.body"
	## The tooling calls the send itself (rigFloor empty), as its confirmation of an answer does. A member's send goes through its stub, which sets the floor.
	local rigOp="--slack-send-message --team-member"
	[ "$rigFloor" = hold ] || rigOp="--intern-op-comms-slack-send-message"
	printf '%s' "${rigBody:-Спасибо, сообщение получено.}" | ( cd "$rigWs" && env -i ${rigSess:+MDAT_SPAWN_SESSION_ID=$rigSess} MDAT_SEND_FLOOR="$rigFloor" HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" RIG_SCENARIO="$rigTmp/scenario" RIG_DM="${rigDmId:-}" RIG_PARTY="${rigParty:-}" RIG_ROOT="${rigRoot:-}" \
		bash "$rigFn" $rigOp magic-team "${rigTarget:-${rigDmId:-DRIGJULIA1}:1700000000.000001}" --identity-bot ${2:+--address-to "$2"} --from-stdin ) > "$1" 2>&1
	printf '%s' "$?" > "$1.rc"
}
rigCount(){ LC_ALL=C grep -c '^chat.postMessage$' "$rigTmp/scenario/calls.log" 2> /dev/null || :; }
## Under a message the bot posted, so the rule of the one other party decides, not the author of the message a reply answers.
rigRoot='"bot_id":"BRIG00001",'
rigDm "$rigTmp/a" URIGLENA001
rigAssert "an account that is not the other party: posted, addressed to the other party instead, and the send says so" "$( cat "$rigTmp/a.rc" ) $( LC_ALL=C grep -c 'addressed to that party in place of URIGLENA001' "$rigTmp/a" ) $( rigCount )" "0 1 1"
rigAssert "the swapped header names the party, never the account the caller gave" "$( LC_ALL=C grep -c 'URIGLENA001' "$rigTmp/scenario/calls.log" 2> /dev/null || : )" "0"
rigRoot=""
rigDm "$rigTmp/b" URIGJULIA1
rigAssert "the other party itself: posted" "$( cat "$rigTmp/b.rc" ) $( rigCount )" "0 2"
rigDm "$rigTmp/c" ""
rigAssert "no address at all: posted, the other party inferred" "$( cat "$rigTmp/c.rc" ) $( rigCount )" "0 3"
## Whether the last post's body names an account: tagged or untagged.
rigTagged(){ LC_ALL=C grep -q -F "$1" "$rigTmp/scenario/post.body" 2> /dev/null && printf tagged || printf untagged ; }
rigFloor=""
rigDm "$rigTmp/j" ""
rigAssert "control: the tooling's own post in a person's thread, naming nobody, is addressed to the author it answers" "$( cat "$rigTmp/j.rc" ) $( rigCount ) $( rigTagged URIGJULIA1 )" "0 4 tagged"
mkdir -p "$rigTmp/skills/human-owner"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigTmp/skills/human-owner/human-owner.basic.md"
printf 'SLACK_CHANNEL_HUMAN_OWNER=URIGOWNER01\n' >> "$rigWs/.local/.agents/magic-team.agent.env"
## Each post says another thing: the same text to the same place within the half hour is refused as a repeat.
rigDmId=DRIGOWNER1 ; rigParty=URIGOWNER01 ; rigBody="Read: yes by magic-coordinator. It is recorded as the answer to this readback."
rigRoot='"bot_id":"BRIG00001",'
rigDm "$rigTmp/d" ""
rigAssert "the tooling's own post naming nobody, in a thread of his conversation with the bot: posted, never addressed to him" "$( cat "$rigTmp/d.rc" ) $( rigCount ) $( rigTagged URIGOWNER01 )" "0 5 untagged"
rigRoot='"user":"URIGOWNER01",'
rigBody="Read: no by magic-coordinator. It is recorded as the answer to this readback."
rigDm "$rigTmp/e" ""
rigAssert "the same under a thread he opened: posted, never addressed to him" "$( cat "$rigTmp/e.rc" ) $( rigCount ) $( rigTagged URIGOWNER01 )" "0 6 untagged"
rigBody="Granted to magic-developer, for the session."
rigDm "$rigTmp/g" human-owner
rigAssert "the tooling's own post its caller addresses to him, as an ask of his level is: posted, addressed to him" "$( cat "$rigTmp/g.rc" ) $( rigCount ) $( rigTagged URIGOWNER01 )" "0 7 tagged"
rigFloor=hold ; rigBody=""
rigDm "$rigTmp/h" ""
rigAssert "a member's reply under his own message, a readback: posted, addressed to him" "$( cat "$rigTmp/h.rc" ) $( rigCount ) $( rigTagged URIGOWNER01 )" "0 8 tagged"
## A member's own post naming nobody never infers him either, whatever its target. Its session thread is in his conversation with the bot,
## and a raw <conversation>:<ts> of that thread is the same thread as session-current.
rigRefused(){ [ "$( cat "$1.rc" )" != 0 ] && printf refused || printf sent ; }
mkdir -p "$rigWs/.local/agents/sessions/rig-sess"
printf '%s\n' 'DRIGOWNER1:1700000000.000001' > "$rigWs/.local/agents/sessions/rig-sess/session.thread"
rigSess=rig-sess ; rigRoot='"bot_id":"BRIG00001",'
rigBody="Round 3 done, next the board."
rigDm "$rigTmp/m1" ""
rigAssert "a member's post naming nobody, to the raw id of its session thread in his conversation: posted, never addressed to him" "$( cat "$rigTmp/m1.rc" ) $( rigCount ) $( rigTagged URIGOWNER01 )" "0 9 untagged"
rigTarget=session-current ; rigBody="Round 4 done, next the inbox."
rigDm "$rigTmp/m2" ""
rigAssert "the same post to session-current: posted, never addressed to him" "$( cat "$rigTmp/m2.rc" ) $( rigCount ) $( rigTagged URIGOWNER01 )" "0 10 untagged"
rigTarget=DRIGOWNER1 ; rigBody="Round 5 done, next the review."
rigDm "$rigTmp/m3" ""
rigAssert "a member's post naming nobody, at the top of his conversation: posted, never addressed to him" "$( cat "$rigTmp/m3.rc" ) $( rigCount ) $( rigTagged URIGOWNER01 )" "0 11 untagged"
rigTarget="" ; rigBody="Round 6 done, next the close."
rigDm "$rigTmp/m4" human-owner
rigAssert "a member's post to the raw id of its session thread, addressed to him: refused, names magic-coordinator, posts nothing" "$( rigRefused "$rigTmp/m4" ) $( LC_ALL=C grep -c 'Address it to magic-coordinator' "$rigTmp/m4" || : ) $( rigCount )" "refused 1 11"
rigTarget=session-current ; rigBody="Round 7 done, next the sweep."
rigDm "$rigTmp/m5" human-owner
rigAssert "the same post to session-current: refused, names magic-coordinator, posts nothing" "$( rigRefused "$rigTmp/m5" ) $( LC_ALL=C grep -c 'Address it to magic-coordinator' "$rigTmp/m5" || : ) $( rigCount )" "refused 1 11"
rigSess="" ; rigTarget="" ; rigBody=""
## A reply under the other party's own message, naming another account, goes to that party, and the send says so.
rigDmId="" ; rigParty="" ; rigRoot="" ; rigBody="Noted, the review is next."
rigDm "$rigTmp/n1" URIGLENA001
rigAssert "a reply under the other party's message naming another account: posted, addressed to the party, and the send says so" "$( cat "$rigTmp/n1.rc" ) $( LC_ALL=C grep -c "this reply answers URIGJULIA1's message" "$rigTmp/n1" ) $( rigCount ) $( rigTagged URIGJULIA1 )" "0 1 12 tagged"
## In his conversation a post naming another account is never re-addressed to him, by his conversation or by his message.
rigDmId=DRIGOWNER1 ; rigParty=URIGOWNER01 ; rigRoot='"bot_id":"BRIG00001",' ; rigBody="Round 8 done, next the index."
rigDm "$rigTmp/o1" URIGLENA001
rigAssert "a post in his conversation naming another account: posted, addressed to that account, never to him" "$( cat "$rigTmp/o1.rc" ) $( rigCount ) $( rigTagged URIGLENA001 ) $( rigTagged URIGOWNER01 )" "0 13 tagged untagged"
rigRoot='"user":"URIGOWNER01",' ; rigBody="Round 9 done, next the stage."
rigDm "$rigTmp/o2" URIGLENA001
rigAssert "a reply under his own message naming another account: posted, addressed to that account, never to him" "$( cat "$rigTmp/o2.rc" ) $( rigCount ) $( rigTagged URIGLENA001 ) $( rigTagged URIGOWNER01 )" "0 14 tagged untagged"
rigDmId="" ; rigParty="" ; rigRoot="" ; rigBody=""
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK DM ADDRESSEE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_DM_ADDRESSEE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
