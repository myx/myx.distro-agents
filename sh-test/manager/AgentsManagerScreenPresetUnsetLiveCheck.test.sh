#!/usr/bin/env bash
## S7.27 — `d` on a preset key whose value is unset says the key holds nothing, and calls nothing.
## Run, not read, against the REAL dispatcher: the screen's own code through the stand-in terminal of the driver, with the
## real DistroAgentsTools.fn.sh in a scratch workspace of this rig (check-fixtures/manager-screen.live-rig.include.sh),
## holding one preset of its own, so `--manager-scope-read` prints the key rows the screen shows.
##
## Held (epic 20261102-refactorings, S7.27; audit S7.16 item 10): the screen offers `d` on the rows whose state reads
## `missing` too, and the operation refuses a key the scope does not hold by design
## (LocalTools.ManagerScope.include:316-319). The screen refuses first, as it does elsewhere, and calls nothing. Today the
## dialog opens, Enter calls `--manager-scope-unset`, and the answer is the box "The change failed".
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenPresetUnsetLiveCheck )" || exit 1
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

## The fixture: one preset of the scratch workspace, holding one key. Every other key of the preset's catalogue reads
## `missing`, which is what the key under test is.
rigLivePreset rig 'PRESET_CLI_SERVICE=anthropic'
rigScope="agents:preset-rig"

## The key under test: one the scope does not hold.
rigLiveWhere unset
{
	printf 'at configuration clipresets presets %s\n' "$rigScope"
	printf 'wait list 120\nturn 3\n'
	printf 'select PRESET_MODEL_OR_MACRO\nturn 2\n'
	printf 'get ROW\n'
	printf 'keys d\n'
	printf 'wait action 60\nwait list 60\nturn 4\n'
	printf 'get PRESSED\n'
	printf 'keys ENTER\n'
	printf 'wait action 60\nwait list 60\nturn 4\n'
	printf 'get AFTER\n'
} | rigLiveDrive

## The known positive: a key the scope does hold, whose `d` really does ask and then call. Without it "nothing was
## called" would be a finding about the probe.
rigLiveWhere held
{
	printf 'at configuration clipresets presets %s\n' "$rigScope"
	printf 'wait list 120\nturn 3\n'
	printf 'select PRESET_CLI_SERVICE\nturn 2\n'
	printf 'keys d\n'
	printf 'wait action 60\nwait list 60\nturn 4\n'
	printf 'keys ENTER\n'
	printf 'wait action 60\nwait list 60\nturn 4\n'
	printf 'get HELD\n'
} | rigLiveDrive

rigAssert "the key under test is one the preset does not hold" \
	"$( rigLiveVal ROW selected unset )" "PRESET_MODEL_OR_MACRO"
rigAssert "d on a key the preset holds does ask, and calls: the probe can see one" \
	"$( rigLiveCalls "^--manager-scope-unset $rigScope PRESET_CLI_SERVICE\$" held )" "1"
rigAssert "d on the unset key calls nothing" \
	"$( rigLiveCalls "^--manager-scope-unset $rigScope PRESET_MODEL_OR_MACRO\$" unset )" "0"
rigAssert "no failure box opens on it" \
	"$( rigLiveVal AFTER dialogTitle unset )" ""
rigAssert "the status line says the key holds nothing" \
	"$( rigLiveVal AFTER notice unset )" "the key holds nothing"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN PRESET UNSET LIVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_PRESET_UNSET_LIVE: OK (%d assertions, the real dispatcher)\n' "$rigPassCount"
