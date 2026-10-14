#!/usr/bin/env bash
## Behavioural check on the root `Manuals (Help)` of the manager screen (sh-lib/AgentsManagerScreen.py, P15), run
## rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.test.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.test.sh), which notes each start and prints the fixture.
## Held: the root stands last in the root list, a folder, with the number of its place; selected, the left window
## shows what the bare call of the tool prints, as the tooling gives it by --manager-help-read, and no entry of an
## operation; entered, it holds an item for every operation of the help, as `Member Help` holds a member's, each
## showing its block alone, and one whose syntax names it with no block in the help says so plainly; on the row that
## goes up the folder shows itself. The operation is called exactly as the tooling has it. Offline: no operation of
## the real tooling is called.
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
rigTmp="$( mktemp -d -t AgentsManagerScreenManualsCheck )" || exit 1
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
	printf '📘 syntax: DistroAgentsTools.fn.sh --agents-config-option <id> <op>\n📘 syntax: DistroAgentsTools.fn.sh --owner-setup-<domain>\n📘 syntax: DistroAgentsTools.fn.sh [--help]\n\n📘 syntax: DistroAgentsTools.fn.sh --agents-config-option <id> <op>\n📘 syntax: DistroAgentsTools.fn.sh --console-list\n\t\t--agents-config-option <id> <op>\n\t\t\tReads or writes one option.\n\n\t\t--owner-setup-<domain>\n\t\t--owner-setup-<domain> --apply\n\t\t\tSets up one domain.\n\t\t\tIts second line.\n\n' > "rows.--manager-help-read"
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

echo "-- 1. the root: last, a folder; selected, what the bare call prints --"
rigCase root
rigScript <<'RIGSCRIPT'
turn
wait list 10
keys PGDN
wait focus 10
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
rigAssert "selected, the left window shows the bare call's lines, as the tooling gives them, and no entry" "$( rigHolds on '│📘 syntax: DistroAgentsTools.fn.sh --agents-config-option <id> <op>' ) $( rigHolds on '│📘 syntax: DistroAgentsTools.fn.sh [--help]' ) $( rigHolds on 'Reads or writes one option.' ) $( rigHolds on '--console-list' )" "1 1 0 0"
rigAssert "read by the operation as the tooling has it" "$( rigWords '[--manager-help-read]' | LC_ALL=C awk '{ print ( $1 > 0 ) }' )" "1"
rigAssert "its number is that of its place: 9 where Team Data is not there, and the menu Go names it so" "$( rigVal k9.path ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^go|' | LC_ALL=C grep -c -E 'Manuals \(Help\)  *9 ' )" "manuals 1"

echo "-- 2. inside: every operation, each its block alone --"
rigCase inside
rigScript <<'RIGSCRIPT'
turn
wait list 10
keys PGDN ENTER
wait list 10
get in
show up
keys DOWN
show entry
keys DOWN
show second
keys DOWN
show none
RIGSCRIPT
rigAssert "an item for each operation of the help, then each its syntax names with no block" "$( rigVal in.path ) $( rigVal in.rows ) $( rigHolds entry ' --agents-config-option ' ) $( rigHolds entry ' --owner-setup-<domain> ' ) $( rigHolds entry ' --console-list ' )" "manuals 4 1 1 1"
rigAssert "on the row that goes up the folder shows itself: the bare call's lines" "$( rigHolds up '│📘 syntax: DistroAgentsTools.fn.sh --owner-setup-<domain>' ) $( rigHolds up 'Sets up one domain.' )" "1 0"
rigAssert "an operation selected shows its block alone: its syntax lines and its text" "$( rigHolds entry '│--agents-config-option <id> <op>' ) $( rigHolds entry '│    Reads or writes one option.' ) $( rigHolds entry 'Sets up one domain.' ) $( rigHolds second '│--owner-setup-<domain> --apply' ) $( rigHolds second '│    Its second line.' )" "1 1 0 1 1"
rigAssert "one with no block in the help says so plainly" "$( rigHolds none '│It has no description block in the help.' )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN MANUALS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_MANUALS: OK (%d assertions, offline)\n' "$rigPassCount"
