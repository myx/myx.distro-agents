#!/usr/bin/env bash
## Behavioural check on the left panes of the manager screen (sh-lib/AgentsManagerScreen.py) by the owner's rule:
## structured, padded, coloured, compact, what matters first, nothing unimportant, and a folder never shows less than the
## list on the right. Run rather than read, through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.test.py) and the stand-in for the dispatcher (check-fixtures/manager-screen.tools.test.sh).
## Held, view by view: Sessions (a bold caption; every session of the list in one table of the left pane, its state in the
## colour of what is well, to look at, or over; `e` and the title where the pane holds fewer); a session (its agents as a
## table under a heading, no thread ids, its id last); Launch / Spawn (every routine, its start in its colour); Pending
## (every ask as a table, a gone asker in red); an ask (its question ahead of its facts, no Slack ids, no hint); Team Data
## (Items, Git, Board, Main loop as headings, no hint); Operations (a table); Locations (every location with its path); a
## location (what stands in it under its path, what lies outside whole; its members as one table, an unregistered one in
## the colour of what to look at); Consoles (a table); Settings and Configuration (a table with what each subject is, the
## folders of Configuration among its rows); a subject (a table, a missing value in its colour, no hint); Config Checker
## (every check, the worst first, in its colour); Server Keys (a public line whole); Tooling Commands (a table, a command
## a row, its name and its path). Offline:
## no operation of the real tooling is called.
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
rigTmp="$( mktemp -d -t AgentsManagerScreenLeftPanesCheck )" || exit 1
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
rigT=$'\t'
## the fixtures, one read each, as the operations print them
{
	printf 'block\tteam-data\tTeam_Data\t6\n'
	printf 'figure\tteam-data\t%s\n' "root${rigT}Team_Data_Root${rigT}/rig/td${rigT}-${rigT}-${rigT}-" "present${rigT}Team_Data_Present${rigT}yes${rigT}-${rigT}ok${rigT}-" \
		"size${rigT}Team_Data_Size${rigT}1048576${rigT}bytes${rigT}-${rigT}-" "audit-items${rigT}Audit_Items${rigT}7${rigT}count${rigT}-${rigT}-" \
		"board-running${rigT}Board_Items_Running${rigT}2${rigT}count${rigT}-${rigT}-" "board-review${rigT}Board_Items_Review${rigT}1${rigT}count${rigT}-${rigT}-"
} > "rows.--manager-dashboard-read"
{
	cat "rows.--manager-dashboard-read"
	printf 'block\tteam-data-git\tTeam_Data_Git\t4\n'
	printf 'figure\tteam-data-git\t%s\n' "repository${rigT}Team_Data_Repository${rigT}yes${rigT}-${rigT}-${rigT}-" "branch${rigT}Team_Data_Branch${rigT}main${rigT}-${rigT}-${rigT}-" \
		"upstream${rigT}Team_Data_Upstream${rigT}origin/main${rigT}-${rigT}-${rigT}-" "ahead${rigT}Commits_Ahead${rigT}2${rigT}count${rigT}warn${rigT}-"
	printf 'block\tloop\tMain_Loop_And_Heartbeat\t1\nfigure\tloop\tmain-loop-outcome\tMain_Loop_Last_Outcome\tfailed\t-\tbad\t-\n'
} > "rows.--manager-dashboard-read team-data team-data-git loop"
{
	printf 'session\tS-alpha\talpha_work\trunning\t2026-10-14_17:00_+0000\t2026-10-14_17:00_+0000\t1\trunning=1\trunning\t2026-10-14_17:00_+0000\talive\t5000\n'
	printf 'run\tS-alpha\tS-alpha\tkeeper-rig\tactive\trunning\trunning\t2026-10-14_17:00_+0000\t-\trig-host\t/rig/ws\tworking\n'
	printf 'session\tS-beta\tbeta_work\tunclosed\t2026-10-13_10:00_+0000\t2026-10-13_11:00_+0000\t1\tunclosed=1\trunning\t2026-10-13_10:00_+0000\tgone\t900\n'
	printf 'run\tS-beta\tS-beta\tmagic-tester\tactive\tno-process\tunclosed\t2026-10-13_10:00_+0000\t-\trig-host\t/rig/ws\t-\n'
	printf 'session\tS-gamma\tgamma_work\tfinished\t2026-10-12_10:00_+0000\t2026-10-12_11:00_+0000\t1\tfinished=1\tfinished\t2026-10-12_11:00_+0000\tnone\t100\n'
	printf 'run\tS-gamma\tS-gamma\tkeeper-rig\tactive\tno-process\tfinished\t2026-10-12_10:00_+0000\t2026-10-12_11:00_+0000\trig-host\t/rig/ws\t-\n'
	for rigNo in $( seq -w 1 40 ) ; do
		printf 'session\tS-old%s\told_%s\tfinished\t2026-10-01_10:00_+0000\t2026-10-01_11:00_+0000\t0\t-\tfinished\t-\tnone\t-\n' "$rigNo" "$rigNo"
	done
	printf 'counters\t1\t0\t1\t0\t2\t0.50\trig-host\n'
} > "rows.--manager-session-list"
{
	printf 'dispatch\tS-alpha\tfounder\tmagic-coordinator\t-\titem-1\t1790000000.000100\t1790000000.000200\tWork on alpha.\n'
	printf 'control\tS-alpha\trunning\t2026-10-14_17:00_+0000\talive\t4242\n'
	printf 'run\tS-alpha\tS-alpha\tkeeper-rig\tactive\trunning\trunning\t2026-10-14_17:00_+0000\t-\trig-host\t/rig/ws\tworking\n'
} > "rows.--manager-session-read --session-id S-alpha"
printf 'routine\tkeeper-rig.alpha-gap.routine.md\tkeeper-rig\tstartable\tkeeper-rig\t-\t-\tAlpha_gap\t-\nroutine\tkeeper-rig.beta-gap.routine.md\tkeeper-rig\tnot-startable\t-\t-\t-\tBeta_gap\tno_executors\n' > "rows.--manager-routine-list"
cat > "rows.--member-pending-reply-read magic-coordinator --any-owner" <<'RIGASKS'
PENDING-REPLY: A-one
status: reply-pending
owner: keeper-gone
kind: decision
channel: C0RIGCHAN01
question-ts: 1790852505.651369
thread-ts: 1790849290.896079
address-to: human-owner
session-id: 56a396d9-0000-4000-8000-0000000000a1
asked-at: 2026-10-10 14:00 +0000
asker-live: no-process
question: Which way is right for the first ask?

