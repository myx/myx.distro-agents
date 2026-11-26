#!/usr/bin/env bash
## Behavioural check on the tokens rollup's kept index (`AgentsSessionTokensRollupRows`,
## sh-lib/session/AgentsTools.SessionTranscript.include): the rows are summed once into an index and answered from it
## while no board item and no run record is newer, so the coordinator's team read stops paying the walk every call
## (`--spawns` measured 9 to 10 s for five to eighteen lines on 2026-11-26 07:15). Held:
##   1. the first call answers the sum: an item's own `tokens:` plus the item that tracks it
##   2. the index is written under the workspace's own `.local/agents`
##   3. CONTROL, NO WALK: with the item's text changed and its own date kept as it was, the answer stands as indexed --
##      a read that re-walked the item would answer the changed figure
##   4. an item written since the index is read: the answer moves with the store
## Offline: a workspace and a team-data store of this check's own under its temp tree; no socket is opened.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionTranscript.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: the rollup is not at the origin: $rigInclude" >&2 ; exit 1 ; }

rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsTokensRollupIndexCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/agents/spawned/rig-run-1" "$rigWs/.local/agents/sessions" "$rigData/board/running" || exit 1

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigTokens(){ ## item -- its in and out fields from the rollup's row
	HOME="$rigTmp/home" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash -c '. "$1" 2> /dev/null ; AgentsSessionTokensRollupRows "$2"' _ "$rigInclude" "$1" 2> /dev/null \
		| LC_ALL=C awk -F'\t' 'NF >= 5 { print $2 "/" $5 ; exit ; }'
}

## The parent and the item that tracks it, with the tokens headers the rollup sums.
printf -- '---\ntype: task\nspawn-id: rig-run-1\ntokens: in=100 cache-read=200 cache-write=5 out=50\n---\n\n# the parent\n' \
	> "$rigData/board/running/rig-parent.md"
printf -- '---\ntype: task\ntracks: rig-parent\ntokens: in=7 cache-read=9 cache-write=1 out=3\n---\n\n# the child\n' \
	> "$rigData/board/running/rig-child.md"
printf -- '---\nspawn-id: rig-run-1\nsession-id: rig-run-1\nowner: rig-owner\nstatus: spawn-succeeded\n---\n\n# the run\n' \
	> "$rigWs/.local/agents/spawned/rig-run-1/rig-run-1.spawn.md"
## An index that is newer than every input it sums.
: > "$rigData/board/running/.stamp"

rigAssert "the first call answers the sum: the parent's own tokens and the item that tracks it" "$( rigTokens rig-parent )" "107/53"
rigAssert "the index is written under the workspace's own .local/agents" "$( [ -f "$rigWs/.local/agents/tokens-rollup.rows" ] && printf written || printf absent )" "written"

## CONTROL, NO WALK: the parent's text changes, its own date does not, so nothing is newer than the index.
rigStamp="$( date -r "$rigData/board/running/rig-parent.md" '+%Y%m%d%H%M.%S' 2> /dev/null )" || rigStamp=""
printf -- '---\ntype: task\nspawn-id: rig-run-1\ntokens: in=999999 cache-read=0 cache-write=0 out=999999\n---\n\n# the parent, changed\n' \
	> "$rigData/board/running/rig-parent.md"
[ -z "$rigStamp" ] || touch -t "$rigStamp" "$rigData/board/running/rig-parent.md"
rigAssert "no walk: the answer stands as indexed while nothing is newer" "$( rigTokens rig-parent )" "107/53"

## The store moves: a written item is read, and the answer follows it.
printf -- '---\ntype: task\ntracks: rig-parent\ntokens: in=1000 cache-read=0 cache-write=0 out=500\n---\n\n# another child, written now\n' \
	> "$rigData/board/running/rig-child-two.md"
sleep 1
## The parent now reads 999999/999999 (changed in the control above), its own child 7/3, and the new one 1000/500.
rigAssert "an item written since the index is read: the answer moves with the store" "$( rigTokens rig-parent )" "1001006/1000502"

echo
if [ "$rigFail" = "0" ] ; then
	printf 'TOKENS_ROLLUP_INDEX: OK (%s assertions, offline)\n' "$rigPass"
	exit 0
fi
printf '⛔ TOKENS ROLLUP INDEX CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))"
exit 1
