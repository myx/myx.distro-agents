#!/usr/bin/env bash
## Behavioural check on an answer reaching the status of the items that name its ask (AgentsToolsDecisionsStatusFromPending,
## sh-lib/board/AgentsTools.ItemDecisions.include, and --reconcile-answered-status): an item whose status says it waits on an ask
## must not keep saying so once the ask is answered.
## Held:
##   1. a close with a verdict appends `<id> answered <verdict> by <who> at <time>` to the `status:` of each open item that names
##      the ask: its record's own `item:`, an item whose `status:` names it by its first eight characters, and an item whose
##      `condition:` names it whole. Each item stays in its state, and the body of an item that waits by its status is unchanged.
##   2. it leaves alone an item that names another ask still open, a closed item that names this one, and an item that names it
##      only in its body.
##   3. --reconcile-answered-status finds an open item whose status names an ask answered before the status was written, and
##      writes nothing; with --apply it appends the answer, once: a second --apply finds nothing.
##   4. it refuses the rows that must stay: an ask still open, an ask withdrawn, and the items the close already brought up to date.
## Red before the fix: the close leaves every status as it was, and the operation is not there.
## Offline: a fake curl first on PATH answers as Slack. The board is written by its owner (rig-owner-writes), the asks by the ask
## store's own operations, open and close. Never the live team data.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigQuestions="$rigPackage/sh-scripts/DistroAgentsQuestions.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigFn"
[ -f "$rigQuestions" ] || rigRefuse "the questions tool file is not at the origin this workspace resolves: $rigQuestions"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set, so the rig has no workspace temp folder}"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAnsweredStatusCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigWs="$rigTmp/ws"
rigBoard="$rigData/board"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents"
. "$rigPackage/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigTmp/skills"
rigOwnerBoardReady || rigRefuse "the board of the rig could not be made ready"
## THE RIG'S SLACK: a post and a reaction are answered, and nothing leaves the machine.
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
rigMethod=""
for rigArg in "$@" ; do
	case "$rigArg" in https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;; esac
done
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	chat.postMessage) printf '{"ok":true,"channel":"CRIG00001","ts":"1794000000.000100","message":{"ts":"1794000000.000100","user":"URIGBOT01"}}\n' ;;
	reactions.add|reactions.remove|chat.update) printf '{"ok":true}\n' ;;
	conversations.replies) printf '{"ok":true,"messages":[{"ts":"1794000000.000100","user":"URIGBOT01","text":"the question"}],"has_more":false}\n' ;;
	*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac
RIGCURL
chmod +x "$rigTmp/bin/curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
## One command in the rig, guarded to its own trees, the fake curl first on PATH. Output into <result>.
rigRun(){ ## result file, command...
	local runOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ "$( command -v curl )" = "$RIG_TMP/bin/curl" ] || exit 98
			cd "$MMDAPP" && exec "$@"
		' rig "$@" > "$runOut" 2>&1
	printf '%s' "$?" > "$runOut.rc"
}
## A question opened by the ask store's own open, filed on <item> where one is given -- its pending id.
rigAsk(){ ## result name, item (may be empty)
	printf '# rig question\n\nDoes the rig go on?\n' | rigRun "$rigTmp/$1" bash "$rigFn" --intern-op-pending-reply-open keeper-myx --to CRIG00001 --session-id "rig-session-$1" --kind question ${2:+--task-ref "$2"}
	LC_ALL=C sed -n 's/^\([0-9a-f-]\{36\}\)$/\1/p' "$rigTmp/$1" | head -1
}
## One frontmatter field of a rig file, a pending record found in its closed/ folder too.
rigField(){ ## file, field
	[ -f "$1" ] || set -- "${1%/*}/closed/${1##*/}" "$2"
	LC_ALL=C awk -v key="$2" 'NR > 1 && $0 == "---" { exit } index($0, key ": ") == 1 { print substr($0, length(key) + 3) ; exit }' "$1"
}
## The body of an item: every line after its frontmatter.
rigBody(){ ## item file
	LC_ALL=C awk 'fence >= 2 { print ; next } $0 == "---" { fence++ }' "$1"
}
## The lines an operation printed that start with the word given, one per line, in order.
rigLines(){ ## result file, word
	LC_ALL=C grep "^$2 " "$1" | LC_ALL=C tr '\n' ';'
}
rigItem(){ ## state, item name, frontmatter lines (each ending in \n, which %b reads), body
	printf -- '---\ntype: task\nowner: keeper-myx\n%b---\n\n# %s\n\n%s\n' "$3" "$2" "$4" | rigOwnerBoardPut "$1" "$2.md" || rigRefuse "the item $2 could not be written"
}

