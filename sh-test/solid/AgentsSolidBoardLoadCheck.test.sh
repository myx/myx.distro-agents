#!/usr/bin/env bash
## Check on the store rule of AgentsSolidBreachScan.sh: a load of another concern's code is that concern's contract,
## and a data store read past its owner is a breach, whatever folder the reader sits in.
## Held, in the order they are read:
##   1. control: the known-positive store read of a concern that owns no board data comes back as a foreign-store row
##   2. green: a load of board code comes back as no row, for each of the three kinds the package loads -- include, awk, python
##   3. red: the same three files, scanned by the same rule with its exemption removed, each come back as a row
##   4. the exemption clears loads alone: the same concern still rows for its board store read
##   5. the exemption line the red arm removes is the one the scan carries, so the red arm cannot quietly stop reddening
## Usage: AgentsSolidBoardLoadCheck.test.sh [<package root>]   (default: the package at $MDLT_ORIGIN). Offline: it writes only its own rig.
set -u
argRoot=""
case "${1:-}" in --*) ;; "") ;; *) argRoot="$1" ;; esac
if [ -n "$argRoot" ] && [ -d "$argRoot/sh-test/solid" ] ; then
	scanPackage="$argRoot"
else
	: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set, and no package root was given}"
	scanPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
fi
scanTool="$scanPackage/sh-test/solid/AgentsSolidBreachScan.sh"
scanRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$scanTool" ] || scanRefuse "the scan is not where the package root says: $scanTool"
[ -d "$scanPackage/sh-lib" ] || scanRefuse "no package at $scanPackage"
. "$scanPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
scanRig="$( rigTempDir AgentsSolidBoardLoadCheck )" || exit 1
scanRig="$( cd "$scanRig" && pwd -P )" || exit 1
[ -n "${RIG_KEEP:-}" ] || trap 'chmod -R u+w "$scanRig" 2>/dev/null ; rm -rf -- "$scanRig"' EXIT

## The constructed package: four files of one concern that owns no board data, so every board line in them is another
## concern's. Its own copy of the scan is the red arm, made by removing the exemption from the one line that carries it.
scanBuilt="$scanRig/built/pkg"
mkdir -p "$scanBuilt/sh-lib/inbox" "$scanBuilt/sh-scripts" "$scanBuilt/sh-test/solid" || exit 1
printf '## A store read past its owner: the known-positive this check is calibrated on.\nScanInboxBoardStoreRead(){ ## text\n\tlocal readFile="$MDAT_DATA_ROOT/board/pending/scan-item.md"\n\tprintf %%s "$readFile"\n}\n' \
	> "$scanBuilt/sh-lib/inbox/ScanInboxBoardStoreRead.include" || exit 1
printf '## A load of another concern the way the package spells it: an include under sh-lib.\nScanInboxBoardIncludeLoad(){ ## text\n\t. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardStates.include"\n\tprintf %%s ok\n}\n' \
	> "$scanBuilt/sh-lib/inbox/ScanInboxBoardIncludeLoad.include" || exit 1
printf '## A load of another concern the way the package spells it: an awk program under sh-lib.\nScanInboxBoardAwkLoad(){ ## text\n\tLC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsBoardItemFrontmatterPrint.awk" "$1"\n}\n' \
	> "$scanBuilt/sh-lib/inbox/ScanInboxBoardAwkLoad.include" || exit 1
printf '## A load of another concern the way the package spells it: a python program under sh-lib.\nScanInboxBoardPythonLoad(){ ## text\n\tprintf %%s "" | python3 "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsBoardItemPatchApply.py"\n}\n' \
	> "$scanBuilt/sh-lib/inbox/ScanInboxBoardPythonLoad.include" || exit 1

