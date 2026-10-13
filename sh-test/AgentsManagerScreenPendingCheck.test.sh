#!/usr/bin/env bash
## Behavioural check on the section `Pending Questions` of the manager screen (sh-lib/AgentsManagerScreen.py), run
## rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.test.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.test.sh), which notes each start and prints the case's fixture: text in the
## form `--member-pending-reply-read <member> --any-owner` prints, a record `PENDING-REPLY: <id>` with its fields,
## `asker-live:` and `question:`, and `PENDING-REPLIES: <count>` last. The time of day is the case's own.
## Held: the screen asks `--member-pending-reply-read magic-coordinator --any-owner`, while the section is shown and
## not at the root, where the counter of the status line is the list of sessions' own; each open ask is one row under
## the row that goes up, the newest first, with the mark of an asker that is gone, how long ago it was asked, the
## mark of its kind, who asks, of whom, and the first line of its question; the left pane shows the selected ask
## whole: its kind and tag, who asks and of whom, since when, whether its asker is alive and what that means, its
## asking session and item, where it was posted, a field the read prints beyond those under its own name, and the
## first line of the question broken to the width of the pane; on the section itself and on the row that goes up
## the pane says how many wait and how many have no asker any more; a store with no open ask shows an empty level
## and says that nothing waits; no key answers an ask: typing and Enter call nothing but the read, open no line
## and dive nowhere; and a read that fails keeps the rows, marked as old. And the selected ask is read by its id
## while it is selected, and only then: once that read has come, the pane shows in the place of the first line the
## whole question, its options numbered as they were asked, what else its post was filled with under the names
## of its slots, the refused call of a permission, the entries of a permission set, numbered, and its own fields,
## a held change with its whole diff as it is, and last the other fields of its record; an ask made before its
## slots were kept shows its post as the question; the pane scrolls, and still no key answers.
## Offline: no operation of the real tooling is called, and no ask is read from this machine.
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
rigTmp="$( mktemp -d -t AgentsManagerScreenPendingCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRead="--member-pending-reply-read magic-coordinator --any-owner"
## The fixture of three open asks, as the operation prints them: a decision of eleven days whose asker is gone,
## a permission of three hours whose asker runs, with an item, and a question of 25 minutes of a session that is
## not measured, with one field more than the screen sets out itself.
cat > "$rigTmp/three.asks" <<'RIGASKS'
PENDING-REPLY: 0d7affda-0000-4000-8000-000000000001
status: reply-pending
owner: keeper-myx
kind: decision
question-tag: Q11
channel: C0RIGCHAN01
question-ts: 1790852505.651369
thread-ts: 1790849290.896079
address-to: magic-coordinator
session-id: 56a396d9-0000-4000-8000-0000000000a1
asked-at: 2026-10-01 14:01 +0300
asker-live: no-process
question: Fix B is approved as correct and urgent, and the developer is still silent here after a second round of asking. What next?

PENDING-REPLY: 0e0c1c26-0000-4000-8000-000000000002
status: reply-pending
owner: magic-librarian
kind: permission
channel: C0RIGCHAN02
question-ts: 1791830000.000200
thread-ts: 1791820000.000100
address-to: human-owner
session-id: 59056eb9-0000-4000-8000-0000000000b2
item: dispatch-20261012T185601Z-spawn-proxy-83268
asked-at: 2026-10-12 23:30 +0300
asker-live: running
question: May I read inside the folder of the rig?

PENDING-REPLY: 1f2e3d4c-0000-4000-8000-000000000003
status: reply-pending
owner: magic-tester
kind: question
question-tag: Q52
channel: C0RIGCHAN01
question-ts: 1791840000.000400
thread-ts: 1791840000.000300
address-to: human-owner
session-id: 7a7a7a7a-0000-4000-8000-0000000000c3
asked-at: 2026-10-13 02:05 +0300
asker-live: no-spawn-record
options: keep the first | keep the second
question: Which of the two runs is the one to keep?

