#!/usr/bin/env bash
## Behavioural check of the board writer's body-as-a-parameter mode: the caller hands the whole
## document over as one argument, so a session with no shell can create and move a board item and
## no stdin is needed. Covers the create through the internal op and through the public stub a
## work-duty calls, a move that carries a new body, the mutual exclusion against
## --upsert-from-stdin, and the stdin form still working. Temp stores only, in a temp workspace,
## and every op goes through one `env -i` whose child refuses to run outside it.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigItemsFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigItemsFn" ] || rigRefuse "items dispatcher not found: $rigItemsFn"
[ -f "$rigHere/board/AgentsTools.InternOpBoardUpsertMoveEdit.include" ] || rigRefuse "the board writer is not there"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBoardBodyParameterCheck )" || exit 1
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
	mkdir -p "$rigDir/ws/.local" "$rigDir/home/skills/magic-coordinator"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/home/skills/magic-coordinator/magic-coordinator.basic.md"
}
## One op, guarded. stdin is the caller's: a case that must run with none closes it, `< /dev/null`.
rigOp(){ ## result file, op and its arguments...
	local rigResult="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="/usr/bin:/bin" MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigDir/home/skills" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="${RIG_ENTRY:-$rigFn}" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "${MDAT_DATA_ROOT:-$RIG_TMP/}" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigResult" 2> "$rigResult.err"
	printf '%s' "$?" > "$rigResult.rc"
}
## The document this check hands over, as one argument.
rigDoc(){
	printf -- '%s\n' \
		'---' \
		'type: task' \
		'document-contract: board-item.task' \
		'from: keeper-myx' \
		'owner: magic-coordinator' \
		'date: 2026-11-01 19:50 +0200' \
		'---' \
		'' \
		'# Task: Rig the body parameter' \
		'' \
		'The widget keeps its last line.'
}

echo "-- the stdin form still works --"
rigScenario stdin
rigDoc | rigOp "$rigDir/c" --intern-op-board-upsert-move-edit running task-20261101T1950Z-rig.md --create --upsert-from-stdin --context rig
rigAssert "a create from stdin succeeds"                    "$( cat "$rigDir/c.rc" )" 0
rigAssert "the stdin body is stored"                        "$( LC_ALL=C grep -c '^The widget keeps its last line\.$' "$rigStore/board/running/task-20261101T1950Z-rig.md" 2>/dev/null )" 1

echo "-- a create with the body as a parameter, and no stdin --"
rigScenario parameter
rigOp "$rigDir/c" --intern-op-board-upsert-move-edit running task-20261101T1951Z-rig.md --create --upsert-body:"$( rigDoc )" --context rig < /dev/null
rigAssert "the parameter create succeeds with no stdin"     "$( cat "$rigDir/c.rc" )" 0
rigAssert "the parameter body is stored"                    "$( LC_ALL=C grep -c '^The widget keeps its last line\.$' "$rigStore/board/running/task-20261101T1951Z-rig.md" 2>/dev/null )" 1
rigAssert "the title is stored as given"                    "$( LC_ALL=C grep -c '^# Task: Rig the body parameter$' "$rigStore/board/running/task-20261101T1951Z-rig.md" 2>/dev/null )" 1

echo "-- a create through the public stub, and no stdin --"
rigScenario stub
RIG_ENTRY="$rigItemsFn" rigOp "$rigDir/c" --create-running task-20261101T1952Z-rig.md --upsert-body:"$( rigDoc )" < /dev/null
rigAssert "the stub create succeeds with no stdin"          "$( cat "$rigDir/c.rc" )" 0
rigAssert "the stub create stores the parameter body"       "$( LC_ALL=C grep -c '^The widget keeps its last line\.$' "$rigStore/board/running/task-20261101T1952Z-rig.md" 2>/dev/null )" 1

echo "-- a move that carries a new body as a parameter --"
rigScenario move
rigDoc | rigOp "$rigDir/c" --intern-op-board-upsert-move-edit running task-20261101T1953Z-rig.md --create --upsert-from-stdin --context rig
RIG_ENTRY="$rigItemsFn" rigOp "$rigDir/m" --move-to-blocked task-20261101T1953Z-rig.md --from-state:running --upsert-body:"$( rigDoc | LC_ALL=C sed 's/^The widget keeps its last line\.$/It drops it again./' )" < /dev/null
rigAssert "the parameter move succeeds with no stdin"       "$( cat "$rigDir/m.rc" )" 0
rigAssert "the moved item carries the new body"             "$( LC_ALL=C grep -c '^It drops it again\.$' "$rigStore/board/blocked/task-20261101T1953Z-rig.md" 2>/dev/null )" 1

echo "-- the two operations the work-duty itself calls --"
rigScenario duty
RIG_ENTRY="$rigItemsFn" rigOp "$rigDir/g" --grooming-create-running task-20261101T1955Z-rig.md --owner-header-value magic-coordinator --upsert-body:"$( rigDoc )" < /dev/null
rigAssert "grooming-create-running takes the body as a parameter" "$( cat "$rigDir/g.rc" )" 0
rigAssert "and stores it"                                    "$( LC_ALL=C grep -c '^The widget keeps its last line\.$' "$rigStore/board/running/task-20261101T1955Z-rig.md" 2>/dev/null )" 1
RIG_ENTRY="$rigItemsFn" rigOp "$rigDir/a" --advance-to-running task-20261101T1955Z-rig.md --from-state:running --upsert-body:"$( rigDoc )" < /dev/null
rigAssert "advance-to-running takes the body as a parameter"  "$( cat "$rigDir/a.rc" )" 0

echo "-- the two body modes are mutually exclusive --"
rigScenario both
rigOp "$rigDir/c" --intern-op-board-upsert-move-edit running task-20261101T1954Z-rig.md --create --upsert-body:"$( rigDoc )" --upsert-from-stdin --context rig < /dev/null
rigAssert "two body modes are refused"                      "$( cat "$rigDir/c.rc" )" 1
rigAssert "and nothing is written"                          "$( [ -e "$rigStore/board/running/task-20261101T1954Z-rig.md" ] && printf made || printf none )" none

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD BODY PARAMETER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BOARD_BODY_PARAMETER: OK (%d assertions, offline, temp stores only)\n' "$rigPassCount"
