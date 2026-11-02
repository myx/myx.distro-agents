#!/usr/bin/env bash
## S7.26 — Selecting a routine in `Routines` shows its text and its verdicts, with no "A read failed" modal.
## Run, not read, against the REAL dispatcher: the screen's own code through the stand-in terminal of the driver, with the
## real DistroAgentsTools.fn.sh in a scratch workspace of this rig (check-fixtures/manager-screen.live-rig.include.sh),
## holding one routine of the rig's own member folder, so `--manager-routine-list` and `--manager-routine-text` are the
## tooling's own.
##
## Held (epic 20261102-refactorings, S7.26; audit S7.16 item 8): selecting a routine shows its text in the left pane and
## then its verdicts, and no failure box opens. Today AgentsManagerScreen.Routines.py:265 calls
## `--manager-routine-text <selector> --with-verdict`, and the operation wants `--with-verdict` first
## (AgentsTools.ManagerRoutine.include:414-421), so the read fails and the screen opens "A read failed".
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenRoutinesLiveCheck )" || exit 1
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

## The fixture: one routine of the rig's own member folder, with what a routine carries. It is the rig's, not the estate's.
rigLiveSkill magic-tester magic-tester.riglive.routine.md <<'EOF'
---
type: routine
executors: magic-coordinator
maintainers: magic-tester
runs-at: none
---
# A routine of the rig

It exists so that the screen's routine read has a real routine to read.
EOF

rigLiveWhere routines
{
	printf 'at magic-team routines\n'
	printf 'wait list 120\nturn 3\n'
	printf 'select magic-tester/magic-tester.riglive.routine.md\n'
	printf 'wait view 120\nturn 4\n'
	printf 'get ROW\n'
	printf 'show PANE\n'
} | rigLiveDrive

rigAssert "the rig's routine is in the list and selected" \
	"$( rigLiveVal ROW selected routines )" "magic-tester/magic-tester.riglive.routine.md"
## The known positive, straight at the dispatcher of the same rig: the very read the screen makes, with the flag the
## operation wants first, answers. Without it a failing read would say nothing about the order the screen uses.
rigPositive="$( rigLiveOp --manager-routine-text --with-verdict magic-tester.riglive.routine.md )"
rigAssert "the same read with the flag first answers, so the routine and the operation are sound" \
	"$( rigHas "$rigPositive" "A routine of the rig" )" "yes"
rigAssert "the screen did read the routine's text through the dispatcher" \
	"$( [ "$( rigLiveCalls '^--manager-routine-text' routines )" -ge 1 ] && printf yes || printf no )" "yes"
rigAssert "no failure box opened" \
	"$( rigLiveVal ROW dialogTitle routines )" ""
rigAssert "and no read of the pane failed" \
	"$( rigLiveVal ROW failed routines )" ""
rigAssert "the left pane shows the routine's own text" \
	"$( rigHas "$( cat "$rigTmp/screen-routines.out" )" "It exists so that the screen's routine read has a real routine to read." )" "yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN ROUTINES LIVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_ROUTINES_LIVE: OK (%d assertions, the real dispatcher)\n' "$rigPassCount"
