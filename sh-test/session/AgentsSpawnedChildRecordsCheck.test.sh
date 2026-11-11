#!/usr/bin/env bash
## AgentsSpawnedChildRecordsCheck -- the records of the runs a spawn started, as the gate and the
## close read them (AgentsToolsSpawnedChildRecords, AgentsTools.StartedRecords.include).
## Guards: with the lists marked complete (children/.indexed) the parent's list answers and no
## record is grepped; a listed record that is gone, an empty line and a line that leaves spawned/
## are skipped; a parent with no list gets nothing; with no mark, one grep over the records answers
## the same; a parent name that is empty, `-` or carries a slash gets nothing.
## Red: the grep branch taken under a mark fails `no record is read`; a stale list line printed fails `a gone record is skipped`.
## Offline: a temp store of this check alone, removed at its end; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTmp="$( mktemp -d "${MMDAPP:-${TMPDIR:-/tmp}}/.local/agents/scratch/sh-test/AgentsSpawnedChildRecordsCheck.XXXXXXXX" 2> /dev/null || mktemp -d "${TMPDIR:-/tmp}/AgentsSpawnedChildRecordsCheck.XXXXXXXX" )" || exit 1
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
rigAsk(){ ## parent, then the extra arguments -- the paths printed, newline-joined, relative to the store
	( MMDAPP="$rigWs" ; export MMDAPP ; . "$rigLib/session/AgentsTools.StartedRecords.include" ; AgentsToolsSpawnedChildRecords "$@" ) 2> /dev/null | LC_ALL=C sed "s|^$rigWs/.local/agents/spawned/||" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
rigRecord p-folder rig-parent none
rigRecord a-folder rig-a rig-parent
rigRecord b-folder rig-b rig-parent
rigRecord o-folder rig-o rig-other

echo "-- 1. no mark: one grep over the records answers --"
rigAssert "the two children of the parent, and no other"       "$( rigAsk rig-parent | LC_ALL=C tr ' ' '\n' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "a-folder/rig-a.spawn.md b-folder/rig-b.spawn.md"
rigAssert "a parent with no children gets nothing"             "$( rigAsk rig-a )" ""
rigAssert "the workspace argument is honoured"                 "$( ( . "$rigLib/session/AgentsTools.StartedRecords.include" ; AgentsToolsSpawnedChildRecords rig-other "$rigWs" ) 2> /dev/null | LC_ALL=C sed "s|^$rigWs/.local/agents/spawned/||" )" "o-folder/rig-o.spawn.md"

echo "-- 2. the lists marked complete: the parent's list answers, and no record is read --"
mkdir -p "$rigWs/.local/agents/children"
printf 'a-folder/rig-a.spawn.md\n\nz-folder/rig-z.spawn.md\n../elsewhere/x.spawn.md\n/etc/passwd\n' > "$rigWs/.local/agents/children/rig-parent"
: > "$rigWs/.local/agents/children/.indexed"
rigAssert "the listed record that stands is printed"           "$( rigAsk rig-parent )" "a-folder/rig-a.spawn.md"
rigAssert "a child the list does not name is not found: the list is the answer under the mark" "$( rigAsk rig-parent | LC_ALL=C grep -c rig-b )" "0"
rigAssert "a parent with no list gets nothing"                 "$( rigAsk rig-other )" ""
chmod 000 "$rigWs/.local/agents/spawned/b-folder/rig-b.spawn.md"
rigAssert "no record is read: the one the list does not name may be unreadable" "$( rigAsk rig-parent )" "a-folder/rig-a.spawn.md"
chmod 644 "$rigWs/.local/agents/spawned/b-folder/rig-b.spawn.md"

echo "-- 3. a parent name that names nothing --"
rigAssert "empty, dash and a slash get nothing"                "$( rigAsk "" )|$( rigAsk - )|$( rigAsk "x/y" )|$( rigAsk .. )" "|||"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SPAWNED CHILD RECORDS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  warn: the gate's run seats and the close of a parent's children read the wrong runs" >&2
	echo "  fix:  AgentsToolsSpawnedChildRecords in sh-lib/session/AgentsTools.StartedRecords.include" >&2
	exit 1
fi
echo "SPAWNED_CHILD_RECORDS: OK ($rigPass assertions, offline)"
