#!/usr/bin/env bash
## A member's own message to a channel that talks of the human-owner (names him, or what he said, wrote, asked or ruled) is refused with a reason, and nothing
## reaches Slack for it. A message that does not talk of him goes through. A member's own post to its session thread addressed to the human-owner is
## refused and names magic-coordinator; the same post to magic-coordinator, and the tooling's own send of that form, go through.
## Temp workspace only, the credential exposure rig's fake curl first on PATH, under one `env -i` guard. Nothing leaves the machine.
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
rigTmp="$( rigTempDir AgentsSlackSendOwnerTalkCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/magic-team" "$rigTmp/scenario"
cp "$rigTest/check-fixtures/credential-exposure-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
rigSentinel="rig-sentinel-$$-TOKEN"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=%s\n' "$rigSentinel" > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in human-owner magic-coordinator ; do
	mkdir -p "$rigTmp/skills/$rigMember" && printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
done
mkdir -p "$rigWs/.local/agents/cache" "$rigWs/.local/agents/sessions/rig-sess"
printf '%s\n' 'human-owner=URIGOWNER01=-=-=-=-' 'magic-coordinator=URIGCOORD01=-=-=-=-' > "$rigWs/.local/agents/cache/slack-identities.cache"
printf '%s\n' 'CRIG00001:1700000000.000100' > "$rigWs/.local/agents/sessions/rig-sess/session.thread"

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
		RIG_SCENARIO="$rigTmp/scenario" RIG_WS="$rigWs" RIG_MODE=ok RIG_SENTINEL="$rigSentinel" RIG_SENTINEL_B64=none RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_BODY="$3" RIG_OPT="${4:-}" RIG_TARGET="${rigTarget:-magic-team}" RIG_ADDR="${rigAddr:-}" RIG_OP="${rigOp:---slack-send-message --team-member}" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" $RIG_OP magic-team "$RIG_TARGET" --identity-bot ${RIG_OPT:+"$RIG_OPT"} ${RIG_ADDR:+--address-to "$RIG_ADDR"} "$RIG_BODY"
		' > "$1" 2>&1
	printf '%s' "$?" > "$1.rc"
}
rigPosts(){ LC_ALL=C grep -c 'chat.postMessage' "$rigTmp/scenario/argv.log" 2>/dev/null || :; }
rigRc(){ cat "$1.rc"; }

rigFloor=hold ## the member stub sets it on every member send
echo "-- a plain message goes through --"
rigSend "$rigTmp/a" "" "The call-path sweep is done and the checks pass."
LC_ALL=C grep -q 'chat.postMessage' "$rigTmp/scenario/argv.log" 2>/dev/null || rigRefuse "no send reached the fake curl: $( tail -3 "$rigTmp/a" )"
rigAssert "rc 0 and one post reached Slack" "$( rigRc "$rigTmp/a" ) $( rigPosts )" "0 1"

echo "-- a message that talks of him is refused --"
n=1
for rigBody in "Tick record, and the human-owner has asked for less traffic." "He wrote at 20:54 slow down." "Human owner said stop." "His ruling is in the record." "He asked for one line." ; do
	n=$(( n + 1 ))
	rigSend "$rigTmp/r$n" "" "$rigBody"
	rigAssert "refused, says so, posts nothing: $rigBody" "$( [ "$( rigRc "$rigTmp/r$n" )" != 0 ] && printf refused || printf sent ) $( LC_ALL=C grep -c 'never who said what' "$rigTmp/r$n" || : ) $( rigPosts )" "refused 1 1"
done

echo "-- words that only look alike go through --"
rigSend "$rigTmp/s1" "" "The whole record was written by the tool and she wrote nothing."
rigAssert "no talk of him: sent" "$( rigRc "$rigTmp/s1" ) $( rigPosts )" "0 2"

echo "-- a member's post to its session thread addressed to the human-owner is refused, and names magic-coordinator --"
## From here the workspace holds his account in the setting, as a real one does: the mention lookup takes it back from there whenever it cuts the cache.
printf 'SLACK_CHANNEL_HUMAN_OWNER=URIGOWNER01\n' >> "$rigWs/.local/.agents/magic-team.agent.env"
rigTarget=session-current
for rigAddr in human-owner URIGOWNER01 ; do
	rigSend "$rigTmp/t-$rigAddr" rig-sess "Round 3 done, next the board."
	rigAssert "addressed to $rigAddr: refused, names magic-coordinator, posts nothing" "$( [ "$( rigRc "$rigTmp/t-$rigAddr" )" != 0 ] && printf refused || printf sent ) $( LC_ALL=C grep -c 'Address it to magic-coordinator' "$rigTmp/t-$rigAddr" || : ) $( rigPosts )" "refused 1 2"
