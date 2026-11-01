#!/usr/bin/env bash
## Behavioural check on where a Wait's answer to a slack:<channel>:<ts>:conversation source comes from (owner design
## 2026-10-31: Slack is read through the comms cache and the session thread, so a Wait never re-reads Slack itself).
## A round is answered from the thread the comms cache holds; past the cache's own TTL it pulls only what came after
## the cache's newest and merges that in. Held, run and not read:
##   1. A cold cache: the round pulls the thread whole and leaves it in the comms cache, and the messages after the
##      floor are delivered.
##   2. A warm cache, with Slack answering a whole read slower than the bound of the call: the next message is
##      delivered from the cache, by the narrowed read the cache takes and not a whole one, the call keeps its
##      bound, and the source is not left in WAIT-NEVER-READ.
##   3. Control: the same call with the cache off does read the thread whole, and pays that read, which is longer
##      here than the whole bound of section 2. It is the form every round took before the fix: section 1's "left in
##      the cache" and section 2 both fail on the tooling that forced a fresh read of both kinds of round.
##   4. The burst settle is no whole re-read either: with the cache a second stale it pulls what arrived and returns
##      inside the bound, where reading the thread whole would have overrun it as section 3 does.
## Offline: a fake curl first on PATH answers by method, identity and whether the read was narrowed to a floor,
## every workspace is a folder of the rig's own, and no request leaves the rig.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"
rigChannel="CRIG00001"
rigThread="1793000000.000100"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTools" ] || rigRefuse "DistroAgentsTools.fn.sh not found at the origin this workspace resolves: $rigTools"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to act under"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitThreadCacheCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScenario="$rigTmp/scenario"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents/sessions" "$rigWs/.local/temp" "$rigScenario"
cat > "$rigTmp/bin/curl" <<- 'EOF'
	#!/usr/bin/env bash
	set -u
	rigAuth="$( cat )"
	rigMethod="" rigNarrowed=no
	for rigArg in "$@" ; do
		case "$rigArg" in
			https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
			*oldest*) rigNarrowed=yes ;;
		esac
	done
	rigWho=user ; case "$rigAuth" in *rig-bot-*) rigWho=bot ;; esac
	printf '%s %s %s\n' "$rigMethod" "$rigWho" "$rigNarrowed" >> "$RIG_SCENARIO/calls"
	case "$rigMethod" in
		auth.test) printf '{"ok":true,"user_id":"URIGSELF1"}\n' ;;
		conversations.replies)
			## A whole read of this thread is slow enough that no round of the call under test can finish it: that is
			## what section 2 forbids and what section 3 proves the instrument can still produce. A read narrowed to a
			## floor -- what the cache pulls past its newest -- answers at once.
			[ "$rigNarrowed" = "yes" ] || [ ! -f "$RIG_SCENARIO/slow" ] || sleep 12
			cat "$RIG_SCENARIO/replies.json" 2> /dev/null || printf '{"ok":true,"messages":[],"has_more":false}\n'
		;;
		conversations.history) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
		conversations.list) printf '{"ok":true,"channels":[],"response_metadata":{"next_cursor":""}}\n' ;;
		conversations.info) printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n' ;;
		reactions.add|reactions.remove) printf '{"ok":true}\n' ;;
		*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
	esac
