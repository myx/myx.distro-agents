#!/usr/bin/env bash
## Behavioural check on what the manager screen (sh-lib/manager/AgentsManagerScreen.py) does when the selection comes to
## stand on a folder, a row that opens a level of its own, run rather than read. The screen's own code runs through
## the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call the
## dispatcher it calls a stand-in script (check-fixtures/manager-screen.tools.stub.sh), which notes each start and
## prints the fixture: rows in the forms the list operations of the screen print.
## Held: the list of a folder is read while its row is selected, with no Enter, and the left window then shows the
## summary of that folder from its real rows, in the form of its kind: the sessions by their states, then the
## running and the waiting ones one by one with their agents, tokens and members; the asks with how many have no
## asker, for whom they are, the oldest, then the oldest few with who asks whom; the members with who runs and who
## is not started from here and why; the locations with which is not present; what is to start group by group; a
## root of the digest with its subjects, the ones that miss a line first; the routines by whether they are
## started; the server keys with every public key whole; a subject of the settings with its values and never a
## secret; a subject of the configuration with its missing lines first. Until the rows have come the window says
## `Populating <name>...`. The read of a folder starts only when the selection has rested on its row, so a selection
## that runs over the folders starts the read of the one it stops on alone; one such read runs at a time, and one
## under way for a folder that was left never shows in another. While the selection stays on a folder the period
## reads it no more; coming back to it reads it again once its period has passed. Entering a folder afterwards reads
## nothing again until its period has passed. The checks of the installation are never run by the focus: their folder says that
## they were not run, and which key runs them, and that key runs them from the row of the folder, after which the
## folder says how they ended and when. A folder whose read fails says so in the left window.
## Offline: no operation of the real tooling is called.
## Reconciled for F11.0: `Launch / Spawn` is named `Launch (Start)`, `Consoles (Tools)` `Consoles`.
## Reconciled for F11.0, the table lines: two spaces between the columns of every table.
## Reconciled for the count of Pending Questions (owner, 2026-10-20): the root reads the count of the asks (`--count`) whatever is shown, and that start is no read of a folder: the helpers leave it out.
## Reconciled for F11.5: the roots are Dashboard, Pending Questions, Magic-Team (Agents), Locations, Consoles, Settings and Configuration, so the selection steps through those, and the sessions and the members are read inside Magic-Team (Agents) (Activity, Team Members); the asks, the places and the consoles keep their cases.
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
rigTmp="$( rigTempDir AgentsManagerScreenFocusCheck )" || exit 1
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
	rigRow run s-run sp-1 magic-coordinator done live running 2026-10-13T01:00:00Z - righost ws-one working
	rigRow run s-run sp-2 keeper-myx done live running 2026-10-13T01:01:00Z - righost ws-one waiting
	rigRow run s-run sp-3 keeper-myx done ended finished 2026-10-13T01:02:00Z 2026-10-13T01:05:00Z righost ws-one -
	rigRow session s-wait review_of_the_board waiting 2026-10-13T00:00:00Z - 1 waiting=1 waiting 2026-10-13T00:00:05Z gone 1200+
	rigRow run s-wait sp-4 magic-architect done live waiting 2026-10-13T00:00:00Z - righost ws-one waiting
	rigRow session s-open - unclosed 2026-10-12T00:00:00Z - 0 - - - none 0
	rigRow session s-done old_work finished 2026-10-11T00:00:00Z 2026-10-11T01:00:00Z 2 finished=2 - - none 900
	rigRow session s-done2 older_work finished 2026-10-10T00:00:00Z 2026-10-10T01:00:00Z 1 finished=1 - - none 100
	rigRow counters 1 0 2 2 3 0.42 righost
} > "$rigF/rows.--manager-session-list"
cat > "$rigF/rows.--read-pending-reply" <<'RIGROWS'
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
	rigRow line slack app token secret-set hidd******** Bot_token The_token_of_the_bot no:set_at_deployment text workspace file - /rig/conf configuration
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
printf 'fact\t-\tname\tws-one\nfact\t-\tpath\t/rig/Workspaces/ws-one\n' > "$rigF/rows.--manager-workspace-read"
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
	rigOut="$( { printf 'tools bash %s\nwall 2026-10-13 02:30 +0000\nsize 120 36\nroot dashboard\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
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
rigCalls(){ ## text -- how many starts of the stand-in name it in their words, the count of the asks, which the root reads whatever is shown, left out
	LC_ALL=C grep -v -x -F -- "$rigAsksCount" "$MANAGER_SCREEN_RIG/calls" | LC_ALL=C grep -c -F -- "$1" || :
}
rigCallsIn(){ ## file, text -- the same in a copy of the calls
	LC_ALL=C grep -v -x -F -- "$rigAsksCount" "$1" | LC_ALL=C grep -c -F -- "$2" || :
}
rigAsksCount="--read-pending-reply magic-coordinator --any-owner --count"
rigFolderCalls(){ ## how many starts were of the lists that only a folder asks for: not of those that are read whatever is shown
	LC_ALL=C grep -c -v -e '^--manager-dashboard-read$' -e '^--manager-place-list$' -e '^--manager-session-list' -e "^$rigAsksCount\$" "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- the roots: the selection on each loads it and shows its summary, with no Enter --"
rigCase roots
rigScript <<'RIGSCRIPT'
turn
keys DOWN
wait focus 5
show Q
keys DOWN
wait focus 5
show M
keys ENTER DOWN
wait sessions 5
show S
keys DOWN DOWN
wait focus 5
show T
keys BACKSPACE DOWN
wait focus 5
show P
keys DOWN
wait focus 5
show C
keys DOWN
wait focus 5
show W
keys DOWN
wait focus 5
show G
keys DOWN
wait focus 5
show F
get end
RIGSCRIPT
rigAssert "the sessions: every session as a table, nothing above it, its state with the mark of a control thread that is gone, its agents, tokens and members" "$( rigLeft S )" " SESSION             STATE     AGE AGENTS TOKENS MEMBERS /  daily of Monday     running   -   3      57.1M  magic-coordinator, keeper-myx /  review of the board x waiting -   1      1K+    magic-architect /  s-open              unclosed  -   0      0      - /  old work            finished  -   2      900    - /  older work          finished  -   1      100    -"
rigAssert "the asks: every ask as a table, nothing above it, with how long it waits, its kind, who asks whom and the question" "$( rigLeft Q )" "    AGE KIND  FROM         TO               QUESTION /  ❓ 10m ques… keeper-myx   human-owner      Which of the two layouts stays? /  ❓ 2h  ques… keeper-acm   magic-           Who owns the template of the report? /                            coordinator /     3d  appr… magic-devops human-owner      May the old volume be removed now that /                                             the copy is proven on the second host?"
rigAssert "the members: their table alone, numbered, and no line of a summary" "$( rigLeft T )" "$( printf ' %s  %-17s  %-7s  %-8s  %-6s  %s / ' '#' MEMBER RUN STATUS KIND WHERE 1 magic-coordinator running active lead - 2 keeper-myx - active keeper - 3 human-owner - ref-only human - 4 far-member - active keeper - | LC_ALL=C sed 's| / $||' )"
rigAssert "the locations: every location as a table with its path, nothing above it" "$( rigLeft P )" "   PLACE     KIND     STATE   PATH                               SESSIONS CEILING /  • ws-one    workspa… present /rig/Workspaces/ws-one             2        read-wr… /    gone-work workspa… absent  /rig/Volumes/gone-work             0        read-wr… /    deep      directo… present /rig/Workspaces/ws-one/source/deep -        read-on…"
rigAssert "what is to start: each as a table with its command, nothing above it" "$( rigLeft C )" " CONSOLE         GROUP   COMMAND /  Agents Console  Distro  bash DistroAgentsConsole.sh /  Source Console  Distro  bash DistroSourceConsole.sh /  Top             System  top"
rigAssert "the workspace: its facts, the rows of the operation as it printed them, with no Enter" "$( rigLeft W )" " name  ws-one /  path  /rig/Workspaces/ws-one"
rigAssert "the settings: its subjects in a table, with what each holds" "$( rigLeft G | sed 's/^.*while the workspace runs\. \/ //' )" " SUBJECT      LINES MISSING WHAT /  Interface    2     -       how this console looks, saved for the user who runs it /  Scope        -     -       every scope of settings of this workspace, each a /  Settings                   folder of its variables /  Presets      -     -       - /  Tiers        -     -       -"
rigAssert "the configuration: its subjects, how many lines each misses, and its folders" "$( rigLeft F | sed 's/^.*change it later\. \/ //' ) [$( rigLeft F | sed 's/ \/ .*$//' )]" " SUBJECT        LINES MISSING WHAT /  Slack          3     1       - /  Config Checker -     -       the read-only checks of the installation, run on /                               demand /  Server Keys    -     -       the public keys of this server /  Git Settings   -     -       the global git settings of the account that runs the /                               tools /  Installed      -     -       the subsystems of the tool family, installed here or /  Subsystems                   not, and the commands to install and uninstall them /  Diagnostics    -     -       what the tooling sees, read-only: the context it /                               resolves [ SUBJECT        LINES MISSING WHAT]"
rigAssert "nothing was entered, and each list was read once: the asks, the members, what is to start, and the digest for both its roots" "[$( rigVal end.path )] $( rigCalls --read-pending-reply ) $( rigCalls --manager-team-member-list ) $( rigCalls --manager-console-list ) $( rigCalls --manager-config-digest ) $( rigFolderCalls )" "[] 1 1 1 1 5"

echo "-- until the rows have come the window says that it waits; the read starts when the selection has rested --"
rigCase waits
echo "sleep 1" > "$MANAGER_SCREEN_RIG/mode.--read-pending-reply"
rigScript <<'RIGSCRIPT'
turn
keys DOWN
turn
show at
get at
advance 0.2
turn
get soon
advance 0.2
turn
show rested
get rested
wait focus 5
show came
RIGSCRIPT
rigAssert "on the row at once: it waits by its name, and nothing of it is asked yet" "[$( rigLeft at )] [$( rigVal at.reading | tr ',' '\n' | LC_ALL=C grep -c -F pending )] $( rigVal at.restLeft )" "[Populating Pending Questions...] [0] 0.33"
rigAssert "not before the selection has rested there" "[$( rigVal soon.reading | tr ',' '\n' | LC_ALL=C grep -c -F pending )]" "[0]"
rigAssert "rested: its list is asked for, and the window still waits" "[$( rigLeft rested )] [$( rigVal rested.reading | tr ',' '\n' | LC_ALL=C grep -F pending )]" "[Populating Pending Questions...] [list:pending]"
rigAssert "the rows have come: the summary stands there" "$( rigHolds came 'Which of the two layouts stays?' ) $( rigHolds came 'Populating' )" "1 0"

echo "-- a selection that runs over the folders starts the read of the one it stops on alone --"
rigCase runs
rigScript <<RIGSCRIPT
turn
wait list 5
keys DOWN
advance 0.1
keys DOWN
advance 0.1
keys DOWN
advance 0.1
keys DOWN
advance 0.1
turn
get ran
copy $MANAGER_SCREEN_RIG/calls $MANAGER_SCREEN_RIG/calls.ran
advance 0.4
turn
wait focus 5
show stop
RIGSCRIPT
rigAssert "over four folders in half a second: no read of a folder was started on the way" "$( rigVal ran.selected ) $( LC_ALL=C grep -v -x -F -- "$rigAsksCount" "$MANAGER_SCREEN_RIG/calls.ran" | LC_ALL=C grep -c -e --read-pending-reply -e --manager-team-member-list -e --manager-console-list -e --manager-config-digest )" "consoles 0"
rigAssert "and where it stops, that folder alone is read" "$( rigFolderCalls ) $( rigCalls --manager-console-list ) $( rigHolds stop 'DistroAgentsConsole.sh' )" "1 1 1"

echo "-- a slow read of a folder that was left: it holds the next one back, and never shows in another folder --"
rigCase slow
echo "sleep 2" > "$MANAGER_SCREEN_RIG/mode.--read-pending-reply"
rigScript <<'RIGSCRIPT'
turn
wait places 5
keys DOWN
advance 0.4
turn
get asks
keys DOWN DOWN DOWN
advance 0.4
turn
turn
show other
get other
wait focus 5
wait focus 5
show later
keys UP UP UP
turn
show back
RIGSCRIPT
rigAssert "the asks are being read, as a read of the focus" "[$( rigVal asks.selected )] [$( rigVal asks.reading | tr ',' '\n' | LC_ALL=C grep -F pending )]" "[pending] [list:pending]"
rigAssert "three folders on, while that read runs: the folder there waits by its own name, its read held back, and nothing of the asks shows" "[$( rigVal other.selected )] [$( rigLeft other )] [$( rigVal other.reading | tr ',' '\n' | LC_ALL=C grep -c -F consoles )]" "[consoles] [Populating Consoles...] [0]"
rigAssert "when it has ended the folder there is read and shown, and still nothing of the asks" "$( rigHolds later 'DistroAgentsConsole.sh' ) $( rigHolds later 'Which of the two layouts stays?' ) $( rigCalls --manager-console-list )" "1 0 1"
rigAssert "back on the asks: what that read gave stands there at once, and it was made once" "$( rigHolds back 'Which of the two layouts stays?' ) $( rigCalls --read-pending-reply )" "1 1"

echo "-- while the selection stays on a folder its period reads it no more; coming back after the period reads it again --"
rigCase stays
rigScript <<RIGSCRIPT
turn
keys DOWN
wait focus 5
advance 10.5
turn
wait focus 5
advance 10.5
turn
wait focus 5
copy $MANAGER_SCREEN_RIG/calls $MANAGER_SCREEN_RIG/calls.stayed
keys DOWN
advance 0.1
keys UP
turn
wait focus 5
copy $MANAGER_SCREEN_RIG/calls $MANAGER_SCREEN_RIG/calls.back
keys DOWN
advance 0.1
keys UP
turn
wait focus 5
keys u
turn
wait focus 5
RIGSCRIPT
rigAssert "two periods on the row: read once; away and back after the period: once more; away and back at once: no more; and the key that reads now reads it" "$( rigCallsIn "$MANAGER_SCREEN_RIG/calls.stayed" --read-pending-reply ) $( rigCallsIn "$MANAGER_SCREEN_RIG/calls.back" --read-pending-reply ) $( rigCalls --read-pending-reply )" "1 2 3"

echo "-- entering a folder afterwards uses what was read, and reads again when its period has passed --"
rigCase enters
rigScript <<RIGSCRIPT
turn
keys DOWN
wait focus 5
keys ENTER
turn
wait list 5
get in
copy $MANAGER_SCREEN_RIG/calls $MANAGER_SCREEN_RIG/calls.in
advance 10.5
turn
wait list 5
get aged
RIGSCRIPT
rigAssert "entered: its rows are there and no second read was made; the period passed: one more" "[$( rigVal in.path )] $( rigVal in.rows ) $( rigCallsIn "$MANAGER_SCREEN_RIG/calls.in" --read-pending-reply ) $( rigCalls --read-pending-reply )" "[pending] 4 1 2"

echo "-- inside the sessions and the configuration: Launch (Start), Server Keys, a subject; the checker is not run by the focus --"
rigCase inner
rigScript <<'RIGSCRIPT'
turn
keys DOWN DOWN ENTER DOWN ENTER DOWN
wait focus 5
show L
keys BACKSPACE BACKSPACE BACKSPACE DOWN DOWN DOWN DOWN DOWN ENTER DOWN
wait focus 5
advance 11
turn
wait check 5
keys u
turn
wait check 5
show K0
cells k0s 35 0 120
get k0
keys r
get asked
wait check 5
show K1
keys DOWN
wait focus 5
turn 2
wait plan 5
show Y
keys DOWN DOWN DOWN DOWN
wait focus 5
show U
keys r
get refused
keys BACKSPACE UP ENTER DOWN DOWN DOWN DOWN
wait focus 5
show I
RIGSCRIPT
rigAssert "Launch (Start): every routine as a table, its start in a word, nothing above it" "$( rigLeft L )" " ROUTINE  START          OWNER              TITLE          SESSION /  daily    startable      magic-coordinator  Daily meeting  work /  retro    members        magic-coordinator  Retro          work /  sweep    broken         keeper-myx         Sweep          work /  audit    not-startable  keeper-myx         Audit          work"
rigAssert "the checker on its row, rested, the period passed and a read asked for: it was not run; the folder says so and names the key, which the status line offers" "[$( rigVal k0.selected )] [$( rigLeft K0 | sed 's/ \/ .*$//' )] $( rigHolds K0 'r runs them.' ) [$( rigVal k0s | LC_ALL=C grep -c -F 'r Run' )]" "[checker] [The checks were not run yet in this run of the screen.] 1 [1]"
rigAssert "r on that row runs them, once, and the folder then holds every check as a table, the worst first, nothing above it" "[$( rigVal asked.notice )] $( rigCalls --manager-check-run ) [$( rigLeft K1 )]" "[Run the checks: asked of the tooling, it takes up to a minute] 1 [ CHECK  STATE  DOMAIN   REASON /  Token  fail   slack    the token is missing /  Bash   ok     install  fine]"
rigAssert "Server Keys: its groups in one table, each public key whole and never its short form, the list read once and each key that can be read" "$( rigLeft Y ) $( rigHolds Y short-marker ) $( rigCalls --manager-keys-list ) $( rigCalls '--manager-keys-read deploy' ) $( rigCalls '--manager-keys-read host' )" " KEY         TYPE         PUBLIC LINE /  To add to git /  Deploy key  ssh-ed25519  ssh-ed25519 AAAAC3NzaWHOLEKEY rig@host /  To trust when connecting /  Host key    ssh-ed25519  absent: /rig/keys/host.pub 0 1 1 0"
rigAssert "a subject of the configuration: its missing line first, a secret in its one form and nothing beside it (F11.7)" "$( rigLeft U ) $( rigHolds U hidden-value )" " SETTING         VALUE           SOURCE  KEY /  missing, first /  Signing secret  not configured  file    signing in hooks /  app /  Channel         C123            file    channel /  Bot token       hidd********    file    token 0"
rigAssert "on another row of the configuration the key of the checks says that it is not for it" "[$( rigVal refused.notice )]" "[Run the checks: for the checker, not for what is selected]"
rigAssert "a subject of the settings: its settings with their values, a choice by the value it is saved as" "$( rigLeft I )" " SETTING  VALUE  SOURCE  KEY /  Style    tv     file    style /  Period   10     file    period"

echo "-- a folder whose read fails says so --"
rigCase fails
echo fail > "$MANAGER_SCREEN_RIG/mode.--manager-console-list"
rigScript <<'RIGSCRIPT'
turn
keys DOWN DOWN DOWN DOWN
wait focus 5
get box
keys ESC
turn
show said
RIGSCRIPT
rigAssert "a box says it once, and the left window says it while the folder is selected" "[$( rigVal box.dialogTitle )] [$( rigLeft said )]" "[A read failed] [Consoles could not be read: rig-tools: ⛔ ERROR: the rig said fail]"

echo "-- the real screen on a pseudo-terminal: it starts, a folder that has the focus is shown from its rows, and Ctrl-X ends it --"
rigCase pty
mkdir -p "$rigTmp/ws-rig"
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigTools" > "$rigTmp/tools"
chmod +x "$rigTmp/tools"
rigOut="$( MANAGER_SCREEN_PTY_TRACE='asks=QUESTION' "$rigPython" -I -B "$rigDriver" "$rigScreen" pty 120 36 "Magic-Team (Agents)" '\x1bOA\p\x1bOA\p\x1bOA\p\x1bOA\p\x1bOA\p\x1bOA\p\x1bOA\p\aQUESTION\a\x18' 60 -- "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" 2>&1 )"
rigAssert "it draws the summary of the asks with no Enter and ends with status 0, the terminal given back" "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.errorAfterLeft ) $( rigVal pty.modeBack ) [$( rigVal pty.trace | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/ $//' )]" "yes 0 yes none yes [asks]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN FOCUS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_FOCUS: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
