#!/usr/bin/env bash
## S7.21 — Enter on an `Install ...` row of `This Machine > Local AI` opens that part's own plan dialog.
## Run, not read, against the REAL dispatcher: the screen's own code through the stand-in terminal of the driver, with the
## real DistroAgentsTools.fn.sh in a scratch workspace of this rig (check-fixtures/manager-screen.live-rig.include.sh), so
## the parts the screen shows are the tooling's own, and the plan the dialog reads is the tooling's own plan.
##
## Held (epic 20261102-refactorings, S7.21; audit S7.16 item 3): the `Install ...` rows of `Local AI` carry the command
## `--manager-feature-part install <feature> <part>`, and Enter on one opens the dialog that reads that plan. Today the row
## answers "Open: this row has nothing to open": LocalManagerScreen.Features.py:497-503 names the view `local-ai` with the
## places `local-ai:feature-command`, and the plugin `local-ai` is mounted at `machine`, so the real place is
## `machine/local-ai:feature-command` and no command matches.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenLocalAiLiveCheck )" || exit 1
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
rigRow="setup.feature-local-ai/stt-whisper-large-v3-turbo-q5_0:install"

rigLiveWhere local-ai
{
	printf 'at machine local-ai\n'
	printf 'wait list 120\nturn 3\n'
	printf 'select %s\nturn 2\n' "$rigRow"
	printf 'get BEFORE\n'
	printf 'keys ENTER\n'
	printf 'wait list 60\nwait plan 60\nwait full 60\nwait action 60\nturn 4\n'
	printf 'get AFTER\n'
} | rigLiveDrive

## The known positive, in the same run: the identical command row of `Optional Features`, where the view is named as the
## command names it, opens the dialog. Without it a bare "no dialog" would be a finding about the probe, not the screen.
rigLiveWhere features
{
	printf 'at @features\n'
	printf 'wait list 120\nturn 3\n'
	printf 'select %s\nturn 2\n' "$rigRow"
	printf 'keys ENTER\n'
	printf 'wait list 60\nwait plan 60\nwait full 60\nwait action 60\nturn 4\n'
	printf 'get CONTROL\n'
} | rigLiveDrive

rigAssert "an Install row of the local AI is in the list and selected" \
	"$( rigLiveVal BEFORE selected screen-local-ai )" "$rigRow"
rigAssert "the same row on Optional Features opens the part's plan dialog: the probe can see one" \
	"$( rigLiveVal CONTROL dialog screen-features )" "feature-part:run|"
rigAssert "Enter on it opens that part's plan dialog in Local AI too" \
	"$( rigLiveVal AFTER dialog screen-local-ai )" "feature-part:run|"
rigAssert "the dialog is titled for the command the row offers" \
	"$( rigLiveVal AFTER dialogTitle screen-local-ai )" "Install stt-whisper-large-v3-turbo-q5_0"
rigAssert "the plan read that reached the dispatcher is that part's own" \
	"$( rigLiveCalls '^--manager-feature-part install setup[.]feature-local-ai stt-whisper-large-v3-turbo-q5_0$' local-ai )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	rigLiveEnd
	echo "⛔ MANAGER SCREEN LOCAL AI LIVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
rigLiveEnd
printf 'MANAGER_SCREEN_LOCAL_AI_LIVE: OK (%d assertions, the real dispatcher)\n' "$rigPassCount"
