#!/usr/bin/env bash
## Behavioural check on the two closes that end an item's life (board task 2026-11-17T2332Z): an
## item whose `condition:` stands, and one in board-parked, are closed by neither --accept-review
## nor --move-to-processed, and the refusal names what the item waits on. Each refusal is proved
## against a control that must still close: a review item with no condition, accepted and moved
## alike. Offline: a fake `curl` first on PATH opens no socket, and the board is this rig's own
## temp store, written through the owner fixtures.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardMoves.include" ] || rigRefuse "the board moves include is not there"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
. "${MDLT_ORIGIN}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCloseRefusesWaitingItemCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/bin"

## Nothing here reaches Slack: the fake curl is first on PATH in case any close tries to send.
cp "${MDLT_ORIGIN}/myx/myx.distro-agents/sh-test/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
RIG_SCENARIO="$rigTmp/scenario"
RIG_CURL_LOG="$rigTmp/scenario/curl.log"
mkdir -p "$RIG_SCENARIO"
export PATH RIG_SCENARIO RIG_CURL_LOG
: > "$RIG_CURL_LOG"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"

. "${MDLT_ORIGIN}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigTmp/ws" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigTmp/skills"
rigOwnerBoardReady

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One team op, guarded to this rig's own trees, the fake curl first on PATH; rc into <result>.rc.
rigOp(){ ## result file, DistroAgentsTools.fn.sh arguments...
	local opOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_SCENARIO="$RIG_SCENARIO" RIG_CURL_LOG="$RIG_CURL_LOG" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ "$( command -v curl )" = "$RIG_TMP/bin/curl" ] || exit 98
			cd "$MMDAPP" && exec bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@"
		' rig "$@" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}