echo "-- the rig: one ask answered, one left open, one withdrawn, and the items that name them --"
rigOwn="dispatch-20261118T0900Z-spawn-proxy-1-rigown"
printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\n---\n\n# the rig dispatch\n' | rigOwnerBoardPut running "$rigOwn.md" || rigRefuse "the dispatch could not be written"
rigAnswered="$( rigAsk ask1 "$rigOwn" )"
rigOpen="$( rigAsk ask2 "" )"
rigGone="$( rigAsk ask3 "" )"
[ -n "$rigAnswered" ] && [ -n "$rigOpen" ] && [ -n "$rigGone" ] || rigRefuse "an ask was not opened: $( cat "$rigTmp/ask1" "$rigTmp/ask2" "$rigTmp/ask3" | tr '\n' ' ' | cut -c1-600 )"
rigAssert "control: the answered ask is filed on its dispatch" "$( rigField "$rigWs/.local/agents/pending/$rigAnswered.md" item )" "$rigOwn"
rigShort="task-20261118T0901Z-rig-waits-short"
rigCond="task-20261118T0902Z-rig-waits-condition"
rigOther="task-20261118T0903Z-rig-waits-other"
rigDone="task-20261118T0904Z-rig-waits-done"
rigBodyOnly="task-20261118T0905Z-rig-names-in-body"
rigItem running "$rigShort" "status: rechecked by work-duty 5bb4f9f4. That is the owner's call, asked as ${rigAnswered:0:8} at 11:34 +0200 and unanswered.\n" "The body stays as it is."
rigItem blocked "$rigCond" "condition: has the owner answered pending reply $rigAnswered?\n" "Waits on the answer."
rigItem running "$rigOther" "status: asked as ${rigOpen:0:8} and unanswered.\n" "Waits on another ask."
rigItem processed "$rigDone" "status: asked as ${rigAnswered:0:8} and unanswered.\n" "Closed already."
rigItem running "$rigBodyOnly" "" "The body alone names ${rigAnswered:0:8}."
rigShortBody="$( rigBody "$rigBoard/running/$rigShort.md" )"
rigShortStatus="$( rigField "$rigBoard/running/$rigShort.md" status )"
rigOtherStatus="$( rigField "$rigBoard/running/$rigOther.md" status )"
rigDoneStatus="$( rigField "$rigBoard/processed/$rigDone.md" status )"

echo "-- 1. a close with a verdict reaches the status of every open item that names the ask --"
rigRun "$rigTmp/close1" bash "$rigFn" --intern-op-pending-reply-close "$rigAnswered" --if-open --status reply-received --verdict "turn it" --answered-by URIGOWNER
rigAssert "control: the close succeeds" "$( cat "$rigTmp/close1.rc" )" 0
rigAt="$( rigField "$rigWs/.local/agents/pending/$rigAnswered.md" resolved-at )"
[ -n "$rigAt" ] || rigRefuse "the closed record carries no resolved-at: $( tr '\n' ' ' < "$rigTmp/close1" | cut -c1-400 )"
rigLine="$rigAnswered answered turn it by URIGOWNER at $rigAt"
rigAssert "the item whose status names the ask by its short id gets the line" \
	"$( rigField "$rigBoard/running/$rigShort.md" status )" "$rigShortStatus | $rigLine"
rigAssert "the item whose condition names the ask gets it as its status" \
	"$( rigField "$rigBoard/blocked/$rigCond.md" status )" "$rigLine"
rigAssert "the record's own item gets it" \
	"$( rigField "$rigBoard/running/$rigOwn.md" status )" "dispatch-started | $rigLine"
rigAssert "each stays in its state" \
	"$( [ -f "$rigBoard/running/$rigShort.md" ] && [ -f "$rigBoard/blocked/$rigCond.md" ] && [ -f "$rigBoard/running/$rigOwn.md" ] && echo stayed || echo moved )" stayed
rigAssert "the body of the item that waits by its status is unchanged" \
	"$( [ "$( rigBody "$rigBoard/running/$rigShort.md" )" = "$rigShortBody" ] && echo same || echo edited )" same

