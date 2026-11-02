#!/usr/bin/env bash
## S7.22 — Enter on a subsystem row of `Installed Subsystems` opens that subsystem's installer dialog.
## Run, not read, against the REAL dispatcher: the screen's own code through the stand-in terminal of the driver, with the
## real DistroAgentsTools.fn.sh in a scratch workspace of this rig (check-fixtures/manager-screen.live-rig.include.sh), so
## the subsystems and the commands they are offered are the tooling's own.
##
## Held (epic 20261102-refactorings, S7.22; audit S7.16 item 4): Enter on a subsystem row opens the dialog of the command
## that subsystem offers, `install` where it offers one, and the dialog names `--manager-subsystem-run install <name>`. The
## indented command row keeps working as it does. Today Enter on the subsystem row answers "Open: this row has nothing to
## open": LocalManagerScreen.Subsystems.py:200-203 holds `on: ("subsystems:subsystem-command",)` only, and the subsystem
## row (`:71`) has no main action.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenSubsystemLiveCheck )" || exit 1
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

rigLiveWhere subsystems
{
	printf 'at @subsystems\n'
	printf 'wait list 120\nturn 3\n'
	printf 'select deploy\nturn 2\n'
	printf 'get ROW\n'
	printf 'keys ENTER\n'
	printf 'wait action 60\nwait list 60\nturn 4\n'
	printf 'get SYSTEM\n'
} | rigLiveDrive

## The known positive in the same rig: the indented command row, which works today, opens the very dialog the subsystem
## row is asked to open. Without it a bare "no dialog" would be a finding about the probe, not the screen.
rigLiveWhere command
{
	printf 'at @subsystems\n'
	printf 'wait list 120\nturn 3\n'
	printf 'select deploy:install\nturn 2\n'
	printf 'keys ENTER\n'
	printf 'wait action 60\nwait list 60\nturn 4\n'
	printf 'get COMMANDROW\n'
} | rigLiveDrive

## The third case, on a subsystem whose only command is update: the console is installed in this rig, so `agents` offers
## update alone (LocalTools.ManagerSubsystem.include). Enter must open that one, "Update agents".
rigLiveSubsystemInstalled agents
rigLiveWhere updateonly
{
	printf 'at @subsystems\n'
	printf 'wait list 120\nturn 3\n'
	printf 'select agents\nturn 2\n'
	printf 'get UROW\n'
	printf 'keys ENTER\n'
	printf 'wait action 60\nwait list 60\nturn 4\n'
	printf 'get UPD\n'
} | rigLiveDrive

rigAssert "a subsystem that offers install is in the list and selected" \
	"$( rigLiveVal ROW selected screen-subsystems )" "deploy"
rigAssert "the command row below it opens its installer dialog: the probe can see one" \
	"$( rigLiveVal COMMANDROW dialogTitle screen-command )" "Install deploy"
rigAssert "Enter on the subsystem row opens that installer dialog too" \
	"$( rigLiveVal SYSTEM dialogTitle screen-subsystems )" "Install deploy"
rigAssert "and the dialog names the operation for that subsystem" \
	"$( rigLiveVal SYSTEM dialogHolds screen-subsystems )" "runs: install deploy / by: --manager-subsystem-run / It installs the toolset: its package is cloned into .local of the workspace and the console command for it is made. It runs at once and unattended, in a window that follows what it writes. Run starts it; Cancel and Esc do nothing."
rigAssert "a subsystem whose only command is update is selected" \
	"$( rigLiveVal UROW selected updateonly )" "agents"
rigAssert "Enter on it opens Update, named for that subsystem" \
	"$( rigLiveVal UPD dialogTitle updateonly )" "Update agents"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN SUBSYSTEM LIVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_SUBSYSTEM_LIVE: OK (%d assertions, the real dispatcher)\n' "$rigPassCount"