## One items op, guarded the same way; the closing moves into archived and retained are its own.
rigItemsOp(){ ## result file, DistroAgentsItems.fn.sh arguments...
	local opOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" RIG_TMP="$rigTmp" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh" "$@"
		' rig "$@" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}
rigLoc(){ ## item filename -- which board/<state>/ actually holds it	local stateDir
	for stateDir in "$rigData"/board/*/ ; do
		[ -f "$stateDir$1" ] && { basename "$stateDir" ; return 0 ; }
	done
	printf 'not-found'
}

## A review item that waits: its condition is a question nobody answered.
printf -- '---\ntype: task\nowner: rig\ncondition: has the human-owner answered the rig question?\n---\n\nrig item that waits\n' \
	| rigOwnerBoardPut review task-rig-waits.md
## The control: the same item with nothing outstanding.
printf -- '---\ntype: task\nowner: rig\n---\n\nrig item finished\n' | rigOwnerBoardPut review task-rig-ready.md

echo "-- accept: an item whose condition stands is refused, and the condition is named --"
rigOp "$rigTmp/a1" --accept-review --team-member magic-coordinator task-rig-waits --summary "good work"
rigAssert "the accept is refused"                     "$( cat "$rigTmp/a1.rc" )" 1
rigAssert "the item stays in review"                  "$( rigLoc task-rig-waits.md )" review
rigAssert "the refusal names the condition"           "$( LC_ALL=C grep -c 'has the human-owner answered the rig question' "$rigTmp/a1" )" 1
rigAssert "nothing was accepted"                      "$( LC_ALL=C grep -c 'verdict: accepted' "$rigData/board/review/task-rig-waits.md" )" 0

echo "-- accept: an item with nothing outstanding still closes --"
rigOp "$rigTmp/a2" --accept-review --team-member magic-coordinator task-rig-ready --summary "good work"
rigAssert "the accept succeeds"                       "$( cat "$rigTmp/a2.rc" )" 0
rigAssert "the item is processed"                     "$( rigLoc task-rig-ready.md )" processed

echo "-- accept: an item in board-parked is refused, and being parked is said --"
printf -- '---\ntype: task\nowner: rig\ncondition: has the rig release been cut?\n---\n\nrig item deferred\n' \
	| rigOwnerBoardPut parked task-rig-deferred.md
rigOp "$rigTmp/a3" --accept-review --team-member magic-coordinator task-rig-deferred
rigAssert "the accept is refused"                     "$( cat "$rigTmp/a3.rc" )" 1
rigAssert "the item stays parked"                     "$( rigLoc task-rig-deferred.md )" parked
rigAssert "the refusal says it is parked"             "$( LC_ALL=C grep -c 'parked' "$rigTmp/a3" )" 1

echo "-- move-to-processed: a waiting item is refused --"
rigOp "$rigTmp/m1" --move-to-processed --team-member magic-coordinator task-rig-waits.md --from-state:review
rigAssert "the move is refused"                       "$( cat "$rigTmp/m1.rc" )" 1
rigAssert "the item stays in review"                  "$( rigLoc task-rig-waits.md )" review
rigAssert "the refusal names the condition"           "$( LC_ALL=C grep -c 'has the human-owner answered the rig question' "$rigTmp/m1" )" 1

echo "-- move-to-processed: a parked item is refused --"
rigOp "$rigTmp/m2" --move-to-processed --team-member magic-coordinator task-rig-deferred.md --from-state:parked
rigAssert "the move is refused"                       "$( cat "$rigTmp/m2.rc" )" 1
rigAssert "the item stays parked"                     "$( rigLoc task-rig-deferred.md )" parked

echo "-- the other two closing moves refuse a waiting item too --"
printf -- '---\ntype: task\nowner: rig\ncondition: has the rig archive been agreed?\n---\n\nrig item to archive\n' \
	| rigOwnerBoardPut running task-rig-archive.md
rigItemsOp "$rigTmp/r1" --grooming-to-archived --team-member magic-coordinator task-rig-archive.md --from-state:running --owner-header-value rig
rigAssert "archiving a waiting item is refused"      "$( cat "$rigTmp/r1.rc" )" 1
rigAssert "it stays where it was"                    "$( rigLoc task-rig-archive.md )" running
printf -- '---\ntype: task\nowner: rig\ncondition: has the rig retention been agreed?\n---\n\nrig item to retain\n' \
	| rigOwnerBoardPut running task-rig-retain.md
rigItemsOp "$rigTmp/r2" --grooming-to-retained --team-member magic-coordinator task-rig-retain.md --from-state:running --owner-header-value rig
rigAssert "retaining a waiting item is refused"      "$( cat "$rigTmp/r2.rc" )" 1
rigAssert "it stays where it was"                    "$( rigLoc task-rig-retain.md )" running
printf -- '---\ntype: task\nowner: rig\n---\n\nrig item, ready to archive\n' | rigOwnerBoardPut running task-rig-archive-ok.md
rigItemsOp "$rigTmp/r3" --grooming-to-archived --team-member magic-coordinator task-rig-archive-ok.md --from-state:running --owner-header-value rig
rigAssert "a plain item still archives"              "$( cat "$rigTmp/r3.rc" ):$( rigLoc task-rig-archive-ok.md )" 0:archived

echo "-- move-to-processed: a plain item still closes, and so does one whose condition was cleared --"
printf -- '---\ntype: task\nowner: rig\n---\n\nrig item, plain\n' | rigOwnerBoardPut running task-rig-plain.md
rigOp "$rigTmp/m3" --move-to-processed --team-member magic-coordinator task-rig-plain.md --from-state:running
rigAssert "the move succeeds"                         "$( cat "$rigTmp/m3.rc" )" 0
rigAssert "the item is processed"                     "$( rigLoc task-rig-plain.md )" processed
printf -- '---\ntype: task\nowner: rig\n---\n\nrig item whose condition was cleared\n' | rigOwnerBoardPut running task-rig-cleared.md
rigOp "$rigTmp/m4" --move-to-processed --team-member magic-coordinator task-rig-cleared.md --from-state:running
rigAssert "with no condition, an item closes"          "$( cat "$rigTmp/m4.rc" ):$( rigLoc task-rig-cleared.md )" 0:processed

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CLOSE REFUSES WAITING ITEM CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "✅ CLOSE REFUSES WAITING ITEM CHECK PASSED: $rigPassCount assertion(s)"
