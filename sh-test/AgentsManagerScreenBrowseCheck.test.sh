#!/usr/bin/env bash
## Behavioural check on browsing in the manager screen (sh-lib/AgentsManagerScreen.py): the items of the team data
## in `Team Data` (P13), and a team member as a folder (P14), run rather than read. The screen's own code runs
## through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.test.py), and where it would
## call the dispatcher it calls a stand-in script (check-fixtures/manager-screen.tools.test.sh), which notes each
## start and prints the fixture.
## Held: `Team Data` holds Board, Audit and Vault as folders after Operations; a store selected says what it holds,
## folder by folder, and a store that is empty or not there says so plainly; a folder of it selected shows its items
## as a table, from the front matter the read gives, a column no item has a word for left out, its first rows, and
## `e`, named in the status line and in the title, every row; entered it lists its items, and a
## selected item shows its text, read by its store, its folder (`-` the store itself) and its name. A member of
## `Team Members` is a folder, with the mark of one after its name, but one whose workspace cannot be reached; its
## own summary shows its basic information alone, nothing of its settings or its grants; inside it, Permissions
## selected shows its grants as a table under their counts, fitted to the pane: the first column shortened so that
## the others fit, one that still does not left out whole, and with the lines not wrapped the whole table, scrolled
## sideways; and entered is its grants
## as a table under a heading for each kind, a selected grant whole; Skillset Files its files, a selected one shown
## whole where it is text and never read where it is not; Sessions the sessions it is in, each opening where a
## session does, in Sessions (Activity); Member Help on the folder the text of the help before its first option, the
## member's syntax lines, then the chapters after the options, the chapters by --manager-help-read, rendered, and none
## of the blocks of its operations, and inside an item for each operation, its block alone, one with no block saying so. The operations are called
## exactly as the tooling has them. Offline: no operation of the real tooling is called.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.test.py"
rigTools="$rigFixtures/manager-screen.tools.test.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
rigTmp="$( mktemp -d -t AgentsManagerScreenBrowseCheck )" || exit 1
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
rigCase(){ ## name -- a rig of its own, every fixture of this check in it
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cd "$MANAGER_SCREEN_RIG" || exit 1
	printf 'block\tteam-data\tTeam_Data\t2\nfigure\tteam-data\troot\tTeam_Data_Root\t/rig/td\t-\t-\t-\nfigure\tteam-data\tpresent\tTeam_Data_Present\tyes\t-\tok\t-\n' > "rows.--manager-dashboard-read"
	cp "rows.--manager-dashboard-read" "rows.--manager-dashboard-read team-data team-data-git loop"
	printf 'store\tboard\tpresent\t2\t0\nfolder\tboard\trunning\t2\nfolder\tboard\treview\t1\n' > "rows.--manager-team-data-read board"
	printf 'item\tboard\trunning\ttask-20261001T0900Z-a.md\t1200\t20261001T0900\ttask\trunning\tkeeper-rig\t2026-10-01_09:00_+0000\nitem\tboard\trunning\ttask-b.md\t336\t-\t-\t-\t-\t-\n' > "rows.--manager-team-data-read board running"
	printf -- '---\ntitle: A\n---\nThe body of task a.\n' > "rows.--manager-team-data-read board running task-20261001T0900Z-a.md"
	printf 'store\taudit\tpresent\t1\t1\nfolder\taudit\t2026-10\t0\nitem\taudit\t-\tdeclaration-20260928T0000Z-x.md\t5\t20260928T0000\n' > "rows.--manager-team-data-read audit"
	printf 'A declaration.\n' > "rows.--manager-team-data-read audit - declaration-20260928T0000Z-x.md"
	printf 'store\tvault\tpresent\t0\t0\n' > "rows.--manager-team-data-read vault"
	rigMember="member	keeper-rig	-	Rig	Keeper	-	keeper	/rig/ws	here	active	no-process	-"
	printf '%s\nmember\tkeeper-far\t-\tFar\tKeeper\t-\tkeeper\t-\tnot-present\tactive\tno-process\t-\n' "$rigMember" > "rows.--manager-team-member-list"
	{
		printf '%s\ninfo\tdescription\tA_rig_keeper\n' "$rigMember"
		printf 'session\tsess-1\tA_session\trunning\t2026-10-13T01:00Z\t-\t1\t-\n'
		printf 'run\tsess-1\tsp-1\tkeeper-rig\topen\trunning\tworking\t2026-10-13T01:00Z\t-\thost\t/rig/ws\t-\n'
		printf 'grant\tfloor\tread\t/rig/ws/source/**/README.md\tws:source/**/README.md\tfloor\tnone\n'
		printf 'grant\tstanding\twrite\t/rig/ws/source/x/**\tws:source/x/**\tws:workspace\tnone\n'
		printf 'grant\tfloor\twrite\t/rig/ws/.local/temp/**\tws:.local/temp/**\tfloor\tnone\n'
	} > "rows.--manager-team-member-read keeper-rig"
	printf 'file\tSKILL.md\t1889\tyes\nfile\tresources/icon.png\t1473\tno\n' > "rows.--manager-team-member-files keeper-rig"
	printf -- '---\nname: keeper-rig\n---\n# The rig keeper\n' > "rows.--manager-team-member-files keeper-rig SKILL.md"
	printf '📘 syntax: DistroAgentsTools.fn.sh --member-help <team-member>\n📘 syntax: DistroAgentsTools.fn.sh --console-list [--override-workspace <path>]\n\n\t\t--member-help <team-member>\n\t\t\tRead-only. Prints its help.\n\n\t\t--member-board-item-read <team-member> <item-name>\n\t\t--member-board-item-read <team-member> <item-name> --board-state <state>\n\t\t\tReads one item.\n\t\t\tIts second line.\n\n' > "rows.--member-help keeper-rig"
	: > "$MANAGER_SCREEN_RIG/calls"
	: > "$MANAGER_SCREEN_RIG/words"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\nwall 2026-10-13 02:30 +0000\nsize 120 36\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigFolderHolds(){ ## tag, text -- how many lines of that whole screen hold the text and, on the same line, the mark of a folder: a row that is one
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -F -- "$2" | LC_ALL=C grep -c -F '►' || :
}
rigHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigWords(){ ## text -- how many starts of the stand-in had exactly these words, each between brackets
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/words" || :
}
rigUnder(){ ## tag, text, count -- that many lines of the left pane of that screen from the one that is exactly the text, each between brackets, without the spaces at their ends
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -E -e "s/^$1\|(│|║)//" -e 's/(│|║).*$//' -e 's/  *$//' \
		| LC_ALL=C awk -v text="$2" -v count="$3" '$0 == text && !n { n = count } n > 0 { printf "[%s]", $0 ; n-- }'
}
rigItemLine(){ ## the words of a row of the table of a folder's items, in the columns the fixture gives it -- that row as the table draws it
	printf ' %-24s %-4s %-16s %-10s %-7s %s' "$@"
}
rigGrantLine(){ ## the cells of its first column, then the words of a row of the table of grants, all four or the first two -- that row as the table draws it
	local coversCells="$1" ; shift
	case $# in
		4) printf ' %-*s %-6s %-12s %s' "$coversCells" "$1" "$2" "$3" "$4" ;;
		2) printf ' %-*s %s' "$coversCells" "$1" "$2" ;;
	esac
}

