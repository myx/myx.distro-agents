#!/usr/bin/env bash
## Behavioural check on the answer forms of the console app (the F6.10 line of the refactorings epic: "For its answer
## forms, the Slack question is the reference"). In Slack a person picks an answer, and may also write in the thread,
## which the bot reads as a comment on that answer; the question has the forms yes-no, one, many and a plain text. The
## console does the same: a selector, plus a small text box whose text goes with the chosen answer as its comment, and
## a plain question takes the text alone. Run rather than read: the screen's own code (sh-lib/manager/AgentsManagerScreen.py)
## runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call
## the dispatcher it calls the stand-in script (check-fixtures/manager-screen.tools.stub.sh), which notes each start and
## prints the case's fixture.
## Held:
##   1. yes-no and one: the dialog is a list of the answers, one chosen, and a field for words; the call is the answer
##      chosen, with the words after --text
##   2. many: the dialog is boxes in place of the list, the answers checked with Space; nothing checked is refused inside
##      the dialog, which stays open and says so; the call has the checked answers, in their order, as one reply names
##      them (`1 3`), and the words after --text
##   3. a plain question: a field for its answer and no list; its words are the answer alone, an empty one refused inside
##   4. the words are optional with a chosen answer: none, no --text
## Red before: a question of the form many has the list of one answer, so it can be answered with one only (1 and 2
## fail, and the rest holds).
## Offline: no operation of the real tooling is called, and no ask is read from this machine.
## Reconciled for F11.5: Pending Questions is the second root, key 2, and the list of the sessions is Active Sessions of Activity (`root active-sessions`).
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
rigTmp="$( rigTempDir AgentsManagerScreenAnswerFormsCheck )" || exit 1
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
## Four open questions of one asker, newest first as the list shows them: a plain one, one that takes several of its
## options, one that takes one, and a yes-no one.
rigPlain=4d4d4d4d-0000-4000-8000-000000000004 ; rigMany=3c3c3c3c-0000-4000-8000-000000000003
rigOne=2b2b2b2b-0000-4000-8000-000000000002 ; rigYesNo=1a1a1a1a-0000-4000-8000-000000000001
rigAsk(){ ## id, tag, asked-at, the lines after the address line
	printf 'PENDING-REPLY: %s\nstatus: reply-pending\nowner: magic-tester\nkind: question\nquestion-tag: %s\nchannel: C0RIGCHAN01\nquestion-ts: 1791840000.000%s\nthread-ts: 1791840000.000%s\naddress-to: human-owner\nsession-id: 7a7a7a7a-0000-4000-8000-0000000000c3\nasked-at: %s\nasker-live: running\n%s\n\n' \
		"$1" "$2" "${2#Q}" "${2#Q}" "$3" "$4"
}
{
	rigAsk "$rigPlain" Q54 '2026-10-13 02:05 +0300' 'question: Why did the build stop?'
	rigAsk "$rigMany" Q53 '2026-10-10 02:05 +0300' 'select: many
options: alpha first | beta second | gamma third
question: Which of the three do we keep?'
	rigAsk "$rigOne" Q52 '2026-10-05 02:05 +0300' 'select: one
options: keep the first | keep the second
question: Which of the two runs is the one to keep?'
	rigAsk "$rigYesNo" Q51 '2026-10-01 02:05 +0300' 'select: yes-no
question: Is the staging host the one to use?'
	printf 'PENDING-REPLIES: 4\n'
} > "$rigTmp/four.asks"
rigCase(){ ## name -- a fresh rig: the fixture the stand-in prints, no call noted yet, and the reads of each ask as the operation prints them
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	: > "$MANAGER_SCREEN_RIG/calls" ; : > "$MANAGER_SCREEN_RIG/words"
	cp "$rigTmp/four.asks" "$MANAGER_SCREEN_RIG/rows"
	printf 'rows\n' > "$MANAGER_SCREEN_RIG/mode"
	printf 'question\t%s\treply-pending\tquestion\tyes-no\tmagic-tester\thuman-owner\tmagic-coordinator\twords\t-\tyes\t-\nanswer\t-\tyes\tsettles\t-\nanswer\t-\tno\tsettles\t-\n' "$rigYesNo" > "$MANAGER_SCREEN_RIG/rows.--manager-pending-reply-read --id $rigYesNo"
	printf 'question\t%s\treply-pending\tquestion\tone\tmagic-tester\thuman-owner\tmagic-coordinator\twords\t-\tyes\t-\nanswer\t1\tkeep\tsettles\tkeep the first\nanswer\t2\tdrop\tsettles\tkeep the second\n' "$rigOne" > "$MANAGER_SCREEN_RIG/rows.--manager-pending-reply-read --id $rigOne"
	printf 'question\t%s\treply-pending\tquestion\tmany\tmagic-tester\thuman-owner\tmagic-coordinator\twords\t-\tyes\t-\nanswer\t1\talpha\tsettles\tfirst\nanswer\t2\tbeta\tsettles\tsecond\nanswer\t3\tgamma\tsettles\tthird\n' "$rigMany" > "$MANAGER_SCREEN_RIG/rows.--manager-pending-reply-read --id $rigMany"
	printf 'question\t%s\treply-pending\tquestion\t-\tmagic-tester\thuman-owner\tmagic-coordinator\tanswer\t-\tyes\t-\n' "$rigPlain" > "$MANAGER_SCREEN_RIG/rows.--manager-pending-reply-read --id $rigPlain"
	printf 'answered\t%s\t%s\tmagic-coordinator\tconsole:rig\t%s\n' "$1" "$1" "-" > "$MANAGER_SCREEN_RIG/rows.--manager-pending-reply-answer"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in and the time of day; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:magic-team/activity none\nwall 2026-10-13 02:30 +0300\nroot active-sessions\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigBoxHolds(){ ## tag, text -- how many lines of that box hold the text
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigAnswerCalls(){ ## how the stand-in was started for the answer, each word between brackets
	LC_ALL=C grep -F -e '[--manager-pending-reply-answer]' "$MANAGER_SCREEN_RIG/words" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed -e 's/ $//'
}
rigRefuse2(){ ## the case never drew its dialog: nothing below would be measured
	printf '%s\n' "$rigOut" | LC_ALL=C grep -m2 -e DRIVER-FAILED -e Traceback -e Error
}

echo "-- many: boxes, at least one checked, the numbers in their order, the words after --text --"
rigCase many
rigScript <<'RIGSCRIPT'
size 120 40
turn
keys 2
wait list 30
keys DOWN DOWN
wait acts 30
wait view 30
turn
keys ENTER
turn
get dlg
box mbox
keys SPACE DOWN DOWN SPACE
get checked
keys TAB b o t h
get typed
keys ENTER
get asked
RIGSCRIPT
[ -n "$( rigVal dlg.dialog )" ] || rigRefuse "the dialog of the question that takes several was never drawn, so nothing below would be measured: $( rigRefuse2 )"
rigAssert "Enter opens the dialog of the answer, on the answers" "[$( rigVal dlg.dialog | LC_ALL=C cut -d'|' -f1 )]" "[answer-many:answers]"
rigAssert "its answers are boxes, each with its number, its word and what it does, and a field for words" \
	"$( rigBoxHolds mbox '║   [ ] 1. alpha: first  --  settles it' ) $( rigBoxHolds mbox '║   [ ] 3. gamma: third  --  settles it' ) $( rigBoxHolds mbox '║   Words to go with them, or none' )" "1 1 1"
rigAssert "Space checks the one the box is on" "[$( rigVal checked.dialog )]" "[answer-many:answers|1,3]"
rigAssert "the words are typed into the field" "[$( rigVal typed.dialog )]" "[answer-many:words|both]"
rigAssert "Enter answers: the dialog closes, and the operation is called once, with the numbers checked, as one reply names them, and the words" "[$( rigVal asked.dialog )] $( rigAnswerCalls )" "[] [--manager-pending-reply-answer][--id][$rigMany][--answer][1 3][--text][both]"

rigCase manynone
rigScript <<'RIGSCRIPT'
size 120 40
turn
keys 2
wait list 30
keys DOWN DOWN
wait acts 30
wait view 30
turn
keys ENTER
turn
keys ENTER
get none
RIGSCRIPT
rigAssert "none checked is refused inside: the dialog stays open and says so, and nothing is called" "[$( rigVal none.dialog )] [$( rigVal none.dialogSays )] [$( rigAnswerCalls )]" "[answer-many:answers|] [nothing is answered: no answer is checked: check one at least, with Space] []"

echo "-- yes-no and one: a list, one chosen, the words with it --"
rigCase yesno
rigScript <<'RIGSCRIPT'
size 120 40
turn
keys 2
wait list 30
keys DOWN DOWN DOWN DOWN
wait acts 30
wait view 30
turn
keys ENTER
turn
get dlg
box ybox
keys DOWN TAB b e c a u s e
get typed
keys ENTER
get asked
RIGSCRIPT
rigAssert "a yes-no question: the dialog is the list of its two answers on the first, and a field for words" "[$( rigVal dlg.dialog )] $( rigBoxHolds ybox '║   > yes  --  settles it' ) $( rigBoxHolds ybox '║     no  --  settles it' ) $( rigBoxHolds ybox '║   Words to go with it, or none' )" "[answer:answers|yes] 1 1 1"
rigAssert "the answer picked and the words typed beside it are one call: no, and the words after --text" "[$( rigVal typed.dialog )] [$( rigVal asked.dialog )] $( rigAnswerCalls )" "[answer:words|because] [] [--manager-pending-reply-answer][--id][$rigYesNo][--answer][no][--text][because]"
rigCase one
rigScript <<'RIGSCRIPT'
size 120 40
turn
keys 2
wait list 30
keys DOWN DOWN DOWN
wait acts 30
wait view 30
turn
keys ENTER
turn
get dlg
keys 2
turn
keys ENTER
get asked
RIGSCRIPT
rigAssert "a question that takes one: the list of its options, a digit chooses, and with no words there is no --text" "[$( rigVal dlg.dialog )] [$( rigVal asked.dialog )] $( rigAnswerCalls )" "[answer:answers|1] [] [--manager-pending-reply-answer][--id][$rigOne][--answer][2]"

echo "-- a plain question: the words alone --"
rigCase plain
rigScript <<'RIGSCRIPT'
size 120 40
turn
keys 2
wait list 30
keys DOWN
wait acts 30
wait view 30
turn
keys ENTER
turn
get dlg
box pbox
keys u s e SPACE i t
keys ENTER
get asked
RIGSCRIPT
rigAssert "the dialog of a plain question has a field for its answer and no list" "[$( rigVal dlg.dialog )] $( rigBoxHolds pbox '║   The answer' ) $( rigBoxHolds pbox 'Answers' )" "[reply:words|] 1 0"
rigAssert "the words are the answer alone: one call, with them after --answer and no --text" "[$( rigVal asked.dialog )] $( rigAnswerCalls )" "[] [--manager-pending-reply-answer][--id][$rigPlain][--answer][use it]"
rigCase plainnone
rigScript <<'RIGSCRIPT'
size 120 40
turn
keys 2
wait list 30
keys DOWN
wait acts 30
wait view 30
turn
keys ENTER
turn
keys ENTER
get empty
RIGSCRIPT
rigAssert "an empty answer is refused inside, and nothing is called" "[$( rigVal empty.dialog )] [$( rigAnswerCalls )]" "[reply:words|] []"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN ANSWER FORMS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_ANSWER_FORMS: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
