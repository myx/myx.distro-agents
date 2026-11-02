#!/usr/bin/env bash
## S7.18 — Enter alone kills nothing, and says what it waits for. Run, not read, against the REAL dispatcher.
## The screen's own code (sh-lib/manager/LocalManagerScreen.py) runs through the stand-in terminal of the driver, as
## AgentsManagerScreenKillCheck runs it. The difference is the dispatcher behind it: the real DistroAgentsTools.fn.sh in a
## scratch workspace of this rig (check-fixtures/manager-screen.live-rig.include.sh), never a stub. The session is a real
## one of that scratch workspace, so the real kill plan reads it. No session of this machine is read, and no run of it is
## signalled: the stand-in is the check's own and the check ends it.
##
## Held (epic 20261102-refactorings, S7.18; audit S7.16 item 9): `k` on a running session opens the kill dialog; Enter
## with the word field empty leaves that dialog open and tells the person the word typed is not `yes`, in the dialog or in
## the status line; and no kill reaches the dispatcher. Today the default button of a dialog whose required input is
## absent is its Cancel (AgentsManagerScreen.Dialogs.py:120-125), so Enter presses Cancel: the dialog closes, nothing is
## said, and the person cannot tell a refusal from a key that did nothing.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenKillLiveCheck )" || exit 1
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

rigLiveSession rig-live-1
rigLiveWhere kill

{
	printf 'at @activity active-sessions\n'
	printf 'wait sessions 120\nturn 3\n'
	printf 'select rig-live-1\nturn 2\n'
	printf 'keys k\n'
	printf 'wait plan 120\nwait sessions 60\nturn 4\n'
	printf 'get OPENED\n'
	printf 'keys ENTER\n'
	printf 'turn 4\nwait sessions 60\nturn 3\n'
	printf 'get AFTER\nsaid SAID\n'
} | rigLiveDrive

## The other half of the form, in a second session of the same rig: the word typed whole and Enter must really end it, and
## the form must say what it did. Held from the coordinator's 2026-11-02 note: the owner typed `yes` and the kill still did
## nothing, so this side is watched as well as the empty word's.
rigLiveSession rig-live-2
rigLiveWhere typed
{
	printf 'at @activity active-sessions\n'
	printf 'wait sessions 120\nturn 3\n'
	printf 'select rig-live-2\nturn 2\n'
	printf 'keys k\n'
	printf 'wait plan 120\nwait sessions 60\nturn 4\n'
	printf 'keys y e s\nturn 1\nkeys ENTER\n'
	printf 'wait action 180\nwait full 180\nturn 12\nwait sessions 120\nturn 8\n'
	printf 'get TYPED\n'
	printf 'rowids TYPEDROWS\n'
} | rigLiveDrive

rigWords="$( rigLiveVal AFTER dialogSays kill ) $( rigLiveVal SAID kill )"
rigAssert "k on a running session opens the kill dialog, its word field empty" \
	"$( rigLiveVal OPENED dialogTitle kill )" "Kill the session"
rigAssert "the dialog is the person's to type the word in" \
	"$( rigLiveVal OPENED dialog kill )" "kill:word|"
rigAssert "Enter with the word field empty leaves the dialog open" \
	"$( rigLiveVal AFTER dialog kill )" "kill:word|"
rigAssert "and says the word typed is not yes" \
	"$( rigHas "$rigWords" "the word typed is not yes" )" "yes"
## The plan is read while the dialog is open (`--plan`, which ends nothing): that line is the one allowed.
rigAssert "no kill reaches the dispatcher on the empty word" \
	"$( LC_ALL=C grep '^--manager-session-kill' "$rigTmp/calls-kill.log" | LC_ALL=C grep -c -v -e '--plan' || : )" "0"
rigAssert "the plan was read, so the dialog really was open on a session" \
	"$( rigLiveCalls '^--manager-session-kill --session-id rig-live-1 --plan$' kill )" "1"
rigAssert "the word yes and Enter does ask the dispatcher for the kill" \
	"$( rigLiveCalls '^--manager-session-kill --session-id rig-live-2$' typed )" "1"
rigAssert "and the form says what it did" \
	"$( rigHas "$( rigLiveVal TYPED notice typed )" "the session reads finished" )" "yes"
rigAssert "and the session is gone from the running ones" \
	"$( rigHas "$( rigLiveVal TYPEDROWS TYPEDROWS typed )" "rig-live-2" )" "no"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN KILL LIVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_KILL_LIVE: OK (%d assertions, the real dispatcher)\n' "$rigPassCount"