echo "-- 1. Team Data: its board, its audit and its vault, browsed --"
rigCase data
rigScript <<'RIGSCRIPT'
turn
wait list 10
keys 5
wait list 10
get in
show in
keys DOWN DOWN
wait focus 10
get board
show board
keys ENTER
wait list 10
keys DOWN
wait focus 10
get running
show running
keys ENTER
wait list 10
keys DOWN
wait view 10
get item
show item
keys BACKSPACE BACKSPACE DOWN
wait focus 10
keys ENTER
wait list 10
keys DOWN DOWN
wait view 10
show audit
keys BACKSPACE DOWN
wait focus 10
show vault
RIGSCRIPT
rigAssert "Team Data holds Operations, then Board, Audit and Vault as folders, then its blocks" "$( rigVal in.rows ) $( rigFolderHolds in ' Operations ' ) $( rigFolderHolds in ' Board ' ) $( rigFolderHolds in ' Audit ' ) $( rigFolderHolds in ' Vault ' ) $( rigHolds in '║ Team Data ' )" "6 1 1 1 1 1"
rigAssert "Board selected says what it holds, folder by folder, from its read" "$( rigVal board.selectedLabel ) $( rigHolds board '│Board: 3 items in 2 folders.' ) $( rigHolds board '│  running 2' ) $( rigHolds board '│  review  1' ) $( rigWords '[--manager-team-data-read][board]' )" "Board 1 1 1 1"
rigAssert "a folder of it selected says how many items and how much, then its items as a table, the newest first, from the one read of the folder: the name, then what the front matter gives, its type, its date, its owner and its status, and the size; one with no front matter and no stamp has none" \
	"$( rigUnder running 'running: 2 items, 1.5K.' 5 ) $( rigWords '[--manager-team-data-read][board][running]' )" \
	"[running: 2 items, 1.5K.][][$( rigItemLine NAME TYPE DATE OWNER STATUS SIZE )][$( rigItemLine task-20261001T0900Z-a.md task '2026-10-01 09:00' keeper-rig running 1.2K )][$( rigItemLine task-b.md - - - - 336B )] 1"