EOF
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH" ; export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=%s\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' "$rigChannel" > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigWs/.local/.agents/$rigMember.agent.env"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigHas(){ ## text -- how many lines of the last result hold it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/out" || :
}
rigFirst(){ LC_ALL=C sed -n 1p "$rigTmp/out" ; }
rigWholeReads(){ ## -- read where the fake curl answered a whole read of the thread for the last call
	[ "$( LC_ALL=C grep -c -x 'conversations.replies user no' "$rigScenario/calls" || : )" = "0" ] && echo silent || echo read
}
rigAnyRead(){ ## -- read where the fake curl answered any read of the thread for the last call
	[ "$( LC_ALL=C grep -c -x 'conversations.replies user yes' "$rigScenario/calls" || : )" = "0" ] && echo silent || echo read
}
rigCached(){ ## -- the comms cache of the rig's thread: held, or absent
	set -- "$rigWs/.local/cache/comms/slack/slack-$rigChannel-$rigThread"/*/messages.txt
	[ -s "$1" ] && echo held || echo absent
}
rigNeverRead(){ LC_ALL=C grep -c '^WAIT-NEVER-READ' "$rigTmp/out" || : ; }
## The thread: our own post at its ts, then the replies the cache and Slack are asked about.
rigThreadJson(){ ## third reply or none -- the thread as Slack holds it
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"rig thread root"},{"ts":"1793000003.000100","thread_ts":"%s","user":"URIGSELF1","text":"RIG-FIRST-REPLY"},{"ts":"1793000009.000100","thread_ts":"%s","user":"URIGSELF1","text":"RIG-SECOND-REPLY"}%s],"has_more":false}\n' \
		"$rigThread" "$rigThread" "$rigThread" "${1:+,{\"ts\":\"$1\",\"thread_ts\":\"$rigThread\",\"user\":\"URIGSELF1\",\"text\":\"RIG-THIRD-REPLY\"}}"
}
rigWait(){ ## timeout, floor, cache ttl, settle seconds -- one Wait on the conversation source, the result in out
	: > "$rigScenario/calls"
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		RIG_SCENARIO="$rigScenario" MDAT_WAIT_REMIND=off MDAT_WAIT_SETTLE_SECONDS="$4" MMDAPP="$rigWs" MDAT_SLACK_THREAD_CACHE_SECONDS="$3" \
		bash "$rigTools" --wait-for-input --team-member "$rigMember" --wait-source "slack:$rigChannel:$rigThread:conversation" --wait-timeout "$1" --wait-since-utime "$2" ) > "$rigTmp/out" 2> "$rigTmp/err"
}
rigThreadJson "" > "$rigScenario/replies.json"

echo "-- 1. a cold cache: the round pulls the thread and caches it, and what stands after the floor is delivered --"
rigWait 20 "$rigThread" 120 0
rigAssert "the replies after the floor arrive" "$( rigFirst ) $( rigHas RIG-FIRST-REPLY ) $( rigHas RIG-SECOND-REPLY )" "WAIT-RESULT: RECEIVED 1 1"
rigAssert "and the round left the thread in the comms cache" "$( rigCached )" "held"
rigAssert "the source is not left in WAIT-NEVER-READ" "$( rigNeverRead )" "0"

echo "-- 2. a warm cache, with Slack slower than the whole bound: the next message arrives from the cache --"
: > "$rigScenario/slow"
rigBegan=$SECONDS
rigWait 6 1793000003.000100 120 0
rigAssert "the second reply arrives, from the cache" "$( rigFirst ) $( rigHas RIG-SECOND-REPLY )" "WAIT-RESULT: RECEIVED 1"
rigAssert "control: what stood at or before the floor is not delivered again" "$( rigHas RIG-FIRST-REPLY )" "0"
rigAssert "no whole read of the thread reached Slack" "$( rigWholeReads )" "silent"
rigAssert "and the call kept its bound, which a whole read could not have done here" "$( [ $(( SECONDS - rigBegan )) -lt 6 ] && echo inside || echo over )" "inside"
rigAssert "the source is not left in WAIT-NEVER-READ" "$( rigNeverRead )" "0"

echo "-- 3. control, the form every round took before the fix: the cache off, the same thread and bound --"
rigBegan=$SECONDS
rigWait 6 1793000003.000100 0 0
rigAssert "control: with the cache off the round does read the thread whole, so section 2's silence is a fact" "$( rigWholeReads )" "read"
rigAssert "control: and that read is the wait's own cost, here longer than section 2's whole bound" "$( [ $(( SECONDS - rigBegan )) -ge 12 ] && echo over-bound || echo inside )" "over-bound"

echo "-- 4. the settle, with the cache on: it pulls what arrived, it does not read the thread again --"
rigThreadJson 1793000015.000100 > "$rigScenario/replies.json"
rigBegan=$SECONDS
rigWait 6 1793000009.000100 1 3
rigAssert "the third reply arrives" "$( rigFirst ) $( rigHas RIG-THIRD-REPLY )" "WAIT-RESULT: RECEIVED 1"
rigAssert "no whole read of the thread was made, by the round or by the settle" "$( rigWholeReads )" "silent"
rigAssert "control: the narrowed read the cache pulls is seen, so that silence is a fact" "$( rigAnyRead )" "read"
rigAssert "and the settle kept the call inside its bound" "$( [ $(( SECONDS - rigBegan )) -lt 6 ] && echo inside || echo over )" "inside"
rigAssert "the source is not left in WAIT-NEVER-READ" "$( rigNeverRead )" "0"

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
