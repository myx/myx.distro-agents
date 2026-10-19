#!/usr/bin/env bash
## Behavioural check on the leftovers of the manager screen (sh-lib/AgentsManagerScreen.py), the small things its
## specification left for last, run rather than read. The screen's own code runs through the stand-in terminal of
## the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a
## stand-in script (check-fixtures/manager-screen.tools.stub.sh), which notes each start and prints the fixture.
## Held: the title of the left window always says how its long lines are shown, `[wrap]` or `[cut]`, beside the
## mode of a thing that has a log, in every style, and the choice is kept as the selection moves; the status line
## names the key of the help, last of the keys that work in every window; a kill whose plan could not be read is
## not asked for: its dialog says so, takes no word and has Cancel alone, and no kill reaches the tooling.
## The number keys of the roots follow the order of the root list, top to bottom, `Launch (Start)` after them, and the
## menu Go names them so.
## And, with the real screen on a pseudo-terminal that is its controlling terminal: while a child has the whole
## terminal, an interrupt and a quit typed there reach the child and never end the screen, and a stop typed there
## leaves neither the child nor the screen stopped: the child reads on, ends in order, and the screen is back.
## Offline: no operation of the real tooling is called.
## Reconciled for F11.0: `Launch / Spawn` is named `Launch (Start)`, `Consoles (Tools)` `Consoles`.
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
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenLeftoversCheck )" || exit 1
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
## What no machine has: five sessions, one running with three runs of two members, one waiting whose control thread
## is gone, one unclosed, two finished; three asks, the oldest of a run that is gone; four members, one running, one
## that is nobody to start and one whose workspace is not here; three locations, one absent; three things to start
## in two groups; a subject of the settings and one of the configuration, with a secret that is set and one that is
## missing; four routines, one started here, one with members named, one broken, one not for a hand; two groups of
## server keys, a key whose row carries its whole line and one that is absent; two checks; one block.
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow session s-run daily_of_Monday running 2026-10-13T01:00:00Z - 3 running=2,finished=1 running 2026-10-13T01:00:05Z alive 57100000
	rigRow run s-run sp-1 magic-coordinator done running running 2026-10-13T01:00:00Z - righost ws-one working
	rigRow run s-run sp-2 keeper-myx done running running 2026-10-13T01:01:00Z - righost ws-one waiting
	rigRow run s-run sp-3 keeper-myx done ended finished 2026-10-13T01:02:00Z 2026-10-13T01:05:00Z righost ws-one -
	rigRow session s-wait review_of_the_board waiting 2026-10-13T00:00:00Z - 1 waiting=1 waiting 2026-10-13T00:00:05Z gone 1200+
	rigRow run s-wait sp-4 magic-architect done running waiting 2026-10-13T00:00:00Z - righost ws-one waiting
	rigRow session s-open - unclosed 2026-10-12T00:00:00Z - 0 - - - none 0
	rigRow session s-done old_work finished 2026-10-11T00:00:00Z 2026-10-11T01:00:00Z 2 finished=2 - - none 900
	rigRow session s-done2 older_work finished 2026-10-10T00:00:00Z 2026-10-10T01:00:00Z 1 finished=1 - - none 100
	rigRow counters 1 0 2 2 3 0.42 righost
} > "$rigF/rows.--manager-session-list"
cat > "$rigF/rows.--member-pending-reply-read" <<'RIGROWS'
PENDING-REPLY: ask-new
asked-at: 2026-10-13 02:20 +0000
kind: question
owner: keeper-myx
address-to: human-owner
question: Which of the two layouts stays?
asker-live: running

PENDING-REPLY: ask-old
asked-at: 2026-10-10 02:30 +0000
kind: approval
owner: magic-devops
address-to: human-owner
question: May the old volume be removed now that the copy is proven on the second host?
asker-live: no-process

PENDING-REPLY: ask-mid
asked-at: 2026-10-13 00:30 +0000
kind: question
owner: keeper-acm
address-to: magic-coordinator
question: Who owns the template of the report?
asker-live: running