echo "-- 2. what must stay as it was --"
rigAssert "an item naming another ask, still open, keeps its status" \
	"$( rigField "$rigBoard/running/$rigOther.md" status )" "$rigOtherStatus"
rigAssert "a processed item naming the ask keeps its status" \
	"$( rigField "$rigBoard/processed/$rigDone.md" status )" "$rigDoneStatus"
rigAssert "an item naming the ask in its body only gets no status" \
	"$( rigField "$rigBoard/running/$rigBodyOnly.md" status )" ""

echo "-- 3. the reconcile finds an item whose status was written after the answer --"
rigLate="task-20261118T0906Z-rig-written-late"
rigGoneItem="task-20261118T0907Z-rig-waits-withdrawn"
rigRun "$rigTmp/close3" bash "$rigFn" --intern-op-pending-reply-close "$rigGone" --if-open --status withdrawn --withdrawn-by keeper-myx --withdraw-reason "the rig withdraws it"
rigAssert "control: the withdrawal succeeds" "$( cat "$rigTmp/close3.rc" )" 0
rigItem running "$rigLate" "status: asked as ${rigAnswered:0:8} at 11:34 +0200 and unanswered.\n" "Written after the answer."
rigItem running "$rigGoneItem" "status: asked as ${rigGone:0:8} and unanswered.\n" "Waits on a withdrawn ask."
rigLateStatus="$( rigField "$rigBoard/running/$rigLate.md" status )"
rigGoneStatus="$( rigField "$rigBoard/running/$rigGoneItem.md" status )"
rigRun "$rigTmp/rec1" bash "$rigQuestions" --reconcile-answered-status --team-member magic-coordinator
rigAssert "the read finds the late item alone" "$( rigLines "$rigTmp/rec1" STATUS-STALE )" "STATUS-STALE $rigLate running $rigAnswered;"
rigAssert "and writes nothing" "$( rigField "$rigBoard/running/$rigLate.md" status )" "$rigLateStatus"
rigRun "$rigTmp/rec2" bash "$rigQuestions" --reconcile-answered-status --team-member magic-coordinator --apply
rigAssert "--apply appends the answer to it" "$( rigLines "$rigTmp/rec2" STATUS-ANSWERED )" "STATUS-ANSWERED $rigLate running $rigAnswered;"
rigAssert "its status carries the line" "$( rigField "$rigBoard/running/$rigLate.md" status )" "$rigLateStatus | $rigLine"
rigRun "$rigTmp/rec3" bash "$rigQuestions" --reconcile-answered-status --team-member magic-coordinator --apply
rigAssert "a second --apply finds nothing" "$( rigLines "$rigTmp/rec3" STATUS-ANSWERED )$( LC_ALL=C grep -c -x 'STATUS-NONE' "$rigTmp/rec3" )" "1"

echo "-- 4. the rows the reconcile refuses --"
rigAssert "an item waiting on an ask still open keeps its status" "$( rigField "$rigBoard/running/$rigOther.md" status )" "$rigOtherStatus"
rigAssert "an item waiting on a withdrawn ask keeps its status" "$( rigField "$rigBoard/running/$rigGoneItem.md" status )" "$rigGoneStatus"
rigAssert "the items the close brought up to date carry the line once" \
	"$( rigField "$rigBoard/running/$rigShort.md" status | LC_ALL=C awk -v want="$rigLine" '{ count = 0 ; while ( ( at = index( $0, want ) ) > 0 ) { count++ ; $0 = substr( $0, at + length( want ) ) ; } print count ; }' )" 1
rigRun "$rigTmp/rec4" bash "$rigQuestions" --reconcile-answered-status --team-member magic-coordinator --rig-argument-no-operation-takes
rigAssert "an argument it does not take is refused before it acts" \
	"$( [ "$( cat "$rigTmp/rec4.rc" )" != 0 ] && LC_ALL=C grep -c 'invalid option: --rig-argument-no-operation-takes' "$rigTmp/rec4" )" 1

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ ANSWERED STATUS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  warn: an item whose status names an answered ask keeps saying it is unanswered" >&2
	echo "  fix:  sh-lib/board/AgentsTools.ItemDecisions.include, AgentsToolsDecisionsStatusFromPending, and --reconcile-answered-status -- never the assertion" >&2
	exit 1
fi
printf 'ANSWERED_STATUS: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
