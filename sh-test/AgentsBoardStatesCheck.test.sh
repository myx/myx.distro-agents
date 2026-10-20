#!/usr/bin/env bash
## Behavioural check on the board's state folders: every operation that writes the board
## makes it ready first, by the one function of AgentsTools.BoardStates.include, so no write
## fails because a state folder is not there; a read takes a missing folder as an empty
## state and makes nothing; a state added to the one list has its folder with no further
## code; the step that sets a workspace up makes them all. Temp stores only, in a temp
## workspace, and every op goes through one `env -i` whose child refuses to run outside it.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigHere/board/AgentsTools.BoardStates.include" ] || rigRefuse "the one list is not there: $rigHere/board/AgentsTools.BoardStates.include"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBoardStatesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigDir="" ; rigStore=""
rigScenario(){ ## name
	rigDir="$rigTmp/$1" ; rigStore="$rigDir/store"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/home/skills/magic-tester" "$rigDir/home/skills/magic-coordinator"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/home/skills/magic-tester/magic-tester.basic.md"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/home/skills/magic-coordinator/magic-coordinator.basic.md"
}
## One op, guarded; stdin is the caller's. The store is $rigStore unless RIG_NO_ROOT is set.
rigOp(){ ## result file, op and its arguments...
	local rigResult="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="/usr/bin:/bin" MMDAPP="$rigDir/ws" ${RIG_NO_ROOT:-MDAT_DATA_ROOT="$rigStore"} MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigDir/home/skills" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "${MDAT_DATA_ROOT:-$RIG_TMP/}" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigResult" 2> "$rigResult.err"
	printf '%s' "$?" > "$rigResult.rc"
}
rigStates(){ ## store: the state folders it has, in the order of the one list
	( . "$rigHere/board/AgentsTools.BoardStates.include" ; for s in $agentsBoardStates ; do [ ! -d "$1/board/$s" ] || printf '%s ' "$s" ; done )
}
rigAll="$( . "$rigHere/board/AgentsTools.BoardStates.include" ; printf '%s ' $agentsBoardStates )"
rigItem="note-20261014T0101Z-rig.md"

echo "-- the one list --"
rigAssert "the list names the nine states" "$rigAll" "backlog pending running review blocked parked processed archived retained "

echo "-- a create with no board at all --"
rigScenario create
printf -- '---\ntype: note\n---\nrig body\n' | rigOp "$rigDir/c" --intern-op-board-upsert-move-edit running "$rigItem" --create --upsert-from-stdin --context rig
rigAssert "the create succeeds"                              "$( cat "$rigDir/c.rc" )" 0
rigAssert "and the item is in its state"                     "$( [ -f "$rigStore/board/running/$rigItem" ] && printf yes || printf no )" yes
rigAssert "every state of the one list has its folder now"   "$( rigStates "$rigStore" )" "$rigAll"

echo "-- a move into a state whose folder is gone --"
rm -rf "$rigStore/board/review" "$rigStore/board/processed" "$rigStore/board/backlog"
rigOp "$rigDir/m" --intern-op-board-upsert-move-edit review "$rigItem" --from-state:running --context rig
rigAssert "the move succeeds"                                "$( cat "$rigDir/m.rc" )" 0
rigAssert "the item is in the new state and left the old"    "$( [ -f "$rigStore/board/review/$rigItem" ] && [ ! -e "$rigStore/board/running/$rigItem" ] && printf yes || printf no )" yes
rigAssert "the folders that were gone are back"              "$( rigStates "$rigStore" )" "$rigAll"

echo "-- an edit in place with every other folder gone --"
for rigState in $rigAll ; do [ "$rigState" = review ] || rm -rf "$rigStore/board/$rigState" ; done
rigOp "$rigDir/e" --intern-op-board-upsert-move-edit review "$rigItem" --from-state:review --header:upsert:rig-mark:yes --context rig
rigAssert "the edit succeeds"                                "$( cat "$rigDir/e.rc" ):$( LC_ALL=C grep -c '^rig-mark: yes$' "$rigStore/board/review/$rigItem" 2> /dev/null )" "0:1"

echo "-- an untrash into a state whose folder is gone --"
mkdir -p "$rigStore/trash" && printf -- '---\ntype: note\n---\nwas trashed\n' > "$rigStore/trash/note-20261014T0102Z-trashed.md"
rm -rf "$rigStore/board/parked"
rigOp "$rigDir/u" --intern-op-board-trash magic-coordinator parked note-20261014T0102Z-trashed.md --untrash
rigAssert "the item is back on the board"                    "$( cat "$rigDir/u.rc" ):$( [ -f "$rigStore/board/parked/note-20261014T0102Z-trashed.md" ] && printf yes || printf no )" "0:yes"
rigAssert "with every state folder made"                     "$( rigStates "$rigStore" )" "$rigAll"

