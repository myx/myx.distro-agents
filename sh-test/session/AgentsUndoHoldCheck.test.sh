#!/usr/bin/env bash
## Behavioural check on the undo hold (S13.19 stage 1): the marker `undo.hold` in a spawn
## sandbox root. The sweep and the GC read it and leave the sandbox; the purge refuses while
## one is open; a sandbox with no marker is deleted by both, as before. Offline: no tree but
## this check's own rig.
set -u
: "${MDAT_WORKSPACE_MODE:=team-rig}" ; export MDAT_WORKSPACE_MODE
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigSweepLib="$rigPackage/sh-lib/session/AgentsTools.SpawnSandbox.include"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSweepLib" ] || rigRefuse "the sandbox include is missing from the package: $rigSweepLib"
[ -x "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsUndoHoldCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHost="$( hostname -s 2>/dev/null || echo unknown )"

## A fresh rig: fake workspace, data root and spawned root. The purge scenario needs its
## own, since it refuses while ANY hold of the workspace is open.
rigNew(){ ## name
	rigWs="$rigTmp/$1/ws"
	rigD="$rigTmp/$1/data"
	rigSp="$rigWs/.local/agents/spawned"
	mkdir -p "$rigD/inboxes/magic-coordinator/incoming" "$rigD/board/processed" "$rigWs/.local/agents/members/magic-coordinator" "$rigWs/.local/temp"
	printf '# magic-coordinator\n' > "$rigWs/.local/agents/members/magic-coordinator/SKILL.md"
}
rigNew main

## A dead sandbox folder of this rig, input/ filled, its record aged past the sweep's
## 10-minute launch window. The record is closed (spawn-succeeded), so both cleaners see
## it as removable once the hold is not there.
rigMake(){ ## name, held (yes|no)
	mkdir -p "$rigSp/$1/input"
	printf 'rig\n' > "$rigSp/$1/input/brief.md"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nstatus: spawn-succeeded\n---\n' "$1" "$1" "$rigHost" > "$rigSp/$1/$1.spawn.md"
	touch -t 202001010000 "$rigSp/$1/$1.spawn.md"
	[ "$2" != yes ] || : > "$rigSp/$1/undo.hold"
}
rigPresent(){ ## path -- present or gone
	[ -e "$1" ] || [ -L "$1" ] && printf present || printf gone
}
rigLeft(){ find "$rigSp/$1/input" -mindepth 1 | LC_ALL=C grep -c . || : ; }
rigSweep(){ ## result file -- the sweep against this rig, as a rig
	env -i MDAT_WORKSPACE_MODE=team-rig PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_LIB="$rigSweepLib" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			MDSC_CMD=rig ; . "$RIG_LIB" ; AgentsToolsSpawnSandboxSweep rig-sweep
		' > "$1" 2>&1
	printf '%s' "$?" > "$1.rc"
}
rigItem(){ ## session id, held (yes|no) -- an aged processed dispatch item naming that spawn
	printf -- '---\ntype: dispatch\nowner: rig-member\nspawn-id: %s\n---\n\nrig item\n' "$1" > "$rigD/board/processed/dispatch-$1.md"
	touch -t 202001010000 "$rigD/board/processed/dispatch-$1.md"
	rigMake "$1" "$2"
}
rigGc(){ ## result file
	( cd "$rigWs" && env -u MDAT_SKILLSET_ROOT HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigD" \
		bash "$rigTool" --intern-team-data-final-gc-deletion magic-coordinator ) > "$1" 2>&1
	printf '%s' "$?" > "$1.rc"
}
rigPurge(){ ## result file
	( cd "$rigWs" && env -u MDAT_SKILLSET_ROOT HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --owner-cleanup-purge ) > "$1" 2>&1
	printf '%s' "$?" > "$1.rc"
}

echo "-- the sweep --"
rigMake riguh-held yes
rigMake riguh-plain no
rigSweep "$rigTmp/sweep.out"
rigAssert "a held sandbox keeps its input"          "$( rigLeft riguh-held )" 1
rigAssert "a sandbox with no marker is emptied"    "$( rigLeft riguh-plain )" 0
rigAssert "the sweep said so"                      "$( LC_ALL=C grep -c 'emptied input/ of riguh-plain' "$rigTmp/sweep.out" || : )" 1
rigAssert "nothing is said of the held sandbox"    "$( LC_ALL=C grep -c 'emptied input/ of riguh-held' "$rigTmp/sweep.out" || : )" 0

echo "-- the GC --"
rigItem riguh-gc-held yes
rigItem riguh-gc-plain no
rigGc "$rigTmp/gc.out"
rigAssert "a held folder keeps the item and the folder" "$( [ -f "$rigD/board/processed/dispatch-riguh-gc-held.md" ] && printf kept || printf deleted ) $( rigPresent "$rigSp/riguh-gc-held" )" "kept present"
rigAssert "a folder with no marker is deleted with its item" "$( [ -f "$rigD/board/processed/dispatch-riguh-gc-plain.md" ] && printf kept || printf deleted ) $( rigPresent "$rigSp/riguh-gc-plain" )" "deleted gone"
rigAssert "the summary names one removed folder"      "$( LC_ALL=C grep -c -F ' 1 sandbox-folders removed.' "$rigTmp/gc.out" || : )" 1

echo "-- the purge --"
rigNew purge
mkdir -p "$rigWs/.local/.cleanup" && printf 'junk\n' > "$rigWs/.local/.cleanup/junk.txt"
rigMake riguh-purge-held yes
rigPurge "$rigTmp/purge1.out"
rigAssert "the purge refuses while a hold is open, and removes nothing" "$( cat "$rigTmp/purge1.out.rc" ):$( [ -f "$rigWs/.local/.cleanup/junk.txt" ] && printf kept || printf gone )" "1:kept"
rm -f "$rigSp/riguh-purge-held/undo.hold"
rigPurge "$rigTmp/purge2.out"
rigAssert "with no hold it purges"                  "$( cat "$rigTmp/purge2.out.rc" ):$( [ -f "$rigWs/.local/.cleanup/junk.txt" ] && printf kept || printf gone )" "0:gone"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ UNDO HOLD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'UNDO_HOLD: OK (%d assertions, offline)\n' "$rigPassCount"
