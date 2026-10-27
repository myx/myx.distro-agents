#!/usr/bin/env bash
## Behavioural check of the board writer's --upsert-from-slots body mode: the member gives only the
## slot values, and the writer renders the document's body from the type's template
## (sh-lib/templates/board-item.<type>.document.format.md), the front matter stamped as on any create.
## Covers the one-line title (`matter`), a simple `body` slot, the sectioned types (change), and the
## approval `blocks` front-matter key, present and absent. Temp stores only, in a temp workspace, and
## every op goes through one `env -i` whose child refuses to run outside it.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigHere/board/AgentsBoardItemDocumentFill.awk" ] || rigRefuse "the board document filler is not there: $rigHere/board/AgentsBoardItemDocumentFill.awk"
[ -f "$rigHere/templates/board-item.task.document.format.md" ] || rigRefuse "the tool-side task template is not there"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBoardSlotRenderCheck )" || exit 1
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
## One op, guarded; stdin is the caller's. The store is $rigStore.
rigOp(){ ## result file, op and its arguments...
	local rigResult="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="/usr/bin:/bin" MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigDir/home/skills" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "${MDAT_DATA_ROOT:-$RIG_TMP/}" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigResult" 2> "$rigResult.err"
	printf '%s' "$?" > "$rigResult.rc"
}

echo "-- a task from its slots --"
rigScenario task
printf -- 'matter: Rig the widget\nbody:\n  The widget drops its last line.\n  Make it keep it.\n' \
	| rigOp "$rigDir/c" --intern-op-board-upsert-move-edit running task-20261014T0101Z-rig.md --create --upsert-from-slots --context rig
rigAssert "the create succeeds"                              "$( cat "$rigDir/c.rc" )" 0
rigAssert "the type and contract are stamped"               "$( LC_ALL=C grep -c -e '^type: task$' -e '^document-contract: board-item.task$' "$rigStore/board/running/task-20261014T0101Z-rig.md" 2>/dev/null )" 2
rigAssert "the title is rendered from matter"               "$( LC_ALL=C grep -c '^# Task: Rig the widget$' "$rigStore/board/running/task-20261014T0101Z-rig.md" 2>/dev/null )" 1
rigAssert "the body is rendered, no stray indent"           "$( LC_ALL=C grep -c -e '^The widget drops its last line\.$' -e '^Make it keep it\.$' "$rigStore/board/running/task-20261014T0101Z-rig.md" 2>/dev/null )" 2

echo "-- a change from its slots --"
rigScenario change
printf -- 'matter: Deploy the widget\nwhat-changed: Rebuilt the loader.\nwhy: It crashed.\nneeds: none\nfiles-touched:\n  - src/loader.c\n  - src/loader.h\n' \
	| rigOp "$rigDir/c" --intern-op-board-upsert-move-edit running change-20261014T0102Z-rig.md --create --upsert-from-slots --context rig
rigAssert "the change create succeeds"                      "$( cat "$rigDir/c.rc" )" 0
rigAssert "the change sections are rendered"                "$( LC_ALL=C grep -c -e '^## What changed$' -e '^## Why$' -e '^## Needs$' -e '^## Files touched$' "$rigStore/board/running/change-20261014T0102Z-rig.md" 2>/dev/null )" 4
rigAssert "the files-touched list is rendered"              "$( LC_ALL=C grep -c -e '^- src/loader\.c$' -e '^- src/loader\.h$' "$rigStore/board/running/change-20261014T0102Z-rig.md" 2>/dev/null )" 2

echo "-- an approval with and without blocks --"
rigScenario approval
printf -- 'matter: Go live\nblocks: change-a, change-b\nbody: Ship it.\n' \
	| rigOp "$rigDir/c" --intern-op-board-upsert-move-edit running approval-20261014T0103Z-rig.md --create --upsert-from-slots --context rig
rigAssert "the approval create succeeds"                    "$( cat "$rigDir/c.rc" )" 0
rigAssert "the blocks front-matter key is set"              "$( LC_ALL=C grep -c '^blocks: change-a, change-b$' "$rigStore/board/running/approval-20261014T0103Z-rig.md" 2>/dev/null )" 1
printf -- 'matter: Go live\nbody: Ship it.\n' \
	| rigOp "$rigDir/c2" --intern-op-board-upsert-move-edit running approval-20261014T0104Z-rig.md --create --upsert-from-slots --context rig
rigAssert "an approval without the required blocks is refused" "$( cat "$rigDir/c2.rc" )" 1
rigAssert "and nothing is written"                           "$( [ -e "$rigStore/board/running/approval-20261014T0104Z-rig.md" ] && printf made || printf none )" none

echo "-- an unknown board type is refused --"
rigScenario unknown
printf -- 'matter: X\nbody: Y\n' \
	| rigOp "$rigDir/c" --intern-op-board-upsert-move-edit running mystery-20261014T0105Z-rig.md --create --upsert-from-slots --context rig
rigAssert "a type with no template is refused"              "$( cat "$rigDir/c.rc" )" 1
rigAssert "and nothing is written"                          "$( [ -e "$rigStore/board/running/mystery-20261014T0105Z-rig.md" ] && printf made || printf none )" none

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD SLOT RENDER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BOARD_SLOT_RENDER: OK (%d assertions, offline, temp stores only)\n' "$rigPassCount"
