#!/usr/bin/env bash
## Check on the wording a wait's result carries when a message interrupts it (S5 item 4): the member is told the
## arrival interrupts its wait, that it may continue the wait, or cancel the task, after reading the message. And an
## asking call's own result says the question stays open. Held, run and not read:
##   1. THE WAIT'S OWN NEXT LINE. A `WAIT-RESULT: RECEIVED` close says the message interrupts the wait, and names both
##      ways on: continue the wait, or cancel the task.
##   2. THE ASKING CALL'S OWN RESULT. `ASK-RESULT: ARRIVED-OTHER` says the question stays open, names the call that
##      goes on waiting, and says the task may be cancelled.
##   3. THE INSTRUMENT, both directions: the same reader run over a copy carrying the old wording of each line fails,
##      so a pass here is not a reader that cannot fail.
## Offline: the tooling's own files are read as text, and a copy of each is planted with the old wording.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTest="$rigOrigin/myx/myx.distro-agents/sh-test"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
rigWait="$rigOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessWait.include"
rigAsk="$rigOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessAsk.include"
[ -f "$rigWait" ] && [ -f "$rigAsk" ] || rigRefuse "the harness includes are not at the origin"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitInterruptWordingCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
## The reader: does one file say both that the wait is interrupted and that the member may continue or cancel?
rigSaysInterrupt(){ ## file -- interrupted, and both ways on
	local sawInterrupt="no" sawContinue="no" sawCancel="no"
	LC_ALL=C grep -q -i -e 'interrupt' "$1" 2> /dev/null && sawInterrupt="yes"
	LC_ALL=C grep -q -i -e 'continue the wait' -e 'Wait mode=continue' "$1" 2> /dev/null && sawContinue="yes"
	LC_ALL=C grep -q -i -e 'cancel the task' -e 'cancel this task' "$1" 2> /dev/null && sawCancel="yes"
	printf '%s:%s:%s\n' "$sawInterrupt" "$sawContinue" "$sawCancel"
}

echo "-- 3. the instrument: the reader fails on the old wording --"
printf "# a close with only the continue line\nNEXT: if this is not what you are waiting for, call Wait mode=continue -- it resumes after what is shown here\n" > "$rigTmp/old.close"
printf 'This call returned because something else this session waits on arrived. It stays open and in your Wait set.\n' > "$rigTmp/old.ask"
rigAssert "the reader sees no interrupt wording in the old close, so a pass is a real pass" \
	"$( rigSaysInterrupt "$rigTmp/old.close" )" "no:yes:no"
rigAssert "and the old asking-call text names no cancel, so that reading fails too" \
	"$( LC_ALL=C grep -c -i 'cancel the task' "$rigTmp/old.ask" || : )" "0"

echo "-- 1. the wait's own next line --"
rigAssert "a returned wait tells the member the message interrupts it, and names continuing the wait and cancelling the task" \
	"$( rigSaysInterrupt "$rigWait" )" "yes:yes:yes"

echo "-- 2. the asking call's own result --"
rigAssert "an asking call's result names the call that goes on waiting" \
	"$([ "$( LC_ALL=C grep -c 'go on waiting for this answer' "$rigAsk" || : )" -ge 1 ] && printf named || printf absent )" "named"
rigAssert "and says the task may be cancelled instead" \
	"$( LC_ALL=C grep -c -i -e 'cancel the task' -e 'cancel this task' "$rigAsk" || : )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	printf '  --- the wording found, for the reader:\n'
	LC_ALL=C grep -n -i -e 'WAIT-RESULT: RECEIVED' -e 'NEXT: if this is not' -e 'NEXT: the message' "$rigWait" | head -8
	LC_ALL=C grep -n -i -e 'go on waiting for this answer' -e 'cancel' "$rigAsk" | head -6
	echo "⛔ WAIT INTERRUPT WORDING CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_INTERRUPT_WORDING: OK (%d assertions, offline)\n' "$rigPassCount"
