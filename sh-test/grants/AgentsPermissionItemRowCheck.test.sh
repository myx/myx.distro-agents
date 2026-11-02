#!/usr/bin/env bash
## AgentsPermissionItemRowCheck -- S21.20, the access row an approved permission set writes on its
## item. `AgentsToolsPermissionItemRow` writes `participants:allow-tool:<tool>:<target>:<granted-by>:<stamp>`
## for a tool, and the item's own contract (`AgentsDocTypeCheck.awk`, form `item-access-rows`) reads
## that value with `:` as its separator, so a tool with NO target -- `WebFetch`, and an entry like
## `cred:` -- is five fields and is refused. The write gate then refuses the whole write and the item
## never carries the row, so a later dispatch tracking it carries no planned allow. Held:
##   1. A tool with no target is written so the contract accepts it, and reads back as that tool.
##   2. A tool with a target, and the read and write verbs, are written and read back as before.
##   3. The round trip through the two instruments: what the row builder writes, the item's own
##      checker accepts, and the reader gives back the tool it meant.
## Red recipe: on live, `AgentsToolsPermissionItemRow WebFetch "" human-owner 20261102T0139Z` gives
## `participants:allow-tool:WebFetch::human-owner:20261102T0139Z`, which the contract refuses with
## "the key access-control has a row that is not participants:<verb>:<value>:<granted-by>:<stamp>".
## Offline by construction: the two functions and the one checker, no workspace, no network.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigCheck="$rigHere/team-data/AgentsDocTypeCheck.awk"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/grants/AgentsTools.InternOpPermission.include" ] || rigRefuse "the permission include is not at this origin"
[ -f "$rigCheck" ] || rigRefuse "the contract checker is not at this origin: $rigCheck"
. "${MDLT_ORIGIN}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPermissionItemRowCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export MMDAPP="${MMDAPP:-$rigTmp/ws}" MDSC_CMD="AgentsPermissionItemRowCheck"
mkdir -p "$MMDAPP"
## The include is a case arm: sourced with a name that is none of its operations, it only defines
## its functions, which is what this check needs.
set -- --none-of-its-operations
. "$rigHere/grants/AgentsTools.InternOpPermission.include"
set --

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The item's own checker over one access row: prints nothing where the row is accepted.
rigContractVerdict(){ ## row text
	printf -- '---\ntype: task\nstatus: task-started\nowner: magic-developer\nfrom: magic-developer\ndate: 2026-11-02 03:47 +0200\ndocument-contract: board-item.task\naccess-control: %s\n---\n\n# A task\n' "$1" > "$rigTmp/task-row.md"
	DOC_NAME="task-row.md" LC_ALL=C awk -f "$rigCheck" "$rigHere/../skillset/magic-team/magic-team/contracts/board-item.task.contract.format.md" "$rigTmp/task-row.md" 2>&1 \
		| LC_ALL=C grep 'contract-form.*access-control' | head -1
}
## The reader's view of one row set: what a spawn carries from it.
rigReadBack(){ ## rows text
	AgentsToolsPermissionItemEntries "$1" task
}

echo "-- 1. a tool with no target --"
rigRow="$( AgentsToolsPermissionItemRow WebFetch "$( AgentsToolsPermissionEscape "" )" human-owner 20261102T0139Z )"
rigAssert "the row is written for a tool with no target"          "$( printf '%s' "$rigRow" | LC_ALL=C grep -c '^participants:allow-tool:WebFetch:' )" "1"
rigAssert "the item's own contract accepts it"                     "$( rigContractVerdict "$rigRow" )" ""
rigAssert "and the reader gives back that tool"                    "$( rigReadBack "$rigRow" )" "task:WebFetch:-:human-owner:20261102T0139Z"
rigCred="$( AgentsToolsPermissionItemRow cred "$( AgentsToolsPermissionEscape "" )" human-owner 20261102T0139Z )"
rigAssert "an entry like cred:, whose target is empty too, is accepted the same" "$( rigContractVerdict "$rigCred" ):$( rigReadBack "$rigCred" )" ":task:cred:-:human-owner:20261102T0139Z"

echo "-- 2. a tool with a target, and the two path verbs, are as they were --"
rigFetch="$( AgentsToolsPermissionItemRow WebFetch "$( AgentsToolsPermissionEscape "https://api.rig.example/v2" )" human-owner 20261102T0139Z )"
rigAssert "a tool with a target still carries it"                  "$( rigContractVerdict "$rigFetch" ):$( rigReadBack "$rigFetch" )" ":task:WebFetch:https%3A//api.rig.example/v2:human-owner:20261102T0139Z"
rigWrite="$( AgentsToolsPermissionItemRow Write "$( AgentsToolsPermissionEscape "" )" human-owner 20261102T0139Z )"
rm -f "$rigTmp/task-row.md"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION ITEM ROW CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PERMISSION_ITEM_ROW: OK (%d assertions, offline)\n' "$rigPassCount"