PENDING-REPLY: A-two
status: reply-pending
owner: keeper-live
kind: question
channel: C0RIGCHAN02
question-ts: 1791830000.000200
thread-ts: 1791820000.000100
address-to: magic-coordinator
session-id: 59056eb9-0000-4000-8000-0000000000b2
asked-at: 2026-10-14 17:30 +0000
asker-live: running
question: May the second ask go on?

PENDING-REPLIES: 2
RIGASKS
printf 'place\trig-ws\tRig_Ws\tworkspace\tread-write\t/rig/ws\tpresent\tyes\t3\nplace\trig-far\tRig_Far\tdirectory\tread-only\t/rig/far-ENDPATH\tnot-present\tno\t-\n' > "rows.--manager-place-list"
{
	printf 'info\tdeclared-by\tbuilt-in\n'
	printf 'stands\tsettings\tMDLT\t/rig/ws/.local/MDLT.settings.env\nstands\tlink\tskills\t/elsewhere/skills\n'
	printf 'member\tkeeper-rig\tkeeper\t/rig/ws\there\t/rig/ws/.local/agents/keeper-rig\nmember\tstray-one\tkeeper\t/x\tnot-in-registry\t/other/stray\n'
} > "rows.--manager-place-read rig-ws"
printf 'console\trig-shell\tshell\tRig_Shell\tterminal\t/rig/ws\t/bin/bash\t-i\nconsole\trig-tool\ttools\tRig_Tool\tterminal\t/rig/ws\t/rig/tool.sh\n' > "rows.--manager-console-list"
{
	printf 'subject\tinterface\t1\tInterface_Settings\n'
	printf 'line\tinterface\tstyle\tRIG_STYLE\tset\tplain\tInterface_Style\tHow_it_looks\tyes\t-\tuser\tuser\t-\t-\tsettings\n'
	printf 'subject\tcli\t2\tCLI_Services\n'
	printf 'line\tcli\tservice\tRIG_CLI_A\tmissing\t-\tCli_A\tWhich_cli\tno:deployed\t-\t-\tenvironment\t-\t-\tconfiguration\n'
	printf 'line\tcli\tservice\tRIG_CLI_B\tset\tclaude\tCli_B\t-\tno:deployed\t-\t-\tdefault\t-\t-\tconfiguration\n'
} > "rows.--manager-config-digest --full"
printf 'check\tinstall\tcore\tbash\tBash_Version\tok\t-\t-\ncheck\tinstall\tcore\tgit\tGit_Remote\tfail\tno_answer\tssh_-T\nsummary\t2\t1\t0\t1\t0\t3\n' > "rows.--manager-check-run"
printf 'group\tg1\t1\tKeys_To_Trust\t-\nkey\tk1\tRig_Key\tg1\tthe_rig_key\tssh-ed25519\tSHA256:rigprint\tshort\t/rig/k1.pub\tpresent\n' > "rows.--manager-keys-list"
printf 'paste\tssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK3WPzg7i8YabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ENDKEY rig@host\n' > "rows.--manager-keys-read k1"
printf 'CmdOne.fn.sh\nCmdTwo.fn.sh\nCmdThree.fn.sh\nCmdFour.fn.sh\nCmdFive.fn.sh\n' > "rows.--manager-command-list"
: > "$MANAGER_SCREEN_RIG/calls"
: > "$MANAGER_SCREEN_RIG/words"
echo rows > "$MANAGER_SCREEN_RIG/mode"