rigAssert "a folder of no more items than it shows has no key for every row: e is named nowhere" "$( rigHolds running 'All rows' ) $( rigHolds running 'and 0 more' )" "0 0"
rigAssert "an item selected shows its text, read by its store, its folder and its name" "$( rigVal item.path ) $( rigHolds item '│The body of task a.' ) $( rigWords '[--manager-team-data-read][board][running][task-20261001T0900Z-a.md]' )" "teamdata/board/running 1 1"
rigAssert "an item in the store itself is read by - for its folder" "$( rigHolds audit '│A declaration.' ) $( rigWords '[--manager-team-data-read][audit][-][declaration-20260928T0000Z-x.md]' )" "1 1"
rigAssert "an empty vault says so plainly" "$( rigHolds vault '│Vault: empty. It holds no items.' )" "1"
rigCase absent
printf 'store\tvault\tabsent\t0\t0\n' > "$MANAGER_SCREEN_RIG/rows.--manager-team-data-read vault"
rigScript <<'RIGSCRIPT'
turn
wait list 10
keys 5
wait list 10
keys DOWN DOWN DOWN DOWN
wait focus 10
show vault
RIGSCRIPT
rigAssert "a vault that is not there says so plainly" "$( rigHolds vault '│Vault: there is none in this team data: it has no such folder.' )" "1"

echo "-- 1b. a folder of more items than the pane shows: as many as it shows, and e every row --"
rigCase many
printf 'store\tboard\tpresent\t1\t0\nfolder\tboard\tbacklog\t60\n' > "$MANAGER_SCREEN_RIG/rows.--manager-team-data-read board"
for rigNo in $( seq -w 1 60 ) ; do printf 'item\tboard\tbacklog\titem-%s.md\t100\t-\t-\t-\t-\t-\n' "$rigNo" ; done > "$MANAGER_SCREEN_RIG/rows.--manager-team-data-read board backlog"
rigScript <<'RIGSCRIPT'
turn
wait list 10
keys 5
wait list 10
keys DOWN DOWN
wait focus 10
keys ENTER
wait list 10
keys DOWN
wait focus 10
get first
show first
keys e
turn
get all
show all
keys e
turn
show again
keys ENTER
wait list 10
keys DOWN
turn
show inside
RIGSCRIPT
rigShown="$( rigHolds first '│ item-' )"
rigAssert "as many of them as the pane has room for, under the count, a blank line and the header, and a last line for how many more: the pane is full; the columns no item has a word for left out" \
	"$( rigUnder first 'backlog: 60 items, 5.9K.' 4 ) $(( rigShown + 4 )) $( rigUnder first "$( printf ' %-10s %s' "item-$( printf '%02d' "$rigShown" ).md" 100B )" 2 )" \
	"[backlog: 60 items, 5.9K.][][$( printf ' %-10s %s' NAME SIZE )][$( printf ' %-10s %s' item-01.md 100B )] $( rigVal first.viewHeight ) [$( printf ' %-10s %s' "item-$( printf '%02d' "$rigShown" ).md" 100B )][  and $(( 60 - rigShown )) more]"
