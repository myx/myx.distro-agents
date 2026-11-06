#!/usr/bin/env bash
## Behavioural check on the duty scan's board scope (S12.17, board task 20261106T0933Z; `--do-board-related-startable` in
## AgentsTools.InternOpSessionContextScan.include). A duty is handed the items it can act on: the ones it owns in pending and running.
## The fault it guards: on 2026-11-06 magic-developer's duty scan listed every item it owned in six states, 1279 lines, in every scan
## and into every prompt. Held, run rather than read:
##   1. THE STARTABLE SET IS PENDING AND RUNNING, of the member's own items.
##   2. IT LEAVES OUT the backlog, review, blocked and parked items the member owns.
##   3. IT LEAVES OUT another member's pending item.
##   4. AND A --state VALUE THAT CONTRADICTS THE SET IS AN ERROR, so two scopes never meet silently.
##   5. THE WIDER SET IS STILL REACHABLE, so the narrowing took nothing away from the callers that want it.
## The board is this rig's own tree of items; no board operation, session or network is reached.
## RED RECIPE, measured on a copy under this check's own scratch on 2026-11-06: change the startable line's `pending running` to the
## six-state set at :311-313 and rows 1 to 3 fail.
## Offline: the scan this check loads, and a rig of its own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/session/AgentsTools.InternOpSessionContextScan.include"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the session-context scan is not at $rigInclude"
[ -f "$rigTool" ] || rigRefuse "the tool is not at $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyScanStartableCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigData/inboxes/rig-keeper/incoming" || exit 1
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nMDAT_WORKSPACE_MODE=team-rig\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
## ONE BOARD ITEM, in the shape the board stores: frontmatter naming its type and owner, then a body line that identifies it.
rigItem(){ ## the state, the filename, the owner, and the one word its body carries
	local itemState="$1" itemName="$2" itemOwner="$3" itemWord="$4"
	mkdir -p "$rigData/board/$itemState" || exit 1
	printf -- '---\ntype: task\nfrom: magic-coordinator\nowner: %s\ndate: 2026-11-06 10:00 +0200\n---\n\n# %s\n\n%s\n' \
		"$itemOwner" "$itemWord" "$itemWord" > "$rigData/board/$itemState/$itemName"
}
rigItem pending task-rig-pending.md mine pending-item
rigItem running task-rig-running.md mine running-item
rigItem backlog task-rig-backlog.md mine backlog-item
rigItem review task-rig-review.md mine review-item
rigItem blocked task-rig-blocked.md mine blocked-item
rigItem parked task-rig-parked.md mine parked-item
rigItem pending task-rig-other.md otherv other-pending
## THE SCAN, in an environment of the rig's own and with the board selector under test. The origin is the package under test's own, because
## the scan loads its readers through it: a copy checked against the live tree would read green whatever the copy held.
case "$rigPackage" in
	*/myx/myx.distro-agents) rigOrigin="${rigPackage%/myx/myx.distro-agents}" ;;
	*) rigRefuse "the package under test is not at <origin>/myx/myx.distro-agents: $rigPackage" ;;
esac
[ -d "$rigOrigin/myx/myx.distro-agents/sh-lib" ] || rigRefuse "no package tree under $rigOrigin"
rigScan(){ ## the flags of the scan, after the member and the common ones
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDSC_CMD=DistroAgentsTools \
		bash "$rigTool" --intern-op-session-context-scan mine --all-types \
		--no-inbox-reflections --no-inbox-notes --no-inbox-other --no-slack --no-email --no-trello "$@" 2>&1
}

echo "-- 1 to 3. the startable set is this member's pending and running items --"
rigOut="$( rigScan --do-board-related-startable )"
rigAssert "the pending item of this member stands in the scan" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'task-rig-pending.md' )" 1
rigAssert "and its running one too" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'task-rig-running.md' )" 1
rigAssert "the backlog item is left out" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'task-rig-backlog.md' )" 0
rigAssert "the review item is left out" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'task-rig-review.md' )" 0
rigAssert "the blocked item is left out" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'task-rig-blocked.md' )" 0
rigAssert "the parked item is left out" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'task-rig-parked.md' )" 0
rigAssert "another member's pending item is left out" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'task-rig-other.md' )" 0

echo "-- 4. a --state that contradicts the set is an error --"
rigErr="$( rigScan --do-board-related-startable --state backlog )"
rigAssert "naming a state of its own answers an error, not an intersection" \
	"$( printf '%s\n' "$rigErr" | LC_ALL=C grep -c 'supplies its own state set' )" 1

echo "-- 5. the wider set is still reachable --"
rigWide="$( rigScan --do-board-related-active )"
rigAssert "the active set still carries the backlog item" "$( printf '%s\n' "$rigWide" | LC_ALL=C grep -c 'task-rig-backlog.md' )" 1
rigAssert "and the review and blocked items" "$( printf '%s\n' "$rigWide" | LC_ALL=C grep -c 'task-rig-review.md' )$( printf '%s\n' "$rigWide" | LC_ALL=C grep -c 'task-rig-blocked.md' )" '11'

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DUTY SCAN STARTABLE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'DUTY_SCAN_STARTABLE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
