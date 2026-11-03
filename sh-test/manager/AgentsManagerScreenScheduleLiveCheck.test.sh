#!/usr/bin/env bash
## S7.20, the screen half — Enter on a flag row of `Magic-Team > Schedule` opens that flag's dialog, and its Set calls the
## write arm. Run, not read, against the REAL dispatcher: the screen's own code through the stand-in terminal of the driver,
## with the real DistroAgentsTools.fn.sh in a scratch workspace of this rig (check-fixtures/manager-screen.live-rig.include.sh).
##
## Held (epic 20261102-refactorings, S7.20; audit S7.16 item 1): Enter on a flag row opens a dialog of its own. For the flags
## set by hand, `learning` among them, that dialog sets the flag, and the set reaches the tooling through
## `--manager-schedule-override-flag`, which the schedule read then reports. Today the row answers
## "Open: this row has nothing to open" (AgentsManagerScreen.Schedule.py:171-182 registers no commands).
##
## The check names no dialog of the screen's own: it asserts what the person sees and what reaches the dispatcher, so the
## dialog may be named and laid out as its builder chooses.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenScheduleLiveCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export TZ=UTC
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/manager-screen.live-rig.include.sh" || exit 1
rigLiveSetup
trap 'rigLiveEnd ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHas(){ ## text, words -- yes where the text holds them
	case "${1:-}" in *"$2"*) printf yes ;; *) printf no ;; esac
}

## Enter on a flag the operator may set: the dialog opens, and its default button is pressed.
rigLiveWhere flag
{
	printf 'at magic-team schedule\n'
	printf 'wait list 120\nturn 3\n'
	printf 'select learning\nturn 2\n'
	printf 'get ROW\n'
	printf 'keys ENTER\n'
	printf 'wait list 60\nwait full 60\nwait action 60\nturn 4\n'
	printf 'get DIALOG\n'
	printf 'keys ENTER\n'
## The Set is asked at once and its answer lands a read or two later: the drive waits on the action and the read that
## follows it, so what it asserts is the frame after the tooling answered, not the one that asked.
	printf 'wait action 120\nwait full 120\nwait list 120\nturn 10\n'
	printf 'get SET\n'
} | rigLiveDrive

## The known positive of the same rig, straight at the dispatcher: the arm the dialog must call really works, so a missing
## call above is the screen's and not the operation's.
rigLiveOpCall(){ rigLiveOp "$@" ; }
rigArm="$( rigLiveOpCall --manager-schedule-override-flag learning )"
rigLiveOpCall --manager-schedule-override-flag --no learning > /dev/null 2>&1 || :

rigAssert "the flag row is in the list and selected" \
	"$( rigLiveVal ROW selected flag )" "learning"
rigDialog flag DIALOG
rigAssert "Enter on it opens a dialog of its own" "$rigDialogKind" "opened"
rigAssert "the arm the dialog calls answers on this rig" "$( rigHas "$rigArm" "learning" )" "yes"
rigAssert "its Set reaches the dispatcher through --manager-schedule-override-flag" \
	"$( rigLiveCalls '^--manager-schedule-override-flag( --no)? learning' flag )" "1"
rigAssert "and the screen says what the flag now is" \
	"$( rigHas "$( rigLiveVal SET notice flag )$( rigLiveVal SET dialogSays flag )" "learning" )" "yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN SCHEDULE LIVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_SCHEDULE_LIVE: OK (%d assertions, the real dispatcher)\n' "$rigPassCount"