rigAssert "the status line names e for every row, and the title says how many rows show" "$( rigHolds first ' e All rows ' ) $( rigHolds first "backlog [$rigShown rows]" )" "1 1"
rigAssert "e: every row, all 60 under the 3 lines above them, the status line names it for as many rows again, the title says all rows, and nothing is read again" \
	"$( rigVal all.selected ) $( rigVal all.viewLines ) $( rigHolds all 'more' ) $( rigHolds all ' e First rows ' ) $( rigHolds all 'backlog [all rows]' ) $( rigWords '[--manager-team-data-read][board][backlog]' )" "backlog 63 0 1 1 1"
rigAssert "e once more: as many as the pane shows again" "$( rigHolds again '│ item-' ) $( rigHolds again "│  and $(( 60 - rigShown )) more" )" "$rigShown 1"
rigAssert "inside the folder, an item selected: e is named nowhere" "$( rigHolds inside 'All rows' ) $( rigHolds inside 'First rows' ) $( rigHolds inside 'rows]' )" "0 0 0"

echo "-- 2. a team member is a folder --"
rigCase member
rigScript <<'RIGSCRIPT'
turn
wait list 10
keys 4
wait list 10
keys DOWN
wait view 10
show on
keys ENTER
wait list 10
get in
show in
keys DOWN
wait focus 10
show perms
keys ENTER
wait list 10
keys DOWN DOWN
get grant
show grant
keys BACKSPACE DOWN
wait focus 10
keys ENTER
wait list 10
keys DOWN
wait view 10
show file
keys DOWN
turn
show icon
keys BACKSPACE DOWN
wait focus 10
show sessions
keys ENTER
wait list 10
keys DOWN
keys ENTER
get jumped
RIGSCRIPT
rigAssert "a member is a folder, with the mark of one; one whose workspace cannot be reached is none" "$( rigFolderHolds on '>keeper-rig ' ) $( rigFolderHolds on ' keeper-far ' ) $( rigHolds on ' keeper-far ' )" "1 0 1"
rigAssert "its own summary shows its basic information alone: nothing of its settings or its grants, no table of them" "$( rigHolds on 'its settings' ) $( rigHolds on 'its grants' ) $( rigHolds on ' COVERS ' ) $( rigHolds on 'ws:source/**/README.md' ) $( rigHolds on '│for       A rig keeper' )" "0 0 0 0 1"
rigAssert "inside it: Permissions, Skillset Files, Sessions and Member Help, each a folder" "$( rigVal in.path ) $( rigVal in.rows ) $( rigFolderHolds in ' Permissions ' ) $( rigFolderHolds in ' Skillset Files ' ) $( rigFolderHolds in ' Sessions ' ) $( rigFolderHolds in ' Member Help ' )" "team/keeper-rig 5 1 1 1 1"
rigAssert "Permissions selected counts its grants by kind, from the read of the member" "$( rigHolds perms '│3 grants: floor 2, standing 1.' ) $( rigWords '[--manager-team-member-read][keeper-rig]' | LC_ALL=C awk '{ print ( $1 > 0 ) }' )" "1 1"
rigAssert "and right under its counts, as their caption, its grants as the table of the member's own summary: its header, a heading for each kind and a row for each grant; no hint stands before it" \
	"$( rigUnder perms '3 grants: floor 2, standing 1.' 7 ) $( rigHolds perms 'Enter opens them' )" \
	"[3 grants: floor 2, standing 1.][$( rigGrantLine 22 COVERS ACCESS FROM ENDS )][ floor (2)][$( rigGrantLine 22 'ws:source/**/README.md' read floor none )][$( rigGrantLine 22 'ws:.local/temp/**' write floor none )][ standing (1)][$( rigGrantLine 22 'ws:source/x/**' write ws:workspace none )] 0"
