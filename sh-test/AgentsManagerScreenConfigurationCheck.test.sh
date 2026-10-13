#!/usr/bin/env bash
## Behavioural check on the two folders of the root `Configuration` of the manager screen (sh-lib/AgentsManagerScreen.py),
## `Config Checker` and `Server Keys`, run rather than read. The screen's own code runs through the stand-in terminal
## of the driver (check-fixtures/manager-screen.driver.test.py), and where it would call the dispatcher it calls a
## stand-in script (check-fixtures/manager-screen.tools.test.sh), which notes each start and prints the fixture: rows
## in the forms `--manager-check-run`, `--manager-keys-list` and `--manager-keys-read <key>` print.
## Held: the two folders stand in `Configuration` ahead of its subjects, and neither is read before it is entered;
## the checks are run on demand alone, by the key the status line names, never on entering, never on the period and
## not by the key that reads now, once for a press and not again while they run; they are listed in the order of
## the operation, each with its state at the end of its row; the folder counts them as their summary row has them;
## a check selected shows its state, why, and its remedy as it is printed, and the screen runs no remedy; a run that
## fails says so in a box; the keys are read once on entering, the list and then each key that can be read by its
## name; the groups come from the rows, each by the label its row gives and in the order of the operation, in the
## list and in the left window alike, and where no row names a group it shows by its word; a public key is shown
## WHOLE wherever one is shown, in the folder and in the view of a key, wrapped and never cut, from its row of the
## list where that carries it and else from the read of that key, and the shortened key of a row is never on the
## screen; a key selected shows what it is for, its type, fingerprint, file, its whole line and where it is to be
## registered; its key shows it alone in a box, read anew, broken only where the box is full; a key that cannot
## be read says so and opens no box; and the real screen, on a pseudo-terminal, starts,
## shows the folders and ends on Ctrl-X with the terminal given back.
## Offline: no operation of the real tooling is called, no check is run and no key of this machine is read.
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
rigTmp="$( mktemp -d -t AgentsManagerScreenConfigurationCheck )" || exit 1
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
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
## A digest of one subject of the configuration, so that the root has a subject under its two folders. Four checks
## as `--manager-check-run` prints them, one of them under a section, and their summary. The keys stand below.
rigFull='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123 mdci@rig-host'
{
	rigRow subject workspace 1 Workspace_Paths
	rigRow line workspace paths workspace-root set /rig/ws_rig Workspace_Root - 'no:set_at_deployment:_a_wizard_will_change_it' - - - - - configuration
} > "$rigF/rows.--manager-config-digest"
{
	rigRow check copilot - COPILOT_HARNESS_INSTALLED Copilot_Harness_Installed ok - -
	rigRow check grok - GROK_CREDENTIAL Grok_Credential fail 'XAI_API_KEY_is_not_set,_and_it_is_required' '/rig/ws_rig/DistroAgentsTools.fn.sh --owner-setup-grok --apply'
	rigRow check slack workspace_rig SLACK_TOKEN Slack_Token warn the_token_is_old -
	rigRow check scaleway - - Scaleway_Check skipped the_check_did_not_end_within_40_seconds -
	rigRow summary 4 1 1 1 1 42
} > "$rigF/rows.--manager-check-run"
rigHostFull='rig-host ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIhostHOSThostHOSThostHOSThostHOSThostHOSThostHOSThost'
rigOursFull='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIoursOURSoursOURSoursOURSoursOURSoursOURSoursOURSours mdci@rig-host'
rigKeyRow(){ ## key, label, group, purpose, type, fingerprint, file, state, the whole line or nothing -- a `key` row, the line with `_` for a blank; its <short> is a text the screen must never show
	if [ $# -ge 9 ] ; then rigRow key "$1" "$2" "$3" "$4" "$5" "$6" SHORT-never-shown "$7" "$8" "${9// /_}" ; else rigRow key "$1" "$2" "$3" "$4" "$5" "$6" SHORT-never-shown "$7" "$8" ; fi
}
## The keys as the list prints them since it names its groups and carries the whole line: four groups, each by a row
## of its own ahead of its keys, with how many, its label and a note, in an order that is not the alphabet's, one of
## them a group the screen was never told of, whose one key cannot be read, with why in its note; five keys in all.
{
	rigRow group trust-on-connect 1 Keys_To_Trust_When_Connecting -
	rigRow group add-to-git 2 Keys_To_Add_To_Git -
	rigRow group add-to-authorized-keys 1 Our_Key_For_Targets_That_Welcome_Us -
	rigRow group kept-for-the-rig 1 Keys_Of_The_Rig no_public_key_can_be_read_at_/rig/kept.pub
	rigKeyRow kept Kept_Key kept-for-the-rig 'a_key_of_a_group_no_screen_knows' - - /rig/kept.pub absent -
	rigKeyRow deploy Deploy_Key add-to-git 'the_deploy_key_of_this_server,_to_list_on_each_git_repository_it_reads' ssh-ed25519 SHA256:abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ /rig/mdci/deploy-keys/mdci.pub present "$rigFull"
	rigKeyRow host-ed25519 Host_Key_ED25519 trust-on-connect 'an_ssh_host_key_of_this_server,_for_the_known_hosts_of_those_who_connect_to_it' ssh-ed25519 SHA256:ZYXWVUTSRQPONMLKJIHGFEDCBAzyxwvutsrqponmlkj /rig/etc/ssh/ssh_host_ed25519_key.pub present "$rigHostFull"
	rigKeyRow generated Generated_Key add-to-git 'the_key_made_for_this_server' - - /rig/mdci/.ssh/id_ed25519.pub absent -
	rigKeyRow ours Our_Key add-to-authorized-keys 'our_own_key,_for_the_authorized_keys_of_a_target_that_welcomes_us' ssh-ed25519 SHA256:oursOURSoursOURSoursOURSoursOURSoursOURSour /rig/mdci/.ssh/ours.pub present "$rigOursFull"
} > "$rigF/rows.--manager-keys-list"
## The same keys as an older tooling lists them: no row of a group, and no whole line at the end of a row.
{
	rigKeyRow deploy Deploy_Key add-to-git 'the_deploy_key_of_this_server' ssh-ed25519 SHA256:abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ /rig/mdci/deploy-keys/mdci.pub present
	rigKeyRow host-ed25519 Host_Key_ED25519 trust-on-connect 'an_ssh_host_key_of_this_server' ssh-ed25519 SHA256:ZYXWVUTSRQPONMLKJIHGFEDCBAzyxwvutsrqponmlkj /rig/etc/ssh/ssh_host_ed25519_key.pub present
} > "$rigTmp/older.keys"
## What the read of one key prints: the line to paste, and for the deploy key two repositories.
{
	rigRow paste "$rigFull"
	rigRow register myx/myx.common git@github.com:myx/myx.common.git
	rigRow register myx/myx.distro-agents git@github.com:myx/myx.distro-agents.git
} > "$rigF/rows.--manager-keys-read deploy"
rigRow paste "$rigHostFull" > "$rigF/rows.--manager-keys-read host-ed25519"
rigRow paste "$rigOursFull" > "$rigF/rows.--manager-keys-read ours"
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
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize %s\nroot sessions\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
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
rigBoxHolds(){ ## tag, text -- how many lines of that box hold the text
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigJoined(){ ## tag -- the left pane of that screen as one text with no blank in it: its lines one after another, so a text holds whatever the wrap
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -e "s/^$1|//" -e 's/^│//' -e 's/^║//' -e 's/│.*$//' -e 's/║.*$//' | LC_ALL=C tr -d ' \n'
}
rigCell(){ ## name -- the cells of that name, without the spaces at their end and with every run of spaces as one
	rigVal "$1" | LC_ALL=C sed -e 's/  *$//' -e 's/   */ ~ /g'
}

echo "-- Configuration holds its two folders ahead of its subjects --"
rigCase root
rigScript <<'RIGSCRIPT'
turn
keys 7
wait list 30
turn
get in
cells row2 3 85 119
cells row3 4 85 119
cells row4 5 85 119
keys DOWN
turn
show c
keys DOWN
turn
show k
advance 11
turn 3
RIGSCRIPT
rigAssert "Config Checker and Server Keys stand under the row that goes up, each a row that is entered, then the subjects" "$( rigVal in.rows ) [$( rigCell row2 )][$( rigCell row3 )][$( rigCell row4 )]" "4 [ Config Checker...][ Server Keys...][ Workspace Paths...]"
rigAssert "on Config Checker the left window says that the checks were not run, and which key runs them" "[$( rigPane c 2 )][$( rigPane c 3 )][$( rigPane c 5 )]" "[ Config Checker][ The checks were not run yet in this run of the screen.][ r runs them. It is the read-only diagnosis of each part of the installation: it]"
rigAssert "neither folder is read before it is entered, whatever time passes" "$( rigCalled --manager-check-run ) $( rigCalled --manager-keys-list ) [$( rigPane k 2 )]" "0 0 [ Server Keys]"

echo "-- Config Checker: the checks are run on demand alone --"
rigCase checker
printf 'sleep 1\n' > "$MANAGER_SCREEN_RIG/mode.--manager-check-run"
rigScript <<'RIGSCRIPT'
turn
keys 7
wait list 30
keys DOWN ENTER
advance 11
turn 3
keys u
advance 11
turn 3
get in
cells inStatus 39 0 120
keys r
turn
get asked
keys r
get twice
wait check 30
turn
get done
cells row2 3 85 119
cells row3 4 85 119
cells row4 5 85 119
cells row5 6 85 119
show u
advance 11
turn 3
keys DOWN DOWN
turn
get g
show g
cells gStatus 39 0 120
keys ENTER
get enter
keys DOWN
turn
show s
keys LEFT
turn
get up
show f
keys ENTER
advance 11
turn 3
get back
RIGSCRIPT
rigAssert "entering it runs nothing, nor does time, nor does the key that reads now: the list is empty and the status line names the key that runs them" "$( rigVal in.path ) $( rigVal in.rows ) $( rigVal in.reading | LC_ALL=C grep -c -F checker ) [$( rigVal inStatus | sed 's/  *$//' )]" "configuration/checker 1 0 [ Enter Open  Left Up  a Active  u Read  m Menu  ^X Exit  r Run  Tab Window]"
rigAssert "r asks for the run, and the status line says so"          "[$( rigVal asked.notice )] $( rigVal asked.reading | LC_ALL=C grep -c -F 'list:configuration/checker' )" "[Run the checks: asked of the tooling, it takes up to a minute] 1"
rigAssert "r while it runs asks for no second run"                   "[$( rigVal twice.notice )]" "[Run the checks: it is running]"
rigAssert "when it has answered the checks are listed in the order of the operation, each with its state at the end of its row" "$( rigVal done.rows ) [$( rigVal done.notice )] [$( rigCell row2 )][$( rigCell row3 )][$( rigCell row4 )][$( rigCell row5 )]" "5 [] [ Copilot Harness Installed ~ ok][ Grok Credential ~ fail][ Slack Token ~ warn][ Scaleway Check ~ skipped]"
rigAssert "on the row that goes up the left window counts them by their states, as the summary row has them" "[$( rigPane u 3 )][$( rigPane u 5 )]" "[ 4 checks: 1 ok, 1 warn, 1 fail, 1 skipped, in 42 seconds.][ r runs them again. It is the read-only diagnosis of each part of the installation:]"
rigAssert "a check selected: its state first, why, and its remedy as it is printed" "$( rigVal g.selectedLabel ) [$( rigPane g 2 )][$( rigPane g 3 )][$( rigPane g 5 )][$( rigPane g 7 )]" "Grok Credential [ Grok Credential][ state     fail][ XAI API KEY is not set, and it is required][ remedy    /rig/ws_rig/DistroAgentsTools.fn.sh --owner-setup-grok --apply]"
rigAssert "then where it is from, and that the screen runs no remedy" "[$( rigPane g 8 )][$( rigPane g 9 )] $( rigPaneHolds g ' The remedy is a command for a console: the screen runs none.' ) $( rigPaneHolds s ' section   workspace_rig' )" "[ domain    grok][ key       GROK_CREDENTIAL] 1 1"
rigAssert "Enter on a check opens nothing, and calls nothing"        "[$( rigVal enter.dialog )] [$( rigVal enter.notice )] $( rigVal enter.path )" "[] [Open: this row has nothing to open] configuration/checker"
rigAssert "left and entered again it holds what the run gave: it was run once, by its key alone, with no argument" "$( rigVal up.path ) $( rigVal up.selected ) [$( rigPane f 3 )] $( rigVal back.rows ) $( rigCalled --manager-check-run ) $( LC_ALL=C grep -c -e '--manager-check-run' "$MANAGER_SCREEN_RIG/calls" )" "configuration checker [ 4 checks: 1 ok, 1 warn, 1 fail, 1 skipped, in 42 seconds.] 5 1 1"

echo "-- a run of the checks that fails says so in a box --"
rigCase checkfails
printf 'fail\n' > "$MANAGER_SCREEN_RIG/mode.--manager-check-run"
rigScript <<'RIGSCRIPT'
turn
keys 7
wait list 30
keys DOWN ENTER r
wait check 30
turn
get failed
RIGSCRIPT
rigAssert "what the operation wrote stands whole in a box"            "[$( rigVal failed.dialogTitle )] [$( rigVal failed.dialogHolds )] [$( rigVal failed.notice )]" "[A read failed] [operation: --manager-check-run / rig-tools: a line that is no error / rig-tools: ⛔ ERROR: the rig said fail] []"

echo "-- Server Keys: the groups from the rows, every key whole --"
rigCase keys
rigScript <<'RIGSCRIPT'
turn
keys 7
wait list 30
keys DOWN DOWN ENTER
wait list 30
turn
wait plan 30
turn
wait plan 30
turn
wait plan 30
turn
get in
cells row2 3 85 119
cells row3 4 85 119
cells row4 5 85 119
cells row5 6 85 119
cells row6 7 85 119
cells row7 8 85 119
cells row8 9 85 119
show u
advance 11
turn 3
get aged
keys DOWN
turn
get g
show g
keys DOWN DOWN DOWN
turn
get d
show d
cells dStatus 39 0 120
style bw
show dbw
style mc
show dmc
style tv
keys f
get asked
wait plan 30
turn
box b
keys ENTER
get closed
keys DOWN
turn
show a
keys f
get absent
keys DOWN f
get gf
RIGSCRIPT
rigAssert "entering it reads the list once, and each key that can be read once by its name, the deploy key once more for its box below; no period reads any again" "$( rigVal in.path ) $( rigVal in.rows ) $( rigCalled --manager-keys-list ) $( rigCalled '--manager-keys-read deploy' ) $( rigCalled '--manager-keys-read host-ed25519' ) $( rigCalled '--manager-keys-read ours' ) $( rigCalled '--manager-keys-read generated' ) $( rigVal aged.reading | LC_ALL=C grep -c -F keys )" "configuration/keys 10 1 2 1 1 0 0"
rigAssert "the groups stand in the order of the operation, each by the label its row gives, its keys under it" "[$( rigCell row2 )][$( rigCell row3 )][$( rigCell row4 )][$( rigCell row5 )][$( rigCell row6 )][$( rigCell row7 )][$( rigCell row8 )]" "[ Keys To Trust When Connecting][ ~ Host Key ED25519][ Keys To Add To Git][ ~ Deploy Key][ ~ Generated Key ~ absent][ Our Key For Targets That Welcome…][ ~ Our Key]"
rigAssert "on the row that goes up: each group under its label, each key with its fingerprint and its whole public line" "[$( rigPane u 3 )][$( rigPane u 4 )][$( rigPane u 5 )][$( rigPane u 6 )] $( rigJoined u | LC_ALL=C grep -c -F 'rig-hostssh-ed25519AAAAC3NzaC1lZDI1NTE5AAAAIhostHOSThostHOSThostHOSThostHOSThostHOSThostHOSThost' )" \
	"[ Keys To Trust When Connecting][   Host Key ED25519][       SHA256:ZYXWVUTSRQPONMLKJIHGFEDCBAzyxwvutsrqponmlkj][       rig-host ssh-ed25519] 1"
rigAssert "a key that cannot be read says so, and the key of ours for a target stands whole as the others" "$( rigPaneHolds u '       absent: /rig/mdci/.ssh/id_ed25519.pub' ) $( rigPaneHolds u ' Our Key For Targets That Welcome Us' ) $( rigJoined u | LC_ALL=C grep -c -F 'ssh-ed25519AAAAC3NzaC1lZDI1NTE5AAAAIoursOURSoursOURSoursOURSoursOURSoursOURSoursOURSoursmdci@rig-host' ) $( rigJoined u | LC_ALL=C grep -c -F 'ssh-ed25519AAAAC3NzaC1lZDI1NTE5AAAAIabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123mdci@rig-host' )" "1 1 1 1"
rigAssert "a group the screen was never told of stands as the others, by its row, with the note of that row under its label" "$( rigPaneHolds u ' Keys Of The Rig' ) $( rigPaneHolds u '   no public key can be read at /rig/kept.pub' ) $( rigPaneHolds u '   Kept Key' ) $( rigPaneHolds u '       absent: /rig/kept.pub' )" "1 1 1 1"
rigAssert "a group selected: the left window shows that group alone, and the key of a key says it is not for it" "$( rigVal g.selected ) [$( rigPane g 2 )][$( rigPane g 3 )] $( rigPaneHolds g ' Keys To Add To Git' ) [$( rigVal gf.selected )] [$( rigVal gf.notice )] [$( rigVal gf.dialog )]" "group trust-on-connect [ Keys To Trust When Connecting][ Keys To Trust When Connecting] 0 [group add-to-authorized-keys] [Full public line: for a server key, not for what is selected] []"
rigAssert "a key selected: what it is for, its type, its fingerprint, its file, its group as the row named it" "$( rigVal d.selected ) [$( rigPane d 2 )][$( rigPane d 3 )][$( rigPane d 5 )][$( rigPane d 6 )][$( rigPane d 7 )][$( rigPane d 8 )]" \
	"deploy [ Deploy Key][ the deploy key of this server, to list on each git repository it reads][ type        ssh-ed25519][ fingerprint SHA256:abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ][ file        /rig/mdci/deploy-keys/mdci.pub][ group       Keys To Add To Git]"
rigAssert "then its whole public line, as it is pasted, what goes on set further in" "[$( rigPane d 12 )][$( rigPane d 13 )] $( rigPane d 14 | LC_ALL=C grep -c '^       AAAAC3NzaC1lZDI1NTE5AAAAIabc' ) $( rigJoined d | LC_ALL=C grep -c -F 'ssh-ed25519AAAAC3NzaC1lZDI1NTE5AAAAIabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123mdci@rig-host' )" "[ Its public line, whole, as it is pasted:][   ssh-ed25519] 1 1"
rigAssert "where it is to be registered, and the key that shows it alone, which the status line names" "$( rigPaneHolds d ' It is to be registered on each of these repositories:' ) $( rigPaneHolds d '   myx/myx.common git@github.com:myx/myx.common.git' ) $( rigPaneHolds d '   myx/myx.distro-agents git@github.com:myx/myx.distro-agents.git' ) $( rigPaneHolds d ' f shows it alone, in a box to copy.' ) [$( rigVal dStatus | sed 's/  *$//' )]" "1 1 1 1 [ f Full  Left Up  a Active  u Read  m Menu  ^X Exit  Tab Window]"
rigAssert "it is whole in B/W and in the compact style too"          "$( rigJoined dbw | LC_ALL=C grep -c -F 'ssh-ed25519AAAAC3NzaC1lZDI1NTE5AAAAIabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123mdci@rig-host' ) $( rigJoined dmc | LC_ALL=C grep -c -F 'ssh-ed25519AAAAC3NzaC1lZDI1NTE5AAAAIabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123mdci@rig-host' )" "1 1"
rigAssert "the shortened key of a row is nowhere on the screen, and no line of the left window is cut" "$( rigScreenHolds u 'SHORT-never' ) $( rigScreenHolds g 'SHORT-never' ) $( rigScreenHolds d 'SHORT-never' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep -e '^u|' -e '^d|' | LC_ALL=C sed -e 's/│║.*$//' | LC_ALL=C grep -c -F '…' )" "0 0 0 0"
rigAssert "f opens the box of that key alone, which says that its line is being read" "[$( rigVal asked.dialog )] [$( rigVal asked.dialogTitle )] [$( rigVal asked.dialogHolds )]" "[keyline:ok|] [Deploy Key] [Its public line is being read.]"
rigAssert "it is read anew for the box, by the name of the key, and stands whole there, broken only where the box is full" "$( rigCalled '--manager-keys-read deploy' ) $( rigBoxHolds b '║  ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIabcdefghijklmnopqrstuvwxyzABCDEFGHIJ ║' ) $( rigBoxHolds b '║ KLMNOPQRSTUVWXYZ0123 mdci@rig-host' ) $( rigBoxHolds b '[ OK ]' )" "2 1 1 1"
rigAssert "with its group, its type and its fingerprint, and where it is to be registered" "$( rigBoxHolds b 'group     Keys To Add To Git' ) $( rigBoxHolds b 'type      ssh-ed25519' ) $( rigBoxHolds b 'fingerprint SHA256:abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ' ) $( rigBoxHolds b '  myx/myx.common  git@github.com:myx/myx.common.git' ) $( rigBoxHolds b '  myx/myx.distro-agents  git@github.com:myx/myx.distro-agents.git' )" "1 1 1 1 1"
rigAssert "Enter closes the box"                                     "[$( rigVal closed.dialog )]" "[]"
rigAssert "a key that cannot be read says so, and f opens no box and reads nothing" "$( rigPaneHolds a ' No public key can be read at its file.' ) $( rigPaneHolds a ' state       absent' ) [$( rigVal absent.dialog )] [$( rigVal absent.notice )] $( LC_ALL=C grep -c -e '--manager-keys-read' "$MANAGER_SCREEN_RIG/calls" )" "1 1 [] [Full public line: no public key can be read there] 4"

echo "-- an older tooling: no row of a group and no whole line in the list --"
rigCase older
cp "$rigTmp/older.keys" "$MANAGER_SCREEN_RIG/rows.--manager-keys-list"
rigScript <<'RIGSCRIPT'
turn
keys 7
wait list 30
keys DOWN DOWN ENTER
wait list 30
turn
wait plan 30
turn
wait plan 30
turn
get in
cells row2 3 85 119
cells row3 4 85 119
cells row4 5 85 119
cells row5 6 85 119
show u
RIGSCRIPT
rigAssert "a group shows by its word, the dashes as blanks, capitalised, in the order its keys come" "$( rigVal in.rows ) [$( rigCell row2 )][$( rigCell row3 )][$( rigCell row4 )][$( rigCell row5 )]" "5 [ Add to git][ ~ Deploy Key][ Trust on connect][ ~ Host Key ED25519]"
rigAssert "the whole line of each key is read by its name, once, and stands under its fingerprint" "$( rigCalled '--manager-keys-read deploy' ) $( rigCalled '--manager-keys-read host-ed25519' ) $( rigJoined u | LC_ALL=C grep -c -F 'ssh-ed25519AAAAC3NzaC1lZDI1NTE5AAAAIabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123mdci@rig-host' ) $( rigJoined u | LC_ALL=C grep -c -F 'rig-hostssh-ed25519AAAAC3NzaC1lZDI1NTE5AAAAIhostHOSThostHOSThostHOSThostHOSThostHOSThostHOSThost' ) $( rigScreenHolds u 'SHORT-never' )" "1 1 1 1 0"

echo "-- a key whose line cannot be read: its place says so, and so does its box --"
rigCase keyfails
cp "$rigTmp/older.keys" "$MANAGER_SCREEN_RIG/rows.--manager-keys-list"
printf 'fail\n' > "$MANAGER_SCREEN_RIG/mode.--manager-keys-read"
rigScript <<'RIGSCRIPT'
turn
keys 7
wait list 30
keys DOWN DOWN ENTER
wait list 30
turn
wait plan 30
turn
wait plan 30
turn
get in
show u
keys DOWN DOWN
turn
keys f
wait plan 30
turn
get failed
RIGSCRIPT
rigAssert "under each key the folder says that its line could not be read, and no box opens of itself" "[$( rigVal in.dialog )] $( rigScreenHolds u 'Its public line could not be read: rig-tools: ⛔ ERROR: the rig said' )" "[] 2"
rigAssert "its own box says that it could not be read, and no other box opens" "[$( rigVal failed.dialog )] [$( rigVal failed.dialogHolds )] $( rigVal failed.waiting )" "[keyline:ok|] [Its public line could not be read: / rig-tools: ⛔ ERROR: the rig said fail] 0"

echo "-- the real screen on a pseudo-terminal: it starts, shows Configuration with its folders, and Ctrl-X ends it --"
rigCase pty
mkdir -p "$rigTmp/ws-rig"
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigTools" > "$rigTmp/tools"
chmod +x "$rigTmp/tools"
rigOut="$( MANAGER_SCREEN_PTY_TRACE='checker=Config Checker|keys=Server Keys' "$rigPython" -I -B "$rigDriver" "$rigScreen" pty 100 30 "Sessions (Activity)" '7\p\aServer Keys\a\x18' 60 -- "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" 2>&1 )"
rigAssert "it draws the folder and ends with status 0, the terminal given back" "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.errorAfterLeft ) $( rigVal pty.modeBack ) [$( rigVal pty.trace )]" "yes 0 yes none yes [checker keys]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN CONFIGURATION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_CONFIGURATION: OK (%d assertions, offline, stand-in terminal, stand-in dispatcher and one pseudo-terminal)\n' "$rigPassCount"