done
rigAddr=magic-coordinator
rigSend "$rigTmp/t-coord" rig-sess "Round 3 done, next the board."
rigAssert "the same post addressed to magic-coordinator: sent" "$( rigRc "$rigTmp/t-coord" ) $( rigPosts )" "0 3"
## The tooling calls the send itself, as an ask does. A member's send goes through its stub, which sets the floor.
rigFloor="" ; rigAddr=human-owner ; rigOp=--intern-op-comms-slack-send-message
rigSend "$rigTmp/t-tool" rig-sess "May the rig go on?"
rigAssert "the tooling's own send of that form, as an ask makes it: sent" "$( rigRc "$rigTmp/t-tool" ) $( rigPosts )" "0 4"
rigTarget="" ; rigAddr="" ; rigFloor=hold ; rigOp=""
echo "-- talk of him sent to a person's own id goes through: that is a direct conversation --"
rigTarget=URIGOWNER01 ; rigPostsBefore="$( rigPosts )"
rigSend "$rigTmp/u-own" "" "Tick record, and the human-owner has asked for less traffic."
rigAssert "to a U id: sent, one post" "$( rigRc "$rigTmp/u-own" ) $(( $( rigPosts ) - rigPostsBefore ))" "0 1"
rigTarget=""
echo "-- his account is read from the setting first, so a cache that lost it lets no post addressed to him through --"
rigIdentities="$rigWs/.local/agents/cache/slack-identities.cache"
case "$( head -1 "$rigIdentities" )" in *=*|'') rigRefuse "the identity cache holds no generation line to keep: $( head -1 "$rigIdentities" )" ;; esac
printf '%s\n' "$( head -1 "$rigIdentities" )" 'human-owner=-' > "$rigIdentities.new" && mv -f "$rigIdentities.new" "$rigIdentities"
rigTarget=session-current ; rigAddr=URIGOWNER01 ; rigPostsBefore="$( rigPosts )"
rigSend "$rigTmp/k-stale" rig-sess "Round 4 done, next the inbox."
rigAssert "his cache row reads - in this lock cycle and the setting holds his id: addressed to URIGOWNER01, refused, names magic-coordinator, posts nothing" "$( [ "$( rigRc "$rigTmp/k-stale" )" != 0 ] && printf refused || printf sent ) $( LC_ALL=C grep -c 'Address it to magic-coordinator' "$rigTmp/k-stale" || : ) $(( $( rigPosts ) - rigPostsBefore ))" "refused 1 0"
echo "-- a cache cut to its generation line takes his id back from the setting, a W id as well as a U id --"
## A workspace of its own, so the setting is read fresh and the cache holds no generation line, which the next mention lookup cuts.
rigWsMain="$rigWs" ; rigWs="$rigTmp/ws-w"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/cache" "$rigWs/.local/agents/sessions/rig-sess"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=%s\nSLACK_CHANNEL_HUMAN_OWNER=WRIGOWNER01\n' "$rigSentinel" > "$rigWs/.local/.agents/magic-team.agent.env"
printf '%s\n' 'human-owner=URIGOWNER01=-=-=-=-' > "$rigWs/.local/agents/cache/slack-identities.cache"
printf '%s\n' 'CRIG00001:1700000000.000100' > "$rigWs/.local/agents/sessions/rig-sess/session.thread"
rigAddr=human-owner
rigSend "$rigTmp/w-word" rig-sess "Round 5 done, next the review."
rigAssert "the setting a W id, the cache cut: his row holds that id, never -" "$( LC_ALL=C grep -c '^human-owner=WRIGOWNER01=' "$rigWs/.local/agents/cache/slack-identities.cache" || : ) $( LC_ALL=C grep -c '^human-owner=-$' "$rigWs/.local/agents/cache/slack-identities.cache" || : )" "1 0"
rigWs="$rigWsMain" ; rigTarget="" ; rigAddr=""

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK SEND OWNER TALK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_SEND_OWNER_TALK: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
