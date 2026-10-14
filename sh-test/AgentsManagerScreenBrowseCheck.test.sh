#!/usr/bin/env bash
## Behavioural check on browsing in the manager screen (sh-lib/AgentsManagerScreen.py): the items of the team data
## in `Team Data` (P13), and a team member as a folder (P14), run rather than read. The screen's own code runs
## through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.test.py), and where it would
## call the dispatcher it calls a stand-in script (check-fixtures/manager-screen.tools.test.sh), which notes each
## start and prints the fixture.
## Held: `Team Data` holds Board, Audit and Vault as folders after Operations; a store selected says what it holds,
## folder by folder, and a store that is empty or not there says so plainly; a folder of it lists its items, and a
## selected item shows its text, read by its store, its folder (`-` the store itself) and its name. A member of
## `Team Members` is a folder, with the mark of one after its name, but one whose workspace cannot be reached; its
## own summary counts its grants by kind and says that Permissions holds them; inside it, Permissions is its grants
## as a table under a heading for each kind, a selected grant whole; Skillset Files its files, a selected one shown
## whole where it is text and never read where it is not; Sessions the sessions it is in, each opening where a
## session does, in Sessions (Activity); Member Help its help as the tooling gives a member its help, whole on the
## folder, and an item for each operation, its block alone, one with no block saying so. The operations are called
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
	printf 'item\tboard\trunning\ttask-20261001T0900Z-a.md\t1200\t20261001T0900\nitem\tboard\trunning\ttask-b.md\t336\t-\n' > "rows.--manager-team-data-read board running"
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
rigAssert "a folder of it selected says how many items and how much, the newest first" "$( rigHolds running '│running: 2 items, 1.5K.' ) $( rigHolds running '│  task-20261001T0900Z-a.md' ) $( rigWords '[--manager-team-data-read][board][running]' )" "1 1 1"
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
rigAssert "its own summary counts its grants by kind and says that Permissions holds them" "$( rigHolds on '│its grants: 3, floor 2, standing 1' ) $( rigHolds on '│  Permissions holds them as a table.' ) $( rigHolds on 'ws:source/x/**' )" "1 1 0"
rigAssert "inside it: Permissions, Skillset Files, Sessions and Member Help, each a folder" "$( rigVal in.path ) $( rigVal in.rows ) $( rigFolderHolds in ' Permissions ' ) $( rigFolderHolds in ' Skillset Files ' ) $( rigFolderHolds in ' Sessions ' ) $( rigFolderHolds in ' Member Help ' )" "team/keeper-rig 5 1 1 1 1"
rigAssert "Permissions selected counts its grants by kind, from the read of the member" "$( rigHolds perms '│3 grants: floor 2, standing 1.' ) $( rigWords '[--manager-team-member-read][keeper-rig]' | LC_ALL=C awk '{ print ( $1 > 0 ) }' )" "1 1"
rigAssert "inside, its grants are a table under a heading for each kind" "$( rigHolds grant ' COVERS ' ) $( rigHolds grant ' ACCESS ' ) $( rigHolds grant ' floor (2)' ) $( rigHolds grant ' standing (1)' ) $( rigVal grant.selectedLabel )" "1 1 1 1 ws:source/**/README.md"
rigAssert "a selected grant shows whole: the path it covers and the rule of its location" "$( rigHolds grant '│covers    /rig/ws/source/**/README.md' ) $( rigHolds grant '│rule      ws:source/**/README.md' ) $( rigHolds grant '│from      floor' )" "1 1 1"
rigAssert "a skillset file selected shows whole, read by the member and its path" "$( rigHolds file '│# The rig keeper' ) $( rigWords '[--manager-team-member-files][keeper-rig]' | LC_ALL=C awk '{ print ( $1 > 0 ) }' ) $( rigWords '[--manager-team-member-files][keeper-rig][SKILL.md]' )" "1 1 1"
rigAssert "one that is no text says so and is never read" "$( rigHolds icon '│resources/icon.png: 1.4K, no text: it is not shown.' ) $( rigWords '[--manager-team-member-files][keeper-rig][resources/icon.png]' )" "1 0"
rigAssert "Sessions selected counts the sessions it is in; Enter on one opens it where a session does" "$( rigHolds sessions '│1 session: 1 running' ) $( rigVal jumped.path )" "1 sessions/sess-1"

echo "-- 3. Member Help --"
rigCase help
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
rigAssert "Member Help selected shows the member's help whole, as the tooling gives it" "$( rigHolds whole '│📘 syntax: DistroAgentsTools.fn.sh --member-help <team-member>' ) $( rigHolds whole 'Read-only. Prints its help.' ) $( rigHolds whole 'Its second line.' ) $( rigWords '[--member-help][keeper-rig]' | LC_ALL=C awk '{ print ( $1 > 0 ) }' )" "1 1 1 1"
rigAssert "inside, an item for each operation of the help, then each its syntax names with no block" "$( rigVal in.rows ) $( rigHolds entry ' --member-help ' ) $( rigHolds entry ' --member-board-item-read ' ) $( rigHolds entry ' --console-list ' )" "4 1 1 1"
rigAssert "an operation selected shows its block alone: its syntax lines and its text" "$( rigHolds entry '│--member-board-item-read <team-member> <item-name> --board-state <state>' ) $( rigHolds entry '│    Reads one item.' ) $( rigHolds entry 'Prints its help.' )" "1 1 0"
rigAssert "one with no block in the help says so plainly" "$( rigHolds none '│It has no description block in the help.' )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN BROWSE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_BROWSE: OK (%d assertions, offline)\n' "$rigPassCount"