scanExemptMark='word !~ /sh-lib$/'
scanExemptCount="$( LC_ALL=C grep -cF "$scanExemptMark" "$scanTool" )" || :
[ "$scanExemptCount" = 1 ] || scanRefuse "the exemption this check removes appears $scanExemptCount times in $scanTool, so its red arm would prove nothing"
scanRedTool="$scanBuilt/sh-test/solid/AgentsSolidBreachScan.sh"
LC_ALL=C awk -v mark="$scanExemptMark" '
	index($0, mark) == 0 { print ; next ; }
	{ line = $0 ; sub(/ && word !~ \/sh-lib\$\//, "", line) ; print line ; }' "$scanTool" > "$scanRedTool" || scanRefuse "the red copy could not be written"
! LC_ALL=C grep -qF "$scanExemptMark" "$scanRedTool" || scanRefuse "the red copy still carries the exemption"
chmod +x "$scanRedTool" || scanRefuse "the red copy could not be made executable"

scanPassCount=0
scanFailCount=0
scanAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; scanPassCount=$(( scanPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; scanFailCount=$(( scanFailCount + 1 ))
	fi
}
scanRowsOf(){ ## rows, file -- the foreign-store rows naming that file, `<file>:<line>` joined by `; `
	LC_ALL=C awk -F'\t' -v want="$2" '$2 == "foreign-store" && index($3, want ":") == 1 { printf "%s%s", rowSep, $3 ; rowSep = "; " ; }' <<< "$1"
}
scanRun(){ ## scan, package -- its rows, or a refusal when it printed none of its own accord
	bash "$1" "$2" 2> "$scanRig/scan.err"
}

echo "-- 1. control: the scan reads the constructed package, and a known-positive store read still counts --"
scanRows="$( scanRun "$scanTool" "$scanBuilt" )" || scanRefuse "the scan failed on the constructed package: $( LC_ALL=C tail -n 3 "$scanRig/scan.err" )"
scanAssert "control: the scan printed rows for the constructed package at all" \
	"$( [ -n "$scanRows" ] && printf rows || printf none )" rows
scanAssert "a board store read from a concern that owns no board data is a foreign-store row" \
	"$( scanRowsOf "$scanRows" sh-lib/inbox/ScanInboxBoardStoreRead.include )" "sh-lib/inbox/ScanInboxBoardStoreRead.include:3"

echo "-- 2. green: a load of board code is no row, for each kind of file the package loads --"
scanAssert "a sourced board include is no row" "$( scanRowsOf "$scanRows" sh-lib/inbox/ScanInboxBoardIncludeLoad.include )" ""
scanAssert "a board awk program passed to awk is no row" "$( scanRowsOf "$scanRows" sh-lib/inbox/ScanInboxBoardAwkLoad.include )" ""
scanAssert "a board python program passed to python3 is no row" "$( scanRowsOf "$scanRows" sh-lib/inbox/ScanInboxBoardPythonLoad.include )" ""

echo "-- 3. red: the same three files, under the same rule without its exemption, are each a row --"
scanRedRows="$( scanRun "$scanRedTool" "$scanBuilt" )" || scanRefuse "the red copy of the scan failed on the constructed package: $( LC_ALL=C tail -n 3 "$scanRig/scan.err" )"
scanAssert "red: the sourced board include is a row without the exemption" \
	"$( scanRowsOf "$scanRedRows" sh-lib/inbox/ScanInboxBoardIncludeLoad.include )" "sh-lib/inbox/ScanInboxBoardIncludeLoad.include:3"
scanAssert "red: the board awk program is a row without the exemption" \
	"$( scanRowsOf "$scanRedRows" sh-lib/inbox/ScanInboxBoardAwkLoad.include )" "sh-lib/inbox/ScanInboxBoardAwkLoad.include:3"
scanAssert "red: the board python program is a row without the exemption" \
	"$( scanRowsOf "$scanRedRows" sh-lib/inbox/ScanInboxBoardPythonLoad.include )" "sh-lib/inbox/ScanInboxBoardPythonLoad.include:3"
scanAssert "the store read stays a row in the red arm, so the two arms differ by the loads alone" \
	"$( scanRowsOf "$scanRedRows" sh-lib/inbox/ScanInboxBoardStoreRead.include )" "sh-lib/inbox/ScanInboxBoardStoreRead.include:3"

echo "-- 4. the exemption clears loads alone, not every board line of the concern --"
scanAssert "the green arm's rows carry no board load, and do carry the store read" \
	"$( LC_ALL=C awk -F'\t' '$2 == "foreign-store" { n++ ; } END { print n + 0 ; }' <<< "$scanRows" )" 1

if [ "$scanFailCount" -ne 0 ] ; then
	echo "⛔ SOLID BOARD LOAD CHECK FAILED: $scanFailCount of $(( scanPassCount + scanFailCount )) assertion(s)" >&2
	echo "  fix:  sh-test/solid/AgentsSolidBreachScan.sh, the foreign-store rule -- never the assertion" >&2
	exit 1
fi
printf 'SOLID_BOARD_LOAD: OK (%d assertions, offline)\n' "$scanPassCount"