rigAssert "inside, its grants are a table under a heading for each kind" "$( rigHolds grant ' COVERS ' ) $( rigHolds grant ' ACCESS ' ) $( rigHolds grant ' floor (2)' ) $( rigHolds grant ' standing (1)' ) $( rigVal grant.selectedLabel )" "1 1 1 1 ws:source/**/README.md"
rigAssert "a selected grant shows whole: the path it covers and the rule of its location" "$( rigHolds grant '│covers    /rig/ws/source/**/README.md' ) $( rigHolds grant '│rule      ws:source/**/README.md' ) $( rigHolds grant '│from      floor' )" "1 1 1"
rigAssert "a skillset file selected shows whole, read by the member and its path" "$( rigHolds file '│The rig keeper' ) $( rigWords '[--manager-team-member-files][keeper-rig]' | LC_ALL=C awk '{ print ( $1 > 0 ) }' ) $( rigWords '[--manager-team-member-files][keeper-rig][SKILL.md]' )" "1 1 1"
rigAssert "one that is no text says so and is never read" "$( rigHolds icon '│resources/icon.png: 1.4K, no text: it is not shown.' ) $( rigWords '[--manager-team-member-files][keeper-rig][resources/icon.png]' )" "1 0"
rigAssert "Sessions selected counts the sessions it is in; Enter on one opens it where a session does" "$( rigHolds sessions '│1 session: 1 running' ) $( rigVal jumped.path )" "1 sessions/sess-1"

echo "-- 2b. the grants of a member, the table Permissions shows selected, follow the width of the pane --"
rigCase widths
rigScript <<'RIGSCRIPT'
turn
wait list 10
keys 4
wait list 10
keys DOWN
wait view 10
keys ENTER
wait list 10
keys DOWN
wait focus 10
size 64 36
turn
get fit
show fit
size 52 36
turn
get narrow
show narrow
size 64 36
turn
keys TAB w
turn
get cut
show cut
keys RIGHT RIGHT
turn
get panned
show panned
RIGSCRIPT
rigAssert "a pane too narrow for every column: the columns after the first, no longer than their longest word, keep it, and the first, the path it covers, gives way, wrapped in its own column, nothing cut" \
	"$( rigVal fit.viewWidth ) $( rigUnder fit '3 grants: floor 2, standing 1.' 5 ) $( rigHolds fit '…' )" \
	"43 [3 grants: floor 2, standing 1.][$( rigGrantLine 16 COVERS ACCESS FROM ENDS )][ floor (2)][$( rigGrantLine 16 'ws:source/**/REA' read floor none )][ DME.md] 0"
rigAssert "a narrower one leaves out whole each column after it that still does not fit, the last first, of the header too, and the room that frees goes back to the first" \
	"$( rigVal narrow.viewWidth ) $( rigUnder narrow "$( rigGrantLine 22 COVERS ACCESS )" 3 ) $( rigVal narrow.spills ) $( rigHolds narrow '…' )" \
	"31 [$( rigGrantLine 22 COVERS ACCESS )][ floor (2)][$( rigGrantLine 22 'ws:source/**/README.md' read )] 0 0"
rigAssert "with the lines not wrapped the table is whole, its first column uncut, and the pane scrolls sideways to the columns after it" \
	"$( rigVal cut.wrap ) $( rigHolds cut ' ws:source/**/README.md read' ) $( rigHolds cut "$( printf '%-12s %s' ws:workspace none )" ) $( rigVal panned.viewLeft | LC_ALL=C awk '{ print ( $1 > 0 ) }' ) $( rigHolds panned "$( printf '%-12s %s' floor none )" ) $( rigHolds panned "$( printf '%-12s %s' ws:workspace none )" )" \
	"no 1 0 1 2 1"