PENDING-REPLIES: 3
RIGASKS
printf 'PENDING-REPLIES: 0\n' > "$rigTmp/no.asks"
## A fresh rig for one case: no call noted yet, what the stand-in prints, and what it does at each start.
rigCase(){ ## name, the fixture the stand-in prints, what it does at every start, then what it does at start 1, 2, ... where that differs
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	: > "$MANAGER_SCREEN_RIG/calls"
	cp "$rigTmp/$2" "$MANAGER_SCREEN_RIG/rows"
	printf '%s\n' "$3" > "$MANAGER_SCREEN_RIG/mode"
	shift 3
	local caseStart=0
	for caseMode in "$@" ; do
		caseStart=$(( caseStart + 1 ))
		printf '%s\n' "$caseMode" > "$MANAGER_SCREEN_RIG/mode.$caseStart"
	done
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in and the time of day, with the read of one ask taken out of the table; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:sessions none\ntable view:pending:record none\nwall 2026-10-13 02:30 +0300\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigScriptWhole(){ ## the same with the read of one ask as the screen has it
	rigOut="$( { printf 'tools bash %s\ntable list:sessions none\nwall 2026-10-13 02:30 +0300\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigCalls(){ ## how many times the stand-in was started
	LC_ALL=C grep -c '' "$MANAGER_SCREEN_RIG/calls" || :
}
rigOtherCalls(){ ## how many of its starts were anything but the read of the asks
	LC_ALL=C grep -c -v -x -F -- "$rigRead" "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- the asks are read while the section is shown --"
rigCase root three.asks rows
rigScript <<'RIGSCRIPT'
size 200 40
turn 3
keys DOWN
turn
get first
cells firstLine 2 0 139
keys ENTER
get asked
wait list 30
keys LEFT
turn
get on
cells title 1 0 139
cells line1 2 0 139
cells line2 3 0 139
keys ENTER
advance 9
turn 3
get early
advance 2
wait list 30
RIGSCRIPT
rigAssert "at the root nothing of the asks is read, and the pane of the section is empty" "$( rigVal first.selected ) [$( rigVal first.reading )] [$( rigVal firstLine )]" "pending [] []"
rigAssert "entering the section starts the read"                     "$( rigVal asked.path ) $( rigVal asked.reading )" "pending list:pending"
rigAssert "it is the read of every owner's asks, named for magic-coordinator" "[$( LC_ALL=C sed -n '1p' "$MANAGER_SCREEN_RIG/calls" )]" "[$rigRead]"
rigAssert "back on the section itself the left pane says how many wait, and how many have no asker" "$( rigVal on.selected ) [$( rigVal title )] [$( rigVal line1 )] [$( rigVal line2 )]" \
	"pending [ Pending Questions] [ 3 asks wait for an answer.] [ 1 of them was asked by a run that is gone (x in the list): nobody is there to take the answer.]"
rigAssert "it is read again on the period, and not before"           "[$( rigVal early.reading )] $( rigCalls ) $( rigOtherCalls )" "[] 2 0"

echo "-- each open ask is one row --"
rigCase rows three.asks rows
rigScript <<'RIGSCRIPT'
size 200 40
keys DOWN ENTER
wait list 30
get a
cells title 1 140 200
cells row1 2 140 200
cells row2 3 140 200
cells row3 4 140 200
cells row4 5 140 200
cells row5 6 140 200
cells up1 2 0 139
size 120 40
cells narrow2 3 84 120
cells narrow4 5 84 120
get n
RIGSCRIPT
rigAssert "the level shows the three asks under the row that goes up" "$( rigVal a.path ) $( rigVal a.rows ) [$( rigVal title )] [$( rigVal row1 )] [$( rigVal row5 )]" "pending 4 [ Pending Questions] [>..] []"
rigAssert "the newest first: how long ago, the mark of its kind, who asks, of whom, the first line of the question" \
	"[$( rigVal row2 )]" "[   25m ❓ magic-tester > human-owner  Which of the two runs…]"
rigAssert "then the one of three hours"                              "[$( rigVal row3 )]" "[    3h 🔐 magic-librarian > human-owner  May I read inside …]"
rigAssert "last the one of eleven days, with the plain mark of an asker that is gone" \
	"[$( rigVal row4 )]" "[ x 11d 🧭 keeper-myx > magic-coordinator  Fix B is approved…]"
rigAssert "on the row that goes up the left pane says how many wait" "[$( rigVal up1 )]" "[ 3 asks wait for an answer.]"
rigAssert "at 120 columns a row is cut to the list, the age, the kind and who asks first" "[$( rigVal narrow2 )] [$( rigVal narrow4 )] $( rigVal n.spills )" "[   25m ❓ magic-tester > human-owne…] [ x 11d 🧭 keeper-myx > magic-coordi…] 0"
rigAssert "only the read of the asks was called"                     "$( rigOtherCalls )" 0

echo "-- the left pane shows the selected ask --"
rigCase ask three.asks rows
rigScript <<'RIGSCRIPT'
size 120 40
keys DOWN ENTER
wait list 30
keys DOWN DOWN DOWN
turn
get a
show s
keys UP
turn
get b
show t
keys UP
turn
show u
RIGSCRIPT
rigPane(){ ## tag, line counted from 1 -- the left pane's part of that line of the screen, without the spaces at its end
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n "${2}p" | LC_ALL=C sed -e "s/^$1|//" -e 's/│.*$//' -e 's/  *$//'
}
rigAssert "the oldest ask is selected, and the pane is titled by its row" "$( rigVal a.selected ) [$( rigPane s 2 | LC_ALL=C cut -c1-22 )]" "0d7affda-0000-4000-8000-000000000001 [ x 11d 🧭 keeper-myx]"
rigAssert "its kind, with its mark and its tag"                      "[$( rigPane s 3 )]" "[ 🧭 decision Q11]"
rigAssert "who asks, and of whom"                                    "[$( rigPane s 5 )][$( rigPane s 6 )]" "[ asked by  keeper-myx][ asked of  magic-coordinator]"
rigAssert "since when, and how long ago"                             "[$( rigPane s 7 )]" "[ asked at  2026-10-01 14:01 +0300 (11d ago)]"
rigAssert "that its asker is gone, and what that means"              "[$( rigPane s 8 )]" "[ asker     no-process: nothing runs as it, so nobody is there to take the answer]"
rigAssert "its asking session"                                       "[$( rigPane s 9 )]" "[ session   56a396d9-0000-4000-8000-0000000000a1]"
rigAssert "where it was posted"                                      "[$( rigPane s 10 )]" "[ posted    channel C0RIGCHAN01, thread 1790849290.896079, message 1790852505.651369]"
rigAssert "its status and its own id"                                "[$( rigPane s 11 )][$( rigPane s 12 )]" "[ status    reply-pending][ ask       0d7affda-0000-4000-8000-000000000001]"
rigAssert "the first line of its question, broken to the width of the pane" "[$( rigPane s 14 )][$( rigPane s 15 )][$( rigPane s 16 )][$( rigPane s 17 )]" \
	"[ question, its first line:][ Fix B is approved as correct and urgent, and the developer is still silent here][ after a second round of asking. What next?][]"
rigAssert "and that it is for viewing only"                          "[$( rigPane s 18 )]" "[ viewing only: an ask is answered where it was posted]"
rigAssert "the ask above it replaces the pane: its item stands with its session" "$( rigVal b.selected ) [$( rigPane t 3 )][$( rigPane t 8 )][$( rigPane t 9 )][$( rigPane t 10 )]" \
	"0e0c1c26-0000-4000-8000-000000000002 [ 🔐 permission][ asker     running: a process of this host runs as it][ session   59056eb9-0000-4000-8000-0000000000b2][ item      dispatch-20261012T185601Z-spawn-proxy-83268]"
rigAssert "a field the read prints beyond those is shown under its own name: the place of the options" "[$( rigPane u 3 )][$( rigPane u 14 )]" \
	"[ ❓ question Q52][ options   keep the first | keep the second]"
rigAssert "a field longer than the pane is broken, and goes on under its value" "[$( rigPane u 8 )][$( rigPane u 9 )][$( rigPane u 10 | LC_ALL=C cut -c1-10 )]" \
	"[ asker     no-spawn-record: a session no spawn started, with no end recorded: not][           measured][ session  ]"

echo "-- no key answers an ask --"
rigCase nokey three.asks rows
rigScript <<'RIGSCRIPT'
size 120 40
handler kill
handler start
keys DOWN ENTER
wait list 30
keys DOWN
turn
get on
cells keysLine 37 0 83
keys y e SPACE o ENTER
turn
get typed
keys RIGHT
get dived
RIGSCRIPT
rigAssert "an ask is selected, and the left pane names no key for it" "$( rigVal on.selected ) [$( rigVal keysLine )]" "1f2e3d4c-0000-4000-8000-000000000003 []"
rigAssert "a text is typed and Enter is pressed: no line opens, and nothing is submitted" "[$( rigVal typed.dialog )] [$( rigVal typed.notice )] $( rigVal typed.quit )" "[] [] no"
rigAssert "Enter and Right dive nowhere"                             "$( rigVal dived.path ) $( rigVal dived.selected )" "pending 1f2e3d4c-0000-4000-8000-000000000003"
rigAssert "no operation that changes an ask is called: every start is the read" "$( rigOtherCalls ) $( [ "$( rigCalls )" -ge 1 ] && printf read )" "0 read"

echo "-- a store with no open ask --"
rigCase empty no.asks rows
rigScript <<'RIGSCRIPT'
size 120 40
keys DOWN ENTER
wait list 30
get a
cells row1 2 84 120
cells row2 3 84 120
cells line1 2 0 83
keys LEFT
turn
cells rootLine1 2 0 83
RIGSCRIPT
rigAssert "the level shows the row that goes up, and nothing more"   "$( rigVal a.rows ) [$( rigVal row1 )] [$( rigVal row2 )]" "1 [>..] []"
rigAssert "the left pane says that nothing waits"                    "[$( rigVal line1 )]" "[ Nothing waits for an answer.]"
rigAssert "on the section at the root the pane says the same"        "[$( rigVal rootLine1 )]" "[ Nothing waits for an answer.]"

echo "-- a read of the asks that fails --"
rigCase fail three.asks rows rows fail rows
rigScript <<'RIGSCRIPT'
size 120 40
keys DOWN ENTER
wait list 30
keys DOWN DOWN
get good
advance 11
wait list 30
get bad
cells badTitle 1 84 120
cells badLine 38 0 83
advance 11
wait list 30
get mended
cells mendedTitle 1 84 120
RIGSCRIPT
rigAssert "the second read failed"                                   "$( rigCalls ) [$( rigVal bad.failed )]" "3 [list:pending]"
rigAssert "the asks stay, and the selection with them"               "$( rigVal bad.rows ) $( rigVal bad.selected )" "4 0e0c1c26-0000-4000-8000-000000000002"
rigAssert "the level is marked as old"                               "[$( rigVal badTitle )]" "[ ! Pending Questions]"
rigAssert "and the error line of the read is shown"                  "[$( rigVal badLine )]" "[ --member-pending-reply-read: rig-tools: ⛔ ERROR: the rig said fail]"
rigAssert "a good read takes the mark away"                          "[$( rigVal mended.failed )] [$( rigVal mendedTitle )]" "[] [ Pending Questions]"

## Four asks for the read of one ask by its id: the decision above, asked before its slots were kept; the
## permission above, with its slots and its refused call; a permission set with its entries; a held change with
## its diff. For each, what that read prints: the lines of the list, then what the stores hold of it.
rigD=0d7affda-0000-4000-8000-000000000001 ; rigP=0e0c1c26-0000-4000-8000-000000000002
rigT=4a4a4a4a-0000-4000-8000-000000000004 ; rigC=5c5c5c5c-0000-4000-8000-000000000005
{
	LC_ALL=C sed -n '1,28p' "$rigTmp/three.asks"
	cat <<RIGASKS
PENDING-REPLY: $rigT
status: reply-pending
owner: magic-developer
kind: permission-set
channel: C0RIGCHAN02
question-ts: 1791850000.000600
thread-ts: 1791850000.000500
address-to: human-owner
session-id: 8b8b8b8b-0000-4000-8000-0000000000d4
asked-at: 2026-10-13 01:00 +0300
asker-live: running
question: Three things for the migration.

PENDING-REPLY: $rigC
status: reply-pending
owner: magic-librarian
kind: change
channel: C0RIGCHAN02
question-ts: 1791860000.000800
thread-ts: 1791860000.000700
address-to: human-owner
session-id: 9c9c9c9c-0000-4000-8000-0000000000e5
asked-at: 2026-10-13 01:30 +0300
asker-live: running
question: May this change to the routine be applied?

PENDING-REPLIES: 4
RIGASKS
} > "$rigTmp/four.asks"
rigOne(){ ## id -- the lines the list prints of that one ask, and the empty line after them
	LC_ALL=C awk -v id="$1" '$0 == "PENDING-REPLY: " id { on = 1 } on { print } on && $0 == "" { exit }' "$rigTmp/four.asks"
}
rigStoredFile(){ ## id -- where the stand-in keeps what the read of that ask by its id prints
	printf '%s' "$rigTmp/stored/rows.--member-pending-reply-read magic-coordinator $1"
}
mkdir -p "$rigTmp/stored"
{
	rigOne "$rigD"
	cat <<RIGSTORED
PENDING-REPLY-STORED: $rigD
host: rig-host
communication-channel-id: slack:C0RIGCHAN01:1790849290.896079
question-key: 3459631396-123
reminders: 1
posted: # 🧭 Decision Q11
posted: 
posted: Fix B is approved as correct and urgent, and the developer is still silent here after a second round of asking. What next?
posted: 
posted: **📋 Options**
posted: - Proceed - land Fix B now
posted: - Keep waiting - one more bounded round
posted: - Hold - do not land Fix B
option: Proceed - land Fix B now on the review of the architect, with the consult rule of the asker still unmet, which is the longest of the three
option: Keep waiting - one more bounded round
option: Hold - do not land Fix B
kept-beside: options

RIGSTORED
} > "$( rigStoredFile "$rigD" )"
{
	rigOne "$rigP"
	cat <<RIGSTORED
PENDING-REPLY-STORED: $rigP
host: rig-host
refusal-id: r-77
posted: # 🔐 Permission
posted: 
posted: May I read inside the folder of the rig?
field-asked-as: magic-librarian
field-question: May I read inside the folder of the rig?
field-question: 
field-question: It holds the index the audit names.
field-refused-tool: Read
field-refused-target: /rig/folder/index.md
field-reason: the index is needed for the audit
field-folder: /rig/folder
field-project: rig/project
refused-tool: Read
refused-text: REFUSED: /rig/folder is outside what magic-librarian may read
kept-beside: refused.md

RIGSTORED
} > "$( rigStoredFile "$rigP" )"
{
	rigOne "$rigT"
	cat <<RIGSTORED
PENDING-REPLY-STORED: $rigT
host: rig-host
posted: # 🔐 Permission set
field-question: Three things for the migration.
set-scope: task
set-entry: Edit sh-lib/** in ws-rig
set-entry: execute make build in ws-rig
set-entry: Read /rig/other/**
set-place: ws-rig
set-purpose: the migration of the index
set-reason: each of them was refused once already

RIGSTORED
} > "$( rigStoredFile "$rigT" )"
{
	rigOne "$rigC"
	cat <<RIGSTORED
PENDING-REPLY-STORED: $rigC
host: rig-host
posted: # ✏️ Change for approval
field-question: May this change to the routine be applied?
field-act: Edit
field-file: skillset/rig/rig.routine.md
change-store: change-0005
change-diff: --- a/skillset/rig/rig.routine.md
change-diff: +++ b/skillset/rig/rig.routine.md
change-diff: @@ -3,2 +3,3 @@
change-diff:  - step one
change-diff: +- step two, a line of the diff that goes on well past the width of the pane and stays one line there
change-diff: $( printf '\t' )- step three

RIGSTORED
} > "$( rigStoredFile "$rigC" )"
rigCaseStored(){ ## name, what the stand-in does at every start, then what it does at start 1, 2, ... where that differs
	rigCase "$1" four.asks "${@:2}"
	cp "$rigTmp/stored"/* "$MANAGER_SCREEN_RIG/"
}
rigPaneHolds(){ ## tag, text -- how many lines of the left pane of that screen are exactly the text, the spaces at their ends aside
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -e "s/^$1|//" -e 's/│.*$//' -e 's/  *$//' | LC_ALL=C grep -c -x -F -- "$2" || :
}
rigReadOf(){ ## id -- how many times that one ask was read by its id
	LC_ALL=C grep -c -x -F -- "--member-pending-reply-read magic-coordinator $1" "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- the selected ask is read by its id, while it is selected --"
rigCaseStored one rows rows "sleep 2"
rigScriptWhole <<'RIGSCRIPT'
size 120 40
keys DOWN ENTER
wait list 30
get in
keys DOWN
advance 1
turn
get asked
show early
wait view 30
get c
show c
keys DOWN
wait view 30
show t
keys DOWN
wait view 30
show p
keys DOWN
wait view 30
get d
show d
advance 11
wait view 30
wait list 30
keys LEFT
advance 11
turn 3
get up
RIGSCRIPT
rigAssert "on the row that goes up no ask is read by its id"          "$( rigVal in.selected ) [$( rigVal in.reading )]" ".. []"
rigAssert "selecting an ask reads it by its id, as a call of its own" "$( rigVal asked.selected ) $( rigVal asked.reading )" "$rigC view:pending|record:$rigC"
rigAssert "until that read has come, the pane shows the first line of the question" "$( rigPaneHolds early ' question, its first line:' ) $( rigPaneHolds early ' May this change to the routine be applied?' ) [$( rigPane early 2 | LC_ALL=C cut -c1-3 )]" "1 1 [ ~ ]"
rigAssert "then the question stands whole in its place"               "$( rigPaneHolds c ' question, its first line:' ) $( rigPaneHolds c ' question:' ) $( rigPaneHolds c ' May this change to the routine be applied?' )" "0 1 1"
rigAssert "each ask is read once when it is selected, and again on the period while it stays selected" "$( rigReadOf "$rigC" ) $( rigReadOf "$rigT" ) $( rigReadOf "$rigP" ) $( rigReadOf "$rigD" )" "1 1 1 2"
rigAssert "with no ask selected none is read, whatever time passes"   "$( rigVal up.selected ) [$( rigVal up.reading )] $( rigOtherCalls )" "pending [] 5"

echo "-- a held change: its fields, and its whole diff as it is --"
rigAssert "what its post was filled with stands under the names of its slots" "$( rigPaneHolds c ' act Edit' ) $( rigPaneHolds c ' file skillset/rig/rig.routine.md' ) $( rigPaneHolds c ' change store change-0005' )" "1 1 1"
rigAssert "the diff stands as it is, line for line"                   "$( rigPaneHolds c ' the diff:' ) $( rigPaneHolds c ' --- a/skillset/rig/rig.routine.md' ) $( rigPaneHolds c ' @@ -3,2 +3,3 @@' ) $( rigPaneHolds c '  - step one' )" "1 1 1 1"
rigAssert "a long line of it stays one line, cut where the pane ends, and a TAB keeps its place" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^c|' | LC_ALL=C sed -e 's/│.*$//' -e 's/  *$//' | LC_ALL=C grep -c '^c| +- step two, a line of the diff that goes on well past the width of the pane .*…$' ) $( rigPaneHolds c ' stays one line there' ) $( rigPaneHolds c '     - step three' )" "1 0 1"
rigAssert "the post itself comes after, and last the other fields of its record" "$( rigPaneHolds c ' as posted:' ) $( rigPaneHolds c ' # ✏️ Change for approval' ) $( rigPaneHolds c ' its record:' ) $( rigPaneHolds c ' host rig-host' )" "1 1 1 1"
rigAssert "and it is still for viewing only"                          "$( rigPaneHolds c ' viewing only: an ask is answered where it was posted' )" 1

echo "-- a permission set: its entries, numbered --"
rigAssert "the entries stand numbered, in their order"                "$( rigPaneHolds t ' entries:' ) $( rigPaneHolds t '  1. Edit sh-lib/** in ws-rig' ) $( rigPaneHolds t '  2. execute make build in ws-rig' ) $( rigPaneHolds t '  3. Read /rig/other/**' )" "1 1 1 1"
rigAssert "with its scope, its place, its purpose and its reason"     "$( rigPaneHolds t ' scope task' ) $( rigPaneHolds t ' place ws-rig' ) $( rigPaneHolds t ' purpose the migration of the index' ) $( rigPaneHolds t ' reason each of them was refused once already' )" "1 1 1 1"

echo "-- a permission: the whole question, the refused call --"
rigAssert "the question of several lines stands whole, its empty line kept" "[$( rigPane p 15 )][$( rigPane p 16 )][$( rigPane p 17 )][$( rigPane p 18 )]" "[ question:][ May I read inside the folder of the rig?][][ It holds the index the audit names.]"
rigAssert "what was refused, where and why, each under the name of its slot" "$( rigPaneHolds p ' refused-tool Read' ) $( rigPaneHolds p ' refused-target /rig/folder/index.md' ) $( rigPaneHolds p ' reason the index is needed for the audit' ) $( rigPaneHolds p ' folder /rig/folder' ) $( rigPaneHolds p ' project rig/project' )" "1 1 1 1 1"
rigAssert "and what the tool said of the refused call"                "$( rigPaneHolds p ' refused text REFUSED: /rig/folder is outside what magic-librarian may read' )" 1

echo "-- a decision asked before its slots were kept: its post is the question, its options are numbered --"
rigAssert "the post stands as the question, whole, a long line broken to the pane" "$( rigPaneHolds d ' question, as posted:' ) $( rigPaneHolds d ' # 🧭 Decision Q11' ) $( rigPaneHolds d ' Fix B is approved as correct and urgent, and the developer is still silent here' ) $( rigPaneHolds d ' after a second round of asking. What next?' ) $( rigPaneHolds d ' as posted:' )" "1 1 1 1 0"
rigAssert "the options stand numbered as they were asked, a long one broken under itself" "$( rigPaneHolds d ' options:' ) $( rigPaneHolds d '  1. Proceed - land Fix B now on the review of the architect, with the consult rule' ) $( rigPaneHolds d '     of the asker still unmet, which is the longest of the three' ) $( rigPaneHolds d '  2. Keep waiting - one more bounded round' ) $( rigPaneHolds d '  3. Hold - do not land Fix B' )" "1 1 1 1 1"

echo "-- the whole ask scrolls, and still no key answers it --"
rigCaseStored scroll rows
rigScriptWhole <<'RIGSCRIPT'
size 120 20
keys DOWN ENTER
wait list 30
keys DOWN
wait view 30
get c
show c
keys TAB PGDN
get paged
show paged
keys PGDN PGDN PGDN
get end
show end
keys TAB y e s ENTER RIGHT
turn
get typed
RIGSCRIPT
rigAssert "the pane starts at the top of the ask, and does not follow its end" "$( rigVal c.viewTop ) $( rigVal c.follow ) [$( rigPane c 3 )]" "0 no [ ✏️ change]"
rigAssert "with the focus on it, PageDown shows its next page"        "$( rigVal paged.focus ) $( rigVal paged.viewTop ) $( rigPaneHolds paged ' the diff:' )" "view 16 1"
rigAssert "and reaches its last line"                                 "$( rigPaneHolds end ' viewing only: an ask is answered where it was posted' ) $( rigVal end.spills )" "1 0"
rigAssert "a text is typed and Enter is pressed: no line opens, nothing is submitted, nothing is dived into" "[$( rigVal typed.dialog )] [$( rigVal typed.notice )] $( rigVal typed.path ) $( rigVal typed.selected )" "[] [s: stop is not built yet] pending $rigC"
rigAssert "every call was a read of the asks: the list, or one ask by its id" "$( LC_ALL=C grep -c -v -- '^--member-pending-reply-read magic-coordinator ' "$MANAGER_SCREEN_RIG/calls" || : ) $( [ "$( rigReadOf "$rigC" )" -ge 1 ] && printf read )" "0 read"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN PENDING CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_PENDING: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
