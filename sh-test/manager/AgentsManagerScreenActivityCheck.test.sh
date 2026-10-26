#!/usr/bin/env bash
## Behavioural check on `Magic-Team (Agents)` and the Activity reorganisation of the console app (F11.5 of the refactorings epic), run rather than read.
## The screen's own code (sh-lib/manager/AgentsManagerScreen.py) runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py)
## and the stand-in for the dispatcher (check-fixtures/manager-screen.tools.stub.sh), which prints the rows the rig keeps for each operation.
## Held (F11.5, and the rulings of 2026-10-19 on it):
##   1. `Magic-Team (Agents)` is a root, after the Dashboard and `Pending Questions`, which stands second after the Dashboard; it holds `Activity`,
##      `Launchpad`, `Team Members`, and `Team Data` where the team data is there; `Pending Questions` stands at the root alone, not under it; the old
##      roots Sessions, Team Members and Team Data are gone from the root list
##   2. `Launchpad` is a section of `Magic-Team` of its own, after `Activity` (20261021-refactorings.sketch.md, `Magic-Team` -> `Reorder`);
##      `Activity` holds `Active Sessions` (the sessions that are not closed), `Closed Sessions`, `Top Tokens` (the sessions whose tokens are known, the ones
##      that ate most first), `Active Agents`, `Waiting Agents` and `Closed Agents`; the left pane on `Activity` is the table of the sessions, as the root had
##      it, and each of the lists shows the table of its own rows
##   3. diving into a session lists its participants; a participant shows a Summary, and an agent that sits in a Wait says what it waits on and for how long
##   4. a participant is a folder of `CheckList`, `Transcript` and `Permissions`: the same folder under a session of a list of sessions, of a member, and
##      in a list of agents
##   5. `Transcript` is the log and the raw log, switchable from the Summary: the keys of the modes work there and nowhere else of a participant; the
##      session and the agent have their summary alone
##   6. `CheckList` shows the member's check list in that session, as Markdown, read by --manager-session-checklist-read
##   7. `Permissions` of a participant shows the grants that apply to its run in its session (the floor, standing, session, task and once grants of that
##      session, asked for with `--list-permissions --member --session-id`), and a grant of a session shows the status of its session, finished or active, and not
##      its condition; so does `Permissions` of a member
##   8. diving into a session under a member's `Sessions` stays in that tree, and does not jump to `Activity`
##   9. a member holds `Member Settings` before `Member Help`: its own scope settings, changed by the forms of the settings
## Red before F11.5: the root Sessions, the root Team Members and the root Team Data, a list of all the sessions with the modes of the left window on a
## session and on an agent, a session of a member that jumps into the sessions' tree, grants that show the condition of a session, no folder of a participant.
## Offline: no operation of the real tooling is called.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigScreen="$rigPackage/sh-lib/manager/AgentsManagerScreen.py"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigTools="$rigFixtures/manager-screen.tools.stub.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenActivityCheck )" || exit 1
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
rigS1=11111111-0000-4000-8000-000000000001 ; rigS2=22222222-0000-4000-8000-000000000002 ; rigS3=33333333-0000-4000-8000-000000000003
rigS4=44444444-0000-4000-8000-000000000004 ; rigS5=55555555-0000-4000-8000-000000000005
rigA1=a1a1a1a1-0000-4000-8000-0000000000a1 ; rigA2=a2a2a2a2-0000-4000-8000-0000000000a2
rigB1=b1b1b1b1-0000-4000-8000-0000000000b1 ; rigB2=b2b2b2b2-0000-4000-8000-0000000000b2
rigD1=d1d1d1d1-0000-4000-8000-0000000000d1 ; rigE1=e1e1e1e1-0000-4000-8000-0000000000e1
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
## Five sessions, the newest first, each with its tokens as the list gives them (the last field): a named one that runs, with three agents (one waits,
## one works, one has ended), 1500000 tokens; one with no name and two agents, waiting, 40000 tokens with a run not counted in; one lone run with no name,
## finished, 9000000 tokens; one of another host, named, with no figure; one lone run with no name whose record is still open, 500 tokens.
{
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0300 - 3 running=2,finished=1 - - alive 1500000
	rigRow run "$rigS1" "$rigA1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0300 - rig-host ws-rig waiting
	rigRow run "$rigS1" "$rigA2" magic-tester spawn-started running running 2026-10-12_17:05_+0300 - rig-host ws-rig working
	rigRow run "$rigS1" - keeper-myx spawn-succeeded no-spawn-id finished 2026-10-12_17:06_+0300 2026-10-12_18:00_+0300 rig-host ws-rig -
	rigRow session "$rigS2" - waiting 2026-10-12_09:00_+0300 - 2 finished=2 - - none 40000+
	rigRow run "$rigS2" "$rigB1" magic-librarian spawn-succeeded no-process finished 2026-10-12_09:00_+0300 2026-10-12_09:30_+0300 rig-host ws-rig -
	rigRow run "$rigS2" "$rigB2" magic-developer spawn-failed no-process finished 2026-10-12_09:10_+0300 2026-10-12_09:20_+0300 rig-host ws-rig -
	rigRow session "$rigS3" - finished 2026-10-11_14:28_+0300 2026-10-11_14:51_+0300 1 finished=1 - - none 9000000
	rigRow run "$rigS3" "$rigS3" magic-devops spawn-succeeded no-process finished 2026-10-11_14:28_+0300 2026-10-11_14:51_+0300 rig-host ws-rig -
	rigRow session "$rigS4" far_away unknown-foreign 2026-10-10_08:00_+0300 - 1 unknown-foreign=1 - - none -
	rigRow run "$rigS4" "$rigD1" keeper-mel spawn-started unknown-foreign unknown-foreign 2026-10-10_08:00_+0300 - other-host ws-rig -
	rigRow session "$rigS5" - unclosed 2026-09-30_10:34_+0300 - 1 unclosed=1 - - none 500
	rigRow run "$rigS5" "$rigE1" keeper-ae3 spawn-started no-process unclosed 2026-09-30_10:34_+0300 - rig-host ws-rig -
	rigRow counters 1 0 1 1 3 0.42
} > "$rigF/rows.--manager-session-list"
## The read of one run of the session that sits in a Wait: the run, and the store of it; it waits on an ask, since its last milestone at 21:00 UTC,
## an hour and a half before the time of the rig.
{
	rigRow run "$rigS1" "$rigA1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0300 - rig-host ws-rig waiting
	rigRow store "$rigA1" store claude 10 20 30 40 - - 2026-10-12T21:00:00Z wait-going-idle ask-7-of-keeper-myx - - -
} > "$rigF/rows.--manager-session-read"
## The transcript of that run, a log line, and the feed.
{
	rigRow source "$rigA1" magic-coordinator transcript /rig/transcript.jsonl
	rigRow log "$rigA1" magic-coordinator 'the_raw_line_one'
	rigRow feed 2026-10-12T21:00:00Z "$rigA1" magic-coordinator tool - 'the_feed_line_one'
} > "$rigF/rows.--manager-session-transcript-read"
printf '# Check list\n\n- [x] the first thing is done\n- [ ] the second thing is not\n' > "$rigF/rows.--manager-session-checklist-read"
## One member, whole: its sessions with its own runs, its grants, and what the digest keeps of its scope; two grants of a session, one of a session that
## runs and one of a session that has finished, and a standing one.
{
	rigRow member magic-coordinator - - - - - here here active - 
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0300 - 1 running=1
	rigRow run "$rigS1" "$rigA1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0300 - rig-host ws-rig waiting
	rigRow grant standing read /rig/ws_rig/docs docs:. standing_by_owner none
	rigRow grant session read /rig/ws_rig/a - "ref-1_by_magic-coordinator" "until_session_${rigS1}_ends"
	rigRow grant session write /rig/ws_rig/b - "ref-2_by_magic-coordinator" "until_session_${rigS3}_ends"
	rigRow grant session read /rig/ws_rig/c - "ref-3_by_magic-coordinator" "until_session_${rigS2}_ends"
} > "$rigF/rows.--manager-team-member-read"
rigRow member magic-coordinator - - - - - here here active - > "$rigF/rows.--manager-team-member-list"
## The grants that apply to that member in the first session, as the list of permissions prints them for it (the session's own, coworking and parent stores):
## the standing one, one of the session, and one of a session that has finished.
{
	rigRow standing read /rig/ws_rig/docs docs:. "standing by owner" none
	rigRow session read /rig/ws_rig/a - "ref-1 by magic-coordinator" "until session ${rigS1} ends"
	rigRow session write /rig/ws_rig/b - "ref-2 by magic-coordinator" "until session ${rigS3} ends"
} > "$rigF/rows.--list-permissions --member magic-coordinator --session-id ${rigS1}"
{
	rigRow subject scopes 2
	rigRow line scopes magic-coordinator EMAIL_USER set coordinator@rig.example Email_User 'The_address_it_writes_from.' yes text user default - /rig/user.env settings
	rigRow line scopes magic-coordinator SLACK_BOT_TOKEN secret-set - Slack_bot_token - 'no:set_at_deployment' - - - - - configuration
	rigRow line scopes magic-tester OTHER_KEY set elsewhere - - 'no:x' - - - - - settings
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
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize 120 40\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigPaneHolds(){ ## tag, text -- how many lines of the left pane of that screen hold the text
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' | LC_ALL=C grep -c -F -- "$2" || :
}

echo "-- 1. Magic-Team (Agents) is a root: after the Dashboard and Pending Questions, which is second --"
rigCase roots
rigScript <<'RIGSCRIPT'
at
rowids roots
at @magic-team
turn
rowids team
cells row1 3 85 119
cells row2 4 85 119
cells gap 5 85 119
cells row3 6 85 119
table list:pending --read-pending-reply magic-coordinator --any-owner
at @pending
wait list 30
rowids pend
RIGSCRIPT
rigAssert "the roots, in order: the Dashboard, Pending Questions second, Magic-Team (Agents), and none of Sessions, Team Members, Team Data" \
	"$( rigVal roots )" "dashboard pending magic-team places consoles workspace machine settings configuration manuals"
rigAssert "Magic-Team (Agents) holds Activity, Launchpad, Team Members and Routines, and Team Data only where the team data is there" \
	"$( rigVal team )" ".. activity launch team routines"
rigAssert "each shows by its name, and a spacer stands under Launchpad, setting it apart from the members (sketch 14.5)" "[$( rigVal row1 )][$( rigVal row2 )][$( rigVal gap | sed 's/ *$//' )][$( rigVal row3 )]" "[ Activity                        ►][ Launchpad                       ►][][ Team Members                    ►]"
rigAssert "Pending Questions at the root reads the questions, and Magic-Team holds no copy of it" \
	"$( rigCalled "--read-pending-reply magic-coordinator --any-owner" ) $( printf '%s\n' "$( rigVal team )" | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -- 'pending' )" "1 0"

echo "-- 2. Activity: the lists; Launchpad stands above, under Magic-Team; its left pane is the table of the sessions --"
rigCase activity
rigScript <<'RIGSCRIPT'
at @activity
wait sessions 30
rowids act
cells row2 3 85 119
cells row3 4 85 119
cells row4 5 85 119
cells row5 6 85 119
cells row6 7 85 119
cells row7 8 85 119
cells head 2 1 83
RIGSCRIPT
rigAssert "Active Sessions, Closed Sessions, Top Tokens, Active Agents, Waiting Agents, Closed Agents, and no Launchpad of its own" \
	"$( rigVal act )" ".. active-sessions closed-sessions top-tokens active-agents waiting-agents closed-agents"
rigAssert "they show by those names" "[$( rigVal row2 )][$( rigVal row3 )][$( rigVal row4 )][$( rigVal row5 )][$( rigVal row6 )][$( rigVal row7 )]" \
	"[ Active Sessions                 ►][ Closed Sessions                 ►][ Top Tokens                      ►][ Active Agents                   ►][ Waiting Agents                  ►][ Closed Agents                   ►]"
rigAssert "the left pane on Activity is the table of the sessions, as the root had it" "[$( rigVal head )]" "[ SESSION                      STATE     AGE AGENTS TOKENS MEMBERS]"

echo "-- 3. the lists of sessions --"
rigCase sessions
rigScript <<'RIGSCRIPT'
at @activity active-sessions
wait sessions 30
rowids active
cells head 2 1 83
cells r1 3 85 119
cells r2 4 85 119
cells r3 5 85 119
cells r4 6 85 119
keys DOWN
show sel
at @activity closed-sessions
rowids closed
at @activity top-tokens
rowids top
RIGSCRIPT
rigAssert "Active Sessions are those that are not closed: the running one, the waiting one, the one of another host and the one whose record is open, in the order of the list" \
	"$( rigVal active )" ".. $rigS1 $rigS2 $rigS4 $rigS5"
rigAssert "Closed Sessions are the finished ones" "$( rigVal closed )" ".. $rigS3"
rigAssert "Top Tokens are the sessions whose tokens are known, the ones that ate most first; the one with no figure is left out, one counted with a + keeps its number" \
	"$( rigVal top )" ".. $rigS3 $rigS1 $rigS2 $rigS5"
rigAssert "one read of the list of the sessions makes them all" "$( rigCalled --manager-session-list )" "1"
rigAssert "a session shows by its name and its state, with its tokens at the end" "[$( rigVal r1 )][$( rigVal r2 )][$( rigVal r3 )][$( rigVal r4 )]" \
	"[ daily of Monday  running   1.5M ►][ 22222222-0000-4… waiting   40K+ ►][ far away unknown-foreign      - ►][ keeper-ae3 555… unclosed    500 ►]"
rigAssert "the left pane shows the table of that list: its sessions only" "[$( rigVal head )]" "[ SESSION              STATE     AGE AGENTS TOKENS MEMBERS]"
rigAssert "the pane names no keys of the row in a line of its own: the status line has them" "$( rigPaneHolds sel 'keys:' ) $( rigPaneHolds sel ' k Kill' )" "0 1"

echo "-- 4. the lists of agents --"
rigCase agents
rigScript <<'RIGSCRIPT'
at @activity active-agents
wait sessions 30
rowids active
cells head 2 1 83
cells r1 3 85 119
cells r2 4 85 119
at @activity waiting-agents
rowids waiting
at @activity closed-agents
rowids closed
RIGSCRIPT
rigBoth="" ; rigActiveIds=" $( rigVal active ) "
for rigOne in $( rigVal waiting ) ; do
	if [ "$rigOne" != ".." ] && [ "${rigActiveIds#*" $rigOne "}" != "$rigActiveIds" ] ; then rigBoth="$rigBoth $rigOne" ; fi
done
rigAssert "Active Agents are the runs that work, not the one that waits; the lists of Active and Waiting Agents share no run" "$( rigVal active ) /$rigBoth" ".. $rigA2 $rigD1 $rigE1 /"
rigAssert "Waiting Agents are the ones that sit in a Wait" "$( rigVal waiting )" ".. $rigA1"
rigAssert "Closed Agents are the ones whose run is finished, one with no id of its own by the session it is in and its place there" \
	"$( rigVal closed )" ".. -$rigS1.2 $rigB1 $rigB2 $rigS3"
rigAssert "an agent shows by its member and the session it works in, with its state" "[$( rigVal r1 )][$( rigVal r2 )]" \
	"[ magic-tester  … running working ►][ keeper-mel  fa… unknown-foreign ►]"
rigAssert "the left pane shows the table of the agents of that list" "[$( rigVal head )]" "[ AGENT         STATE            SESSION              AGE]"

echo "-- 5. diving into a session: its participants, each with a Summary; one in a Wait says what it waits on, and for how long --"
rigCase participants
rigScript <<RIGSCRIPT
at @activity active-sessions
wait sessions 30
keys DOWN ENTER
get in
rowids ids
keys DOWN
wait view 30
show a1
RIGSCRIPT
rigAssert "Enter on a session lists its agents, and stays in the tree of Activity" "$( rigVal in.path ) | $( rigVal ids )" "magic-team/activity/active-sessions/$rigS1 | .. $rigA1 $rigA2 -2"
rigAssert "the Summary of the one that waits says what it waits on and for how long" "$( rigPaneHolds a1 'waits on   ask-7-of-keeper-myx for 5h' )" "1"
rigAssert "the read of that agent asks for that one run" "$( rigCalled "--manager-session-read --session-id $rigA1 --run" )" "1"
rigAssert "the agent and the session have their Summary alone: the keys of the modes are not in the status line" "$( rigPaneHolds a1 ' l Log' ) $( rigPaneHolds a1 ' k Kill' )" "0 1"

echo "-- 6. a participant is a folder of CheckList, Transcript, Permissions --"
rigCase folder
rigScript <<RIGSCRIPT
at @activity active-sessions $rigS1 $rigA1
turn
rowids items
cells i1 3 85 119
cells i2 4 85 119
cells i3 5 85 119
keys DOWN
wait view 30
show chk
at @activity active-agents $rigA1
turn
rowids items2
at @team magic-coordinator sessions $rigS1 $rigA1
turn
rowids items3
RIGSCRIPT
rigAssert "it holds CheckList, Transcript and Permissions" "$( rigVal items )" ".. checklist.md transcript permissions"
rigAssert "which show by those names, the last a folder" "[$( rigVal i1 )][$( rigVal i2 )][$( rigVal i3 )]" "[ CheckList][ Transcript][ Permissions                     ►]"
rigAssert "the same folder is under an agent of a list of agents, and under a session of a member" "$( rigVal items2 ) | $( rigVal items3 )" ".. checklist.md transcript permissions | .. checklist.md transcript permissions"
rigAssert "CheckList asks for the check list of that member in that session" "$( rigCalled "--manager-session-checklist-read --session-id $rigS1 magic-coordinator" )" "1"
rigAssert "and shows it as Markdown: the text of its heading and its items, without the marks that write them" "$( rigPaneHolds chk 'Check list' ) $( rigPaneHolds chk '[x] the first thing is done' ) $( rigPaneHolds chk '# Check list' )" "1 1 0"

echo "-- 7. Transcript is the log and the raw log, switchable from the Summary --"
rigCase transcript
rigScript <<RIGSCRIPT
at @activity active-sessions $rigS1 $rigA1
turn
keys DOWN DOWN
wait view 30
border t1 1 0 84
show s1
keys l
wait feed 30
border t2 1 0 84
show s2
keys g
wait feed 30
border t3 1 0 84
show s3
keys b
wait view 30
border t4 1 0 84
RIGSCRIPT
rigAssert "Transcript opens at the Summary of the participant, with the waiting it shows, and the status line offers the log and the raw log" \
	"$( rigVal t1 ) $( rigPaneHolds s1 'waits on' ) $( rigPaneHolds s1 ' l Log' ) $( rigPaneHolds s1 ' g Raw log' )" "Transcript [summary] [wrap] 1 1 1"
rigAssert "l shows the log, the feed of that run, and the status line offers the Summary" "$( rigVal t2 ) $( rigPaneHolds s2 'the_feed_line_one' ) $( rigPaneHolds s2 ' b Summary' )" "Transcript [log] [wrap] 1 1"
rigAssert "g shows the raw log, which asks for the lines of the session log besides" "$( rigVal t3 ) $( rigCalled "--manager-session-transcript-read --session-id $rigA1 --run --log" )" "Transcript [raw] [wrap] 1"
rigAssert "b is back at the Summary" "$( rigVal t4 )" "Transcript [summary] [wrap]"
rigAssert "the feed of the run is asked for by the run alone" "$( rigCalled "--manager-session-transcript-read --session-id $rigA1 --run" )" "1"

echo "-- 8. Permissions of a participant: the member's grants, a session grant shows the status of its session --"
rigCase permissions
rigScript <<RIGSCRIPT
at @activity active-sessions $rigS1 $rigA1 permissions
wait list 30
turn
rowids perm
show pp
RIGSCRIPT
rigAssert "the grants of the member stand under a heading for each kind, as they are read" "$( rigVal perm )" ".. kind:standing 0 kind:session 1 2"
rigAssert "a grant of a session shows the status of that session, active or finished, and not the condition; a standing one shows what it showed" \
	"$( rigPaneHolds pp '/rig/ws_rig/a  read    ref-1 by magic-coordinator  active' ) $( rigPaneHolds pp '/rig/ws_rig/b  write   ref-2 by magic-coordinator  finished' ) $( rigPaneHolds pp 'until session' ) $( rigPaneHolds pp 'docs:.         read    standing by owner           none' ) $( rigPaneHolds pp '/rig/ws_rig/c' )" "1 1 0 1 0"
rigAssert "the grants are those that apply to the member of that participant in its session, not all it holds: asked for that session once, never for the member alone, and the whole read of the member is not made for it" "$( rigCalled "--list-permissions --member magic-coordinator --session-id $rigS1" ) $( rigCalled "--list-permissions --member magic-coordinator" ) $( rigCalled "--manager-team-member-read --full magic-coordinator" )" "1 0 0"
rigCase memberpermissions
rigScript <<RIGSCRIPT
at @team magic-coordinator permissions
wait list 30
turn
show mp
RIGSCRIPT
rigAssert "the Permissions of the member show the same, and the grant it holds in another session besides, which the participant's do not" "$( rigPaneHolds mp '/rig/ws_rig/a  read    ref-1 by magic-coordinator  active' ) $( rigPaneHolds mp '/rig/ws_rig/b  write   ref-2 by magic-coordinator  finished' ) $( rigPaneHolds mp 'until session' ) $( rigPaneHolds mp '/rig/ws_rig/c  read    ref-3 by magic-coordinator  active' )" "1 1 0 1"

echo "-- 9. Team Members: a session of a member opens in the tree of the member, and a member holds Member Settings before Member Help --"
rigCase member
rigScript <<RIGSCRIPT
at @team
wait list 30
get tg
rowids team
at @team magic-coordinator
turn
rowids member
at @team magic-coordinator sessions
wait list 30
keys DOWN ENTER
get ses
rowids sesids
at @team magic-coordinator settings
wait list 30
turn
rowids setids
show st
keys DOWN ENTER
get dlg
RIGSCRIPT
rigAssert "Team Members stands under Magic-Team (Agents), and lists the members" "$( rigVal tg.path ) | $( rigVal team )" "magic-team/team | .. magic-coordinator"
rigAssert "a member holds its folders, Member Settings before Member Help" "$( rigVal member )" ".. permissions files sessions settings help"
rigAssert "Enter on a session of a member stays in the tree of the member, and lists the agents of that session" "$( rigVal ses.path ) | $( rigVal sesids )" "magic-team/team/magic-coordinator/sessions/$rigS1 | .. $rigA1 $rigA2 -2"
rigAssert "Member Settings lists the lines of the scope of that member, and none of another" "$( rigVal setids )" ".. EMAIL_USER SLACK_BOT_TOKEN"
rigAssert "as a table of the settings, a credential only as configured" "$( rigPaneHolds st 'Email User       coordinator@rig.example  default  EMAIL_USER' ) $( rigPaneHolds st 'Slack bot token  configured' )" "1 1"
rigAssert "Enter on a line opens the form of that setting, on its value" "$( rigVal dlg.dialog ) | $( rigVal dlg.dialogTitle )" "setting-text:words|coordinator@rig.example | Email User"

echo "-- 9b. Member Settings: every setting is changed with Enter (F11.7), the ones the digest does not change by the scope that holds them --"
rigCase memberedit
{
	rigRow subject scopes 4
	rigRow line scopes magic-coordinator TEAM_DATA_GIT_REMOTE set git@rig.example:board.git Team_Data_Git_Remote 'The_clone_URL.' 'no:set_at_deployment' - - - - - configuration
	rigRow line scopes magic-coordinator MDAT_KNOWLEDGE_STORE set off Knowledge_Store 'Whether_it_is_kept.' 'no:set_at_deployment' - - - - - configuration
	rigRow line scopes magic-coordinator TEAM_DATA_ROOT set /rig/ws/team-data Team_Data_Root 'The_folder.' 'no:set_at_deployment' - - - - - configuration
	rigRow line scopes magic-coordinator SLACK_BOT_TOKEN secret-set 'xoxb-1************' Slack_Bot_Token 'The_token.' 'no:set_at_deployment' - - - - - configuration
	rigRow subject knowledge 1 Knowledge_Store
	rigRow line knowledge store MDAT_KNOWLEDGE_STORE set off Knowledge_Store_Switch 'Whether_the_team_keeps_a_store.' yes choice user default 'off=Off,on=On' /rig/user.env settings
} > "$MANAGER_SCREEN_RIG/rows.--manager-config-digest"
printf 'git@rig.example:board.git\n' > "$MANAGER_SCREEN_RIG/rows.--manager-scope-reveal agents:magic-coordinator TEAM_DATA_GIT_REMOTE"
printf 'off\n' > "$MANAGER_SCREEN_RIG/rows.--manager-scope-reveal agents:magic-coordinator MDAT_KNOWLEDGE_STORE"
printf '/rig/ws/team-data\n' > "$MANAGER_SCREEN_RIG/rows.--manager-scope-reveal agents:magic-coordinator TEAM_DATA_ROOT"
rigScript <<'RIGSCRIPT'
at @team magic-coordinator settings
wait list 30
turn
rowids setids
cells mrow1 3 85 119
cells mrow2 4 85 119
cells mrow3 5 85 119
cells mrow4 6 85 119
keys DOWN
turn
get plainSel
keys ENTER
turn
get plain
wait plan 30
turn
get plainLoaded
keys BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE b o a r d
turn
get plainTyped
keys ENTER
turn
wait action 30
turn 2
get plainSaved
keys DOWN ENTER
turn
get enum
show enum
keys DOWN SPACE
turn
get enumPicked
keys ENTER
turn
wait action 30
turn 2
get enumSaved
keys DOWN ENTER
turn
get path
wait plan 30
turn
get pathLoaded
keys ESC
keys DOWN ENTER
turn
get cred
RIGSCRIPT

rigAssert "every line of the scope of a member is a row that Enter opens, the plain, the enum and the path ones, whatever the digest says of changing it" "$( rigVal setids ) [$( rigVal mrow1 )][$( rigVal mrow2 )][$( rigVal mrow3 )][$( rigVal mrow4 )]" ".. TEAM_DATA_GIT_REMOTE MDAT_KNOWLEDGE_STORE TEAM_DATA_ROOT SLACK_BOT_TOKEN [ TEAM_DATA_GIT_REMOTE...][ MDAT_KNOWLEDGE_STORE...][ TEAM_DATA_ROOT...][ SLACK_BOT_TOKEN...]"
rigAssert "Enter on a plain one opens its form, its value read whole, typed over, and saved in the scope of the member by the operation of the scope, the value on the standard input alone" "$( rigVal plain.dialog ) / $( rigVal plainLoaded.dialog ) / $( rigVal plainTyped.dialog ) / $( rigCalled '--manager-scope-set agents:magic-coordinator TEAM_DATA_GIT_REMOTE' ) [$( rigVal plainSaved.dialog )] $( LC_ALL=C grep -c -F -- 'board' "$MANAGER_SCREEN_RIG/calls" || : )" "scope-edit:words| / scope-edit:words|git@rig.example:board.git / scope-edit:words|board / 1 [] 0"
rigAssert "Enter on an enum one opens the form of a choice on the value it holds, with the values the digest declares for the key, and saves the one chosen in that scope" "$( rigVal enum.dialog ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^enum|' | LC_ALL=C grep -c -F -e ' Off' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^enum|' | LC_ALL=C grep -c -F -e ' On' ) / $( rigVal enumPicked.dialog ) / $( rigCalled '--manager-scope-set agents:magic-coordinator MDAT_KNOWLEDGE_STORE' ) [$( rigVal enumSaved.dialog )] [$( LC_ALL=C tr -d '\n' < "$MANAGER_SCREEN_RIG/stdin.--manager-scope-set" 2> /dev/null )]" "setting:choice|off 1 1 / setting:choice|on / 1 [] [boardon]"
rigAssert "Enter on a path one opens the form of a text with its value read whole" "$( rigVal path.dialog ) / $( rigVal pathLoaded.dialog )" "scope-edit:words| / scope-edit:words|/rig/ws/team-data"
rigAssert "Enter on a credential of the scope opens the form of a credential, its one form in the field, with Reveal, as in Scope Settings" "$( rigVal cred.dialog )" "scope-credential:words|xoxb-1************"

echo "-- 10. the key that takes all or only the active is not offered on the lists made whole of the one read; it stays where it has something to take --"
rigCase unfiltered
rigScript <<'RIGSCRIPT'
at @activity closed-sessions
turn
cells stClosed 39 0 120
at @activity active-agents
turn
cells stAgents 39 0 120
at @activity active-sessions
turn
keys m RIGHT RIGHT
turn
show viewmenu
keys ESC
at @team
turn
cells stTeam 39 0 120
keys m RIGHT RIGHT
turn
show viewmenuTeam
RIGSCRIPT
rigAssert "not in the status line of Closed Sessions or of the agents, not in the menu View of Active Sessions; in the status line of the members" \
	"$( printf '%s' "$( rigVal stClosed )" | LC_ALL=C grep -c -F ' a Active' ) $( printf '%s' "$( rigVal stAgents )" | LC_ALL=C grep -c -F ' a Active' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^viewmenu|' | LC_ALL=C grep -c -F 'All or active' || : ) $( printf '%s' "$( rigVal stTeam )" | LC_ALL=C grep -c -F ' a Active' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^viewmenuTeam|' | LC_ALL=C grep -c -F 'All or active' || : )" "0 0 0 1 1"

echo
if [ "$rigFailCount" -gt 0 ] ; then
	echo "⛔ MANAGER SCREEN ACTIVITY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)"
	exit 1
fi
echo "✅ MANAGER SCREEN ACTIVITY CHECK: all $rigPassCount assertions hold"
exit 0
