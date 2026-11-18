#!/usr/bin/env bash
## Behavioural check on the review wait limit counting from the answer a run was given
## (AgentsReviewWaitLeft, sh-lib/board/AgentsTools.ReviewFlow.include): a run whose item waits in
## review keeps running once an ask of its own session is answered, so it reaches its apply report.
## Held:
##   1. with no answer the limit is as before: an item two hours in review is expired.
##   2. an ask of the run's session answered a moment ago: the limit counts from that answer, so the
##      run is not released.
##   3. an ask of another session answered a moment ago holds nothing: the run's own session counts.
##   4. an ask of the run's session that nobody answered holds nothing: only an answer counts.
##   5. an ask of the run's session that was withdrawn holds nothing: a withdrawal answers nothing.
##   6. control: an item that entered review a moment ago is not expired, with no ask at all.
## Offline: a fake curl first on PATH answers as Slack and opens no socket. The board and the spawn
## records are written by their own owners (sh-test/check-fixtures/rig-owner-writes.include.sh), the
## asks by the ask store's own operations, open and close. Never the live team data.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigReview="$rigPackage/sh-lib/board/AgentsTools.ReviewFlow.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigFn"
[ -f "$rigReview" ] || rigRefuse "the review flow is not at the origin this workspace resolves: $rigReview"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set, so the rig has no workspace temp folder}"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReviewWaitAskAnswerCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSpawned"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigTmp/skills"
rigOwnerBoardReady
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"
## THE RIG'S SLACK: a post and a reaction are answered, and nothing leaves the machine.
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
rigDir="${0%/*}/../slack"
rigMethod=""
for rigArg in "$@" ; do
	case "$rigArg" in https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;; esac
done
mkdir -p "$rigDir"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	chat.postMessage) printf '{"ok":true,"channel":"CRIG00001","ts":"1794000000.000100","message":{"ts":"1794000000.000100","user":"URIGBOT01"}}\n' ;;
	reactions.add|reactions.remove) printf '{"ok":true}\n' ;;
	conversations.replies) printf '{"ok":true,"messages":[{"ts":"1794000000.000100","user":"URIGBOT01","text":"the question"}],"has_more":false}\n' ;;
	*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac
