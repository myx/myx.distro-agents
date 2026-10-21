#!/usr/bin/env bash
## Behavioural check on the root `Locations (Places)` of the manager screen (sh-lib/manager/AgentsManagerScreen.py) and on
## its rule that shows a path inside a registered location by the name of that location, run rather than read. The
## screen's own code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py),
## and where it would call the dispatcher it calls a stand-in script (check-fixtures/manager-screen.tools.stub.sh),
## which notes each start and prints the fixture: rows in the forms `--manager-place-list` and
## `--manager-place-read <place>` print.
## Held: the root list holds `Locations (Places)` as a folder after `Team Members`, and `9` goes there; its list is
## read by `--manager-place-list` with no argument, once when the screen starts, whatever is shown, and again, on
## the period and when a read is asked for, only while it is the list shown; the locations stand in a table under a
## header, each by its key, with its kind, its ceiling, its state and its sessions in the columns that fit whole,
## the mark of the one the console runs in ahead of it, and no column of a host; the one the console runs in stands
## out, one that is not present shows plainer; a line that is no row of a location is left out; the left window
## shows what the folder holds, and of the selected location its facts, and, once `--manager-place-read` was
## called with its key exactly as it is, what declares it, what stands in it, each path as it stands under the path
## of the location, and the members that belong to it, by the way they are set up, a folder under the path of the
## location as it stands there, one in another location by the rule below (the owner: "paths ... in Locations/Places
## `Its members` may start with place:preffix instead of absolute"), one in none as it is; in the table, in the
## summary of a location but its members' folders, in the subject of the workspace's paths and in what is started
## with the whole terminal a path stands as it is; in every other view a path inside a location is drawn as the key
## of that location, a colon and what follows, the longest location winning, the key in the palette entry of a
## folder, and a path that only begins as one does is left alone; a value of the dashboard takes the rule where it is set out; the answer dialog of a
## question takes it, with the path as it is under its paragraph, and a message box does not; with no location
## known every path stands as it is.
## Offline: no operation of the real tooling is called.
## Reconciled for F11.0: a spacer stands between the groups of the roots; every dialog has bigger margins inside its
## frame (two empty lines under its top, one more under its buttons, three blank cells at each side), so its box is
## four cells wider and two lines taller and what it holds stands where it stood.
## Reconciled for F11.0, the table lines: two spaces between the columns of the tables of the left window and of the list, whose rows are in the look of their ground (here underlined: l).
## Reconciled for F11.5: Locations (Places) is the fourth root, key 4, and the list a case gives a generic list is that of `Launch (Start)` under Activity (`at @activity launch`).
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
rigTmp="$( rigTempDir AgentsManagerScreenPlacesCheck )" || exit 1
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
## Five locations no machine has: a built-in one; the workspace the console runs in; a directory that lies inside
## that workspace, so two locations hold its paths and the longer one wins; a workspace that is not present; one of
## which nothing is known, not even its path. And two lines that are no row of a location.
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow place .skillset-shared Skillset_Shared directory read-write /rig/home/.claude/skills present no -
	rigRow place ws-one Ws_One workspace read-write /rig/Workspaces/ws-one present yes 196
	rigRow place deep Deep directory read-only /rig/Workspaces/ws-one/source/deep present no -
	rigRow other thing of another name
	rigRow place gone-work Gone_Work workspace read-write /rig/Volumes/gone-work absent no 0
	rigRow place nowhere@ws-two Nowhere directory - - unknown no -
	rigRow place short
} > "$rigF/rows.--manager-place-list"
{
	rigRow place deep Deep directory read-only /rig/Workspaces/ws-one/source/deep present no -
	rigRow info declared-by a-project
	rigRow info workspace /rig/Workspaces/ws-one
	rigRow info registry /rig/Workspaces/ws-one/.local/agents/directories.registry
	rigRow stands console DistroAgentsConsole.sh /rig/Workspaces/ws-one/source/deep/DistroAgentsConsole.sh
	rigRow stands team-data-root - /rig/Workspaces/ws-one/source/deep/team-data
	rigRow stands home keeper-far /rig/elsewhere/homes/keeper-far
	rigRow stands home keeper-wide /rig/Workspaces/ws-one/homes/keeper-wide
	rigRow member magic-linked magic elsewhere origin-symlink /rig/origin/skillset/magic-linked
	rigRow member keeper-own keeper none source-symlink /rig/Workspaces/ws-one/source/deep/skillset/keeper-own
	rigRow member stray-one keeper none not-in-registry /rig/Workspaces/ws-one/source/deep/.local/agents/members/stray-one
	rigRow member far-one keeper elsewhere origin-symlink /rig/Workspaces/ws-one/skillset/far-one
} > "$rigF/rows.--manager-place-read deep"
{
	rigRow block data Team_Data 2
	rigRow figure data root Team_Data_Root /rig/Workspaces/ws-one/source/deep/team-data - - -
	rigRow figure data home Some_Home /rig/Workspaces/ws-one - ok -
} > "$rigF/rows.--manager-dashboard-read"
rigRow counters 0 0 0 0 0 0.42 righost > "$rigF/rows"
## The commands of the workspace, as the tooling lists those its palette gets: one that runs with the whole
## terminal, and one that runs unattended.
{
	rigRow command 🖥️_Start_Source_Console myx.distro-source terminal
	rigRow command ⬇️_Pull/Sync_All_Known_Sources myx.distro-source output
} > "$rigF/rows.--manager-place-command-list ws-one"
## A fresh rig for one case: a copy of the fixtures, no call noted yet.
rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls"
	: > "$MANAGER_SCREEN_RIG/words"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable list:settings none\ntable list:consoles none\nwall 2026-10-13 02:30 +0000\nsize %s\nroot dashboard\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigListLine(){ ## tag, text -- the list's part of the first line of that screen whose list holds the text, every run of blanks as one, without its frame
	RIG_OUT="$rigOut" "$rigPython" -I -B -c '
import os, re, sys
show, text = sys.argv[1:3]
for line in os.environ["RIG_OUT"].split("\n"):
    if line.startswith(show + "|"):
        line = line[len(show) + 1:].rstrip("|").rstrip(" ")
        line = line[:-1] if line[-1:] in "║│▲▼■▒" else line
        if text in re.split("[║│]", line)[-1]:
            print(re.sub("  +", " ", re.split("[║│]", line)[-1]).rstrip(" "))
            break
' "$1" "$2"
}
rigLookAt(){ ## tag of the screen as text, tag of the same screen as looks, text [, the first column to look from] -- how the cells that text stands in are drawn, on the first line that holds it from that column on
	RIG_OUT="$rigOut" "$rigPython" -I -B -c '
import os, sys
show, looks, text = sys.argv[1:4]
out = os.environ["RIG_OUT"].split("\n")
shown = [line[len(show) + 1:] for line in out if line.startswith(show + "|")]
drawn = [line[len(looks) + 1:] for line in out if line.startswith(looks + "|")]
for number, line in enumerate(shown):
    at = line.find(text, int(sys.argv[4] or 0))
    if at >= 0:
        print(drawn[number][at:at + len(text)])
        break
' "$1" "$2" "$3" "${4:-0}"
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigPlaceCalls(){ ## how many starts were of an operation of the locations, and how many of those were neither the list with no argument nor the read of one key
	printf '%s %s' "$( LC_ALL=C grep -c -- '^--manager-place-' "$MANAGER_SCREEN_RIG/calls" || : )" "$( LC_ALL=C grep -- '^--manager-place-' "$MANAGER_SCREEN_RIG/calls" | LC_ALL=C grep -c -v -x -e '--manager-place-list' -e '--manager-place-read [^ ]*' || : )"
}
## The line every case of the rule puts into the left window: a path in the longer location, a path that only
## begins as the workspace's does, the workspace's own path between brackets, and a path in the workspace alone.
rigSaid='it reads /rig/Workspaces/ws-one/source/deep/a.txt and /rig/Workspaces/ws-one-other/b and (/rig/Workspaces/ws-one) and /rig/Workspaces/ws-one/x.sh too'
rigPlaced='it reads deep:a.txt and /rig/Workspaces/ws-one-other/b and (ws-one) and ws-one:x.sh too'

echo "-- the root, its table, and what the left window shows of it"
rigCase table
rigSize="200 40" rigScript <<'EOF'
workspace /rig/Workspaces/ws-one
turn
wait places 5
get start
show root
keys 4
turn
wait places 5
turn
get in
show t
roles tr
border inTitle 1 0 140
keys DOWN DOWN DOWN
turn
wait view 5
get deep
show d
looks dl
border deepTitle 1 0 140
keys DOWN DOWN
turn
wait view 5
get odd
show o
keys BACKSPACE
turn
get out
show s
EOF
rigAssert "the list of the locations is read when the screen starts, with no argument, though another root is shown" "$( rigVal start.selected ) $( rigCalled --manager-place-list )" "dashboard 1"
rigAssert "the root list holds it after Magic-Team (Agents) and the spacer under its group, as a folder" "[$( rigListLine root 'Magic-Team (Agents)' )] [$( rigListLine root 'Locations (Places)' )] $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^root|' | LC_ALL=C grep -A2 -F 'Magic-Team (Agents)' | LC_ALL=C grep -F 'Locations (Places)' | LC_ALL=C grep -c -F '►' )" "[ Magic-Team (Agents) ►] [ Locations (Places) ►] 1"
rigAssert "9 goes there: the row that goes up and a row a location, in the order of the operation, and a line that is no row of one is left out" "[$( rigVal in.path )] $( rigVal in.rows ) $( rigHolds t 'another name' ) $( rigHolds t 'short' )" "[places] 6 0 0"
rigAssert "the table has a header: the key, the kind, the ceiling, the state, the sessions, and no column of a host" "[$( rigListLine t 'PLACE' )] $( rigHolds t 'HOST' )" "[ PLACE KIND CEILING STATE SESSIONS] 0"
rigAssert "a location is a row of it, by its key; the one the console runs in has the mark ahead of it" "[$( rigListLine t '.skillset-shared' )] [$( rigListLine t '• ws-one ' )] [$( rigListLine t 'gone-work' )]" "[ .skillset-shared directory read-write present -] [ • ws-one workspace read-write present 196 ►] [ gone-work workspace read-write absent 0]"
rigAssert "what is not known of one is a dash, and its key stands as the operation gives it" "[$( rigListLine t 'nowhere@ws-two' )]" "[ nowhere@ws-two directory - unknown -]"
rigAssert "the one the console runs in stands out, one that is not present shows plainer, another is plain" "$( rigLookAt t tr '• ws-one' 140 ) $( rigLookAt t tr 'gone-work' 140 ) $( rigLookAt t tr 'deep' 140 )" "BBBBBBBB DDDDDDDDD cccc"
rigAssert "on the row that goes up the left window shows every location as a table with its path, nothing above it, how many in the frame" "[$( rigVal inTitle )] $( rigHolds t ' 5 rows ' ) $( rigHolds t 'PLACE             KIND       STATE    PATH' ) $( rigHolds t 'gone-work         workspace  absent   /rig/Volumes/gone-work' )" "[Locations (Places) [wrap]] 1 1 1"
rigAssert "a location selected: its read is called with its key, once, and the left window shows its facts" "$( rigVal deep.selected ) [$( rigVal deepTitle )] $( rigCalled '--manager-place-read deep' ) $( rigHolds d '│Deep (deep) ' ) $( rigHolds d '│ kind         directory ' ) $( rigHolds d '│ ceiling      read-only ' ) $( rigHolds d '│ state        present ' )" "deep [deep [wrap]] 1 1 1 1 1"
rigAssert "in the summary of a location its own path and what declares it stand as they are" "$( rigHolds d '│ path         /rig/Workspaces/ws-one/source/deep ' ) $( rigHolds d '│ registry     /rig/Workspaces/ws-one/.local/agents/directories.registry ' ) $( rigHolds d 'declared-by  a-project' ) $( rigVal deep.spills )" "1 1 1 0"
rigAssert "what stands in it is a table of what, its name and where, each path as it stands under the path of the location, which is said once, at the top; a thing in another location by its key and a colon, as in its members, and one in none keeps its whole path, a row of the same table" "$( rigHolds d '│  WHAT            NAME                    WHERE ' ) $( rigHolds d '│  console         DistroAgentsConsole.sh  DistroAgentsConsole.sh ' ) $( rigHolds d '│  team-data-root  -                       team-data ' ) $( rigHolds d '│  home            keeper-far              /rig/elsewhere/homes/keeper-far ' ) $( rigHolds d '│  home            keeper-wide             ws-one:homes/keeper-wide ' ) $( rigHolds d '/rig/Workspaces/ws-one/source/deep' )" "1 1 1 1 1 1"
rigAssert "its members stand under that as one table, how each is set up in a column of its own as their rows say it, those whose folder lies in the location first, a folder under its path where it lies there, one in another location by its key and a colon, one in none as it is; one that no registry names has that word in the colour of what to look at" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^d|' | LC_ALL=C grep -o -e '│Its members ' -e '│  MEMBER        KIND    SETUP            FOLDER ' -e '│  keeper-own    keeper  source-symlink   skillset/keeper-own ' -e '│  stray-one     keeper  not-in-registry  .local/agents/members/stray-one ' -e '│  magic-linked  magic   origin-symlink   /rig/origin/skillset/magic-linked ' -e '│  far-one       keeper  origin-symlink   ws-one:skillset/far-one ' | LC_ALL=C tr -d '│' | LC_ALL=C sed 's/^ *//;s/ *$//' | LC_ALL=C tr -s ' ' | LC_ALL=C tr '\n' '|' ) $( rigLookAt d dl 'not-in-registry' ) $( rigLookAt d dl 'source-symlink' ) $( rigHolds d '/rig/Workspaces/ws-one/skillset/far-one' )" "Its members|MEMBER KIND SETUP FOLDER|keeper-own keeper source-symlink skillset/keeper-own|stray-one keeper not-in-registry .local/agents/members/stray-one|magic-linked magic origin-symlink /rig/origin/skillset/magic-linked|far-one keeper origin-symlink ws-one:skillset/far-one| BBBBBBBBBBBBBBB .............. 0"
rigAssert "a key with a mark in it is given to the read as it is" "$( rigVal odd.selected ) $( rigCalled '--manager-place-read nowhere@ws-two' ) $( rigHolds o '│Nowhere (nowhere@ws-two) ' ) $( rigHolds o '│ path ' )" "nowhere@ws-two 1 1 0"
rigAssert "Backspace goes back to the root, onto its row, where the left window says the same of the folder" "[$( rigVal out.path )] $( rigVal out.selected ) $( rigHolds s ' 5 rows ' )" "[] places 1"
rigAssert "no operation of the locations was called but the list with no argument and the read of one key" "$( rigPlaceCalls )" "3 0"

echo "-- where the list has little room the columns that do not fit are left out whole"
rigCase narrow
rigScript <<'EOF'
turn
wait places 5
keys 4
turn
show n
get n
style bw
turn
get b
style magic
turn
show c
get c
EOF
rigAssert "at 120 columns: the key and the kind, and the mark" "[$( rigListLine n 'PLACE' )] [$( rigListLine n '•  ws-one ' )] $( rigVal n.spills )" "[ PLACE KIND] [ • ws-one workspace ►] 0"
rigAssert "the other styles draw it, nothing past a line, the mark of the location the console runs in on one line of the list and of the table of the left pane" "$( rigVal b.spills ) $( rigVal c.spills ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^c|' | LC_ALL=C grep -o -F -e ' • ws-one ' -e ' •  ws-one ' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "0 0 2"

echo "-- the rule: a path inside a location is drawn by the name of that location"
rigCase rule
rigSize="240 40" rigScript <<EOF
workspace /rig/Workspaces/ws-one
turn
wait list 5
wait places 5
turn
show dash
roles dashr
wait sessions 5
table list:magic-team/activity/launch none
rows magic-team/activity/launch s1=one
rows settings workspace=Workspace_Paths other=Other_Subject
rows consoles c1=A_Console
at @activity launch
turn
keys DOWN DOWN
turn
viewline $rigSaid
turn
show v
roles vr
get v
keys 7 DOWN DOWN DOWN DOWN
turn
viewline $rigSaid
turn
get paths
show p
keys DOWN
turn
viewline $rigSaid
turn
get other
show q
keys 5 DOWN
turn
viewline $rigSaid
turn
get console
show k
EOF
rigAssert "in a view of the sessions: the longest location wins, the workspace's own path is its key, a path that only begins as one does is left alone" "$( rigVal v.selected ) $( rigHolds v "│$rigPlaced " ) $( rigHolds v '/rig/Workspaces/ws-one/' ) $( rigVal v.spills )" "s1 1 0 0"
rigAssert "the key of a location stands in the palette entry of a folder, and nothing else of the line does" "$( rigLookAt v vr 'it reads deep:a.txt and' ) $( rigLookAt v vr '(ws-one) and ws-one:x.sh too' )" ".........eeee.......... .eeeeee......eeeeee........."
rigAssert "a value of the dashboard takes the rule where it is set out: the box keeps its width, the key its look" "$( rigHolds dash ' deep:team-data │' ) $( rigHolds dash ' ws-one │' ) $( rigLookAt dash dashr 'deep:team-data' ) $( rigLookAt dash dashr ' ws-one │' )" "1 1 eeeeBBBBBBBBBB .eeeeee.."
rigAssert "in the subject of the workspace's paths a path stands as it is" "$( rigVal paths.selected ) $( rigHolds p "│$rigSaid " ) $( rigHolds p 'deep/a.txt' | LC_ALL=C sed 's/^1$/as it is/' )" "workspace 1 as it is"
rigAssert "in another subject it takes the rule" "$( rigVal other.selected ) $( rigHolds q "│$rigPlaced " )" "other 1"
rigAssert "in what is started with the whole terminal a path stands as it is" "$( rigVal console.selected ) $( rigHolds k "│$rigSaid " )" "c1 1"

echo "-- a dialog: the answer to a question takes the rule, the path as it is under its paragraph; a message box does not"
rigCase dialog
rigScript <<'EOF'
turn
wait places 5
turn
opened answer | asked by :: someone / file :: /rig/Workspaces/ws-one/source/deep/a.txt / may it write /rig/Workspaces/ws-one/x.sh, and (/rig/Workspaces/ws-one-other/b)?
turn
box a
get a
keys ESC
tell A box | it failed at /rig/Workspaces/ws-one/x.sh
turn
box m
EOF
rigBox(){ ## tag, text -- how many lines of that box hold the text
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigAssert "a fact of the dialog shows by the name of the location, and the path as it is stands under it" "$( rigVal a.dialog | LC_ALL=C cut -d'|' -f1 ) $( rigBox a '║   file      deep:a.txt ' ) $( rigBox a '║             /rig/Workspaces/ws-one/source/deep/a.txt ' )" "answer:answers 1 1"
rigAssert "so does a paragraph: the path as it is under it, without what ends the sentence, and a path of no location is left alone" "$( rigBox a '║   may it write ws-one:x.sh, and (/rig/Workspaces/ws-one-other/b)? ' ) $( rigBox a '║     /rig/Workspaces/ws-one/x.sh  ' ) $( rigBox a '║   asked by  someone ' )" "1 1 1"
rigAssert "a message box shows what it was given, as it is" "$( rigBox m 'it failed at /rig/Workspaces/ws-one/x.sh' ) $( rigBox m 'ws-one/x.sh' )" "1 1"

echo "-- when it is read: once at the start; again, on the period and when a read is asked for, only while it is the list shown"
rigCase period
rigScript <<'EOF'
turn
wait places 5
advance 11
turn
wait places 5
advance 11
turn
wait places 5
get root
keys 4
turn
wait places 5
get shown
advance 11
turn
wait places 5
get aged
keys LEFT DOWN
turn
advance 11
turn
wait places 5
get away
keys u
turn
wait places 5
get asked
EOF
rigAway="$( rigCalled --manager-place-list )"
rigAssert "at another root it is not read again, however long" "$( rigVal root.selected ) $( rigVal root.path )" "dashboard "
rigAssert "it was read: once at the start, at once when its list is shown after its period, again when that passed there, never after it was left, and not when a read was asked for at another root" "[$( rigVal shown.path )] [$( rigVal away.path )] $( rigVal away.selected ) $rigAway" "[places] [] consoles 3"
rigScript <<'EOF'
turn
wait places 5
keys 4
turn
wait places 5
keys u
turn
wait places 5
get there
EOF
rigAssert "a read asked for while its list is shown reads it: once at that start, and once for the key" "[$( rigVal there.path )] $(( $( rigCalled --manager-place-list ) - rigAway )) $( rigPlaceCalls | LC_ALL=C cut -d' ' -f2 )" "[places] 2 0"

echo "-- a workspace that is there opens into its commands (the owner: \"All same as added to palette\")"
rigCase commands
rigSize="200 40" rigScript <<'EOF'
workspace /rig/Workspaces/ws-one
turn
wait places 5
keys 4
turn
wait places 5
keys DOWN DOWN
turn
wait view 5
wait focus 5
get folder
show f
keys ENTER
turn
wait list 5
get inside
show i
keys DOWN
turn
get first
show c1
keys ENTER
turn
get ask
show ask
keys ESC
turn
get cancelled
keys DOWN
turn
keys ENTER
turn
get ask2
show ask2
keys ENTER
wait follow 5
get ran
keys ENTER
turn
get closed
keys UP
turn
child 0
keys ENTER
turn
keys ENTER
turn
turn
get started
EOF
rigAssert "a workspace that is there is a folder, its mark at the edge, a directory is none; selected, the left window still shows the location itself" \
	"[$( rigListLine f '• ws-one' | LC_ALL=C sed 's/.* //' )] [$( rigListLine f ' deep ' | LC_ALL=C sed 's/.* //' )] $( rigHolds f 'Ws One (ws-one)' ) $( rigHolds f 'What stands in it' )" "[►] [-] 1 0"
rigAssert "Enter opens it: its commands, each by its name with its emoji, as an item that opens a dialog, read by the key of the workspace" \
	"$( rigVal inside.path ) $( rigHolds i '🖥️ Start Source Console...' ) $( rigHolds i '⬇️ Pull/Sync All Known Sources...' ) $( rigCalled '--manager-place-command-list ws-one' | LC_ALL=C sed 's/^[1-9][0-9]*$/read/' )" "places/ws-one 1 1 read"
rigAssert "a command selected: the left window says which package declares it and how it runs" \
	"$( rigVal first.selectedLabel ) $( rigHolds c1 ' myx.distro-source' ) $( rigHolds c1 ' with the whole terminal, as a console' )" "🖥️ Start Source Console 1 1"
rigAssert "Enter asks first: what runs, in which workspace, how, and Run or Cancel; Esc runs nothing" \
	"$( rigVal ask.dialog ) [$( rigVal ask.dialogTitle )] $( rigHolds ask 'workspace ws-one' ) $( rigHolds ask 'It runs in that workspace with the whole terminal' ) [$( rigVal cancelled.dialog )]" "placecommand:run| [Run: 🖥️ Start Source Console] 1 1 []"
rigAssert "one that runs unattended runs in the big output dialog, by the operation of the tooling, the workspace and its name as the list gives it" \
	"[$( rigVal ask2.dialogTitle )] $( rigHolds ask2 'in a window that follows what it writes' ) $( rigVal ran.dialog | LC_ALL=C sed 's/:.*//' ) $( rigVal ran.dialogHolds | LC_ALL=C grep -c -F 'Ended with status 0' ) [$( rigVal closed.dialog )] $( LC_ALL=C grep -c -x -F -e '[--manager-place-command-run][ws-one][⬇️_Pull/Sync_All_Known_Sources]' "$MANAGER_SCREEN_RIG/words" || : )" \
	"[Run: ⬇️ Pull/Sync All Known Sources] 1 output 1 [] 1"
rigAssert "one that runs with the whole terminal is given the terminal, as a console is: the dispatcher of the reads, the same operation, from this workspace" \
	"$( rigVal started.children ) $( rigVal started.childWords ) $( rigVal started.childDirectory ) $( LC_ALL=C grep -c -F -e '[--manager-place-command-run][ws-one][🖥️_Start_Source_Console]' "$MANAGER_SCREEN_RIG/words" || : )" \
	"1 [bash][$rigTools][--manager-place-command-run][ws-one][🖥️_Start_Source_Console] /rig/Workspaces/ws-one 0"

echo "-- no location known: every path stands as it is; and a list that fails"
rigCase none
: > "$MANAGER_SCREEN_RIG/rows.--manager-place-list"
rigSize="240 40" rigScript <<EOF
turn
wait places 5
keys 4
turn
show e
wait sessions 5
table list:magic-team/activity/launch none
rows magic-team/activity/launch s1=one
at @activity launch
turn
keys DOWN DOWN
turn
viewline $rigSaid
turn
show v
get v
EOF
rigAssert "the folder says that none is known, and a path in another view stands as it is" "$( rigHolds e 'No location is known here: the operation listed none.' ) $( rigHolds v "│$rigSaid " ) $( rigVal v.spills )" "1 1 0"
rigCase failing
echo fail > "$MANAGER_SCREEN_RIG/mode.--manager-place-list"
rigScript <<'EOF'
turn
wait places 5
get f
EOF
rigAssert "a list that fails says so in a box, whole" "[$( rigVal f.dialogTitle )] [$( rigVal f.failed )] $( rigVal f.dialogHolds | LC_ALL=C grep -c -F -- 'operation: --manager-place-list' )" "[A read failed] [list:places] 1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN PLACES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_PLACES: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
