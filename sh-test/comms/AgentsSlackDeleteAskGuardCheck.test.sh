#!/usr/bin/env bash
## Behavioural check that --slack-delete-message refuses to delete the question of an ask still
## waiting, and a message that has replies in its thread (epic S6.10). Run through the real
## operation, in a rig workspace of its own, over a Slack-shaped fake curl, and read back through a
## separate path: the fake's own log of the Slack methods each call asked for. Held:
##   1. the question of an open ask is refused as refused-open-ask, and chat.delete is never asked
##   2. a message whose thread carries a reply is refused as refused-has-replies, and chat.delete is never asked
##   3. a message with no replies and no ask is still deleted, and chat.delete is asked once for it
##   4. a thread the read cannot answer is refused as unverified-thread: a check that cannot reach its subject never passes
## Red: on the package before this guard, rows 1, 2 and 4 all read `deleted` with chat.delete in the log.
## Offline: the fake curl opens no socket, and the rig is a folder of the workspace's own scratch.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackDeleteAskGuardCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills" rigData="$rigTmp/data" rigHome="$rigTmp/home"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/pending" "$rigSkills/$rigMember" "$rigHome" "$rigTmp/bin" \
	|| rigRefuse "could not create the rig"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigWs/.local/.agents/$rigMember.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The fake curl: every method logged, and a thread answered from replies.<ts>.json where the
## scenario has one, refused where it has none, so an unanswered read is a read that failed.
cat > "$rigTmp/bin/curl" <<'RIG_CURL'
#!/usr/bin/env bash
set -u
cat > /dev/null
rigMethod="no-method"
rigTs=""
for rigArg in "$@" ; do
	case "$rigArg" in
		ts@*) rigTs="$( cat "${rigArg#ts@}" 2>/dev/null )" ;;
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
	esac
done
printf '%s\n' "$rigMethod" >> "$RIG_CURL_LOG"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"user_id":"URIGSELF1"}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n' ;;
	conversations.replies)
		if [ -n "$rigTs" ] && [ -f "$RIG_SCENARIO/replies.$rigTs.json" ] ; then
			cat "$RIG_SCENARIO/replies.$rigTs.json"
		else
			printf '{"ok":false,"error":"rig_no_replies"}\n'
		fi
	;;
	*) printf '{"ok":true}\n' ;;
esac
RIG_CURL
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:/usr/bin:/bin"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"
RIG_CURL_LOG="$rigTmp/curl.log" ; export RIG_CURL_LOG ; : > "$RIG_CURL_LOG"
RIG_SCENARIO="$rigTmp/scenario" ; export RIG_SCENARIO ; mkdir -p "$RIG_SCENARIO"

## Four messages: the ask's question, an answered one, one nobody touched, and one whose thread
## the fake cannot answer.
rigAskTs="1700000100.000100"
rigAnsweredTs="1700000200.000200"
rigOrdinaryTs="1700000300.000300"
rigSilentTs="1700000400.000400"
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"RIG-ASK"}]}\n' "$rigAskTs" > "$RIG_SCENARIO/replies.$rigAskTs.json"
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"RIG-ANSWERED","reply_count":1},{"ts":"1700000201.000201","user":"URIGOTHER","text":"RIG-REPLY"}]}\n' \
	"$rigAnsweredTs" > "$RIG_SCENARIO/replies.$rigAnsweredTs.json"
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"RIG-ORDINARY"}]}\n' "$rigOrdinaryTs" > "$RIG_SCENARIO/replies.$rigOrdinaryTs.json"

rigEnv(){ ## command... -- the rig's workspace, with no model key
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u ANTHROPIC_API_KEY -u OPENAI_API_KEY \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDAT_SPAWN_AGENT="$rigMember" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" "$@" )
}
## The one ask, opened by the store's own operation, so its record is the store's own writing.
rigAskId="$( printf '# Ask\n\nMay I?\n' | rigEnv bash "$rigTool" --intern-op-pending-reply-open "$rigMember" --to CRIG00001 \
	--kind question --channel CRIG00001 --question-ts "$rigAskTs" --thread-ts "$rigAskTs" --addressees URIGOWNER --asking-accounts ' URIGSELF1 ' 2> "$rigTmp/open.err" )"
[ -n "$rigAskId" ] && [ -f "$rigWs/.local/agents/pending/$rigAskId.md" ] \
	|| rigRefuse "the ask was not opened, so this check could not test its message: $( cat "$rigTmp/open.err" )"

rigDelete(){ ## the message's ts -- one delete call, its state and its chat.delete count
	: > "$RIG_CURL_LOG"
	rigDeleteRc=0
	rigEnv bash "$rigTool" --slack-delete-message --team-member "$rigMember" "CRIG00001:$1" < /dev/null > "$rigTmp/delete.out" 2> "$rigTmp/delete.err" || rigDeleteRc=$?
	rigDeleteState="$( LC_ALL=C sed -n 's/^DELETE_STATE=//p' "$rigTmp/delete.out" )"
	rigDeleteDeletes="$( LC_ALL=C grep -c -x 'chat.delete' "$RIG_CURL_LOG" || : )"
}

echo "-- 1. the question of an open ask --"
rigDelete "$rigAskTs"
rigAssert "control: the call ran and reported a state" "$( [ -n "$rigDeleteState" ] && printf yes || printf no )" yes
rigAssert "refused, the state naming the open ask" "$rigDeleteState" "refused-open-ask"
rigAssert "the ask is named in the one line, with the operation that closes it" \
	"$( LC_ALL=C grep -c -F -- "$rigAskId" "$rigTmp/delete.err" || : ):$( LC_ALL=C grep -c -F -- '--settle-pending-reply' "$rigTmp/delete.err" || : )" "1:1"
rigAssert "chat.delete was never asked" "$rigDeleteDeletes" 0
rigAssert "and the call ends non-zero, so a caller's status check sees it" "$rigDeleteRc" 1

echo "-- 2. a message somebody answered --"
rigDelete "$rigAnsweredTs"
rigAssert "refused, the state naming the replies" "$rigDeleteState" "refused-has-replies"
rigAssert "the count of replies is in the line" "$( LC_ALL=C grep -c -F -- '1 replies stand in its thread' "$rigTmp/delete.err" || : )" 1
rigAssert "chat.delete was never asked" "$rigDeleteDeletes" 0

echo "-- 3. an ordinary message --"
rigDelete "$rigOrdinaryTs"
rigAssert "deleted: the guard did not widen into a refusal of everything" "$rigDeleteState" "deleted"
rigAssert "chat.delete was asked once" "$rigDeleteDeletes" 1
rigAssert "and the call ends 0" "$rigDeleteRc" 0

echo "-- 4. a thread the read cannot answer refuses rather than passing --"
rigDelete "$rigSilentTs"
rigAssert "refused as unverified, not deleted" "$rigDeleteState" "unverified-thread"
rigAssert "chat.delete was never asked" "$rigDeleteDeletes" 0

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ SLACK DELETE ASK GUARD CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'SLACK_DELETE_ASK_GUARD: OK (%s assertions, offline, rig tree only)\n' "$rigPassCount"