## each view: what it shows (show <tag>) and the looks of its cells by their roles (roles <tag>r)
rigOut="$( "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 <<RIGSCRIPT
tools bash $rigTools
wall 2026-10-14 18:30 +0000
size 120 40
turn
wait list 10
keys 2
wait list 10
show sessions
roles sessionsr
keys e
turn
show sessionsAll
keys e DOWN
wait focus 10
show launch
roles launchr
keys DOWN
wait view 10
show session
roles sessionr
keys 3
wait list 10
show pending
roles pendingr
keys DOWN
wait view 10
show ask
keys 5
wait list 10
show teamdata
keys DOWN
wait focus 10
show operations
roles operationsr
keys 6
wait list 10
show places
roles placesr
keys DOWN
wait view 10
show place
roles placer
keys 7
wait list 10
show consoles
keys 8
wait list 10
show settings
keys DOWN
wait focus 10
show subject
keys 9
wait list 10
show configuration
keys DOWN
wait focus 10
keys r
wait check 30
turn
show checker
roles checkerr
keys DOWN
wait focus 10
wait plan 10
turn
show keys
keys DOWN
wait focus 10
show commands
keys DOWN
wait focus 10
show cli
roles clir
RIGSCRIPT
)"
rigPane(){ ## tag -- the lines of the left pane of that screen, without its frame
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n '3,$p' | LC_ALL=C sed -E -e "s/^$1\|(│|║)//" -e 's/(│|║|▲|▼|▒|■).*$//'
}
rigTitle(){ ## tag -- the top border of the left pane
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n '2p'
}
rigHas(){ ## tag, text -- 1 where the left pane holds the text, else 0
	rigPane "$1" | LC_ALL=C grep -c -F -- "$2" | LC_ALL=C awk '{ print ( $1 > 0 ) }'
}
rigRoles(){ ## tag, text -- the looks, by their roles, of the first line of the left pane that holds the text
	printf '%s\n' "$rigOut" | "$rigPython" -I -B -c '
import sys
tag, text = sys.argv[1:3]
lines = sys.stdin.read().split("\n")
shown = [line for line in lines if line.startswith(tag + "|")]
roles = [line for line in lines if line.startswith(tag + "r|")]
for number, line in enumerate(shown):
    ## the left pane alone: up to its right frame
    edges = [at for at, mark in enumerate(line) if mark in "│║"] + [len(line), len(line)]
    if text in line[:edges[1]] and number < len(roles):
        print(roles[number][len(tag) + 2:edges[1] + 1]) ; break
' "$1" "$2"
}
rigRole(){ ## tag, text, role letter -- 1 where the line that holds the text has a cell of that look
	rigRoles "$1" "$2" | LC_ALL=C grep -c -F -- "$3" | LC_ALL=C awk '{ print ( $1 > 0 ) }'
}
rigHeading(){ ## tag, text -- 1 where a line of the left pane is that text alone, else 0
	rigPane "$1" | LC_ALL=C sed 's/  *$//' | LC_ALL=C grep -c -x -F -- "$2" | LC_ALL=C awk '{ print ( $1 > 0 ) }'
}
rigLineOf(){ ## tag, text -- the number of the line of the left pane that holds the text, or 0
	rigPane "$1" | LC_ALL=C grep -n -F -- "$2" | head -1 | LC_ALL=C sed 's/:.*//' | LC_ALL=C awk '{ print $1 + 0 } END { if ( NR == 0 ) print 0 }'
}