echo "-- 2c. Skillset Files selected: every file as a table, its path, its size and whether it is text --"
rigCase files
for rigNo in $( seq -w 1 19 ) ; do printf 'file\tresources/file-%s.md\t%s\t%s\n' "$rigNo" "$(( 1000 + 10#$rigNo ))" "$( [ "$rigNo" = 07 ] && echo no || echo yes )" ; done > "$MANAGER_SCREEN_RIG/rows.--manager-team-member-files keeper-rig"
rigScript <<'RIGSCRIPT'
turn
wait list 10
keys 4
wait list 10
keys DOWN
wait view 10
keys ENTER
wait list 10
keys DOWN DOWN
wait focus 10
get files
show files
RIGSCRIPT
rigAssert "the left pane shows no fewer files than the list: all 19 as a table under the count, a file a row with its size and whether it is text, nothing left out" \
	"$( rigVal files.selectedLabel ) $( rigUnder files '19 files, 18.7K; 18 of them text.' 4 ) $( rigHolds files '│ resources/file-' ) $( rigHolds files 'more' ) $( rigHolds files 'rows]' ) $( rigHolds files "$( printf ' %-20s %-5s %s' resources/file-07.md 1007B binary )" )" \
	"Skillset Files [19 files, 18.7K; 18 of them text.][][$( printf ' %-20s %-5s %s' NAME SIZE CONTENT )][$( printf ' %-20s %-5s %s' resources/file-01.md 1001B text )] 19 0 0 1"

echo "-- 2d. at the width the owner's screen has: the key column has its room first, the long ones give way, wrapped, nothing cut --"
rigCase owner
{
	printf '%s\n' "$rigMember"
	printf 'grant\tfloor\tread\t/rig/ws/source/myx/myx.distro-agents/sh-lib/AgentsManagerScreen.py\tws:source/myx/myx.distro-agents/sh-lib/AgentsManagerScreen.py\tset-3ef0ea61-ff24-46e7-8299-bb3c5ee6b4fc_by_U75H0DK43\tuntil_session_5680fa0b-cd80-4db6-82cf-1779e5fb10db_ends\n'
	printf 'grant\tfloor\twrite\t/rig/ws/.local/temp/**\tws:.local/temp/**\tfloor\tnone\n'
} > "$MANAGER_SCREEN_RIG/rows.--manager-team-member-read keeper-rig"
rigScript <<'RIGSCRIPT'
size 201 40
turn
wait list 10
keys 4
wait list 10
keys DOWN
wait view 10
keys ENTER
wait list 10
keys DOWN
wait focus 10
get wide
show wide
roles lw
RIGSCRIPT
rigWideLine="$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^wide|' | LC_ALL=C grep -n -F ' ws:source/myx/myx.distro-agents/sh-lib/AgentsManagerScreen.py ' | LC_ALL=C sed 's/:.*$//' | head -1 )"
rigAssert "the path it covers stands whole on the first line of its row; where it comes from and when it ends wrap in their columns, every word of them there; nothing is cut" \
	"$( rigVal wide.columns ) $( rigHolds wide ' ws:source/myx/myx.distro-agents/sh-lib/AgentsManagerScreen.py read' ) $( rigHolds wide 'set-3ef0ea61-' ) $( rigHolds wide 'U75H0DK43' ) $( rigHolds wide '5680fa0b-' ) $( rigHolds wide '…' )" \
	"201 1 1 1 1 0"
rigAssert "the header stands out, and the rows take turns in two looks, every line of a row in its own" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^lw|//p' | LC_ALL=C sed -n "$(( rigWideLine - 2 ))p;$(( rigWideLine ))p;$(( rigWideLine + 1 ))p" | LC_ALL=C cut -c3 | LC_ALL=C tr -d '\n' ) $( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^lw|//p' | LC_ALL=C grep -c '^.j' )" \
	"ucc 1"

