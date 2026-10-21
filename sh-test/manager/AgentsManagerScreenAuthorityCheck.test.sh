#!/usr/bin/env bash
## Behavioural check on the console app's step of the authority to resolve and dismiss (F6.10 of the refactorings
## epic): a request made without the authority, a permission addressed to its holder, shows in `Pending Questions`;
## approving it there with the existing answer key opens one confirmation dialog, and only its OK acts. Run rather
## than read: the screen's own code (sh-lib/manager/AgentsManagerScreen.py) runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls the stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which notes each start and prints the case's fixture.
## Held:
##   1. the request is a row of Pending Questions, and Enter opens the dialog of its answer, as for any ask
##   2. approving it there opens one confirmation dialog, and calls nothing
##   3. Cancel of that dialog closes it, and calls nothing
##   4. its OK acts: one call of the answer operation, with the answer chosen
##   5. an answer refused for the authority opens the dialog of the two ways to ask for it, and calls nothing
##      more; its Enqueue is one call more, the same with --escalate-enqueue
##   6. its Request and wait runs the same call with --escalate-wait --escalate-stop in the big output dialog the commands of a workspace run
##      in, with its output live; the dialog has Cancel and Enqueue; Enqueue sends the call SIGUSR1 (it leaves the request pending)
##   7. Cancel, asked about first, sends it SIGTERM (it withdraws the request)
## Red before F6.10: the answer dialog acts at once, with no confirmation (2, 3 and 4 fail).
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
rigTmp="$( rigTempDir AgentsManagerScreenAuthorityCheck )" || exit 1
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
## The one open ask: the request a console caller without the authority made, addressed to the human-owner.
rigAsk=4a4a4a4a-0000-4000-8000-000000000001
printf 'PENDING-REPLY: %s\nstatus: reply-pending\nowner: magic-tester\nkind: permission\nchannel: C0RIGCHAN01\nquestion-ts: 1791840000.000400\nthread-ts: 1791840000.000300\naddress-to: human-owner\nsession-id: 7a7a7a7a-0000-4000-8000-0000000000c3\nasked-at: 2026-10-13 02:05 +0300\nasker-live: running\nquestion: May user-rig answer the decision of magic-tester, keep the file?\n\nPENDING-REPLIES: 1\n' \
	"$rigAsk" > "$rigTmp/one.ask"
rigCase(){ ## name -- a fresh rig: no call noted yet, the ask the stand-in prints, what can be done with it, and what an answer prints
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	: > "$MANAGER_SCREEN_RIG/calls"
	cp "$rigTmp/one.ask" "$MANAGER_SCREEN_RIG/rows"
	printf 'rows\n' > "$MANAGER_SCREEN_RIG/mode"
	printf 'question\t%s\treply-pending\tpermission\t-\tmagic-tester\thuman-owner\tuser-rig\twords\tdeny\tyes\t-\nanswer\t-\tallow-once\tsettles\t-\nanswer\t-\tdeny\tsettles\t-\n' "$rigAsk" > "$MANAGER_SCREEN_RIG/rows.--manager-pending-reply-read --id $rigAsk"
	printf 'answered\t%s\tallow-once\tuser-rig\tconsole:rig\t-\n' "$rigAsk" > "$MANAGER_SCREEN_RIG/rows.--manager-pending-reply-answer"
}
rigScriptActs(){ ## the commands of the driver on standard input, after the ones that name the stand-in and the time of day; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:magic-team/activity none\nwall 2026-10-13 02:30 +0300\nroot active-sessions\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigActCalls(){ ## how the stand-in was started for anything but a read, each start between its own brackets
	LC_ALL=C grep -v -e '^\[--read-pending-reply\]' -e '^\[--manager-pending-reply-read\]' -e '^\[--manager-place-list\]$' "$MANAGER_SCREEN_RIG/words" 2> /dev/null | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed -e 's/ $//'
}

echo "-- 1. the request is a row of Pending Questions; Enter opens the dialog of its answer --"
rigCase approve
rigScriptActs <<'RIGSCRIPT'
size 120 40
turn
keys 2
wait list 30
keys DOWN
wait acts 30
wait view 30
turn
get row
keys ENTER
turn
get dlg
keys ENTER
turn
get confirm
RIGSCRIPT
[ "$( rigVal row.selected )" = "$rigAsk" ] || rigRefuse "the request was never a selected row of Pending Questions, so nothing below would be measured: $( printf '%s\n' "$rigOut" | LC_ALL=C grep -m2 -e DRIVER-FAILED -e Traceback -e Error )"
rigAssert "Enter opens the dialog of its answer"                      "$( rigVal dlg.dialog | LC_ALL=C cut -d: -f1 )" answer

