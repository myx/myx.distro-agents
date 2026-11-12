#!/usr/bin/env bash
## AgentsScheduleChildrenKeepCheck -- the schedule pass keeps the children lists on a rig with no main loop
## (AgentsToolsScheduleThreadChildrenKeep, AgentsTools.ScheduleThread.include; epic S12.12).
## Guards: with no mark the pass repairs the lists and writes children/.indexed; a parent's list then names its
## children; a second call within the bound rewrites nothing; a mark older than the bound is repaired again and a
## child made since is listed; with the bound at 0 nothing is written.
## Red: a keep that never repairs fails `the mark is written`; one that repairs at every call fails `nothing is rewritten`.
## Offline: a temp store of this check alone, removed at its end; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTmp="$( mktemp -d "${MMDAPP:-${TMPDIR:-/tmp}}/.local/agents/scratch/sh-test/AgentsScheduleChildrenKeepCheck.XXXXXXXX" 2> /dev/null || mktemp -d "${TMPDIR:-/tmp}/AgentsScheduleChildrenKeepCheck.XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigRecord(){ ## folder, spawn id, parent spawn id
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: %s\nowner: magic-tester\nstatus: spawn-started\n---\n\n# Spawn session\n' "$2" "$2" "$3" > "$rigWs/.local/agents/spawned/$1/$2.spawn.md"
}
rigKeep(){ ## the bound in seconds
	( MMDAPP="$rigWs" MDAT_SCHEDULE_CHILDREN_REPAIR_SECONDS="$1" ; export MMDAPP MDAT_SCHEDULE_CHILDREN_REPAIR_SECONDS ; . "$rigLib/session/AgentsTools.ScheduleThread.include" ; AgentsToolsScheduleThreadChildrenKeep ) 2> /dev/null
}
rigMark="$rigWs/.local/agents/children/.indexed"
rigRecord p-folder rig-parent none
rigRecord a-folder rig-a rig-parent

echo "-- 1. with no mark, the pass repairs the lists --"
rigKeep 3600
rigAssert "the mark is written"                                "$( [ -f "$rigMark" ] && printf yes || printf no )" yes
rigAssert "the parent's list names its child"                  "$( cat "$rigWs/.local/agents/children/rig-parent" 2> /dev/null )" "a-folder/rig-a.spawn.md"

echo "-- 2. within the bound, nothing is rewritten --"
rigRecord b-folder rig-b rig-parent
rigKeep 3600
rigAssert "nothing is rewritten: the child made since is not listed yet" "$( cat "$rigWs/.local/agents/children/rig-parent" 2> /dev/null | LC_ALL=C grep -c rig-b )" 0

echo "-- 3. a mark older than the bound is repaired again --"
touch -t 202001010000 "$rigMark"
rigKeep 3600
rigAssert "the child made since is listed"                     "$( cat "$rigWs/.local/agents/children/rig-parent" 2> /dev/null | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "a-folder/rig-a.spawn.md b-folder/rig-b.spawn.md"
rigAssert "and the mark is fresh"                              "$( [ -z "$( find "$rigMark" -mmin +1 )" ] && printf yes || printf no )" yes

echo "-- 4. the bound at 0: never --"
rm -rf "$rigWs/.local/agents/children"
rigKeep 0
rigAssert "nothing is written"                                 "$( [ -e "$rigWs/.local/agents/children" ] && printf yes || printf no )" no

echo "-- 5. the default bound stands at 300 s, not 3600 --"
## A mark 900 s old separates the two: past 300, well short of 3600. Both platforms' `date` are tried, and the arm skips where neither answers.
rigAgo="$( date -r "$(( $( date +%s ) - 900 ))" '+%Y%m%d%H%M' 2> /dev/null || date -d "@$(( $( date +%s ) - 900 ))" '+%Y%m%d%H%M' 2> /dev/null )" || rigAgo=""
if [ -n "$rigAgo" ] ; then
	rigKeepDefault(){ ( MMDAPP="$rigWs" ; export MMDAPP ; unset MDAT_SCHEDULE_CHILDREN_REPAIR_SECONDS ; . "$rigLib/session/AgentsTools.ScheduleThread.include" ; AgentsToolsScheduleThreadChildrenKeep ) 2> /dev/null ; }
	rm -rf "$rigWs/.local/agents/children"
	rigKeepDefault
	rigAssert "with no mark the default repairs the lists"          "$( [ -f "$rigMark" ] && printf yes || printf no )" yes
	touch -t "$rigAgo" "$rigMark"
	rigRecord c-folder rig-c rig-parent
	rigKeepDefault
	rigAssert "a mark 900 s old is past the default, so its child is listed" "$( LC_ALL=C grep -c rig-c "$rigWs/.local/agents/children/rig-parent" 2> /dev/null )" 1
	rigAssert "and the mark is fresh again"                          "$( [ -z "$( find "$rigMark" -mmin +1 )" ] && printf yes || printf no )" yes
else
	echo "  SKIP  no portable date could name 900 seconds ago"
fi

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SCHEDULE CHILDREN KEEP CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  warn: a rig with no main loop keeps no children lists, and every reader of a parent's children reads every record" >&2
	echo "  fix:  AgentsToolsScheduleThreadChildrenKeep in sh-lib/session/AgentsTools.ScheduleThread.include" >&2
	exit 1
fi
echo "SCHEDULE_CHILDREN_KEEP: OK ($rigPass assertions, offline)"
