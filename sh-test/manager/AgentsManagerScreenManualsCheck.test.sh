#!/usr/bin/env bash
## Behavioural check on the manuals of the root `Manuals (Help)` of the manager screen (sh-lib/manager/AgentsManagerScreen.py, F11.9 of the
## refactorings epic), run rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which notes each start and prints the fixture. The folders of the root and
## its default selection are held by AgentsManagerScreenManualsFoldersCheck; the operation that lists the manuals, by
## AgentsManagerManualReadCheck; the commands, by AgentsManagerScreenConfigurationCheck.
## Held: the root stands last, a folder, with the number of its place; selected, the left window is a table of its three
## folders, each with what it holds, and it asks the tooling for nothing; `User Manuals` and `Maintainer Manuals`, each
## read once by their kind (`--manager-manual-read user`, `maintainer`), hold a row for each project that has the manual,
## by the name of the project, in the order the operation gives, the build order; on the row that goes up the folder shows
## itself, a numbered table of the projects; the key `a` shows them by name, and again in the build order, the status line
## saying which, and the key of the filter of the active ones is none there; a project selected
## is read alone, once (`--manager-manual-read <kind> <project>`), and its manual shows as Markdown, rendered, its title
## saying so; `g` shows it as it is, and `b` renders it again. Offline: no operation of the real tooling is called.
## Reconciled for F11.5: Manuals (Help) is the eighth root, key 8, since Team Data stands under Magic-Team (Agents) and is no root.
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
rigTmp="$( rigTempDir AgentsManagerScreenManualsCheck )" || exit 1
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
rigCase(){ ## name -- a rig of its own, every fixture of this check in it: three projects with a user manual, in the build order zeta, alpha, mid; two with a maintainer manual
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG/rows.--manager-manual-read user ns" "$MANAGER_SCREEN_RIG/rows.--manager-manual-read maintainer ns"
	cd "$MANAGER_SCREEN_RIG" || exit 1
	printf 'ns/zeta\t/rig/source/ns/zeta/README.md\nns/alpha\t/rig/source/ns/alpha/README.md\nns/mid\t/rig/source/ns/mid/README.md\n' > "rows.--manager-manual-read user"
	printf 'ns/zeta\t/rig/source/ns/zeta/MAGIC.md\nns/alpha\t/rig/source/ns/alpha/MAGIC.md\n' > "rows.--manager-manual-read maintainer"
	printf '# Alpha rig\n\nAlpha is the **first** project.\n\n- an item\n\n```\ncode line\n```\n' > "rows.--manager-manual-read user ns/alpha"
	printf '# Zeta maintainer\n\nNotes of **zeta** for the maintainer.\n' > "rows.--manager-manual-read maintainer ns/zeta"
	: > "$MANAGER_SCREEN_RIG/calls"
	: > "$MANAGER_SCREEN_RIG/words"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize 120 36\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
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
rigCell(){ ## name -- the cells that `cells <name>` read, the blanks at both ends taken off
	rigVal "$1" | LC_ALL=C sed -e 's/^[ >]*//' -e 's/ *[►~].*$//' -e 's/  *$//'
}
rigCalls(){ ## words -- how many starts of the stand-in had exactly these words, each between brackets
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/words" || :
}

echo "-- 1. the root: a folder with its number; selected, a table of its three folders, and nothing asked of the tooling --"
rigCase root
rigScript <<'RIGSCRIPT'
turn
wait list 10
get on
show on
keys 1
turn
keys 9
wait list 10
get k9
keys m
turn
show go
RIGSCRIPT
rigAssert "Manuals (Help) is the last root, a folder" "$( rigVal on.selectedLabel ) $( rigFolderHolds on '>Manuals (Help) ' )" "Manuals (Help) 1"
rigAssert "selected, the left window is a table of its three folders, each with what it holds" "$( rigHolds on '│ FOLDER' ) $( rigHolds on 'User Manuals  ' ) $( rigHolds on 'the README.md of each project, in build order' ) $( rigHolds on 'Maintainer Manuals  ' ) $( rigHolds on 'the MAGIC.md of each project, in build order' ) $( rigHolds on 'the commands a console user calls by name' )" "1 1 1 1 1 1"
rigAssert "it asks the tooling for none of its manuals: resting on the root and going to it reads no manual, no help and no command" "$( rigCalls '[--manager-manual-read][user]' ) $( rigCalls '[--manager-manual-read][maintainer]' ) $( rigCalls '[--manager-help-read]' ) $( rigCalls '[--manager-command-list]' )" "0 0 0 0"
rigAssert "its number is that of its place: 9, since Team Data stands under Magic-Team (Agents) and is no root, and the menu Go names it so" "$( rigVal k9.path ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^go|' | LC_ALL=C grep -c -E 'Manuals \(Help\)  *9 ' )" "configuration 0"

echo "-- 2. User Manuals: a row for each project that has a README.md, by its name, in the build order --"
rigCase user
rigScript <<'RIGSCRIPT'
turn
root manuals
keys ENTER
wait list 10
keys DOWN
wait focus 10
turn
get on
show on
keys ENTER
wait list 10
turn
get in
border title 1 84 120
cells r1 3 85 119
cells r2 4 85 119
cells r3 5 85 119
cells r4 6 85 119
show up
RIGSCRIPT
rigAssert "resting on it reads the manuals of that kind, once, and the left window is a numbered table of the projects in the build order" "$( rigVal on.selectedLabel ) $( rigCalls '[--manager-manual-read][user]' ) $( rigHolds on 'PROJECT' ) $( rigHolds on '1  ns/zeta' ) $( rigHolds on '2  ns/alpha' ) $( rigHolds on '3  ns/mid' )" "User Manuals 1 1 1 1 1"
rigAssert "entered, it holds a row for each project, by its name, in the order the operation gave them, under the row that goes up" "$( rigVal in.path ) $( rigVal in.rows ) [$( rigCell r1 )][$( rigCell r2 )][$( rigCell r3 )] [$( rigVal title )]" "manuals/user 4 [ns/zeta][ns/alpha][ns/mid] [User Manuals]"
rigAssert "entering it asked for nothing more, and on the row that goes up the folder shows itself" "$( rigCalls '[--manager-manual-read][user]' ) $( rigHolds up '1  ns/zeta' )" "1 1"

echo "-- 3. the key a: by name, and again in the build order --"
rigCase alphabetical
rigScript <<'RIGSCRIPT'
turn
root manuals
keys ENTER
wait list 10
keys DOWN
wait focus 10
keys ENTER
wait list 10
keys a
turn
get alpha
border atitle 1 84 120
cells a1 3 85 119
cells a2 4 85 119
cells a3 5 85 119
show astatus
keys a
turn
border btitle 1 84 120
cells b1 3 85 119
cells b2 4 85 119
cells b3 5 85 119
show bstatus
RIGSCRIPT
rigAssert "a shows the projects by name" "[$( rigCell a1 )][$( rigCell a2 )][$( rigCell a3 )]" "[ns/alpha][ns/mid][ns/zeta]"
rigAssert "the status line names the key for the way back, and the key of the active ones is none here" "$( rigHolds astatus ' a Build order ' ) $( rigHolds astatus ' a Active ' )" "1 0"
rigAssert "a again shows them in the build order" "[$( rigCell b1 )][$( rigCell b2 )][$( rigCell b3 )] $( rigHolds bstatus ' a Alphabetical ' )" "[ns/zeta][ns/alpha][ns/mid] 1"

echo "-- 4. a project selected: its README.md, read alone, shown as Markdown, rendered; g raw, b rendered again --"
rigCase readme
rigScript <<'RIGSCRIPT'
turn
root manuals
keys ENTER
wait list 10
keys DOWN
wait focus 10
keys ENTER
wait list 10
keys DOWN DOWN
wait view 10
turn
get on
show md
roles mdr
keys g
turn
get raw
show raw
keys b
turn
show back
RIGSCRIPT
rigAssert "it is read by its project's name, once, and no other project's manual was read" "$( rigVal on.selectedLabel ) $( rigCalls '[--manager-manual-read][user][ns/alpha]' ) $( LC_ALL=C grep -c -e '^--manager-manual-read user ns/' "$MANAGER_SCREEN_RIG/calls" )" "ns/alpha 1 1"
rigAssert "it shows rendered: its heading without its mark, its strong words without theirs, its list with its mark, its code as it is, and its title says Markdown" "$( rigHolds md '│Alpha rig' ) $( rigHolds md '# Alpha rig' ) $( rigHolds md 'Alpha is the first project.' ) $( rigHolds md '**' ) $( rigHolds md '➤ an item' ) $( rigHolds md '│code line' ) $( rigHolds md 'ns/alpha [markdown]' )" "1 0 1 0 1 1 1"
rigAssert "g shows it as it is, and says so" "$( rigVal raw.textMode ) $( rigHolds raw '│# Alpha rig' ) $( rigHolds raw '**first**' ) $( rigHolds raw 'ns/alpha [raw]' )" "raw 1 1 1"
rigAssert "b renders it again" "$( rigHolds back '│Alpha rig' ) $( rigHolds back '➤ an item' ) $( rigHolds back 'ns/alpha [markdown]' )" "1 1 1"

echo "-- 5. Maintainer Manuals: the MAGIC.md of each project, by the same rules --"
rigCase maintainer
rigScript <<'RIGSCRIPT'
turn
root manuals
keys ENTER
wait list 10
keys DOWN DOWN DOWN
wait focus 10
turn
get on
show on
keys ENTER
wait list 10
turn
get in
border title 1 84 120
cells r1 3 85 119
cells r2 4 85 119
cells r3 5 85 119
keys DOWN
wait view 10
turn
get zeta
show md
keys a
turn
cells a1 3 85 119
cells a2 4 85 119
border atitle 1 84 120
RIGSCRIPT
rigAssert "resting on it reads the manuals of its kind, once, and the left window is a numbered table of the two projects in the build order" "$( rigVal on.selectedLabel ) $( rigCalls '[--manager-manual-read][maintainer]' ) $( rigCalls '[--manager-manual-read][user]' ) $( rigHolds on '1  ns/zeta' ) $( rigHolds on '2  ns/alpha' ) $( rigHolds on 'ns/mid' )" "Maintainer Manuals 1 0 1 1 0"
rigAssert "entered, it holds a row for each of the two, by its name, in the build order" "$( rigVal in.path ) $( rigVal in.rows ) [$( rigCell r1 )][$( rigCell r2 )] [$( rigVal title )]" "manuals/maintainer 3 [ns/zeta][ns/alpha] [Maintainer Manuals]"
rigAssert "a project selected: its MAGIC.md is read alone, once, and shows rendered" "$( rigVal zeta.selectedLabel ) $( rigCalls '[--manager-manual-read][maintainer][ns/zeta]' ) $( rigHolds md 'Zeta maintainer' ) $( rigHolds md '# Zeta maintainer' ) $( rigHolds md 'ns/zeta [markdown]' )" "ns/zeta 1 1 0 1"
rigAssert "a shows them by name here too" "[$( rigCell a1 )][$( rigCell a2 )]" "[ns/alpha][ns/zeta]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN MANUALS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_MANUALS: OK (%d assertions, offline)\n' "$rigPassCount"
