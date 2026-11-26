#!/usr/bin/env bash
## Behavioural check: priming AGENTS_BOARD_TYPE_TABLE_CACHE changes nothing the handler answers. The schedule primes it once a pass
## so 66 items do not re-parse the table; this proves the answers are identical to the unprimed path, item by item. Offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
parInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardItemHandler.include"
[ -f "$parInclude" ] || { echo "⛔ ERROR: the handler include is not at the origin: $parInclude" >&2 ; exit 1 ; }
parTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsBoardHandlerCacheParityCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$parTmp" 2> /dev/null || :' EXIT
printf -- '---\ntype: task\nowner: magic-devops\ndocument-contract: board-item.task\n---\n\n# Task: a fixture\n' > "$parTmp/task-fixture.md"
printf -- '---\ntype: dispatch\nowner: magic-devops\ndocument-contract: board-item.dispatch\n---\n\n# Dispatch: a fixture\n' > "$parTmp/dispatch-fixture.md"
parOut="$( MMDAPP="$parTmp" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
	. "'"$parInclude"'" 2> /dev/null
	unset AGENTS_BOARD_TYPE_TABLE_CACHE
	for f in "'"$parTmp"'"/task-fixture.md "'"$parTmp"'"/dispatch-fixture.md ; do
		plain="$( AgentsToolsBoardItemHandler "$f" 2> /dev/null )"
		AGENTS_BOARD_TYPE_TABLE_CACHE="$( unset AGENTS_BOARD_TYPE_TABLE_CACHE ; AgentsToolsBoardTypeTable 2> /dev/null )"
		export AGENTS_BOARD_TYPE_TABLE_CACHE
		primed="$( AgentsToolsBoardItemHandler "$f" 2> /dev/null )"
		[ "$plain" = "$primed" ] && printf "same %s\n" "${f##*/}" || printf "DIFF %s\n" "${f##*/}"
	done
' 2> /dev/null )"
parPasses=0 parFails=0
parAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; parPasses=$(( parPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; parFails=$(( parFails + 1 )) ; fi
}
parAssert "the task's handler answer is the same with the table primed" "$( printf '%s\n' "$parOut" | LC_ALL=C grep -c 'same task-fixture.md' )" "1"
parAssert "the dispatch's handler answer is the same with the table primed" "$( printf '%s\n' "$parOut" | LC_ALL=C grep -c 'same dispatch-fixture.md' )" "1"
parAssert "nothing differed" "$( printf '%s\n' "$parOut" | LC_ALL=C grep -c 'DIFF' )" "0"
if [ "$parFails" -ne 0 ] ; then
	echo "⛔ BOARD HANDLER CACHE PARITY CHECK FAILED: $parFails of $(( parPasses + parFails )) assertion(s)" >&2 ; exit 1
fi
echo "BOARD_HANDLER_CACHE_PARITY: OK ($parPasses assertions, offline)"