PENDING-REPLIES: 3
RIGROWS
{
	rigRow member magic-coordinator MC Magic Coordinator Magic lead ws-one present active running -
	rigRow member keeper-myx KM Keeper Myx - keeper ws-one present active idle -
	rigRow member human-owner HO Human Owner - human ws-one present reference-only idle -
	rigRow member far-member FM Far Member - keeper ws-far not-present active idle -
} > "$rigF/rows.--manager-team-member-list"
{
	rigRow place ws-one Ws_One workspace read-write /rig/Workspaces/ws-one present yes 2
	rigRow place gone-work Gone_Work workspace read-write /rig/Volumes/gone-work absent no 0
	rigRow place deep Deep directory read-only /rig/Workspaces/ws-one/source/deep present no -
} > "$rigF/rows.--manager-place-list"
{
	rigRow console agents Distro Agents_Console terminal /rig/Workspaces/ws-one bash DistroAgentsConsole.sh
	rigRow console source Distro Source_Console terminal /rig/Workspaces/ws-one bash DistroSourceConsole.sh
	rigRow console top System Top terminal /rig top
} > "$rigF/rows.--manager-console-list"
{
	rigRow subject interface 2 Interface
	rigRow subject slack 3 Slack
	rigRow line interface screen style set tv Style How_the_screen_is_drawn yes choice user file tv=Turbo_Vision,magic=Magic /rig/conf settings
	rigRow line interface screen period set 10 Period Seconds_between_reads yes number user file 1..60 /rig/conf settings
	rigRow line slack app channel set C123 Channel The_channel no:set_at_deployment text workspace file - /rig/conf configuration
	rigRow line slack app token secret-set hidden-value Bot_token The_token_of_the_bot no:set_at_deployment text workspace file - /rig/conf configuration
	rigRow line slack hooks signing secret-missing - Signing_secret The_signing_secret no:set_at_deployment text workspace file - /rig/conf configuration
} > "$rigF/rows.--manager-config-digest"
{
	rigRow routine magic-coordinator.daily.routine.md magic-coordinator startable any work - Daily_meeting - -
	rigRow routine magic-coordinator.retro.routine.md magic-coordinator not-startable any work - Retro needs_members members
	rigRow routine keeper-myx.sweep.routine.md keeper-myx broken - work - Sweep its_file_is_broken -
	rigRow routine keeper-myx.audit.routine.md keeper-myx not-startable keeper-myx work - Audit not_for_a_hand -
} > "$rigF/rows.--manager-routine-list"
{
	rigRow group git 1 To_add_to_git -
	rigRow key deploy Deploy_key git outgoing ssh-ed25519 SHA256:abcdef short-marker /rig/keys/deploy.pub present ssh-ed25519_AAAAC3NzaWHOLEKEY_rig@host
	rigRow group trust 1 To_trust_when_connecting -
	rigRow key host Host_key trust incoming ssh-ed25519 SHA256:fedcba short-marker /rig/keys/host.pub absent
} > "$rigF/rows.--manager-keys-list"
{
	rigRow check install tools bash Bash ok fine -
	rigRow check slack app token Token fail the_token_is_missing set_the_token
	rigRow summary 2 1 0 1 0 12
} > "$rigF/rows.--manager-check-run"
{
	rigRow block data Team_Data 1
	rigRow figure data root Team_Data_Root 12 count ok -
} > "$rigF/rows.--manager-dashboard-read"
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
	rigOut="$( { printf 'tools bash %s\nwall 2026-10-13 02:30 +0000\nsize 120 36\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigLeft(){ ## tag -- what the left window of that screen holds: its lines that hold something, without the frame, a ` / ` between two
	RIG_OUT="$rigOut" "$rigPython" -I -B -c '
import os, re, sys
held = []
for line in os.environ["RIG_OUT"].split("\n"):
    found = re.match(r"^%s\|[│║](.*?)[│║▒▲▼■]" % re.escape(sys.argv[1]), line)
    if found and found.group(1).strip():
        held.append(found.group(1).rstrip())
