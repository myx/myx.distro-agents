#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on S16 stage 2 item 6: the `status` key leaves the board items that carry it,
## and no code reads it as a run's state.
##   1. THE MIGRATION READS AND WRITES ONE KEY, and nothing else: a `status: ` line in the
##      frontmatter goes, a same-looking line in the body stays, and every other frontmatter
##      line is left exactly as it was.
##   2. IT IS IDEMPOTENT: a second run changes nothing, and its own read-back says so. The count
##      it prints is read back through a second walk, never kept from the write.
##   3. THE CODE NO LONGER READS A BOARD ITEM'S `status`. The three readers that used
##      `dispatch-started` as an open-run test now ask whether the item carries `resolved-at`,
##      which the close stamps and nothing else does.
##   4. CONTROLS: the key probe finds a planted key and reports a clean file clean, and the
##      code probe finds the reader where it is planted.
## Offline: rig copies of the item files only, and the origin's own code read as text.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigMigration="$rigPackage/sh-scripts/AgentsBoardStatusKeyMigration.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigMigration" ] || rigRefuse "the migration is not at the origin this workspace resolves: $rigMigration"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBoardStatusKeyMigrationCheck )" || exit 1
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
## How many frontmatter `status: ` lines a file carries: the body is not the frontmatter.
rigFmKeyCount(){ ## item file
	LC_ALL=C awk '
		NR == 1 && $0 != "---" { body = 1 ; }
		NR > 1 && $0 == "---" { body = 1 ; }
		!body && index($0, "status: ") == 1 { n++ ; }
		END { print n + 0 ; }
	' "$1"
}

rigBoard="$rigTmp/board"
mkdir -p "$rigBoard/running" "$rigBoard/processed" "$rigBoard/backlog"
printf -- '---\ntype: dispatch\nowner: keeper-rig\nstatus: dispatch-started\nsession-id: rig-1\n---\n\n# rig dispatch\n\nstatus: a body line that must stay\n' > "$rigBoard/running/dispatch-20261117T0100Z-rig-open.md"
printf -- '---\ntype: task\nowner: keeper-rig\nstatus: parked, and why\nrecheck-date: 2026-11-20 10:00 +0200\n---\n\n# rig task\n' > "$rigBoard/backlog/task-20261117T0101Z-rig-parked.md"
printf -- '---\ntype: task\nowner: keeper-rig\noutcome: no-action\n---\n\n# rig task with no status at all\n' > "$rigBoard/processed/task-20261117T0102Z-rig-clean.md"

echo "-- 1. the migration reads and writes one key --"
rigDry="$( bash "$rigMigration" "$rigBoard" )" || rigRefuse "the dry run failed"
rigAssert "the dry read counts every item and changes nothing" \
	"$( printf '%s' "$rigDry" | LC_ALL=C tr '\n' ' ' )" "read 3 carrying 2 removed 0 left 0"
rigAssert "control: the dry run left the key in place" \
	"$( rigFmKeyCount "$rigBoard/running/dispatch-20261117T0100Z-rig-open.md" )" 1
bash "$rigMigration" "$rigBoard" --apply > "$rigTmp/applied.txt" 2>&1 || rigRefuse "the apply run failed"
rigAssert "the apply run reports the removal, and its own read-back finds none left" \
	"$( LC_ALL=C tr '\n' ' ' < "$rigTmp/applied.txt" )" "read 3 carrying 2 removed 2 left 0 "
rigAssert "the frontmatter key is gone" \
	"$( rigFmKeyCount "$rigBoard/running/dispatch-20261117T0100Z-rig-open.md" )" 0
rigAssert "the body line that looks like the key stays" \
	"$( LC_ALL=C grep -c '^status: a body line that must stay$' "$rigBoard/running/dispatch-20261117T0100Z-rig-open.md" )" 1
rigAssert "every other frontmatter line is left as it was" \
	"$( LC_ALL=C grep -c -e '^type: dispatch$' -e '^owner: keeper-rig$' -e '^session-id: rig-1$' "$rigBoard/running/dispatch-20261117T0100Z-rig-open.md" )" 3
rigAssert "an item that carried no key is unchanged" \
	"$( LC_ALL=C grep -c '^outcome: no-action$' "$rigBoard/processed/task-20261117T0102Z-rig-clean.md" )" 1

echo "-- 2. a second run changes nothing --"
rigSecond="$( bash "$rigMigration" "$rigBoard" --apply )" || rigRefuse "the second apply failed"
rigAssert "the second run carries nothing and removes nothing" \
	"$( printf '%s' "$rigSecond" | LC_ALL=C tr '\n' ' ' )" "read 3 carrying 0 removed 0 left 0"

echo "-- 3. no code reads a board item's status as a run's state --"
rigBoardHousekeeping="$rigPackage/sh-lib/board/AgentsTools.BoardHousekeeping.include"
rigControlDeath="$rigPackage/sh-lib/session/AgentsTools.SessionControlDeath.include"
rigClose="$rigPackage/sh-lib/spawn/AgentsTools.SpawnProxyClose.include"
rigAssert "the housekeeping no longer tests a board item's status" \
	"$( LC_ALL=C grep -c 'itemPath" status )" = dispatch-started' "$rigBoardHousekeeping" )" 0
rigAssert "the death close no longer tests a board item's status" \
	"$( LC_ALL=C grep -c 'closePath" status )" = dispatch-started' "$rigControlDeath" )" 0
rigAssert "the close no longer writes a status onto the item" \
	"$( LC_ALL=C grep -c 'header:upsert:status:dispatch-' "$rigClose" )" 0
rigAssert "the close stamps resolved-at, which is now the open-run test" \
	"$( LC_ALL=C grep -c 'header:upsert:resolved-at' "$rigClose" )" 1

echo "-- 4. controls: the probes answer both ways --"
printf -- '---\ntype: task\nstatus: planted\n---\nbody\n' > "$rigTmp/planted.md"
rigAssert "control: the key probe finds a planted key" \
	"$( LC_ALL=C awk 'NR == 1 && $0 != "---" { exit ; } NR > 1 && $0 == "---" { exit ; } index($0, "status: ") == 1 { print "found" ; exit ; }' "$rigTmp/planted.md" )" found
printf -- '---\ntype: task\n---\nstatus: in the body only\n' > "$rigTmp/bodyonly.md"
rigAssert "control: and reports a key in the body only as absent from the frontmatter" \
	"$( LC_ALL=C awk 'NR == 1 && $0 != "---" { exit ; } NR > 1 && $0 == "---" { exit ; } index($0, "status: ") == 1 { print "found" ; exit ; }' "$rigTmp/bodyonly.md" )" ""
printf 'x="$( AgentsToolsFrontmatterKey "$itemPath" status )" = dispatch-started\n' > "$rigTmp/reader.md"
rigAssert "control: the code probe finds a reader where it is planted" \
	"$( LC_ALL=C grep -c 'itemPath" status )" = dispatch-started' "$rigTmp/reader.md" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD STATUS KEY MIGRATION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BOARD_STATUS_KEY_MIGRATION: OK (%d assertions, offline, rig items only)\n' "$rigPassCount"