echo "-- Sessions, Launch / Spawn, a session --"
rigAssert "Sessions: a bold caption, every state it holds; one table of every session, finished ones too, in the order of the list" \
	"$( rigRole sessions '43 sessions' B ) $( rigHas sessions '1 running, 1 unclosed, 41 finished' ) $( rigHas sessions 'SESSION' ) $( rigHas sessions 'alpha work' ) $( rigHas sessions 'gamma work' ) $( [ "$( rigLineOf sessions 'alpha work' )" -lt "$( rigLineOf sessions 'gamma work' )" ] && echo ordered )" \
	"1 1 1 1 1 ordered"
rigAssert "Sessions: a running state in the look of what is well, a gone control thread in that of what is bad, a finished one dim" \
	"$( rigRole sessions 'alpha work' k ) $( rigRole sessions 'beta work' X ) $( rigRole sessions 'gamma work' D )" "1 1 1"
rigAssert "Sessions: the pane holds fewer rows than the list, says how many more, its title says so, and e shows every row" \
	"$( rigHas sessions 'more' ) $( rigTitle sessions | LC_ALL=C grep -c -E '\[[0-9]+ rows\]' ) $( rigTitle sessionsAll | LC_ALL=C grep -c -F '[all rows]' ) $( rigHas sessionsAll 'more' )" "1 1 1 0"
rigAssert "Launch / Spawn: every routine as a table, its start in its colour" \
	"$( rigHas launch 'ROUTINE' ) $( rigHas launch 'alpha-gap' ) $( rigHas launch 'beta-gap' ) $( rigRole launch 'alpha-gap' k ) $( rigRole launch 'beta-gap' X )" "1 1 1 1 1"
rigAssert "a session: its agents as a table under a heading, its state in its colour; no thread ids; its id last" \
	"$( rigHeading session 'Agents' ) $( rigRole session 'MEMBER' u ) $( rigRole session 'state ' k ) $( rigHas session '1790000000' ) $( rigHas session 'threads' ) $( [ "$( rigLineOf session 'S-alpha' )" -gt "$( rigLineOf session 'Work on alpha' )" ] && echo last )" \
	"1 1 1 0 0 last"

echo "-- Pending Questions and an ask --"
rigAssert "Pending: a bold caption; every ask as a table with its question; a gone asker in the look of what is bad" \
	"$( rigRole pending '2 asks wait' B ) $( rigHas pending 'QUESTION' ) $( rigHas pending 'first ask' ) $( rigHas pending 'second ask' ) $( rigRole pending 'keeper-gone' X ) $( rigRole pending 'keeper-live' X )" \
	"1 1 1 1 1 0"
