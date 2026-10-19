#!/usr/bin/env bash
## Behavioural check on `w`, the lines of the left window wrapped or cut, in the manager screen
## (sh-lib/manager/AgentsManagerScreen.py), run rather than read, in each kind of view of the left window: a summary with a table
## of its own (a store of the team data), a table of the left pane (a folder's items, a member's grants, the members), a
## Markdown text rendered, the same text raw, and a member's help. The screen's own code runs through the stand-in
## terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a
## stand-in script (check-fixtures/manager-screen.tools.stub.sh), which prints the fixture.
## Held, in each: wrapped, the title says [wrap], no line of the pane is cut with the mark of a cut text, and the word at
## the end of the longest line of the fixture is there to be read (with `e`, every row of a table); cut, the title says [cut], that word is out of view,
## and the pane scrolls sideways. Offline: no operation of the real tooling is called.
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
rigTmp="$( rigTempDir AgentsManagerScreenWrapCheck )" || exit 1
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
export MANAGER_SCREEN_RIG="$rigTmp/rig"
mkdir -p "$MANAGER_SCREEN_RIG"
cd "$MANAGER_SCREEN_RIG" || exit 1
rigLong="a-folder-whose-name-runs-on-past-the-pane-ENDFOLDER"
printf 'block\tteam-data\tTeam_Data\t2\nfigure\tteam-data\troot\tTeam_Data_Root\t/rig/td\t-\t-\t-\nfigure\tteam-data\tpresent\tTeam_Data_Present\tyes\t-\tok\t-\n' > "rows.--manager-dashboard-read"
cp "rows.--manager-dashboard-read" "rows.--manager-dashboard-read team-data team-data-git loop"
printf 'store\tboard\tpresent\t3\t0\nfolder\tboard\trunning\t1\nfolder\tboard\t%s\t1\nfolder\tboard\tmany\t40\n' "$rigLong" > "rows.--manager-team-data-read board"
for rigNo in $( seq -w 1 40 ) ; do printf 'item\tboard\tmany\titem-%s-with-a-name-to-scroll-sideways.md\t100\t-\t-\t-\t-\t-\n' "$rigNo" ; done > "rows.--manager-team-data-read board many"
printf 'item\tboard\trunning\tt-1.md\t1200\t20261001T0900\ttask\topen\tkeeper-rig-with-a-long-owner-name-ENDOWNER\t2026-10-01_09:00_+0000\n' > "rows.--manager-team-data-read board running"
## an Audit folder of many items: its table keeps its count above it, its first rows and its size
printf 'store\taudit\tpresent\t1\t0\nfolder\taudit\tmany\t40\n' > "rows.--manager-team-data-read audit"
for rigNo in $( seq -w 1 40 ) ; do printf 'item\taudit\tmany\titem-%s-with-a-name-to-scroll-sideways.md\t100\t-\t-\t-\t-\t-\n' "$rigNo" ; done > "rows.--manager-team-data-read audit many"
{
	printf '# A heading\n\nA paragraph whose one line runs much longer than the pane is wide, so that it wraps at its words ENDPARA\n\n'
	printf '```\na-code-line-that-is-very-long-and-has-no-blank-in-it-to-break-at-ENDCODE\n```\n\n'
	printf '| COLUMN | OTHER |\n|---|---|\n| a cell of many words that run on and on past the pane ENDCELL | x |\n'
} > "rows.--manager-team-data-read board running t-1.md"
rigMember="member	keeper-rig	-	Rig	Keeper	-	keeper	/rig/ws	here	active	no-process	-"
printf '%s\nmember\thuman-owner-with-a-very-long-name-that-runs-ENDMEMBER\t-\t-\t-\t-\thuman\t/rig/ws\there\treference-only\tno-process\t-\n' "$rigMember" > "rows.--manager-team-member-list"
{
	printf '%s\ninfo\tdescription\tA_rig_keeper\n' "$rigMember"
	printf 'grant\tfloor\tread\t/rig/ws/source/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py\tws:source/myx/myx.distro-agents/sh-lib/AgentsManagerScreen-ENDCOVERS.py\tset-3ef0ea61-ff24-46e7-8299-bb3c5ee6b4fc_by_U75H0DK43\tuntil_session_5680fa0b_ends\n'
} > "rows.--manager-team-member-read keeper-rig"
printf 'file\tSKILL.md\t1889\tyes\n' > "rows.--manager-team-member-files keeper-rig"
printf '📘 syntax: DistroAgentsTools.fn.sh --member-help <team-member> [--a-long-option-of-its-own <value>] [--another-long-option-ENDHELP]\n\n\t\t--member-help <team-member>\n\t\t\tRead-only. Prints its help.\n\n' > "rows.--member-help keeper-rig"
: > "$MANAGER_SCREEN_RIG/calls"
: > "$MANAGER_SCREEN_RIG/words"
echo rows > "$MANAGER_SCREEN_RIG/mode"

rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\nwall 2026-10-13 02:30 +0000\nsize 64 36\nroot dashboard\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
}
rigPane(){ ## tag -- the lines of the left pane of that screen, without its frame
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n '3,$p' | LC_ALL=C sed -E -e "s/^$1\|(│|║)//" -e 's/(│|║|▲|▼|▒|■).*$//'
}
rigTitle(){ ## tag -- the top border of the left pane
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n '2p' | LC_ALL=C sed -E -e 's/(┐|╗).*$//'
}
rigView(){ ## tag, the word at the end of its longest line -- [wrap]/[cut] of the title, how many lines of the pane end in the mark of a cut text, whether the word is in view
	printf '%s %s %s' "$( rigTitle "$1" | LC_ALL=C grep -o -e '\[wrap\]' -e '\[cut\]' | head -1 )" "$( rigPane "$1" | LC_ALL=C sed 's/  *$//' | LC_ALL=C grep -c '…$' || : )" "$( rigPane "$1" | LC_ALL=C grep -c -F -- "$2" | LC_ALL=C awk '{ print ( $1 > 0 ) }' )"
}
## each view: wrapped, then cut (w, the left window's own, with the keys there), then scrolled sideways, then wrapped again
rigToggle(){ ## tag
	printf 'turn\nshow %son\nkeys TAB w\nturn\nshow %soff\nkeys RIGHT RIGHT RIGHT\nturn\nget %span\nkeys w TAB\nturn\n' "$1" "$1" "$1"
}
rigScript <<RIGSCRIPT
turn
wait list 10
keys 5
wait list 10
keys DOWN DOWN
wait focus 10
$( rigToggle store )
keys ENTER
wait list 10
keys DOWN
wait focus 10
$( rigToggle items )
keys ENTER
wait list 10
keys DOWN
wait view 10
$( rigToggle markdown )
keys g
$( rigToggle raw )
keys b
keys 4
wait list 10
$( rigToggle members )
keys DOWN
wait view 10
keys ENTER
wait list 10
keys DOWN
wait focus 10
$( rigToggle grants )
keys DOWN DOWN DOWN
wait focus 10
$( rigToggle help )
RIGSCRIPT
for rigCaseOf in "store:a summary with a table of its own, a store's folders:ENDFOLDER" "items:a table of the left pane, a folder's items:ENDOWNER" \
		"markdown:a Markdown text rendered, its paragraph:ENDPARA" "markdown:a Markdown text rendered, its code:ENDCODE" "markdown:a Markdown text rendered, its table:ENDCELL" \
		"raw:the same text raw:ENDPARA" "members:a table of the left pane, the members, under their summary:ENDMEMBER" "grants:a table of the left pane, a member's grants:ENDCOVERS" "help:a member's help:ENDHELP" ; do
	rigTag="${rigCaseOf%%:*}" ; rigRest="${rigCaseOf#*:}" ; rigWhat="${rigRest%:*}" ; rigWord="${rigRest##*:}"
	rigAssert "$rigWhat: wrapped, nothing cut and $rigWord in view; cut, a line each, out of view, and the pane scrolls sideways" \
		"$( rigView "${rigTag}on" "$rigWord" ) | $( rigView "${rigTag}off" "$rigWord" | LC_ALL=C sed 's/ [0-9]* / /' ) | $( printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^${rigTag}pan.viewLeft=//p" | LC_ALL=C awk '{ print ( $1 > 0 ) }' )" \
		"[wrap] 0 1 | [cut] 0 | 1"
done
echo "-- the header of a table stays over its rows: scrolled down, and scrolled sideways with its columns --"
rigScript <<RIGSCRIPT
turn
wait list 10
keys 5
wait list 10
keys DOWN DOWN DOWN
wait focus 10
keys ENTER
wait list 10
keys DOWN
wait focus 10
turn
show top
keys e TAB PGDN
turn
get down
show down
keys w PGDN
turn
keys RIGHT RIGHT
turn
get side
show side
RIGSCRIPT
rigFirst(){ ## tag -- the first line of the body of the left pane, without the spaces at its end
	rigPane "$1" | head -1 | LC_ALL=C sed 's/  *$//'
}
rigAt(){ ## tag, line of the body counted from 1, text -- the cell the text starts at on that line, or none
	rigPane "$1" | LC_ALL=C sed -n "${2}p" | "$rigPython" -I -B -c 'import sys; line = sys.stdin.read(); print(line.find(sys.argv[1]))' "$3"
}
rigAssert "at the top the header is the first line of the pane, scrolled down it still is, over rows far from the first; cut and scrolled sideways it moves with its columns, SIZE over the sizes" \
	"$( rigPane top | LC_ALL=C sed -n '1p' | LC_ALL=C awk '{ print $1 }' ) $( rigFirst down | LC_ALL=C awk '{ print $1, $2 }' ) $( rigPane down | LC_ALL=C sed -n '2p' | LC_ALL=C grep -c 'item-01' ) $( rigVal side.viewTop | LC_ALL=C awk '{ print ( $1 > 0 ) }' ) $( rigVal side.viewLeft | LC_ALL=C awk '{ print ( $1 > 0 ) }' ) $( [ "$( rigAt side 1 SIZE )" = "$( rigAt side 2 100B )" ] && [ "$( rigAt side 1 SIZE )" -ge 0 ] && echo over || echo apart )" \
	"NAME NAME SIZE 0 1 1 over"
rigAssert "nothing was drawn past a pane" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'DRIVER-FAILED\|Traceback' || : )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN WRAP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_WRAP: OK (%d assertions, offline)\n' "$rigPassCount"
