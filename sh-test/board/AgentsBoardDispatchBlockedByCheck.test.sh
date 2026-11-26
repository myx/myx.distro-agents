#!/usr/bin/env bash
## Behavioural check on the start guard (AgentsToolsBoardBlockedByBlocker): a board item whose `blocked-by:` names an item standing in
## board-blocked answers with that blocker's bare name, so a dispatch refuses to start; a clear blocker, or none, answers nothing.
## Offline: a board of its own is built here, one blocked item, and nothing of a real workspace is read.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
blkInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardDependencies.include"
[ -f "$blkInclude" ] || { echo "⛔ ERROR: the dependencies include is not at the origin: $blkInclude" >&2 ; exit 1 ; }
blkTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsBoardDispatchBlockedByCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$blkTmp" 2> /dev/null || :' EXIT
mkdir -p "$blkTmp/board/blocked"
printf -- '---\ntype: task\nowner: magic-devops\n---\n' > "$blkTmp/board/blocked/task-alpha.md"
blkPasses=0 blkFails=0
blkAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; blkPasses=$(( blkPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; blkFails=$(( blkFails + 1 )) ; fi
}
blkAnswer(){ ## the item's text -> the blocker, or `clear` where none is answered
	MDAT_DATA_ROOT="$blkTmp" bash -c '. "'"$blkInclude"'" ; AgentsToolsBoardBlockedByBlocker "$1"' _ "$1" 2> /dev/null || printf 'clear\n'
}
blkAssert "a blocked-by naming a blocked item answers with it" "$( blkAnswer '---
blocked-by: task-alpha
---
' )" "task-alpha"
blkAssert "a blocked-by naming an item that is not blocked answers nothing" "$( blkAnswer '---
blocked-by: task-beta
---
' )" "clear"
blkAssert "an item with no blocked-by answers nothing" "$( blkAnswer '---
type: task
---
' )" "clear"
blkAssert "of two blockers, the one standing in board-blocked is the one named" "$( blkAnswer '---
blocked-by: task-beta, task-alpha
---
' )" "task-alpha"
if [ "$blkFails" -ne 0 ] ; then
	echo "⛔ BOARD DISPATCH BLOCKED-BY CHECK FAILED: $blkFails of $(( blkPasses + blkFails )) assertion(s)" >&2 ; exit 1
fi
echo "BOARD_DISPATCH_BLOCKED_BY: OK ($blkPasses assertions, offline)"