echo "-- 2. approving it there opens one confirmation dialog, and calls nothing --"
rigDialogKind(){ ## tag -- which dialog that screen shows: none, the answer's, or another, a confirmation
	local kindOf
	kindOf="$( rigVal "$1.dialog" )"
	if [ -z "$kindOf" ] ; then printf none
	elif [ "${kindOf%%:*}" = answer ] ; then printf the-answer-dialog
	else printf a-confirmation
	fi
}
rigAssert "a dialog stands, and it is a confirmation, no longer the answer's" "$( rigDialogKind confirm )" a-confirmation
rigAssert "and nothing was called"                                    "[$( rigActCalls )]" "[]"

echo "-- 3. Cancel of the confirmation closes it, and calls nothing --"
rigCase cancel
rigScriptActs <<'RIGSCRIPT'
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
turn
keys ESC
turn
get cancelled
RIGSCRIPT
rigAssert "the dialog is closed, and nothing was called"              "[$( rigVal cancelled.dialog )] [$( rigActCalls )]" "[] []"

echo "-- 4. its OK acts: one call of the answer operation --"
rigCase ok
rigScriptActs <<'RIGSCRIPT'
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
turn
get confirmed
keys ENTER
wait action 30
turn
get done
RIGSCRIPT
rigAssert "the confirmation was asked before the call"                "$( rigDialogKind confirmed )" a-confirmation
rigAssert "its OK: one call, with the answer chosen"                  "$( rigActCalls )" "[--manager-pending-reply-answer][--id][$rigAsk][--answer][allow-once]"

echo "-- 5. a refusal for the authority offers to request and wait, or to enqueue; Enqueue is the same call with --escalate-enqueue --"
rigCase refused
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "🙋 WARNING: DistroAgentsTools: the answer allow-once of question %s needs the authority of magic-tester, which user-rig does not hold, so nothing was done." >&2\nexit 3\n' "$rigAsk" > "$MANAGER_SCREEN_RIG/refused.sh"
printf 'script refused.sh\n' > "$MANAGER_SCREEN_RIG/mode.--manager-pending-reply-answer --id $rigAsk --answer allow-once"
printf 'PENDING 9f9f9f9f-0000-4000-8000-000000000009 magic-tester\n' > "$MANAGER_SCREEN_RIG/rows.--manager-pending-reply-answer --id $rigAsk --answer allow-once --escalate-enqueue"
rigScriptActs <<'RIGSCRIPT'
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
turn
keys ENTER
wait action 30
turn
get offered
keys TAB
turn
get picked
keys ENTER
wait action 30
turn
get done
RIGSCRIPT
rigAssert "the refusal opens the dialog of the two ways, the keys on its first"  "$( rigVal offered.dialog )" "escalate:wait|"
rigAssert "the refusal called nothing more; its Enqueue: one call more, the same call with --escalate-enqueue" "$( rigVal picked.dialog ) $( rigActCalls )" \
	"escalate:enqueue| [--manager-pending-reply-answer][--id][$rigAsk][--answer][allow-once] [--manager-pending-reply-answer][--id][$rigAsk][--answer][allow-once][--escalate-enqueue]"
rigAssert "and the dialog is closed"                                  "[$( rigVal done.dialog )]" "[]"

