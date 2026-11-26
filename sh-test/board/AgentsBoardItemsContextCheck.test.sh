#!/usr/bin/env bash
## Behavioural check on the board reader's empty-root guard (sh-lib/board/AgentsTools.ItemDecisions.include,
## AgentsToolsBoardItemsInto): a call that resolved no team data root, in a workspace that keeps a store, reads no item and
## must say so once. Held, run rather than read:
##   1. WITH NO DATA ROOT and a store on disk, the call warns and answers nothing.
##   2. WITH THE DATA ROOT resolved, the same call reads the item and says nothing.
## The backfill script (magic-developer's, 2026-11-25) read zero open items this way and printed success over nothing.
## RED RECIPE, measured on live 2026-11-25 17:3x +0200: before the guard, assertion 1 fails with no warning.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/board/AgentsTools.ItemDecisions.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: no $rigInclude" >&2 ; exit 1 ; }
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBoardItemsContextCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigStore="$rigWs/.local/agents/team-data-root"
mkdir -p "$rigStore/board/backlog" || exit 1
printf -- '---\ntype: task\nfrom: magic-coordinator\n---\n' > "$rigStore/board/backlog/task-rig-item.md" || exit 1
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
rigRead(){ ## the data root the call resolves, '' for none
	RIG_ROOT="$1" MMDAPP="$rigWs" bash -c '
		. "$1" || exit 1
		items=()
		AgentsToolsBoardItemsInto items "" backlog
		printf "items=%s\n" "${#items[@]}"
	' rig-read "$rigInclude" 2> "$rigTmp/err" > "$rigTmp/out"
	printf '%s' "$?"
}

echo "-- 1. no data root, a store on disk: warned, nothing read --"
export MDAT_DATA_ROOT=""
unset MDAT_DATA_ROOT
rigRead "" > /dev/null
rigAssert "the call answers no item" "$( LC_ALL=C grep -c '^items=0$' "$rigTmp/out" )" 1
rigAssert "and warns once that the root is not resolved" "$( LC_ALL=C grep -c 'no team data root is resolved' "$rigTmp/err" )" 1

echo "-- 2. the data root resolved: the item is read, nothing said --"
MDAT_DATA_ROOT="$rigStore" bash -c '
	. "$1" || exit 1
	items=()
	AgentsToolsBoardItemsInto items "" backlog
	printf "items=%s\n" "${#items[@]}"
' rig-read "$rigInclude" 2> "$rigTmp/err2" > "$rigTmp/out2"
rigAssert "the item is read" "$( LC_ALL=C grep -c '^items=1$' "$rigTmp/out2" )" 1
rigAssert "and nothing is said" "$( LC_ALL=C grep -c 'no team data root is resolved' "$rigTmp/err2" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD ITEMS CONTEXT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'BOARD_ITEMS_CONTEXT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
