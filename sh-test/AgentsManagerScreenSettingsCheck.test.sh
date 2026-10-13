#!/usr/bin/env bash
## Behavioural check on the section `Settings / Configuration` of the manager screen (sh-lib/AgentsManagerScreen.py),
## run rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.test.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.test.sh), which notes each start and prints the fixture: rows in the form
## `--manager-config-digest` prints, a `subject` row and then its `line` rows.
## Held: the digest is read only while the section is shown, by `--manager-config-digest` with no argument, and
## again on its period; the section lists the subjects in the order of the operation, each by its name, with how
## many of its lines are missing at the end of its row; the left pane shows the selected subject: what it holds,
## how many lines and how many missing, then its lines group by group, each group under a line of its own, a key
## as it is written; a plain setting shows its value, a path with an underscore as it is written, a date with its
## spaces; a secret shows only as configured or not configured, and nothing of a value its row might carry is ever
## on the screen; a missing line is marked; a scope of an outside system reads as set, with the keys it lacks, or
## as missing them, and a system no scope holds says so; a CLI reads as usable or not; a subject longer than the
## pane scrolls with the focus on the left pane; and the section is for viewing only: the left pane names no key
## for a subject, a text typed there and Enter open no line and call nothing, Enter and Right dive nowhere, and no
## operation is ever called but the two reads.
## Offline: no operation of the real tooling is called, and no setting of this machine is read.
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
rigTmp="$( mktemp -d -t AgentsManagerScreenSettingsCheck )" || exit 1
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
## A digest of five subjects. workspace: two paths, one of them missing, and a place. cli: what the workspace asks
## for, a leg with a secret that is set, whose row carries a value the screen must never show, and one that is
## missing, and a leg that is not usable. systems: a scope that is set, one that is set and lacks two keys, one
## that misses a key, and a system no scope holds. loop: an outcome, a date and a word. scopes: two scopes, one of
## forty-two keys, so that the subject is longer than the pane, the other with a key and a secret that are missing.
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow subject workspace 3
	rigRow line workspace paths workspace-root set /rig/ws_rig
	rigRow line workspace paths session-stores missing /rig/ws_rig/.local/agents/stores
	rigRow line workspace places ws-rig set /rig/ws_rig
	rigRow subject cli 7
	rigRow line cli workspace SPAWN_CLI_SERVICE set claude
	rigRow line cli workspace SPAWN_HARNESS_TIER missing -
	rigRow line cli claude present set /rig/harness/claude.sh
	rigRow line cli claude ANTHROPIC_API_KEY secret-set sk-must-never-show
	rigRow line cli claude CLAUDE_CODE_OAUTH_TOKEN secret-missing -
	rigRow line cli claude usable set yes
	rigRow line cli grok usable missing no
	rigRow subject systems 4
	rigRow line systems slack magic-team set -
	rigRow line systems slack magic-coordinator set SLACK_APP_TOKEN,SLACK_SIGNING_SECRET
	rigRow line systems confluence magic-team missing CONFLUENCE_SPACE
	rigRow line systems jira - missing -
	rigRow subject loop 3
	rigRow line loop main-loop MAIN_LOOP_LAST_OUTCOME set failed
	rigRow line loop heartbeat recheck-date set 2026-10-09_04:28_+0000
	rigRow line loop heartbeat running set no
	rigRow subject scopes 44
	rigRow line scopes magic-coordinator EMAIL_USER set coordinator@rig.example
	rigRow line scopes magic-coordinator SLACK_BOT_TOKEN secret-set -
	rigNumber=1 ; while [ "$rigNumber" -le 40 ] ; do rigRow line scopes magic-coordinator "$( printf 'KEY_%02d' "$rigNumber" )" set "$( printf 'value_%02d' "$rigNumber" )" ; rigNumber=$(( rigNumber + 1 )) ; done
	rigRow line scopes magic-team TRELLO_BOARD missing -
	rigRow line scopes magic-team TRELLO_TOKEN secret-missing -
} > "$rigF/rows.--manager-config-digest"
rigRow counters 0 0 0 0 0 0.42 > "$rigF/rows"
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
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize %s\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigPane(){ ## tag, line counted from 1 -- the left pane's part of that line of the screen, without the spaces at its end
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n "${2}p" | LC_ALL=C sed -e "s/^$1|//" -e 's/^┌\(─\)* \(.*\) \(─\)*┐.*$/ \2/' -e 's/^╔\(═\)* \(.*\) \(═\)*╗.*$/ \2/' -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' -e 's/  *$//'
}
rigPaneHolds(){ ## tag, text -- how many lines of the left pane of that screen are exactly the text, the spaces at their ends aside
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -e "s/^$1|//" -e 's/^┌\(─\)* \(.*\) \(─\)*┐.*$/ \2/' -e 's/^╔\(═\)* \(.*\) \(═\)*╗.*$/ \2/' -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' -e 's/  *$//' | LC_ALL=C grep -c -x -F -- "$2" || :
}
rigScreenHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigOthers(){ ## how many starts were neither the list of the sessions nor the digest with no argument
	LC_ALL=C grep -c -v -x -e '--manager-session-list' -e '--manager-config-digest' "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- Settings / Configuration lists the subjects of the digest --"
rigCase list
rigScript <<'RIGSCRIPT'
turn
wait sessions 30
keys DOWN DOWN DOWN
advance 11
wait sessions 30
get on
keys ENTER
get asked
wait list 30
turn
get in
show u
border title 1 84 120
cells row1 2 85 119
cells row2 3 85 119
cells row3 4 85 119
cells row4 5 85 119
cells row5 6 85 119
cells row6 7 85 119
cells row7 8 85 119
advance 11
wait list 30
keys LEFT
advance 11
wait sessions 30
turn 3
get root
show r
RIGSCRIPT
rigAssert "until the section is entered the digest is not read, whatever time passes" "$( rigVal on.selected ) [$( rigVal on.reading )] $( rigVal on.viewLines )" "settings [] 0"
rigAssert "entering it asks the operation that prints the digest"    "$( rigVal asked.path ) $( rigVal asked.reading )" "settings list:settings"
rigAssert "the subjects are listed under the row that goes up, in the order of the operation" "[$( rigVal title )] $( rigVal in.rows ) [$( rigVal row1 )][$( rigVal row5 )][$( rigVal row7 )]" "[Settings / Configuration] 6 [>..][ loop][]"
rigAssert "a subject with missing lines carries their count at the end of its row" "[$( rigVal row2 )][$( rigVal row3 )][$( rigVal row4 )][$( rigVal row6 )]" \
	"[ workspace               1 missing][ cli                     3 missing][ systems                 2 missing][ scopes                  2 missing]"
rigAssert "on the row that goes up the left pane says what the digest holds, and that it is for viewing" "[$( rigPane u 3 )][$( rigPane u 4 )]" "[ 5 subjects, 61 lines, 8 missing.][ Viewing only: no key changes a setting here.]"
rigAssert "the digest is read with no argument, once on entering and once more when its period has passed" "$( rigCalled --manager-config-digest ) $( rigOthers )" "2 0"
rigAssert "back at the root it is not read again, and the section says what it held" "[$( rigVal root.path )] $( rigVal root.selected ) [$( rigPane r 3 )]" "[] settings [ 5 subjects, 61 lines, 8 missing.]"

echo "-- the left pane shows the selected subject, group by group --"
rigCase subjects
rigScript <<'RIGSCRIPT'
keys DOWN DOWN DOWN ENTER
wait list 30
keys DOWN
turn
get w
show w
cells wKeys 37 1 83
keys DOWN
turn
show c
keys DOWN
turn
show s
keys DOWN
turn
get l
show l
RIGSCRIPT
rigAssert "workspace: what it holds, and how many of its lines are missing" "$( rigVal w.selected ) [$( rigPane w 3 )][$( rigPane w 4 )]" "workspace [ workspace: the paths of this workspace, and the places it knows][ 3 lines, 1 missing, each marked !]"
rigAssert "its paths under a line of their own, a path with an underscore as it is written, a missing one marked" "[$( rigPane w 6 )][$( rigPane w 7 )][$( rigPane w 8 )]" \
	"[ paths][     workspace-root  /rig/ws_rig][   ! session-stores  /rig/ws_rig/.local/agents/stores (missing)]"
rigAssert "then its places, under a line of their own"               "[$( rigPane w 9 )][$( rigPane w 10 )][$( rigPane w 11 )][$( rigPane w 12 )]" "[][ places][     ws-rig  /rig/ws_rig][]"
rigAssert "the left pane names no key for a subject"                 "[$( rigVal wKeys )] $( rigVal w.spills )" "[] 0"
rigAssert "cli: what the workspace asks for, a key as it is written, a missing one marked" "[$( rigPane c 3 )][$( rigPane c 6 )][$( rigPane c 7 )][$( rigPane c 8 )]" \
	"[ cli: the CLI service the workspace asks for, and each CLI the console knows][ workspace][     SPAWN_CLI_SERVICE   claude][   ! SPAWN_HARNESS_TIER  missing]"
rigAssert "a secret shows only as configured or not configured"      "[$( rigPane c 10 )][$( rigPane c 11 )][$( rigPane c 12 )][$( rigPane c 13 )][$( rigPane c 14 )]" \
	"[ claude][     present                  /rig/harness/claude.sh][     ANTHROPIC_API_KEY        configured][   ! CLAUDE_CODE_OAUTH_TOKEN  not configured][     usable                   yes]"
rigAssert "nothing of the value of a secret is on the screen, though its row carried one" "$( rigScreenHolds c 'sk-must' ) $( rigScreenHolds c 'never-show' ) $( LC_ALL=C grep -c -F 'sk-must-never-show' "$MANAGER_SCREEN_RIG/rows.--manager-config-digest" )" "0 0 1"
rigAssert "a CLI that is not usable is marked"                       "[$( rigPane c 16 )][$( rigPane c 17 )]" "[ grok][   ! usable  no]"
rigAssert "systems: a scope that is set, and one that is set and lacks keys" "[$( rigPane s 4 )][$( rigPane s 6 )][$( rigPane s 7 )][$( rigPane s 8 )]" \
	"[ 4 lines, 2 missing, each marked !][ slack][     magic-team         set][     magic-coordinator  set, lacks SLACK_APP_TOKEN, SLACK_SIGNING_SECRET]"
rigAssert "a scope that misses a key, and a system no scope holds"   "[$( rigPane s 10 )][$( rigPane s 11 )][$( rigPane s 13 )][$( rigPane s 14 )]" "[ confluence][   ! magic-team  missing: CONFLUENCE_SPACE][ jira][   ! no scope  missing]"
rigAssert "loop: no line is missing, and a date reads with its spaces" "$( rigVal l.selected ) [$( rigPane l 4 )][$( rigPane l 6 )][$( rigPane l 7 )][$( rigPane l 9 )][$( rigPane l 10 )][$( rigPane l 11 )]" \
	"loop [ 3 lines][ main-loop][     MAIN_LOOP_LAST_OUTCOME  failed][ heartbeat][     recheck-date  2026-10-09 04:28 +0000][     running       no]"

echo "-- a subject longer than the pane scrolls with the focus on the left pane --"
rigCase scroll
rigSize="120 20"
rigScript <<'RIGSCRIPT'
keys DOWN DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN
turn
get top
show top
keys TAB PGDN
get paged
show paged
keys PGDN PGDN PGDN
get end
show end
RIGSCRIPT
rigSize=""
rigAssert "scopes is selected, longer than the pane, shown from its top" "$( rigVal top.selected ) $( rigVal top.viewLines ) $( rigVal top.viewTop ) [$( rigPane top 3 )][$( rigPane top 6 )]" "scopes 50 0 [ scopes: each scope that holds a key, with its keys][ magic-coordinator]"
rigAssert "with the focus on the left pane, PageDown shows its next page" "$( rigVal paged.focus ) $( rigVal paged.viewTop ) [$( rigPane paged 3 )]" "view 16 [     KEY_11           value_11]"
rigAssert "and reaches its last lines: a key and a secret that are missing, marked" "$( rigPaneHolds end '   ! TRELLO_BOARD  missing' ) $( rigPaneHolds end '   ! TRELLO_TOKEN  not configured' ) $( rigVal end.spills )" "1 1 0"

echo "-- viewing only: typing in the section changes nothing --"
rigCase viewing
rigScript <<'RIGSCRIPT'
keys DOWN DOWN DOWN ENTER
wait list 30
keys DOWN DOWN
turn
keys y e SPACE o ENTER
get typed
keys RIGHT
get dived
keys k
get kill
keys ESC
keys n
get start
keys ESC
keys TAB y ENTER TAB
turn 3
get end
RIGSCRIPT
rigAssert "a text is typed on a subject and Enter is pressed: no line opens, and nothing is submitted" "[$( rigVal typed.dialog )] [$( rigVal typed.notice )] $( rigVal typed.selected ) $( rigVal typed.quit )" "[] [] cli no"
rigAssert "Enter and Right dive nowhere"                             "$( rigVal dived.path ) $( rigVal dived.selected )" "settings cli"
rigAssert "the keys of the actions find nothing to act on"           "[$( rigVal kill.dialogHolds )][$( rigVal start.dialogHolds )] [$( rigVal start.dialog )]" "[k: nothing to kill here: k kills a session or an agent][n: nothing to start here: n starts a team member with a prompt] [message:ok|]"
rigAssert "no operation was called but the two reads, and the digest never with an argument" "$( rigOthers ) $( rigCalled --manager-config-digest ) $( rigVal end.calls ) [$( rigVal end.dialog )]" "0 1 0 []"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN SETTINGS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_SETTINGS: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