echo "-- 3. Member Help --"
rigCase help
printf 'chapter\thead\t\nchapter\thead\t**HEAD-TEXT-OF-THE-HELP** before the summary.\nchapter\thead\t\nchapter\thead\t##  Summary:\nchapter\thead\t\nchapter\thead\t\t\tThe rig tool, in short.\nchapter\thead\t\nchapter\thead\t##  Options:\nchapter\tfoot\t##  Notes:\nchapter\tfoot\t\nchapter\tfoot\t\t\tFOOT-TEXT-OF-THE-HELP after the options.\nchapter\tfoot\t\nchapter\tfoot\t##  Examples:\nchapter\tfoot\t\nchapter\tfoot\t\t\t# Start the rig,\nchapter\tfoot\t\t\t# then stop it\nchapter\tfoot\t\t\t```\nchapter\tfoot\t\t\trig  --start   now\nchapter\tfoot\t\t\t```\n' \
	> "$MANAGER_SCREEN_RIG/rows.--manager-help-read"
rigScript <<'RIGSCRIPT'
turn
wait list 10
keys 4
wait list 10
keys DOWN
keys ENTER
wait list 10
keys DOWN DOWN DOWN DOWN
wait focus 10
show whole
keys ENTER
wait list 10
get in
keys DOWN DOWN
show entry
keys DOWN
show none
RIGSCRIPT
rigAssert "Member Help selected shows the text of the help before its first option, the member's syntax lines, then the chapters after the options, in that order, and no block of an operation" \
	"$( rigHolds whole '│📘 syntax: DistroAgentsTools.fn.sh --member-help <team-member>' ) $( rigHolds whole 'HEAD-TEXT-OF-THE-HELP before the summary.' ) $( rigHolds whole 'FOOT-TEXT-OF-THE-HELP after the options.' ) $( rigHolds whole 'Read-only. Prints its help.' ) $( rigHolds whole 'Its second line.' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^whole|' | LC_ALL=C awk '/HEAD-TEXT/ { a = NR } /--console-list/ && !b { b = NR } /FOOT-TEXT/ { c = NR } END { print ( a && a < b && b < c ) ? "in-order" : "out-of-order" }' )" \
	"1 1 1 0 0 in-order"
rigAssert "the syntax lines are the member's, by --member-help, and the chapters are read by --manager-help-read" "$( rigWords '[--member-help][keeper-rig]' | LC_ALL=C awk '{ print ( $1 > 0 ) }' ) $( rigWords '[--manager-help-read]' | LC_ALL=C awk '{ print ( $1 > 0 ) }' )" "1 1"
rigAssert "the examples of the help, a paragraph whose first line is a comment of the shell, show as they are written, as code, set in: a comment is no heading, a fence and runs of blanks are kept" \
	"$( rigHolds whole '│          # Start the rig,' ) $( rigHolds whole '│          # then stop it' ) $( rigHolds whole '│          ```' ) $( rigHolds whole '│          rig  --start   now' ) $( rigHolds whole '│        Start the rig,' ) $( rigHolds whole '━' )" "1 1 2 1 0 0"
rigAssert "the chapters are Markdown: a heading without its marks, strong words without theirs, the text under a heading as a paragraph" "$( rigHolds whole '│Summary:' ) $( rigHolds whole '│Notes:' ) $( rigHolds whole '##' ) $( rigHolds whole '**' ) $( rigHolds whole '│        The rig tool, in short.' )" "1 1 0 0 1"
rigAssert "inside, an item for each operation of the help, then each its syntax names with no block" "$( rigVal in.rows ) $( rigHolds entry ' --member-help ' ) $( rigHolds entry ' --member-board-item-read ' ) $( rigHolds entry ' --console-list ' )" "4 1 1 1"
rigAssert "an operation selected shows its block alone: its syntax lines and its text" "$( rigHolds entry '│--member-board-item-read <team-member> <item-name> --board-state <state>' ) $( rigHolds entry '│    Reads one item.' ) $( rigHolds entry 'Prints its help.' )" "1 1 0"
rigAssert "one with no block in the help says so plainly" "$( rigHolds none '│It has no description block in the help.' )" "1"
rigAssert "the help is Markdown: an operation's block rendered, a paragraph's lines as one, and the titles say so" "$( rigHolds entry '│    Reads one item. Its second line.' ) $( rigHolds entry '--member-board-item-read [markdown]' ) $( rigHolds whole 'Member Help [markdown]' )" "1 1 1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN BROWSE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_BROWSE: OK (%d assertions, offline)\n' "$rigPassCount"
