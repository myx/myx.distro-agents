#!/usr/bin/env bash
## Behavioural check: the live block text of the session lists (AgentsToolsSessionLiveBlockText in AgentsTools.SessionStores.include)
## starts no process for a block. The list of the active sessions took ten seconds for thirty-five blocks, since each block cost six forks.
## Held:
##   1. THE TEXT IS RIGHT: the id line of each block with its word and pid, then its rows, for a block whose session state agrees.
##   2. NO PROCESS A BLOCK: the processes the builder starts for three blocks and for twelve are the same number.
##   3. A STALE BLOCK IS REBUILT: a block whose seq differs from its session state is written again, and its new rows are read.
## Red before the fix: row 2 counts six more starts for each further block.
## Offline: a folder of this rig's own stands for the workspace. No real session is read.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/session/AgentsTools.SessionStores.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the session stores include is not at $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionLiveBlockForkCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
	return 0
}

## Each tool of the rig's own PATH writes one line to the log and runs the real one, so every process the builder starts is counted.
rigBin="$rigTmp/bin"
rigLog="$rigTmp/starts.log"
mkdir -p "$rigBin" || exit 1
for rigTool in awk sed cat grep cut tr head sort mktemp date printf dirname basename readlink sleep ; do
	rigReal="$( command -v "$rigTool" 2> /dev/null )" || continue
	case "$rigReal" in /*) ;; *) continue ;; esac
	printf '#!/bin/sh\necho %s >> "%s"\nexec %s "$@"\n' "$rigTool" "$rigLog" "$rigReal" > "$rigBin/$rigTool"
	chmod +x "$rigBin/$rigTool"
done

## A workspace with a number of live blocks, each with a session state of the same seq, and one owner that is gone.
rigMake(){ ## workspace folder, count
	local rigWs="$1" rigCount="$2" rigIndex=0 rigId
	mkdir -p "$rigWs/.local/agents/live" || exit 1
	while [ "$rigIndex" -lt "$rigCount" ] ; do
		rigIndex=$(( rigIndex + 1 ))
		rigId="rig-session-$rigIndex"
		mkdir -p "$rigWs/.local/agents/sessions/$rigId/control" || exit 1
		printf 'seq: 7\n' > "$rigWs/.local/agents/sessions/$rigId/control/state"
		printf 'seq: 7\nowner: 999999 Mon_Jan_1_00:00:00_2001\nrow-one-of-%s\nrow-two-of-%s\n' "$rigId" "$rigId" > "$rigWs/.local/agents/live/$rigId.rows"
	done
}
rigBuild(){ ## workspace folder
	: > "$rigLog"
	env -i PATH="$rigBin:/usr/bin:/bin" HOME="$rigTmp" MMDAPP="$1" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_INCLUDE="$rigInclude" \
		bash -c '. "$RIG_INCLUDE" && AgentsToolsSessionLiveBlockText'
}
rigStarts(){ ## processes counted in the log, those of the process list excluded
	LC_ALL=C grep -c -v '^ps$' "$rigLog" 2> /dev/null || :
}

echo "-- 1. the text of three blocks --"
rigMake "$rigTmp/ws3" 3
rigText="$( rigBuild "$rigTmp/ws3" )"
rigStartsThree="$( rigStarts )"
rigAssert "each block: its id with its word and pid, then its rows" "$( printf '%s\n' "$rigText" | LC_ALL=C grep -c -E '^rig-session-[0-9]+	gone	999999$' ):$( printf '%s\n' "$rigText" | LC_ALL=C grep -c '^row-' )" "3:6"

echo "-- 2. no process a block --"
rigMake "$rigTmp/ws12" 12
rigText="$( rigBuild "$rigTmp/ws12" )"
rigAssert "twelve blocks start as many processes as three" "$( rigStarts )" "$rigStartsThree"
rigAssert "and twelve blocks are all in the text" "$( printf '%s\n' "$rigText" | LC_ALL=C grep -c '^row-one' )" "12"

echo "-- 3. a stale block is rebuilt --"
printf 'seq: 3\nowner: 999999 Mon_Jan_1_00:00:00_2001\nrow-one-of-stale\n' > "$rigTmp/ws3/.local/agents/live/rig-session-1.rows"
rigText="$( rigBuild "$rigTmp/ws3" )"
rigAssert "the stale block's own rows are not taken as fact" "$( printf '%s\n' "$rigText" | LC_ALL=C grep -c 'row-one-of-stale' )" "0"

printf '%s: %s passed, %s failed\n' "${0##*/}" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