echo "-- 6. Request and wait runs in the big output dialog, with Cancel and Enqueue; Enqueue leaves the request pending --"
rigWaitCall="--manager-pending-reply-answer --id $rigAsk --answer allow-once --escalate-wait --escalate-stop"
rigCaseWait(){ ## name -- the refusal of section 5, and a stand-in tool call that waits like the real one: SIGTERM withdraws, SIGUSR1 leaves the request pending
	rigCase "$1"
	printf '#!/usr/bin/env bash\nprintf "%%s\\n" "🙋 WARNING: DistroAgentsTools: the answer allow-once of question %s needs the authority of magic-tester, which user-rig does not hold, so nothing was done." >&2\nexit 3\n' "$rigAsk" > "$MANAGER_SCREEN_RIG/refused.sh"
	printf 'script refused.sh\n' > "$MANAGER_SCREEN_RIG/mode.--manager-pending-reply-answer --id $rigAsk --answer allow-once"
	printf '#!/usr/bin/env bash\ntrap '"'"'printf "WITHDRAWN 9f9f\\n" ; exit 130'"'"' TERM\ntrap '"'"'printf "ENQUEUED 9f9f\\n" ; exit 0'"'"' USR1\nprintf "PENDING 9f9f magic-tester\\n"\nwhile : ; do sleep 1 ; done\n' > "$MANAGER_SCREEN_RIG/waits.sh"
	printf 'script waits.sh\n' > "$MANAGER_SCREEN_RIG/mode.$rigWaitCall"
}
rigCaseWait enqueued
rigScriptActs <<'RIGSCRIPT'
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
turn
keys ENTER
wait action 30
turn
keys ENTER
turn
wait follow 2
get running
keys TAB
turn
get second
keys ENTER
wait follow 30
turn
get ended
RIGSCRIPT
rigAssert "the output dialog opens, titled by what it does, on Cancel (its first button), and shows the call's live output" "$( rigVal running.dialog ) [$( rigVal running.dialogTitle )] $( rigVal running.dialogHolds | LC_ALL=C grep -c -F 'PENDING 9f9f magic-tester' )" "output:stop| [Request and wait] 1"
rigAssert "the call is the same call with --escalate-wait --escalate-stop, run at once, not as an action" "$( rigActCalls )" "[--manager-pending-reply-answer][--id][$rigAsk][--answer][allow-once] [--manager-pending-reply-answer][--id][$rigAsk][--answer][allow-once][--escalate-wait][--escalate-stop]"
rigAssert "Enqueue is the second button" "$( rigVal second.dialog )" "output:enqueue|"
rigAssert "Enqueue sends the call SIGUSR1: it ends 0 having said it left the request pending, and the dialog has OK alone" "$( rigVal ended.dialog ) $( rigVal ended.dialogHolds | LC_ALL=C grep -c -F 'ENQUEUED 9f9f' ) $( rigVal ended.dialogHolds | LC_ALL=C grep -c -F 'Ended with status 0' )" "output:ok| 1 1"

echo "-- 7. Cancel is asked about first, and sends the call SIGTERM: it withdraws the request --"
rigCaseWait cancelled
rigScriptActs <<'RIGSCRIPT'
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
turn
keys ENTER
wait action 30
turn
keys ENTER
turn
turn
keys ENTER
turn
get asked
keys ENTER
wait follow 30
turn
get ended
RIGSCRIPT
rigAssert "Cancel asks first: its buttons are Cancel it and Go on" "$( rigVal asked.dialog ) $( rigVal asked.dialogSays | LC_ALL=C grep -c -F 'withdraws the request' )" "output:stop| 1"
rigAssert "Cancel it sends SIGTERM: the call ends 130 having withdrawn the request" "$( rigVal ended.dialog ) $( rigVal ended.dialogHolds | LC_ALL=C grep -c -F 'WITHDRAWN 9f9f' ) $( rigVal ended.dialogHolds | LC_ALL=C grep -c -F 'Ended with status 130' )" "output:ok| 1 1"

echo "-- 8. the console never serialises behind a waiting or an enqueued call: Request and wait, Enqueue, and the next request runs and asks at once --"
rigCaseWait again
rigScriptActs <<RIGSCRIPT
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
turn
keys ENTER
wait action 30
turn
keys ENTER
turn
wait follow 2
keys TAB
turn
keys ENTER
wait follow 30
turn
get first
keys ENTER
turn
keys ENTER
turn
keys ENTER
turn
keys ENTER
wait action 30
turn
keys ENTER
turn
wait follow 2
keys TAB
turn
keys ENTER
wait follow 30
turn
get second
keys ENTER
turn
keys ENTER
turn
keys ENTER
turn
keys ENTER
wait action 30
turn
keys ENTER
turn
wait follow 2
keys TAB
turn
keys ENTER
wait follow 30
turn
get third
RIGSCRIPT
rigWaitStarts="$( rigActCalls | LC_ALL=C grep -o -F -e '[--escalate-wait][--escalate-stop]' | LC_ALL=C grep -c . )"
rigAssert "three requests in a row, each left pending by Enqueue: each ran and asked at once (three starts of the waiting call), and each dialog ended" "$rigWaitStarts $( rigVal first.dialog ) $( rigVal second.dialog ) $( rigVal third.dialog )" "3 output:ok| output:ok| output:ok|"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN AUTHORITY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_AUTHORITY: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