print(" / ".join(held))
' "$1"
}
rigCalls(){ ## text -- how many starts of the stand-in name it in their words
	LC_ALL=C grep -c -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigFolderCalls(){ ## how many starts were of the lists that only a folder asks for: not of those that are read whatever is shown
	LC_ALL=C grep -c -v -e '^--manager-dashboard-read$' -e '^--manager-place-list$' -e '^--manager-session-list' "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- the title of the left window always shows the wrap state --"
rigCase title
rigScript <<'RIGSCRIPT'
turn
wait sessions 5
border t0 1 0 84
keys DOWN
turn
border t1 1 0 84
keys TAB w
border t2 1 0 84
keys TAB DOWN
turn
border t3 1 0 84
keys UP ENTER DOWN DOWN
turn
border t4 1 0 84
keys TAB w TAB
border t5 1 0 84
style bw
turn
border t6 1 0 84
style magic
turn
show m
RIGSCRIPT
rigAssert "wrapped, as the screen starts: the title says so, on every row" "[$( rigVal t0 )] [$( rigVal t1 )]" "[Dashboard (Monitor) [wrap]] [Sessions (Activity) [wrap]]"
rigAssert "w in the left window: the title says cut, and still does when the selection has moved" "[$( rigVal t2 )] [$( rigVal t3 )]" "[Sessions (Activity) [cut]] [Pending Questions [cut]]"
rigAssert "a thing that has a log: the wrap state stands beside its mode, cut and then wrapped again" "[$( rigVal t4 )] [$( rigVal t5 )]" "[daily of Monday [summary] [cut]] [daily of Monday [summary] [wrap]]"
rigAssert "with no colours and in Magic too" "[$( rigVal t6 )] $( rigHolds m 'daily of Monday [summary] [wrap]' )" "[daily of Monday [summary] [wrap]] 1"

echo "-- Help has its word in the status line --"
rigCase help
rigScript <<'RIGSCRIPT'
turn
wait sessions 5
cells status 35 0 120
keys TAB
cells statusLeft 35 0 120
keys ?
get h
RIGSCRIPT
rigAssert "the status line names the key of the help, last of the keys that work in every window, whichever window has the keys; the key opens the box of the keys" "[$( rigVal status )] [$( rigVal statusLeft )] [$( rigVal h.dialogTitle )]" "[ ENTER Open  a Active  u Read  m Menu  ^X Exit  TAB Window  ? Help] [ u Read  m Menu  ^X Exit  TAB Window  ? Help] [Keys]"

echo "-- a kill whose plan cannot be read is not asked for --"
rigCase unread
echo fail > "$MANAGER_SCREEN_RIG/mode.--manager-session-kill"
rigScript <<'RIGSCRIPT'
turn
wait sessions 5
keys DOWN ENTER DOWN DOWN
turn
keys k
wait plan 5
turn
get k
box kb
keys y e s ENTER
turn
wait action 5
get after
RIGSCRIPT
rigAssert "the dialog says that the plan could not be read and that nothing is done, takes no word, and has Cancel alone" "[$( rigVal k.selected )] [$( rigVal k.dialog )] $( rigVal k.dialogHolds | LC_ALL=C grep -c -F 'What its kill would do could not be read: rig-tools: ⛔ ERROR: the rig said fail / So it is not asked for: nothing is killed, dismissed or closed.' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^kb|' | LC_ALL=C grep -c -F ' »Cancel« ▅' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^kb|' | LC_ALL=C grep -c -e 'Kill \]' -e 'Close \]' -e 'Type yes' )" "[s-run] [kill:cancel|] 1 1 0"
rigAssert "the word typed and Enter leave it: no kill was asked of the tooling, only its plan was read" "[$( rigVal after.dialog )] $( LC_ALL=C grep -c -x -F -- '--manager-session-kill --session-id s-run' "$MANAGER_SCREEN_RIG/calls" ) $( LC_ALL=C grep -c -x -F -- '--manager-session-kill --session-id s-run --plan' "$MANAGER_SCREEN_RIG/calls" )" "[] 0 1"

echo "-- the number keys of the roots follow the order of the root list --"
rigCase digits
rigScript <<'RIGSCRIPT'
turn
wait sessions 5
keys 1
get k1
keys 2
get k2
keys 3
get k3
keys 4
get k4
keys 5
get k5
keys 6
get k6
keys 7
get k7
keys 8
get k8
keys 9
get k9
keys ALT-4
get a4
keys m
turn
show go
RIGSCRIPT
rigAssert "1 to 9 go to the roots in the order of the list, the ninth Manuals (Help); Launch (Start) after them has none past nine; Alt with a number does the same" "$( rigVal k1.path ) $( rigVal k2.path ) $( rigVal k3.path ) $( rigVal k4.path ) $( rigVal k5.path ) $( rigVal k6.path ) $( rigVal k7.path ) $( rigVal k8.path ) $( rigVal k9.path ) $( rigVal a4.path )" "dashboard sessions pending team places consoles settings configuration manuals team"
rigAssert "the menu Go names them so, top to bottom" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^go|' | LC_ALL=C grep -o -e 'Dashboard (Monitor)  *1 ' -e 'Sessions (Activity)  *2 ' -e 'Pending Questions  *3 ' -e 'Team Members  *4 ' -e 'Locations (Places)  *5 ' -e 'Consoles  *6 ' -e 'Settings  *7 ' -e 'Configuration  *8 ' -e 'Manuals (Help)  *9 ' | LC_ALL=C sed 's/   */ /g;s/ $//' | LC_ALL=C tr '\n' '|' )" "Dashboard (Monitor) 1|Sessions (Activity) 2|Pending Questions 3|Team Members 4|Locations (Places) 5|Consoles 6|Settings 7|Configuration 8|Manuals (Help) 9|"

echo "-- the real screen on a pseudo-terminal it controls: an interrupt, a quit and a stop typed while a child has the terminal are the child's alone --"
rigCase child
mkdir -p "$rigTmp/ws-rig"
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigTools" > "$rigTmp/tools"
chmod +x "$rigTmp/tools"
## a child that says when it is up, says each interrupt and each quit it is sent, and ends in order when it reads the line `x`
cat > "$rigTmp/child.sh" <<'RIGCHILD'
trap 'echo GOT-INT' INT
trap 'echo GOT-QUIT' QUIT
echo CHILD-UP
while : ; do
	if IFS= read -r rigLine ; then
		echo "READ-$rigLine"
		[ "$rigLine" != x ] || exit 0
	fi
done
RIGCHILD
rigRow console child Rig Rig_Child terminal "$rigTmp" bash "$rigTmp/child.sh" > "$MANAGER_SCREEN_RIG/rows.--manager-console-list"
rigOut="$( MANAGER_SCREEN_PTY_SESSION=1 MANAGER_SCREEN_PTY_TRACE='up=CHILD-UP|int=GOT-INT|quit=GOT-QUIT|read=READ-x|ended=Rig Child: ended with status 0' "$rigPython" -I -B "$rigDriver" "$rigScreen" pty 120 36 "Sessions (Activity)" '\x1bOB\p\x1bOB\p\x1bOB\p\x1bOB\p\x1bOB\p\aRig Child\a\r\p\x1bOB\p\r\p\aCHILD-UP\a\x03\p\aGOT-INT\a\x1c\p\aGOT-QUIT\a\x1a\px\r\p\aended with status 0\a\x18' 60 -- "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" 2>&1 )"
rigAssert "Ctrl-C and Ctrl-\\ reach the child, which says so and runs on; after Ctrl-Z it still reads its line and ends in order; the screen is back, says how it ended, and ends with status 0 by its own key, having left its screen" "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.errorAfterLeft ) [$( rigVal pty.trace | LC_ALL=C tr ' ' '\n' | LC_ALL=C uniq | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )]" "yes 0 yes none [up int quit read ended]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN LEFTOVERS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_LEFTOVERS: OK (%d assertions, offline, stand-in terminal, stand-in dispatcher and one pseudo-terminal)\n' "$rigPassCount"