RIGCURL
chmod +x "$rigTmp/bin/curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nREVIEW_WAIT_LIMIT=3600\nSPAWN_TIER_NORMAL=rig-cli\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
## One command in the rig, guarded to its own trees, the fake curl first on PATH. Output into
## <result>, rc into <result>.rc.
rigEnv=()
rigRun(){ ## result file, command...
	local runOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" "${rigEnv[@]+"${rigEnv[@]}"}" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ "$( command -v curl )" = "$RIG_TMP/bin/curl" ] || exit 98
			cd "$MMDAPP" && exec "$@"
		' rig "$@" > "$runOut" 2>&1
	printf '%s' "$?" > "$runOut.rc"
}
rigOp(){ ## result file, DistroAgentsTools.fn.sh args...
	local opOut="$1" ; shift
	rigRun "$opOut" bash "$rigFn" "$@"
}
## The run under test: its own session, its item in review since the moment given.
rigNowEpoch="$( date +%s )"
rigUser(){ ## run id, session id, seconds its item has been in review -- the run's record and its item
	rigItem="${1%%-*}"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nowner: keeper-myx\nstatus: spawn-succeeded\nstarted-at: 2026-11-17 20:00 +0200\nspawns: rig-dispatch-%s\n---\n\n# Spawn session: %s\n' \
		"$2" "$1" "$rigHost" "$1" "$2" | rigOwnerSpawnPut "$1" || rigRefuse "the record of $1 could not be written"
	printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\nspawn-id: %s\nreview-by: magic-coordinator\nreview-since-epoch: %s\nreview-reason: handback\n---\n\n# the rig task of %s\n' \
		"$1" "$(( rigNowEpoch - $3 ))" "$1" | rigOwnerBoardPut review "rig-dispatch-$1.md" || rigRefuse "the item of $1 could not be written"
}
## A question of a session, opened and then closed by the ask store's own operations. The answer is
## given now, so its record stands at this moment: the check moves the item instead.
rigAskAnswered(){ ## session id, the answer word -- the pending id
	local askId=""
	printf '# rig question\n\nDoes the rig go on?\n' | rigOp "$rigTmp/open.$$" --intern-op-pending-reply-open keeper-myx --to CRIG00001 --session-id "$1" --kind question || :
	askId="$( LC_ALL=C sed -n 's/^\([0-9a-f-]\{36\}\)$/\1/p' "$rigTmp/open.$$" | head -1 )"
	[ -n "$askId" ] || rigRefuse "the ask of session $1 was not opened: $( tr '\n' ' ' < "$rigTmp/open.$$" | cut -c1-400 )"
	rigOp "$rigTmp/close.$$" --intern-op-pending-reply-close "$askId" --if-open --status reply-received --verdict "$2" --answered-by URIGOWNER || :
	printf '%s\n' "$askId"
}
rigAskOpen(){ ## session id -- the pending id of a question nobody has answered
	local askId=""
	printf '# rig question\n\nDoes the rig go on?\n' | rigOp "$rigTmp/open2.$$" --intern-op-pending-reply-open keeper-myx --to CRIG00001 --session-id "$1" --kind question || :
	askId="$( LC_ALL=C sed -n 's/^\([0-9a-f-]\{36\}\)$/\1/p' "$rigTmp/open2.$$" | head -1 )"
	[ -n "$askId" ] || rigRefuse "the open ask of session $1 was not opened: $( tr '\n' ' ' < "$rigTmp/open2.$$" | cut -c1-400 )"
	printf '%s\n' "$askId"
}
rigLeft(){ ## run id -- what the review limit gives its Wait: `<rc>:<what it printed>`
	rigRun "$rigTmp/left.$$" bash -c '. "$1" ; . "$2" ; rigOut="$( AgentsReviewWaitLeft "$3" )" ; printf "%s:%s\n" "$?" "$rigOut"' rig "$rigFn" "$rigReview" "$1"
	## The tooling's context banner goes to the same stdout: the limit's own line is the one that starts with a status.
	LC_ALL=C grep -E '^[0-9]+:' "$rigTmp/left.$$" | LC_ALL=C sed -n '1p'
}
## The number of seconds the limit gave, where it gave one: a range, so a run of the rig that takes a
## second is not a failure.
rigLeftIs(){ ## the limit's own line -- expired | left | nothing
	case "$1" in
		"0:expired") printf 'expired' ;;
		"0:"[0-9]*) printf 'left' ;;
		*) printf '%s' "${1:-nothing}" ;;
	esac
}
## The kept measure of a session, as the ask store's own reader gives it.
rigKept(){ ## session id
	rigRun "$rigTmp/kept.$$" bash -c '. "$1" ; . "$2" ; rigOut="" ; AgentsToolsPendingReplySessionAnswerInto rigOut "$3" ; printf "KEPT:%s\n" "$rigOut"' rig "$rigFn" "$rigPackage/sh-lib/questions/AgentsTools.PendingReplyRecords.include" "$1"
	LC_ALL=C sed -n 's/^KEPT://p' "$rigTmp/kept.$$" | LC_ALL=C sed -n '1p'
}
rigSeed(){ ## the seed's own count
	rigRun "$rigTmp/seed.$$" bash -c '. "$1" ; . "$2" ; AgentsToolsPendingReplyAnswersSeed' rig "$rigFn" "$rigPackage/sh-lib/questions/AgentsTools.PendingReplyRecords.include"
	LC_ALL=C grep -E '^[0-9]+$' "$rigTmp/seed.$$" | tail -1
}

echo "-- 1. with no answer the limit is as before --"
rigUser rig-run-none rig-sess-none 7200
rigAssert "control: no ask at all, an item two hours in review: expired" \
	"$( rigLeftIs "$( rigLeft rig-run-none )" )" expired

