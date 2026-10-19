#!/usr/bin/env bash
## Behavioural check on reading a table first, in the left window of the manager screen (F11.3 of the refactorings epic: "reading first"), run
## rather than read. The screen's own code (sh-lib/manager/AgentsManagerScreen.py) runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls the stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which prints the case's fixture.
## Held, for a table that is all of the left window (the members of the team, here eighty of them):
##   1. by default it is read like a text with `less`: no row is highlighted, and the keys of the paging scroll it
##   2. Enter puts a row cursor on the top visible row, drawn as the selection is, and the arrows move it a row
##   3. Enter on a row opens that row whole in the information dialog, one `head: cell` line for each column of the table; Esc closes
##      the dialog, with the cursor where it was
##   4. Esc leaves the cursor, back to reading; with no cursor it does nothing to the table
##   5. while the cursor is on, the keys that scroll the pane keep it in view: scrolled out of view it comes to the top visible row, or to
##      the last one where the pane went up
##   6. a left window that is no table has no such cursor: Enter does nothing there
## No setting for it. Offline: the only thing the screen calls here is the stand-in for the dispatcher.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigTools="$rigFixtures/manager-screen.tools.stub.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenRowCursorCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export TZ=UTC

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRow(){ ## the fields of one row, joined by TAB
	local rowText="$1" ; shift
	while [ $# -gt 0 ] ; do rowText="$rowText"$'\t'"$1" ; shift ; done
	printf '%s\n' "$rowText"
}
rigS1=11111111-0000-4000-8000-000000000001
rigCase(){ ## name members -- a rig of its own: that many team members, and a Markdown file for the case of a left window that is no table
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	( cd "$MANAGER_SCREEN_RIG" || exit 1
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 1 running=1 running 2026-10-12_16:58_+0000 gone > "rows"
	rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting >> "rows"
	rigRow counters 1 0 1 0 1 0.42 >> "rows"
	{
		rigRow member keeper-rig :triangular_ruler: Sage Bourne cronjob keeper ws-rig here active running
		for rigN in $( seq 1 "$2" ) ; do rigRow member "member-$( printf '%02d' "$rigN" )" :ear_of_rice: Thea Vance farmhand keeper ws-far elsewhere active no-process ; done
	} > "rows.--manager-team-member-list"
	rigMember="$( rigRow member keeper-rig - Rig Keeper - keeper /rig/ws here active no-process - )"
	printf '%s\ninfo\tdescription\tA_rig_keeper\n' "$rigMember" > "rows.--manager-team-member-read keeper-rig"
	{ rigRow file SKILL.md 900 yes ; } > "rows.--manager-team-member-files keeper-rig"
	{
		printf -- '---\nname: keeper-rig\n---\n# The rig keeper\n\n'
		for rigN in $( seq 1 150 ) ; do printf -- '- item %d of the list\n' "$rigN" ; done
	} > "rows.--manager-team-member-files keeper-rig SKILL.md"
	: > "calls" ; : > "words"
	echo rows > "mode" )
}
rigScript(){ ## size -- the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:sessions:record none\ntable feed:sessions:record none\nwall 2026-10-13 02:30 +0000\nsize %s\n' "$rigTools" "$1" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
## the left window of a screen, as text: each line of the screen cut to the cells of the left window (the first cell is its border), with its
## roles; the lines drawn as the selection is (reverse, role R) over most of their width are the marked ones
cat > "$rigTmp/left.py" <<'RIGLEFT'
import re, sys
what, shownTag, rolesTag = sys.argv[1:4]
out = sys.stdin.read().split("\n")
shown = [line[len(shownTag) + 1:] for line in out if line.startswith(shownTag + "|")]
roles = [line[len(rolesTag) + 1:] for line in out if line.startswith(rolesTag + "|")] if rolesTag != "-" else []
marked, numbers = [], []
for number, line in enumerate(shown):
    text = re.sub(r" +", " ", line[1:84]).strip()
    if number < len(roles) and roles[number][1:84].count("R") >= 20:
        marked.append(text)
    if re.match(r"[0-9]+ ", text):
        numbers.append(text.split(" ")[0])
if what == "marked":
    print(" // ".join(marked) if marked else "none")
else:
    print(" ".join(numbers))
RIGLEFT
rigMarked(){ ## text tag, roles tag -- the marked lines of the left window, their blanks squeezed, joined by ` // `, or `none`
	printf '%s\n' "$rigOut" | "$rigPython" -I -B "$rigTmp/left.py" marked "$1" "$2"
}
rigNumbers(){ ## text tag -- the numbers at the start of the numbered rows in view in the left window, in a line
	printf '%s\n' "$rigOut" | "$rigPython" -I -B "$rigTmp/left.py" numbers "$1" -
}
rigNumberOf(){ ## marked text -- the number the row starts with
	printf '%s\n' "$1" | LC_ALL=C awk '{ print $1 }'
}

echo "-- 1, 2, 3, 4. a table of eighty-one rows --"
rigCase table 80
rigScript "120 30" <<'RIGSCRIPT'
root sessions
turn
wait sessions 30
root team
turn 2
turn
keys ENTER
wait list 10
turn
keys TAB
get read
show a
roles aR
keys PGDN
show a2
roles a2R
keys HOME
keys ENTER
get cursor
show b
roles bR
keys DOWN
show c
roles cR
keys DOWN DOWN
show d
roles dR
keys UP
show e
roles eR
keys ENTER
get dialog
keys ESC
get closed
show f
roles fR
keys ESC
get left
show g
roles gR
keys ENTER
keys SPACE
get paged
show h
roles hR
keys END
show i
roles iR
keys HOME
show j
roles jR
keys PGDN PGDN
keys ESC
show k
roles kR
RIGSCRIPT
rigAssert "control: the table of the members is the left window, which has the keys, and holds more rows than it shows" "$( rigVal read.focus ) $( [ "$( rigVal read.viewLines )" -gt 60 ] && echo long || echo "short: $( rigVal read.viewLines )" )" "view long"
rigAssert "by default no row is highlighted, also after the keys of the paging scrolled it" "$( rigMarked a aR ) / $( rigMarked a2 a2R ) / $( rigVal read.viewTop )" "none / none / 0"
rigFirstRow="$( rigNumbers b | LC_ALL=C awk '{ print $1 }' )"
rigAssert "Enter puts the cursor on the top visible row, drawn as the selection is: one row, the first one in view" "$( rigNumberOf "$( rigMarked b bR )" ) $( rigMarked b bR | LC_ALL=C grep -c -F ' // ' )" "$rigFirstRow 0"
rigAssert "the arrows move it a row at a time" "$( rigNumberOf "$( rigMarked c cR )" ) $( rigNumberOf "$( rigMarked d dR )" ) $( rigNumberOf "$( rigMarked e eR )" )" "$(( rigFirstRow + 1 )) $(( rigFirstRow + 3 )) $(( rigFirstRow + 2 ))"
rigRowName="$( rigMarked e eR | LC_ALL=C awk '{ print $2 }' )"
rigAssert "Enter on that row opens it whole in the information dialog, titled by its first cell, one head: cell line for each column" \
	"$( rigVal dialog.dialogTitle ) | $( rigVal dialog.dialogHolds | LC_ALL=C grep -c -F "MEMBER: $rigRowName" ) $( rigVal dialog.dialogHolds | LC_ALL=C grep -c -F ' / STATUS: ' ) $( rigVal dialog.dialogHolds | LC_ALL=C grep -c -F 'KIND: ' )" "$rigRowName | 1 1 1"
rigAssert "Esc closes the dialog, and the cursor stays on its row" "[$( rigVal closed.dialogTitle )] $( rigMarked f fR | LC_ALL=C awk '{ print $2 }' )" "[] $rigRowName"
rigAssert "Esc leaves the cursor, back to reading, and the left window keeps the keys" "$( rigMarked g gR ) $( rigVal left.focus )" "none view"
rigAssert "with the cursor on, Space pages the pane and the cursor comes to the top row in view" "$( rigNumberOf "$( rigMarked h hR )" ) $( rigNumbers h | LC_ALL=C awk '{ print $1 }' )" "$( rigNumbers h | LC_ALL=C awk '{ print $1 " " $1 }' )"
rigAssert "End goes to the bottom of the table: the cursor is in view, on the top row of the last page" "$( rigNumberOf "$( rigMarked i iR )" ) $( rigNumbers i | LC_ALL=C awk '{ print $1 }' )" "$( rigNumbers i | LC_ALL=C awk '{ print $1 " " $1 }' )"
rigAssert "Home goes to the top: the cursor comes to the last row in view, as the pane went up" "$( rigNumberOf "$( rigMarked j jR )" )" "$( rigNumbers j | LC_ALL=C awk '{ print $NF }' )"
rigAssert "and after more paging and Esc the table is read again with no row highlighted" "$( rigMarked k kR )" "none"

echo "-- 6. a left window that is no table: Enter does nothing --"
rigCase text 3
rigScript "120 36" <<'RIGSCRIPT'
turn
wait list 10
keys 4
wait list 10
keys DOWN ENTER
wait list 10
keys DOWN DOWN
wait focus 10
keys ENTER
wait list 10
keys DOWN
wait view 10
keys TAB ENTER
get text
show t
roles tR
keys DOWN
get down
RIGSCRIPT
rigAssert "a Markdown text: Enter opens no dialog and puts no cursor on it, and the arrows scroll it a line" "[$( rigVal text.dialogTitle )] $( rigMarked t tR ) $( rigVal text.focus ) $( rigVal text.viewTop ) $( rigVal down.viewTop )" "[] none view 0 1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN ROW CURSOR CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_ROW_CURSOR: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
