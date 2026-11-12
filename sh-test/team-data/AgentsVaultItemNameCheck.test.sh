#!/usr/bin/env bash
## Behavioural check of the vault's name rule and its rename. A name that carries a vault contract's type word is
## `<type word>-<date>-<matter>`, `<date>` YYYYMMDD'T'HHmm'Z' (the tooling Rule: a date inside any name): the vault read and
## the typed write refuse any other. A name with no type word is not the rule's. The rename moves an item to a name its
## contract accepts and repoints every board, inbox and vault item that names it, matched whole; it refuses a missing item,
## a name the rule refuses and a name already taken. Temp stores only, in a temp workspace, and every op goes through one
## `env -i` whose child refuses to run outside it.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigItems="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigItems" ] || rigRefuse "items dispatcher not found: $rigItems"
[ -f "$rigTools" ] || rigRefuse "tools dispatcher not found: $rigTools"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsVaultItemNameCheck )" || exit 1
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
	mkdir -p "$rigDir/ws/.local" "$rigDir/home/skills/magic-coordinator" "$rigStore/vault" "$rigStore/board/backlog" "$rigStore/inboxes/magic-coordinator/incoming"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/home/skills/magic-coordinator/magic-coordinator.basic.md"
}
## One op, guarded; stdin is the caller's. The store is $rigStore.
rigOp(){ ## result file, dispatcher, op and its arguments...
	local rigResult="$1" rigFn="$2" ; shift 2
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="/usr/bin:/bin" MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigDir/home/skills" \
		MDAT_TEAM_DATA_COMMIT_THREAD=off MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "${MDAT_DATA_ROOT:-$RIG_TMP/}" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigResult" 2> "$rigResult.err"
	printf '%s' "$?" > "$rigResult.rc"
}

echo "-- the read refuses a typed name whose date is not YYYYMMDD'T'HHmm'Z', and reads one that is --"
rigScenario read
printf '# Sprint\n\nrig plan\n' > "$rigStore/vault/planning-20261109-sprint.md"
printf '# Sprint\n\nrig plan\n' > "$rigStore/vault/planning-20261109T0000Z-sprint.md"
printf '# Notes\n\nrig notes\n' > "$rigStore/vault/notes-20261109.md"
rigOp "$rigDir/r1" "$rigItems" --get-vault-item --team-member magic-coordinator planning-20261109-sprint
rigAssert "a date with no time: refused"                      "$( cat "$rigDir/r1.rc" ):$( LC_ALL=C grep -c 'is no valid planning name' "$rigDir/r1.err" )" "1:1"
rigAssert "and nothing of it is printed"                      "$( LC_ALL=C grep -c 'rig plan' "$rigDir/r1" )" 0
rigOp "$rigDir/r2" "$rigItems" --get-vault-item --team-member magic-coordinator planning-20261109T0000Z-sprint
rigAssert "the same item under a valid name is read"          "$( cat "$rigDir/r2.rc" ):$( LC_ALL=C grep -c 'rig plan' "$rigDir/r2" )" "0:1"
rigOp "$rigDir/r3" "$rigItems" --get-vault-item --team-member magic-coordinator notes-20261109
rigAssert "a name with no type word is not the rule's"        "$( cat "$rigDir/r3.rc" ):$( LC_ALL=C grep -c 'rig notes' "$rigDir/r3" )" "0:1"

echo "-- the typed write refuses a name its contract does not accept --"
rigScenario write
printf '# Epic\n\nrig epic\n' | rigOp "$rigDir/w1" "$rigItems" --upsert-vault-epic-blueprint --team-member magic-coordinator epic-blueprint-20261102-rig --upsert-from-stdin
rigAssert "a typed write under a date with no time: refused"  "$( cat "$rigDir/w1.rc" ):$( LC_ALL=C grep -c 'is no valid epic-blueprint name' "$rigDir/w1.err" )" "1:1"
rigAssert "and nothing is written"                            "$( ls "$rigStore/vault" | LC_ALL=C grep -c 'epic-blueprint-' )" 0

echo "-- the rename moves the item and repoints what names it, whole names only --"
rigScenario rename
printf '# Epic\n\nrig epic\n' > "$rigStore/vault/epic-blueprint-20261102-rig.md"
printf -- '---\ntype: task\n---\n\ntracking: vault/epic-blueprint-20261102-rig.md\nsee epic-blueprint-20261102-rig, and epic-blueprint-20261102-rig-old stays\n' > "$rigStore/board/backlog/task-20261102T0000Z-rig.md"
printf 'nothing here\n' > "$rigStore/inboxes/magic-coordinator/incoming/note-20261102T0000Z-rig.md"
rigOp "$rigDir/m1" "$rigTools" --intern-op-vault-item-rename magic-coordinator epic-blueprint-20261102-rig epic-blueprint-20261102T0000Z-rig
rigAssert "the rename succeeds and says what it did"          "$( cat "$rigDir/m1.rc" ):$( LC_ALL=C grep -c -x 'REPOINTED: 1 item(s)' "$rigDir/m1" )" "0:1"
rigAssert "the item stands under its new name only"           "$( [ -f "$rigStore/vault/epic-blueprint-20261102T0000Z-rig.md" ] && printf new ):$( [ -e "$rigStore/vault/epic-blueprint-20261102-rig.md" ] && printf old || printf gone )" "new:gone"
rigAssert "every whole citation names the new name"           "$( LC_ALL=C grep -c 'epic-blueprint-20261102T0000Z-rig' "$rigStore/board/backlog/task-20261102T0000Z-rig.md" )" 2
rigAssert "a longer name that starts the same is untouched"   "$( LC_ALL=C grep -c 'epic-blueprint-20261102-rig-old stays' "$rigStore/board/backlog/task-20261102T0000Z-rig.md" )" 1
rigAssert "an item naming nothing of it is left as it was"    "$( cat "$rigStore/inboxes/magic-coordinator/incoming/note-20261102T0000Z-rig.md" )" "nothing here"

echo "-- the rename refuses, changing nothing --"
rigOp "$rigDir/m2" "$rigTools" --intern-op-vault-item-rename magic-coordinator epic-blueprint-20261102T0000Z-rig epic-blueprint-20261102-again
rigAssert "a new name the rule refuses"                       "$( cat "$rigDir/m2.rc" ):$( [ -f "$rigStore/vault/epic-blueprint-20261102T0000Z-rig.md" ] && printf kept )" "1:kept"
rigOp "$rigDir/m3" "$rigTools" --intern-op-vault-item-rename magic-coordinator epic-blueprint-20261103T0000Z-none epic-blueprint-20261103T0000Z-other
rigAssert "an old item that is not there"                     "$( cat "$rigDir/m3.rc" ):$( ls "$rigStore/vault" | LC_ALL=C grep -c 'other' )" "1:0"
printf '# Other\n' > "$rigStore/vault/epic-blueprint-20261104T0000Z-other.md"
rigOp "$rigDir/m4" "$rigTools" --intern-op-vault-item-rename magic-coordinator epic-blueprint-20261104T0000Z-other epic-blueprint-20261102T0000Z-rig
rigAssert "a new name already taken"                          "$( cat "$rigDir/m4.rc" ):$( LC_ALL=C grep -c 'rig epic' "$rigStore/vault/epic-blueprint-20261102T0000Z-rig.md" ):$( [ -f "$rigStore/vault/epic-blueprint-20261104T0000Z-other.md" ] && printf kept )" "1:1:kept"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ VAULT ITEM NAME CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'VAULT_ITEM_NAME: OK (%d assertions, offline, temp stores only)\n' "$rigPassCount"
