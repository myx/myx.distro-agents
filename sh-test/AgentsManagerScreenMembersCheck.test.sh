#!/usr/bin/env bash
## Behavioural check on the section `Team Members` of the manager screen (sh-lib/AgentsManagerScreen.py), run rather
## than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.test.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.test.sh), which notes each start, its arguments word for word and what came
## on its standard input, and prints the fixture kept for those arguments: rows in the forms
## `--manager-team-member-list`, `--manager-team-member-read` and `--manager-spawn-member` print.
## Held: entering the section asks `--manager-team-member-list` once and lists every member in the order of the
## operation, by its name; one with a live run stands out, with `running` at the end of its row; one that is not
## started from here, whose status is `reference-only` or whose workspace cannot be reached, shows plainer, with
## that at the end of its row; a selected member is read by its name, `--manager-team-member-read <member>`, only
## once the selection has rested on it, and until then the pane shows what the list holds of it; then the left pane
## shows its mark and names, its kind, its status, whether a run of it is alive, its workspace and what it is for,
## its information, the sessions it is in with the member's own runs, its workspace by its paths, its grants and
## its settings, a secret setting only as configured or not and never anything of its value, a missing one marked;
## the pane scrolls with the focus on it; the left pane names `n start` on a member that can be started and on no
## other; `n` opens the line for one line of prompt, then for a name that may be left empty, and calls
## `--manager-spawn-member <member> [--session-name-or-comment <name>]` once, with the line on its standard input
## and no word of it among its arguments; an empty line starts nothing; Esc at either step starts nothing; `n` on
## a member that is not started says why and asks nothing, and `n` on a row that is no member says so; what the
## operation printed is shown, the list of the sessions is read again and holds the new session; and an error of
## the start is shown.
## Offline: no operation of the real tooling is called, no CLI is started, and no member of this machine is read.
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
rigTmp="$( mktemp -d -t AgentsManagerScreenMembersCheck )" || exit 1
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
## Five members: an identity record nobody is started as; the coordinator, with no run alive; a keeper with a live
## run; a keeper set up in another workspace; and one whose workspace cannot be reached. What the read of the
## keeper prints: its information, two bullets, a session it runs in and one it ran in, two grants, and five
## settings, of which one secret is set, with a value in its row that the screen must never show, one secret is
## missing, one plain key is set, one is missing, and one is read elsewhere. One session runs; then the list of the
## sessions as it reads once a start has made a new one.
rigS1=11111111-0000-4000-8000-000000000001 ; rigS2=22222222-0000-4000-8000-000000000002 ; rigNew=99999999-0000-4000-8000-000000000009
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
rigKeeper(){ rigRow member keeper-myx 📐 Sage Bourne cronjob keeper ws-rig here active running ; }
{
	rigRow member human-owner :myx: - - - human ws-rig here reference-only no-process
	rigRow member magic-coordinator 🐭 Magic Vane dispatchr magic ws-rig here active no-process
	rigKeeper
	rigRow member keeper-far 🌾 Thea Vance farmhand keeper ws-far elsewhere active no-process
	rigRow member keeper-gone - - - - - - not-present - no-process
} > "$rigF/rows.--manager-team-member-list"
{
	rigKeeper
	rigRow info description Source-content_steward_for_the_common_tools_and_the_distro_tools_of_the_rig,_their_scripts_and_their_help.
	rigRow info workspace /rig/ws-rig
	rigRow info home /rig/home_of/ws-rig
	rigRow info link-kind source-symlink
	rigRow info skillset-path myx/util.workspace-rig/skillset/keeper-myx
	rigRow bullet Description source-content_authority_for_the_rig.
	rigRow bullet Name Sage_Bourne.
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 3 running=2,finished=1
	rigRow run "$rigS1" "$rigS1" keeper-myx spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig working
	rigRow session "$rigS2" - finished 2026-10-11_14:28_+0000 2026-10-11_14:51_+0000 1 finished=1
	rigRow run "$rigS2" "$rigS2" keeper-myx spawn-succeeded no-process finished 2026-10-11_14:28_+0000 2026-10-11_14:51_+0000 rig-host ws-rig -
	rigRow grant standing write '/rig/ws-rig/source/myx/**' 'ws-rig:source/myx/**' ws-rig:namespace none
	rigRow grant session read '/rig/other/**' - pass-0007_by_magic-coordinator 2026-10-14_10:00_+0000
	rigRow setting SLACK_BOT_TOKEN secret-set xoxb-must-never-show ws-rig
	rigRow setting SLACK_USER_TOKEN secret-missing - ws-rig
	rigRow setting EMAIL_USER set keeper_myx@rig.example ws-rig
	rigRow setting TRELLO_BOARD missing - ws-rig
	rigRow setting JIRA_HOST elsewhere - ws-far
} > "$rigF/rows.--manager-team-member-read keeper-myx"
{
	rigRow member keeper-far 🌾 Thea Vance farmhand keeper ws-far elsewhere active no-process
	rigRow info description The_keeper_of_the_far_workspace.
	rigRow info workspace /rig/ws-far
} > "$rigF/rows.--manager-team-member-read keeper-far"
{
	rigRow member human-owner :myx: - - - human ws-rig here reference-only no-process
	rigRow info description Reference-only_identity_record_of_the_owner.
	rigRow info workspace /rig/ws-rig
} > "$rigF/rows.--manager-team-member-read human-owner"
rigOld(){
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 1 running=1
	rigRow run "$rigS1" "$rigS1" keeper-myx spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig working
}
{ rigOld ; rigRow counters 1 0 1 0 3 0.42 ; } > "$rigF/rows"
{
	rigRow session "$rigNew" the_index running 2026-10-13_02:30_+0000 - 1 running=1
	rigRow run "$rigNew" "$rigNew" keeper-myx spawn-started running running 2026-10-13_02:30_+0000 - rig-host ws-rig working
	rigOld
	rigRow counters 2 0 2 0 3 0.42
} > "$rigF/after.rows"
rigRow spawn "$rigNew" keeper-myx the_index dispatch-20261013T023000Z-spawn-proxy-1 > "$rigF/rows.--manager-spawn-member"
## A fresh rig for one case: a copy of the fixtures, no call noted yet.
rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls"
	: > "$MANAGER_SCREEN_RIG/words"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size, with the reads of one session taken out of the table; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:sessions:record none\ntable feed:sessions:record none\nwall 2026-10-13 02:30 +0000\nsize %s\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigPane(){ ## tag, line counted from 1 -- the left pane's part of that line of the screen, without the spaces at its end
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n "${2}p" | LC_ALL=C sed -e "s/^$1|//" -e 's/│.*$//' -e 's/  *$//'
}
rigPaneHolds(){ ## tag, text -- how many lines of the left pane of that screen are exactly the text, the spaces at their ends aside
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -e "s/^$1|//" -e 's/│.*$//' -e 's/  *$//' | LC_ALL=C grep -c -x -F -- "$2" || :
}
rigScreenHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigLooks(){ ## tag, line counted from 1, the cells from and to counted from 1 -- how those cells are drawn
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -n "${2}p" | LC_ALL=C cut -c"$3-$4"
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigStarts(){ ## how many times the operation that starts a member was started, whatever its arguments
	LC_ALL=C grep -c -- '^--manager-spawn-member' "$MANAGER_SCREEN_RIG/calls" || :
}
rigStartWords(){ ## number -- the arguments of that start of the operation that starts a member, each between brackets
	LC_ALL=C grep -F -- '[--manager-spawn-member]' "$MANAGER_SCREEN_RIG/words" | LC_ALL=C sed -n "${1}p"
}
rigOthers(){ ## how many starts were none of the four operations this screen may call here
	LC_ALL=C grep -c -v -e '^--manager-session-list' -e '^--manager-team-member-list$' -e '^--manager-team-member-read ' -e '^--manager-spawn-member ' "$MANAGER_SCREEN_RIG/calls" || :
}
rigType(){ ## text -- the keys that type it, one a character
	local typeText="$1" typeKeys="" typeChar
	while [ -n "$typeText" ] ; do
		typeChar="${typeText%"${typeText#?}"}" ; typeText="${typeText#?}"
		[ "$typeChar" != " " ] || typeChar=SPACE
		typeKeys="$typeKeys $typeChar"
	done
	printf '%s' "$typeKeys"
}
rigInput(){ ## text -- what the operation that starts a member got on its standard input, in all its starts: `none` where nothing came, `same` where it is exactly the text and a line end, else what came
	local inputFile="$MANAGER_SCREEN_RIG/stdin.--manager-spawn-member"
	if [ ! -e "$inputFile" ] ; then printf none
	elif printf '%s\n' "$1" | cmp -s - "$inputFile" ; then printf same
	else cat "$inputFile" ; fi
}

echo "-- Team Members lists the members --"
rigCase list
rigScript <<'RIGSCRIPT'
turn
wait sessions 30
keys DOWN DOWN
turn
get on
keys ENTER
get asked
wait list 30
turn
get in
show u
cells title 1 84 120
cells row1 2 84 120
cells row2 3 84 120
cells row3 4 84 120
cells row4 5 84 120
cells row5 6 84 120
cells row6 7 84 120
cells row7 8 84 120
looks k
keys k
get kill
keys n
get start
RIGSCRIPT
rigAssert "until the section is entered the members are not read"    "$( rigVal on.selected ) [$( rigVal on.reading )]" "team []"
rigAssert "entering it asks the operation that lists the members, once" "$( rigVal asked.path ) $( rigVal asked.reading ) $( rigCalled --manager-team-member-list ) $( rigOthers )" "team list:team 1 0"
rigAssert "every member is listed under the row that goes up, in the order of the operation, by its name" "[$( rigVal title )] $( rigVal in.rows ) [$( rigVal row1 )][$( rigVal row3 )][$( rigVal row5 )][$( rigVal row7 )]" "[ Team Members] 6 [>..][ magic-coordinator][ keeper-far][]"
rigAssert "one with a live run carries that at the end of its row, and stands out" "[$( rigVal row4 )] $( rigLooks k 6 86 86 )$( rigLooks k 5 86 86 )" "[ keeper-myx                  running] B."
rigAssert "one nobody is started as, and one whose workspace cannot be reached, show plainer, with why" "[$( rigVal row2 )][$( rigVal row6 )] $( rigLooks k 4 86 86 )$( rigLooks k 8 86 86 )" "[ human-owner          reference-only][ keeper-gone             not-present] DD"
rigAssert "on the row that goes up the left pane says what the section holds" "[$( rigPane u 3 )][$( rigPane u 4 )]" "[ 5 members, 1 with a live run.][ 2 of them are not started from here.]"
rigAssert "k and n on the row that goes up find nothing to act on"   "[$( rigVal kill.notice )][$( rigVal start.notice )] [$( rigVal start.dialog )]" "[k: nothing to kill here: k kills a session or an agent][n: nothing to start here: n starts a team member with a prompt] []"

echo "-- a selected member is read once the selection has rested, and shown --"
rigCase member
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN
get moved
show early
advance 0.2
turn
get resting
advance 0.2
turn
get asked
wait view 30
get m
show m
cells keysLine 37 0 83
RIGSCRIPT
rigAssert "the selection comes onto a member: nothing of it is read yet" "$( rigVal moved.selected ) [$( rigVal moved.reading )] $( rigVal moved.restLeft ) [$( rigVal resting.reading )]" "keeper-myx [] 0.33 []"
rigAssert "until then the pane shows what the list holds of it, and says that the rest is not read" "[$( rigPane early 3 )][$( rigPane early 5 )][$( rigPane early 11 )]" "[ 📐 Sage Bourne, alias cronjob][ kind      keeper][ its information, its sessions, its grants and its settings: not read yet]"
rigAssert "once it has rested it is read by its name, as a call of its own" "$( rigVal asked.reading ) $( rigCalled '--manager-team-member-read keeper-myx' ) $( rigOthers )" "view:team|record:keeper-myx 1 0"
rigAssert "its status, whether a run of it is alive, its workspace, and that n starts it" "[$( rigPane m 6 )][$( rigPane m 7 )][$( rigPane m 8 )][$( rigPane m 9 )]" \
	"[ status    active][ process   a run of it is alive][ workspace ws-rig, set up here][ start     n starts it with a prompt, in a session of its own]"
rigAssert "what it is for, a long text broken to the pane"           "[$( rigPane m 10 )][$( rigPane m 11 )]" "[ for       Source-content steward for the common tools and the distro tools of the][           rig, their scripts and their help.]"
rigAssert "its information, the bullets of its basic.md"             "[$( rigPane m 13 )][$( rigPane m 14 )][$( rigPane m 15 )]" "[ its information:][   Description: source-content authority for the rig.][   Name: Sage Bourne.]"
rigAssert "the sessions it is in, the one with its live run first, each with its own run" "[$( rigPane m 17 )][$( rigPane m 18 )][$( rigPane m 19 )]" \
	"[ the sessions it is in: 2, 1 with a live run of it][   daily of Monday          running   running working since 2026-10-12 16:57 +0000][   22222222-0000-4000-8000… finished  finished until 2026-10-11 14:51 +0000]"
rigAssert "its workspace, by its paths, a path with an underscore as it is written" "[$( rigPane m 21 )][$( rigPane m 22 )][$( rigPane m 23 )][$( rigPane m 24 )][$( rigPane m 25 )]" \
	"[ its workspace:][   path      /rig/ws-rig][   home      /rig/home_of/ws-rig][   link      source-symlink][   skillset  myx/util.workspace-rig/skillset/keeper-myx]"
rigAssert "its grants, a long one going on under itself"             "[$( rigPane m 27 )][$( rigPane m 28 )][$( rigPane m 29 )][$( rigPane m 30 )]" \
	"[ its grants: 2][   standing write   ws-rig:source/myx/**, from ws-rig:namespace][   session read /rig/other/**, from pass-0007 by magic-coordinator, ends][       2026-10-14 10:00 +0000]"
rigAssert "its settings: a secret only as configured or not, a plain one by its value, a missing one marked" "[$( rigPane m 32 )][$( rigPane m 33 )][$( rigPane m 34 )][$( rigPane m 35 )][$( rigPane m 36 )]" \
	"[ its settings: 5][     SLACK_BOT_TOKEN   configured][   ! SLACK_USER_TOKEN  not configured][     EMAIL_USER        keeper_myx@rig.example][   ! TRELLO_BOARD      missing]"
rigAssert "nothing of the value of a secret is on the screen, though its row carried one" "$( rigScreenHolds m 'xoxb' ) $( rigScreenHolds m 'must-never-show' ) $( LC_ALL=C grep -c -F 'xoxb-must-never-show' "$MANAGER_SCREEN_RIG/rows.--manager-team-member-read keeper-myx" )" "0 0 1"
rigAssert "the left pane names the key that starts it, and nothing spills" "[$( rigVal keysLine )] $( rigVal m.spills )" "[ keys: n start] 0"

echo "-- the pane of a member scrolls, and a member set up elsewhere says so --"
rigCase scroll
rigSize="120 20"
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN
wait view 30
get top
keys TAB PGDN
get paged
show paged
keys PGDN PGDN
get end
show end
keys TAB DOWN
wait view 30
show far
cells farKeys 17 0 83
RIGSCRIPT
rigSize=""
rigAssert "the pane starts at the top of the member"                 "$( rigVal top.viewTop ) $( rigVal top.viewLines ) $( rigVal top.follow )" "0 35 no"
rigAssert "with the focus on it, PageDown shows its next page"       "$( rigVal paged.focus ) $( rigVal paged.viewTop ) $( rigPaneHolds paged ' its workspace:' )" "view 15 1"
rigAssert "and reaches its last line, a setting read in another workspace" "$( rigPaneHolds end '     JIRA_HOST         read in the workspace it is set up in' ) $( rigVal end.spills )" "1 0"
rigAssert "a member set up in another workspace says so, and can be started" "$( rigPaneHolds far ' workspace ws-far, set up in another workspace of this machine' ) $( rigPaneHolds far ' for       The keeper of the far workspace.' ) [$( rigVal farKeys )]" "1 1 [ keys: n start]"

echo "-- n, a prompt and a name start that member --"
rigCase start
rigScript <<RIGSCRIPT
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN
wait view 30
copy $rigTmp/start/after.rows $rigTmp/start/rows
keys n
get asked
show d
keys$( rigType 'fix the index, please' )
get typed
keys ENTER
get name
show n
turn 3
get waiting
keys$( rigType 'the index' ) ENTER
get started
cells startedLine 38 0 83
wait action 30
get answered
show a
cells answeredLine 38 0 83
wait sessions 30
turn
keys LEFT UP UP ENTER
get up
cells upRow3 4 84 120
cells upRow4 5 84 120
RIGSCRIPT
rigAssert "n opens the line for the prompt"                          "[$( rigVal asked.dialog )] [$( rigPane d 34 )][$( rigPane d 35 )]" "[prompt:|] [ START the member keeper-myx with a prompt, in a new session of its own][ It runs as that member, whoever is at the console.]"
rigAssert "and says where the line goes, and that no secret belongs in it" "[$( rigPane d 36 )][$( rigPane d 37 )][$( rigPane d 38 )]" \
	"[ The line typed below is its prompt, given to the operation on its standard input.][ No secret belongs in it: a brief shows on the command line of the CLI.][ Enter goes on to the name of the session. Esc starts nothing.]"
rigAssert "the prompt is typed, and Enter goes on to the name of the session" "[$( rigVal typed.dialog )] [$( rigVal name.dialog )] [$( rigPane n 36 )][$( rigPane n 37 )]" \
	"[prompt:|fix the index, please] [name:|] [ START keeper-myx: fix the index, please][ The line below is the name of its session, or none: it then shows by its id.]"
rigAssert "until the name is entered nothing is started"             "[$( rigVal waiting.dialog )] $( rigVal waiting.calls ) [$( rigVal waiting.reading )]" "[name:|] 0 []"
rigAssert "Enter starts it, beside the screen"                       "[$( rigVal started.dialog )] $( rigVal started.reading ) [$( rigVal startedLine )]" "[] action:start:keeper-myx [ start asked of the tooling: the member keeper-myx, named the index]"
rigAssert "the operation is called once, for that member, with the name as one word and no word of the prompt" "$( rigStarts ) [$( rigStartWords 1 )]" "1 [[--manager-spawn-member][keeper-myx][--session-name-or-comment][the index]]"
rigAssert "the prompt is on its standard input, whole, with a line end" "$( rigInput 'fix the index, please' ) $( rigOthers )" "same 0"
rigAssert "what the operation printed is shown: the session, the member, the name, the item" "[$( rigVal answeredLine )] [$( rigPane a 3 )][$( rigPane a 4 )][$( rigPane a 5 )][$( rigPane a 6 )][$( rigPane a 7 )][$( rigPane a 8 )]" \
	"[ started: keeper-myx, session $rigNew] [ the start, answered 02:30:00:][ session   $rigNew][ member    keeper-myx][ name      the index][ item      dispatch-20261013T023000Z-spawn-proxy-1][]"
rigAssert "the list of the sessions is read again, and the new session is among its rows" "$( rigCalled --manager-session-list ) $( rigVal up.path ) [$( rigVal upRow3 )][$( rigVal upRow4 )]" "2 sessions [ the index                   running][ daily of Monday             running]"

echo "-- no name, an empty prompt, Esc --"
rigCase bare
rigScript <<RIGSCRIPT
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN
keys n$( rigType 'look at the index' ) ENTER ENTER
wait action 30
RIGSCRIPT
rigAssert "with no name the member is started under none"            "$( rigStarts ) [$( rigStartWords 1 )] $( rigInput 'look at the index' )" "1 [[--manager-spawn-member][keeper-myx]] same"
rigOdd='-n "it'"'"'s" 50% a\b $(id) ; rm -rf x --session-name-or-comment z'
rigCase odd
rigScript <<RIGSCRIPT
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN
keys n$( rigType "$rigOdd" ) ENTER ENTER
wait action 30
RIGSCRIPT
rigAssert "a prompt with quotes, a percent sign, a backslash, a dollar and a first word that starts with a dash arrives unchanged" "$( rigInput "$rigOdd" ) [$( rigStartWords 1 )]" "same [[--manager-spawn-member][keeper-myx]]"
rigCase empty
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN
keys n ENTER
get empty
cells emptyLine 38 0 83
keys n SPACE SPACE ENTER
get spaces
keys n x ESC
get esc
keys n x ENTER y ESC
get escName
turn 3
get end
RIGSCRIPT
rigAssert "Enter with no text starts nothing, and says so"           "[$( rigVal empty.dialog )] [$( rigVal emptyLine )]" "[] [ nothing was started: the line was empty]"
rigAssert "spaces alone are no text; Esc at the prompt and Esc at the name start nothing" "[$( rigVal spaces.notice )] [$( rigVal esc.dialog )$( rigVal esc.notice )] [$( rigVal escName.dialog )$( rigVal escName.notice )]" "[nothing was started: the line was empty] [] []"
rigAssert "the operation that starts a member was never called"      "$( rigStarts ) $( rigOthers ) $( rigVal end.calls )" "0 0 0"

echo "-- a member that is not to be started cannot be started here --"
rigCase refuse
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN
wait view 30
get owner
show o
cells ownerKeys 37 0 83
keys n
get refused
cells refusedLine 38 0 83
keys DOWN DOWN DOWN DOWN
advance 1
turn 3
get gone
show g
cells goneKeys 37 0 83
keys n
get unreachable
turn 3
get end
RIGSCRIPT
rigAssert "the identity record is selected: the pane says why it is not started, and names no key" "$( rigVal owner.selected ) $( rigPaneHolds o ' start     not started from here: its status is reference-only: nobody is started' )$( rigPaneHolds o '           as this member' ) [$( rigVal ownerKeys )]" "human-owner 11 []"
rigAssert "n on it opens no line, and the bottom line says that this member is not started" "[$( rigVal refused.dialog )] [$( rigVal refusedLine )]" "[] [ n: human-owner is not started: its status is reference-only: nobody is started as…]"
rigAssert "a member whose workspace cannot be reached is not started either" "$( rigVal gone.selected ) $( rigPaneHolds g ' start     not started from here: its workspace cannot be reached from this machine' ) [$( rigVal goneKeys )] [$( rigVal unreachable.dialog )] [$( rigVal unreachable.notice )]" \
	"keeper-gone 1 [] [] [n: keeper-gone is not started: its workspace cannot be reached from this machine]"
rigAssert "and it is not read, since its read would be refused: the pane says so" "[$( rigVal gone.reading )] $( rigCalled '--manager-team-member-read keeper-gone' ) $( rigPaneHolds g ' nothing more is read of it: its workspace cannot be reached from this machine' )" "[] 0 1"
rigAssert "the operation that starts a member was never called"      "$( rigStarts ) $( rigVal end.calls )" "0 0"

echo "-- an error of the start is shown --"
rigCase fail
echo fail > "$MANAGER_SCREEN_RIG/mode.--manager-spawn-member"
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN
keys n x ENTER ENTER
wait action 30
get failed
show f
cells failedLine 38 0 83
RIGSCRIPT
rigAssert "the error line of the operation stands in the bottom line" "[$( rigVal failedLine )]" "[ --manager-spawn-member: rig-tools: ⛔ ERROR: the rig said fail]"
rigAssert "and in the left pane, which says that the start failed"   "[$( rigPane f 3 )][$( rigPane f 4 )][$( rigPane f 5 )]" "[ the start failed, answered 02:30:00:][ rig-tools: ⛔ ERROR: the rig said fail][]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN MEMBERS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_MEMBERS: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
