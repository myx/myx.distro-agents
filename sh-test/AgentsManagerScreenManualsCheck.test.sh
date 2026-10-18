#!/usr/bin/env bash
## Behavioural check on the root `Manuals (Help)` of the manager screen (sh-lib/AgentsManagerScreen.py, P15), run
## rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which notes each start and prints the fixture.
## Held: the root stands last in the root list, a folder, with the number of its place; selected, the left window
## shows the first part of what the tooling gives by --manager-help-read (the syntax lines a user calls), and no entry
## of an operation; entered, it holds an item for every operation of the help, as `Member Help` holds a member's, each
## showing its block alone, and one whose syntax names it with no block in the help says so plainly; on the row that
## goes up the folder shows itself. The help is Markdown (the owner: "better to show them as MD to terminal"): an
## operation's block shows rendered, its heading, its code and its list each in its look, its syntax line as it is,
## and its title says so; a shell example in it, a paragraph whose first line is a comment of the shell, shows as it is
## written, as code, its comment no heading; the raw mode (`g`) shows it as it is and the summary mode (`b`) renders it again; the root's
## view is rendered too. The operation is called exactly as the tooling has it. Offline: no operation of the real
## tooling is called.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsManagerScreen.py"
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
	printf '📘 syntax: DistroAgentsTools.fn.sh --agents-config-option <id> <op>\n📘 syntax: DistroAgentsTools.fn.sh --owner-setup-<domain>\n📘 syntax: DistroAgentsTools.fn.sh [--help]\n\n📘 syntax: DistroAgentsTools.fn.sh --agents-config-option <id> <op>\n📘 syntax: DistroAgentsTools.fn.sh --console-list\n\t\t--agents-config-option <id> <op>\n\t\t\tReads or writes one option.\n\n\t\t\t### Its kinds\n\n\t\t\t- `read_one`: prints it.\n\t\t\t- **write**: sets it.\n\n\t\t\t# read one option\n\t\t\trig-tool a  --select   KEY\n\n\t\t--owner-setup-<domain>\n\t\t--owner-setup-<domain> --apply\n\t\t\tSets up one domain.\n\t\t\tIts second line.\n\n' > "rows.--manager-help-read"
	printf 'chapter\thead\t##  Summary:\nchapter\thead\t\t\tCHAPTER-HEAD-TEXT\nchapter\thead\t##  Options:\nchapter\tfoot\t##  Notes:\nchapter\tfoot\t\t\t--chapter-foot-text after the options\n' >> "rows.--manager-help-read"
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
rigLookOf(){ ## show tag, roles tag, text -- the letters of the looks (roles) of the cells under the text, on the first line that holds it
	printf '%s\n' "$rigOut" | "$rigPython" -I -c '
import sys
shown, roles, text = sys.argv[1:4]
lines = sys.stdin.read().split("\n")
texts = [line[len(shown) + 1:] for line in lines if line.startswith(shown + "|")]
letters = [line[len(roles) + 1:] for line in lines if line.startswith(roles + "|")]
for number, line in enumerate(texts):
    if text in line and number < len(letters):
        at = line.index(text)
        print(letters[number][at:at + len(text)])
        break
else:
    print("none")
' "$1" "$2" "$3"
}

echo "-- 1. the root: last, a folder; selected, the first part of its read --"
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
rigAssert "selected, the left window shows the first part of the read, as the tooling gives it, and no entry" "$( rigHolds on '│📘 syntax: DistroAgentsTools.fn.sh --agents-config-option <id> <op>' ) $( rigHolds on '│📘 syntax: DistroAgentsTools.fn.sh [--help]' ) $( rigHolds on 'Reads or writes one option.' ) $( rigHolds on '--console-list' )" "1 1 0 0"
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
rigAssert "on the row that goes up the folder shows itself: the first part of the read" "$( rigHolds up '│📘 syntax: DistroAgentsTools.fn.sh --owner-setup-<domain>' ) $( rigHolds up 'Sets up one domain.' )" "1 0"
rigAssert "the chapters the read gives after its operations are no operation and stand neither in the root's view nor among its items" "$( rigHolds up 'CHAPTER-HEAD-TEXT' ) $( rigHolds up 'Summary' ) $( rigHolds up 'chapter-foot-text' ) $( rigHolds entry 'chapter-foot-text' ) $( rigHolds none 'chapter-foot-text' ) $( rigHolds none 'Notes' )" "0 0 0 0 0 0"
rigAssert "an operation selected shows its block alone: its syntax lines and its text" "$( rigHolds entry '│--agents-config-option <id> <op>' ) $( rigHolds entry '│    Reads or writes one option.' ) $( rigHolds entry 'Sets up one domain.' ) $( rigHolds second '│--owner-setup-<domain> --apply' ) $( rigHolds second '│    Sets up one domain.' )$( rigHolds second '│    Its second line.' )" "1 1 0 1 11"
rigAssert "one with no block in the help says so plainly" "$( rigHolds none '│It has no description block in the help.' )" "1"

echo "-- 3. the help is Markdown: an operation's block and the root's view rendered; the raw mode shows it as it is --"
rigCase markdown
rigScript <<'RIGSCRIPT'
turn
wait list 10
keys PGDN
wait focus 10
show root
keys ENTER
wait list 10
keys DOWN
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
rigAssert "a heading set in under an entry shows as --help prints it, as it is written" "$( rigHolds md '│    ### Its kinds' ) $( rigHolds md '│    ┄┄┄┄┄┄┄┄┄ ' ) $( rigLookOf md mdr 'Its kinds' )" "1 0 ........."
rigAssert "its list has its marks, its code and its strong words show without their marks, each in its look" "$( rigHolds md '│    ➤ read_one: prints it.' ) $( rigHolds md '`' ) $( rigHolds md '**' ) $( rigLookOf md mdr '➤ read_one' ) $( rigLookOf md mdr 'write: sets' )" "1 0 0 e.DDDDDDDD BBBBB......"
rigAssert "its syntax line stands as it is, plain, as --help prints it, and its title says it is rendered" "$( rigHolds md '│--agents-config-option <id> <op>' ) $( rigLookOf md mdr '--agents-config-option <id> <op>' ) $( rigHolds md '--agents-config-option [markdown]' )" "1 ................................ 1"
rigAssert "a shell example in a block shows as it is written, as --help prints it: its comment no heading, its runs of blanks kept" \
	"$( rigHolds md '│    # read one option' ) $( rigHolds md '│    rig-tool a  --select   KEY' ) $( rigHolds md '│    read one option' ) $( rigLookOf md mdr '# read one option' )" "1 1 0 ................."
rigAssert "the raw mode shows the block as it is, and says so" "$( rigVal raw.textMode ) $( rigHolds raw '│    ### Its kinds' ) $( rigHolds raw '│    - `read_one`: prints it.' ) $( rigHolds raw '--agents-config-option [raw]' )" "raw 1 1 1"
rigAssert "the summary mode renders it again" "$( rigHolds back '│    ➤ read_one: prints it.' ) $( rigHolds back '`read_one`' ) $( rigHolds back '--agents-config-option [markdown]' )" "1 0 1"
rigAssert "the root's view is rendered too, its syntax lines as they are, and its title says so" "$( rigHolds root '│📘 syntax: DistroAgentsTools.fn.sh --agents-config-option <id> <op>' ) $( rigHolds root 'Manuals (Help) [markdown]' )" "1 1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN MANUALS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_MANUALS: OK (%d assertions, offline)\n' "$rigPassCount"