echo "-- 2. an ask of the run's session answered a moment ago: the limit counts from the answer --"
rigUser rig-run-answered rig-sess-answered 7200
rigAskAnswered rig-sess-answered yes > /dev/null
rigAnsweredLimit="$( rigLeft rig-run-answered )"
rigAssert "the run is not released: the limit counts from its answer, so an hour is left" \
	"$( rigLeftIs "$rigAnsweredLimit" ):$( [ "${rigAnsweredLimit#0:}" -ge 3500 ] 2> /dev/null && [ "${rigAnsweredLimit#0:}" -le 3600 ] 2> /dev/null && echo an-hour || echo "${rigAnsweredLimit#0:}" )" "left:an-hour"

echo "-- 3. an ask of another session answered a moment ago holds nothing --"
rigUser rig-run-other rig-sess-other 7200
rigAskAnswered rig-sess-somebody-else yes > /dev/null
rigAssert "another session's answer is not this run's: expired" \
	"$( rigLeftIs "$( rigLeft rig-run-other )" )" expired

echo "-- 4. an ask of the run's session that nobody answered holds nothing --"
rigUser rig-run-open rig-sess-open 7200
rigAskOpen rig-sess-open > /dev/null
rigAssert "a question still waiting answers nothing: expired" \
	"$( rigLeftIs "$( rigLeft rig-run-open )" )" expired

echo "-- 5. an ask of the run's session that was withdrawn holds nothing --"
rigUser rig-run-wdrn rig-sess-wdrn 7200
rigWdrawnId="$( rigAskOpen rig-sess-wdrn )"
rigOp "$rigTmp/wd.$$" --intern-op-pending-reply-close "$rigWdrawnId" --if-open --status withdrawn --withdrawn-by keeper-myx --withdraw-reason "the rig takes it back" || :
rigAssert "a withdrawal grants and decides nothing: expired" \
	"$( rigLeftIs "$( rigLeft rig-run-wdrn )" )" expired

echo "-- 6. control: an item that just entered review is not expired --"
rigUser rig-run-fresh rig-sess-fresh 0
rigAssert "control: no ask, an item in review a moment: an hour is left" \
	"$( rigLeftIs "$( rigLeft rig-run-fresh )" )" left

echo "-- 7. the ask store's own close keeps the answer, and the reader reads that, never the records --"
rigUser rig-run-kept rig-sess-kept 7200
rigKeptId="$( rigAskAnswered rig-sess-kept yes )"
rigAnswerEpoch="$( cat "$rigWs/.local/agents/pending/answers/rig-sess-kept.epoch" 2> /dev/null )"
case "$rigAnswerEpoch" in ''|*[!0123456789]*) rigAnswerEpoch="none" ;; esac
rigAssert "the close writes the answer's moment beside the records" \
	"$( [ "$rigAnswerEpoch" != none ] && [ "$(( $( date +%s ) - rigAnswerEpoch ))" -le 60 ] && echo fresh || echo "$rigAnswerEpoch" )" fresh
rigAssert "the reader gives that moment" \
	"$( [ "$( rigKept rig-sess-kept )" = "$rigAnswerEpoch" ] && echo same || echo "$( rigKept rig-sess-kept )" )" same
## The records are gone from both stores: a reader that walked them would find nothing.
rigAssert "so the limit still counts from it" \
	"$( rigLeftIs "$( rigLeft rig-run-kept )" )" left

echo "-- 8. the seed writes the kept measure once, from the answers closed before it existed --"
rigUser rig-run-seed rig-sess-seed 7200
rigAskAnswered rig-sess-seed yes > /dev/null
rm -f "$rigWs/.local/agents/pending/answers/rig-sess-seed.epoch"
rigAssert "with no file, the session reads as no answer: the limit counts from review entry" \
	"$( rigLeftIs "$( rigLeft rig-run-seed )" )" expired
rigSeedCount="$( rigSeed )"
rigSeededEpoch="$( cat "$rigWs/.local/agents/pending/answers/rig-sess-seed.epoch" 2> /dev/null )"
case "$rigSeededEpoch" in ''|*[!0123456789]*) rigSeededEpoch="none" ;; esac
rigAssert "the seed writes a file for it" \
	"$rigSeedCount:$([ "$rigSeededEpoch" != none ] && echo seeded || echo "$rigSeededEpoch")" "1:seeded"
rigAssert "and the limit counts from it again" \
	"$( rigLeftIs "$( rigLeft rig-run-seed )" )" left
rigAssert "a seeded file is never lowered by a second seed" \
	"$( rigSeed ):$rigSeededEpoch" "0:$rigSeededEpoch"

echo "-- 9. the reader never opens the records: with both stores emptied, the kept moment still answers --"
rigUser rig-run-gone rig-sess-gone 7200
rigAskAnswered rig-sess-gone yes > /dev/null
rigGoneEpoch="$( cat "$rigWs/.local/agents/pending/answers/rig-sess-gone.epoch" 2> /dev/null )"
rm -f "$rigWs/.local/agents/pending/"*.md "$rigWs/.local/agents/pending/closed/"*.md
rigAssert "the records are gone and the kept moment still answers" \
	"$( [ -n "$rigGoneEpoch" ] && [ "$( rigKept rig-sess-gone )" = "$rigGoneEpoch" ] && echo stands || echo gone )" stands
rigAssert "and the limit counts from it, so the run is not released" \
	"$( rigLeftIs "$( rigLeft rig-run-gone )" )" left

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ REVIEW WAIT ASK ANSWER CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  warn: a run whose ask was answered is still released by the review limit, so it ends mid-apply" >&2
	echo "  fix:  sh-lib/board/AgentsTools.ReviewFlow.include, AgentsReviewWaitLeft -- never the assertion" >&2
	exit 1
fi
printf 'REVIEW_WAIT_ASK_ANSWER: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