echo "-- every state of the one list is taken, as a target and as a source --"
rigTaken=""
for rigState in $rigAll ; do
	printf -- '---\ntype: note\n---\nrig body\n' | rigOp "$rigDir/t" --intern-op-board-upsert-move-edit "$rigState" "note-20261014T0104Z-$rigState.md" --create --upsert-from-stdin --context rig
	rigOp "$rigDir/t2" --intern-op-board-upsert-move-edit "$rigState" "note-20261014T0104Z-$rigState.md" --from-state:"$rigState" --header:upsert:rig-mark:yes --context rig
	rigTaken="$rigTaken$( cat "$rigDir/t.rc" "$rigDir/t2.rc" )$( [ -f "$rigStore/board/$rigState/note-20261014T0104Z-$rigState.md" ] && printf y || printf n ) "
done
rigAssert "each of the nine, first and last of the list too"  "$rigTaken" "00y 00y 00y 00y 00y 00y 00y 00y 00y "

echo "-- a state that is not of the one list is refused, and a name that only looks like one --"
rigOp "$rigDir/x1" --intern-op-board-upsert-move-edit rig-no-state "$rigItem" --from-state:review --context rig
rigOp "$rigDir/x2" --intern-op-board-upsert-move-edit "review parked" "$rigItem" --from-state:review --context rig
rigOp "$rigDir/x3" --intern-op-board-upsert-move-edit parked "$rigItem" --from-state:"review parked" --context rig
rigAssert "each is refused by name, and nothing is made"     "$( cat "$rigDir/x1.rc" "$rigDir/x2.rc" "$rigDir/x3.rc" ) $( LC_ALL=C grep -c -e 'invalid to-state: rig-no-state' -e 'invalid to-state: review parked' -e 'invalid state: review parked' "$rigDir/x1.err" "$rigDir/x2.err" "$rigDir/x3.err" | LC_ALL=C awk -F: '{ n += $NF } END { print n + 0 }' ) $( [ -e "$rigStore/board/rig-no-state" ] && printf made || printf none )" "111 3 none"

echo "-- a read with no board makes nothing --"
rigScenario read
mkdir -p "$rigStore"
rigOp "$rigDir/s" --intern-op-session-context-scan magic-coordinator --all-types --context rig
rigAssert "a scan of every state ends well"                  "$( cat "$rigDir/s.rc" )" 0
rigAssert "and says no fault of a folder"                    "$( LC_ALL=C grep -c -i -e 'no such file' -e 'no such board state' "$rigDir/s" "$rigDir/s.err" | LC_ALL=C awk -F: '{ n += $NF } END { print n + 0 }' )" 0
rigOp "$rigDir/d" --manager-dashboard-read team-data
rigAssert "the dashboard's team data block ends well"        "$( cat "$rigDir/d.rc" )" 0
rigAssert "with no board figure, for there is no item"       "$( LC_ALL=C grep -c 'board-' "$rigDir/d" || : )" 0
rigOp "$rigDir/r" --magic-state-note-lock-status magic-coordinator
rigAssert "a read of an item of the board that is not there names no folder fault" "$( LC_ALL=C grep -c -i -e 'no such file' -e 'no such board state' "$rigDir/r" "$rigDir/r.err" | LC_ALL=C awk -F: '{ n += $NF } END { print n + 0 }' )" 0
rigAssert "none of the reads made a board"                   "$( [ -e "$rigStore/board" ] && printf made || printf none )" none

echo "-- a state added to the one list has its folder with no further code --"
rigScenario added
(
	. "$rigHere/board/AgentsTools.BoardStates.include"
	agentsBoardStates="$agentsBoardStates rig-new-state"
	MDAT_DATA_ROOT="$rigStore" AgentsToolsBoardReady
)
rigAssert "the new state's folder is made beside the nine"   "$( [ -d "$rigStore/board/rig-new-state" ] && printf yes || printf no ) $( rigStates "$rigStore" )" "yes $rigAll"
rigAssert "and the function makes folders only, no file"     "$( find "$rigStore" -type f | wc -l | LC_ALL=C tr -d ' ' )" 0

echo "-- the step that sets a workspace up makes the board ready --"
rigScenario setup
RIG_NO_ROOT=RIG_UNSET=1 rigOp "$rigDir/a" --owner-setup-storage --workspace-root "$rigDir/ws" --apply
rigAssert "the store of the workspace has every state folder" "$( rigStates "$rigDir/ws/.local/agents/team-data-root" )" "$rigAll"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD STATES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BOARD_STATES: OK (%d assertions, offline, temp stores only)\n' "$rigPassCount"
