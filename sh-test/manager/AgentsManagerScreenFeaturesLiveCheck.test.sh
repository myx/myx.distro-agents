#!/usr/bin/env bash
## S7.23 — Enter on a feature or a part row of `Optional Features` opens that row's own installer dialog, not the agreed
## set's. Run, not read, against the REAL dispatcher: the screen's own code through the stand-in terminal of the driver,
## with the real DistroAgentsTools.fn.sh in a scratch workspace of this rig (check-fixtures/manager-screen.live-rig.include.sh),
## so the features and the commands they are offered are the tooling's own.
##
## Held (epic 20261102-refactorings, S7.23; audit S7.16 item 5): Enter on a feature or a part row opens the dialog that
## reads the plan of the command the row offers, `--manager-feature-part install <feature> <part>`. The indented command
## row keeps opening the same dialog, as it does today. Today Enter on those rows opens `Install the agreed set`:
## LocalManagerScreen.Features.py:500-503 resolves their main action to `featureset`, and the `feature` command stands on
## command rows only (:497-499).
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenFeaturesLiveCheck )" || exit 1
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
rigPart="setup.feature-local-ai/qwen3.5-4b-q8_0"

## The row under test: a part of a feature, Enter pressed on it.
rigLiveWhere part
{
	printf 'at @features\n'
	printf 'wait list 120\nturn 3\n'
	printf 'select %s\nturn 2\n' "$rigPart"
	printf 'get ROW\n'
	printf 'keys ENTER\n'
	printf 'wait list 60\nwait plan 60\nwait full 60\nwait action 60\nturn 4\n'
	printf 'get PART\n'
} | rigLiveDrive

## The known positive: the indented command row of that part, which opens its plan dialog today. Without it a bare "the
## wrong dialog says nothing about this one" would be a finding about the probe.
rigLiveWhere command
{
	printf 'at @features\n'
	printf 'wait list 120\nturn 3\n'
	printf 'select %s:install\nturn 2\n' "$rigPart"
	printf 'keys ENTER\n'
	printf 'wait list 60\nwait plan 60\nwait full 60\nwait action 60\nturn 4\n'
	printf 'get COMMANDROW\n'
} | rigLiveDrive

## The case magic-developer raised: a feature row that offers no command. The tooling gives `setup.feature-local-ai` no
## install, update or uninstall of its own (its parts carry them), so Enter on that row must call nothing and open no
## dialog. The known positive beside it is `i` on the same row, which is the agreed set's own key and must still work.
rigLiveWhere nocommand
{
	printf 'at @features\n'
	printf 'wait list 120\nturn 3\n'
	printf 'select setup.feature-local-ai\nturn 2\n'
	printf 'keys ENTER\n'
	printf 'wait list 60\nwait full 60\nwait action 60\nturn 4\n'
	printf 'get FEATURE\n'
	printf 'keys ESC\nturn 2\n'
	printf 'keys i\n'
	printf 'wait list 60\nwait full 60\nwait action 60\nturn 4\n'
	printf 'get AGREEDSET\n'
} | rigLiveDrive

rigAssert "a part of a feature is in the list and selected" \
	"$( rigLiveVal ROW selected part )" "$rigPart"
rigAssert "the command row below it opens that part's plan dialog: the probe can see one" \
	"$( rigLiveVal COMMANDROW dialogTitle command )" "Install qwen3.5-4b-q8_0"
rigAssert "Enter on the part row opens that part's plan dialog" \
	"$( rigLiveVal PART dialogTitle part )" "Install qwen3.5-4b-q8_0"
rigAssert "it is not the agreed set's dialog" \
	"$( rigLiveVal PART dialog part )" "feature-part:run|"
rigAssert "the plan read that reached the dispatcher is that part's own" \
	"$( rigLiveCalls '^--manager-feature-part install setup[.]feature-local-ai qwen3[.]5-4b-q8_0$' part )" "1"
rigAssert "Enter on a feature row that offers no command calls nothing" \
	"$( rigLiveCalls '^--manager-feature-(part|models)' nocommand )" "0"
rigAssert "and opens no dialog" \
	"$( rigLiveVal FEATURE dialog nocommand )" ""
rigAssert "the agreed set is still its own key on that row, so the probe can see one" \
	"$( rigLiveVal AGREEDSET dialog nocommand )" "feature-set:profile|"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN FEATURES LIVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_FEATURES_LIVE: OK (%d assertions, the real dispatcher)\n' "$rigPassCount"