rigAssert "an ask: its question ahead of its facts; no channel, thread or session of Slack; no hint" \
	"$( [ "$( rigLineOf ask 'second ask' )" -lt "$( rigLineOf ask 'asked by' )" ] && echo first ) $( rigHas ask 'C0RIGCHAN02' ) $( rigHas ask '59056eb9' ) $( rigHas ask 'answered where it was posted' )" \
	"first 0 0 0"

echo "-- Team Data, Operations --"
rigAssert "Team Data: Items, Git, Board and the main loop under headings; no hint" \
	"$( rigHeading teamdata 'Items' ) $( rigHeading teamdata 'Git' ) $( rigHeading teamdata 'Board' ) $( rigHas teamdata 'Main loop and heartbeat' ) $( rigHas teamdata 'Enter opens it' )" "1 1 1 1 0"
rigAssert "Operations: a table, whether each runs here in its colour; no sentence under it" \
	"$( rigHas operations 'OPERATION' ) $( rigRole operations 'Purge The Cleanup Folder' k ) $( rigHas operations 'Each is asked first' )" "1 1 0"

echo "-- Locations and a location --"
rigAssert "Locations: every location as a table with its path, the one not present in its colour; no sentence" \
	"$( rigHas places 'PATH' ) $( rigHas places 'ENDPATH' ) $( rigRole places 'rig-far' X ) $( rigHas places 'In the other views' )" "1 1 1 0"
rigAssert "a location: what stands in it under its path, what lies outside whole; its members as one table, an unregistered one in its colour" \
	"$( rigHas place 'What stands in it' ) $( rigHas place '.local/MDLT.settings.env' ) $( rigHas place '/rig/ws/.local/MDLT' ) $( rigHas place '/elsewhere/skills' ) $( rigHas place 'SETUP' ) $( rigRole place 'stray-one' W )" \
	"1 1 0 1 1 1"

echo "-- Consoles, Settings, Configuration --"
rigAssert "Consoles: every console as a table with its command; no sentence" \
	"$( rigHas consoles 'CONSOLE' ) $( rigHas consoles 'Rig Tool' ) $( rigHas consoles '/rig/tool.sh' ) $( rigHas consoles 'Enter starts one' )" "1 1 1 0"
rigAssert "Settings: its subjects as a table with what each holds; Configuration: its folders among them" \
	"$( rigHas settings 'WHAT' ) $( rigHas settings 'how this console looks' ) $( rigHas configuration 'Config Checker' ) $( rigHas configuration 'Server Keys' )" "1 1 1 1"
rigAssert "a subject: its lines as a table, a missing value in its colour; no hint" \
	"$( rigHas cli 'KEY' ) $( rigHas cli 'SETTING' ) $( rigRole cli 'RIG_CLI_A' W ) $( rigHas cli 'Enter opens it' ) $( rigHas subject 'Enter opens it' )" "1 0 1 0 0"
rigAssert "Config Checker: every check as a table, the worst first, in its colour" \
	"$( rigHas checker 'CHECK' ) $( [ "$( rigLineOf checker 'Git Remote' )" -lt "$( rigLineOf checker 'Bash Version' )" ] && echo worst ) $( rigRole checker 'Git Remote' X )" "1 worst 1"
rigAssert "Server Keys: a table, a public line whole; Tooling Commands: a caption and a table, a command a row with its path" \
	"$( rigHas keys 'PUBLIC LINE' ) $( rigHas keys 'rig@host' ) $( rigPane keys | LC_ALL=C sed 's/  *$//' | LC_ALL=C grep -c '…$' ) $( rigHas commands '5 commands.' ) $( rigPane commands | LC_ALL=C grep -c 'NAME  *PATH' ) $( rigPane commands | LC_ALL=C grep -c 'CmdOne.fn.sh  *Cmd' ) $( rigPane commands | LC_ALL=C grep -c 'CmdOne.fn.sh  *-' )" "1 1 0 1 1 0 1"
rigAssert "nothing was drawn past a pane" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'DRIVER-FAILED\|Traceback' || : )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN LEFT PANES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_LEFT_PANES: OK (%d assertions, offline)\n' "$rigPassCount"
